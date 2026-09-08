# Known Issues & Hardware Quirks

This document tracks known limitations, hardware-specific edge cases, and in-progress fixes for the Blackwell eGPU Manager.

---

### 1. Mode 5 (iGPU Restore): Black screen on Intel internal laptop panels (eDP)
* **Status:** In Progress / Open
* **Affected Platforms:** Laptops with Intel integrated graphics (e.g., Tiger Lake / Iris Xe / Core Ultra) running Wayland (KWin).
* **Unaffected Platforms:** Desktop / Mini PC setups (e.g., AMD HawkPoint) with external DP/HDMI monitors.
* **Symptom:**
  After executing `Mode 5` (iGPU Restore) from `Mode 4` (eGPU-only), the internal laptop display (`eDP-1`) is enumerated and marked as active in Display Settings, but the physical panel remains dark/black.
* **Root Cause (Hypothesis):**
  The driver rebind / PCIe rescan sequence properly restores the device node and pipeline in KWin, but fails to re-initialize the panel power sequencing or backlight PWM duty cycle (`intel_backlight`) via the embedded DisplayPort (eDP) AUX channel.
* **Current Workaround:**
  A full system reboot is currently required to wake up and restore display output on the internal laptop panel after executing `Mode 5`.

---

### 2. Audio Endpoint Priority Shift (Mode 3) & Disappearance (Mode 6)
  * **Status:** Resolved in v1.5.6 (Hardware Quirk Handled)
  * **Affected Platforms:** Laptops and hosts with built-in ALSA/SoundWire endpoints or external USB DACs/soundbars.
* **Symptom:**
  When entering `Mode 3`, the appearance of the NVIDIA HDMI/DP audio controller may cause PipeWire/WirePlumber to switch default sink routing or rename active speaker endpoints, though the internal audio device remains active and fully functional throughout `Mode 3`. Previously, after executing `Mode 6` (Safe Detach), internal or external audio devices could disappear entirely from the system's output list.
* **Resolution (v1.5.6):**
  Resolved via automated `udevadm trigger --action=add` targeting sound cards in `/sys/class/sound/card*` that lost the `SOUND_INITIALIZED=1` flag during DRM teardown. PipeWire restores the audio sinks immediately without requiring a reboot or physical USB reconnect.

---

### 3. BAR0 Allocation Failure on Non-HotPlug Upstream Ports (`BAR0 is 0M @ 0x0`)
  * **Status:** Mitigated in v1.5.6 (Automated Safety Guard)
  * **Affected Platforms:** Hosts running custom/patched kernels (e.g., `pci=realloc=off`), or Thunderbolt/USB4 enclosures (e.g., Barlow Ridge / JHL9480) whose downstream GPU ports lack native `pciehp` (HotPlug) capability.
* **Symptom:**
  During `Mode 3` initialization, the driver probe fails with `NVRM: BAR0 is 0M @ 0x0` or `can't assign; no space` errors in `dmesg`.
* **Root Cause:**
  A two-phase enumeration timing race: the root port rescan sizes the PCIe switch windows before the eGPU link has finished training, locking the address window to a minimal fallback size (e.g., 6 MB) and denying space for BAR0/BAR1 allocation.
* **Resolution (v1.5.6):**
  Added an automatic verification check directly reading `/sys/bus/pci/devices/$GPU_FULL_PCI/resource` following the initial rescan. If BAR0 allocation is zero, the script transparently resets the upstream bridge port, allows the link to finish training, and triggers a clean re-enumeration where the correct memory window is granted.

  
### 4. Dynamic Power Management Configuration (`NVreg_DynamicPowerManagement=0x00`) vs. Distro Defaults
* **Status:** Handled via Runtime Clock Locks (Design Choice)
* **Affected Platforms:** Distributions (such as CachyOS/Arch) shipping default drop-in files (e.g., `/usr/lib/modprobe.d/nvidia.conf`) enforcing `NVreg_DynamicPowerManagement=0x02` (RTD3/D3cold).
* **Symptom:**
  During cold plug or dynamic modalias loading, the driver can initialize with distribution-level `DPM=2`, ignoring runtime module parameters passed via `modprobe` if the driver was already autoloaded.
* **Rationale & Handling (v1.5.6):**
  The project intentionally rejects deploying static overrides into `/etc/modprobe.d/`. Modprobe configuration hierarchies vary across distributions and are prone to being overwritten or causing package conflicts during routine system updates. Instead, `blackwell-egpu` ensures link and tunnel stability at runtime: in `Mode 3`, persistent clock locks (`--lock-gpu-clocks` and `--lock-memory-clocks`) combined with driver persistence mode keep the hardware strictly in `P0`, preventing D3cold entry and Xid timeouts regardless of distribution modprobe defaults.
