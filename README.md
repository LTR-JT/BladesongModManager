# Bladesong Mod Manager

Standalone in-game mod management for Bladesong. Requires working UE4SS, **not BladesongModFramework**. Source candidate 0.1.3.

The manager owns the main-menu Mods entry, catalogue, dependency plans, install/update, uninstall and ownership tools. Its services, JSON parser, menu container and tab renderer are self-contained. It uses stock game widgets and never loads a framework module or PCL asset to open its menu.

[BladesongModFramework](https://github.com/LTR-JT/BladesongModFramework) owns the shared Creative menu base and compatibility services for SDK mods. If a selected mod requires it, the manager adds one compatible framework to the reviewed dependency plan. The manager itself keeps running without it.

## Installing

Close Bladesong, extract the Easy Install With UE4SS package and run INSTALL.cmd. This installs UE4SS and the manager only. With UE4SS already installed, copy the manager Runtime ZIP and enable BladesongModManager in Mods/mods.txt. Framework and PCL are not bundled. Existing framework files and saves are preserved. The Easy Install download includes UE4SS and the manager; the Runtime download is for an existing UE4SS installation.

## Building

BladesongSDK is a build-time schema/packaging dependency only, pinned in BuildDependencies.json. No framework source checkout or installation is needed.

```powershell
python Tools/run_checks.py --lua C:/path/to/lua.exe
python Tools/package_release.py
python Tools/build_bootstrap.py
python Tools/build_easy_install.py
python Tools/check_packages.py
```

SDK runtime capability checks are deferred to the framework after launch; package planning validates API and dependency metadata. Explicit raw-native manifests still require an exact executable hash. Optional SDK settings/page access uses serialized runtime messages only when a framework is running.

With the legacy combined framework installed, its old Mods button is collapsed without destroying the widget; the standalone manager supplies the active button. Creative UI is unchanged. Provenance and MIT attribution are preserved in UPSTREAM.md and LICENSE. Releases require manual dispatch or an explicitly approved, version-matched change to .github/release-plan.json. Ordinary source changes do not publish a release.

## Library data on uninstall

The in-game manager preserves `Data`, `Scripts/preconstructions` (including its blade library and previews), and `Scripts/blades` in `BMF_UserData/<mod-id>` beside the game executable. Reinstall restores missing library files automatically. The original runtime folder is also retained in `BMF_Uninstalled`.

For older uninstalls without a separate data copy, reinstall can restore the data from the latest matching uninstall archive. Keep those backup folders if they contain your only copy of a library.

## Automatic updates during normal startup

An independent UE4SS bootstrap checks for a new official Mod Manager release in the background before the manager menu initializes. It still runs if the menu module fails to initialize, and it does not use the framework or game UI objects.

Verified updates are staged and applied after Bladesong exits normally. The game is never closed or restarted automatically. Your next launch uses the update. No Steam launch option or extra shortcut is required.

Turn off **Automatically update Mod Manager** in Settings to disable this behavior. Pending user changes, local edits and deployments owned by another manager are preserved. UE4SS itself must still start; if a game update prevents UE4SS from loading at all, update UE4SS manually.
