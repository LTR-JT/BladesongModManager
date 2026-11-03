## 0.1.9 candidate

- Independent startup updater checks and downloads the official standalone manager before its UI initializes, even when the menu module fails.
- Updates apply after normal game exit, without forced closure, restart, console windows or new Steam launch settings.
- Automatic manager updates are enabled by default and can be disabled in Settings.
- Existing changes, local edits, libraries and external ownership remain protected.

Bladesong Mod Manager 0.1.7

Standalone in-game mod manager. Requires UE4SS; no framework dependency.

- Browse, install, update, enable, disable and uninstall community mods.
- Preserve Parts/Blades libraries, preview images and settings when uninstalling; restore them on reinstall.
- Recover library data from older uninstall archives when no separate preserved copy exists.
- Reuse identical, unclaimed shared assets when reinstalling PCL. Different files and files owned by another mod remain protected.
- Show per-mod update progress and status. A repository without releases shows "No published releases yet".
- Use separated mod cards, inline installation review and readable confirmation buttons.
- Background downloads run without command windows. The main-menu Mods button uses the native menu page and supports mouse input.

Installation

First-time install: download Easy_Install_With_UE4SS.zip, extract it, close Bladesong, and run INSTALL.cmd. Follow START HERE.txt.

Already have UE4SS: download Runtime.zip, copy its Bladesong folder into your Steam Bladesong game folder, and enable BladesongModManager in ue4ss/Mods/mods.txt.

The manager does not bundle the framework or PCL. Install them through Browse when needed.
Library data is retained in BMF_UserData; original uninstalled folders are also retained in BMF_Uninstalled. Keep these folders if they contain your only library backup.
