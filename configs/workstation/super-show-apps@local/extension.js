import GObject from 'gi://GObject';
import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

export default class SuperShowAppsExtension extends Extension {
    enable() {
        this._origHandlerId = GObject.signal_handler_find(global.display, {
            signalId: 'overlay-key',
        });
        if (this._origHandlerId)
            global.display.block_signal_handler(this._origHandlerId);

        this._handlerId = global.display.connect('overlay-key', () => {
            if (Main.overview.animationInProgress)
                return;

            if (Main.overview.visible) {
                if (Main.overview.dash.showAppsButton.checked)
                    Main.overview.hide();
                else
                    Main.overview.showApps();
            } else {
                Main.overview.showApps();
            }
        });
    }

    disable() {
        if (this._handlerId) {
            global.display.disconnect(this._handlerId);
            this._handlerId = null;
        }
        if (this._origHandlerId) {
            global.display.unblock_signal_handler(this._origHandlerId);
            this._origHandlerId = null;
        }
    }
}
