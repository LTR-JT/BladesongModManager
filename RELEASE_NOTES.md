Unpublished standalone manager 0.1.2 candidate

Fixed the Mods button disappearing when UE4SS returns a fresh Lua proxy for the same native widget. Legacy combined-manager filtering now compares native addresses, preserves the standalone button and restores its visibility. Added a regression reproducing the disappearing button with distinct wrappers sharing a native address.

The manager still runs on UE4SS alone. Creative base UI and SDK compatibility remain in the optional framework. No release publication is authorized; live verification of this fix is pending.
