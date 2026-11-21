# Safe eGPU hot-plug / detach helpers (AMD HawkPoint USB4 + Intel TB5 + NVIDIA Blackwell)
unalias egpu-on egpu-off 2>/dev/null || true

egpu-on() {
    for _ in {1..10}; do
        boltctl list 2>/dev/null | grep -Eq 'status:[[:space:]]+authorizing' || break
        sleep 0.5
    done
    local st mode link
    st=$(blackwell-egpu status)
    mode=$(echo "$st" | grep -o '"mode":[0-9]' | cut -d: -f2)
    if [ "$mode" = "0" ]; then
        echo "[eGPU] Device not detected. Check dock power switch and USB4 cable."
        return 1
    elif [ "$mode" = "3" ]; then
        echo "[eGPU] Already active (Mode 3)."
        nvidia-smi
        return 0
    fi
    echo "[eGPU] Initializing PCIe Gen4 tunnel and loading NVIDIA Open driver..."
    sync
    sudo blackwell-egpu set 3
    st=$(blackwell-egpu status)
    mode=$(echo "$st" | grep -o '"mode":[0-9]' | cut -d: -f2)
    link=$(echo "$st" | grep -o '"link":"[^"]*"' | cut -d'"' -f4)
    if [ "$mode" = "3" ]; then
        systemctl --user restart btop-bg.service 2>/dev/null || true
        echo "[eGPU] Online! Link: ${link:-OK}"
        nvidia-smi
    else
        echo "[eGPU] Failed to enter Mode 3 (current mode: ${mode:-unknown})."
        return 1
    fi
}

egpu-off() {
    echo "[eGPU] Safely detaching GPU (Mode 6)..."
    systemctl --user stop btop-bg.service 2>/dev/null || true
    sudo blackwell-egpu set 6
    local st mode
    st=$(blackwell-egpu status)
    mode=$(echo "$st" | grep -o '"mode":[0-9]' | cut -d: -f2)
    systemctl --user start btop-bg.service 2>/dev/null || true
    if [ "$mode" != "3" ]; then
        echo "[eGPU] Detached safely. Safe to unplug USB4 cable."
    else
        echo "[eGPU] Still busy (active processes detected). Close GPU apps or run 'egpu-off' once more to force kill."
        return 1
    fi
}
