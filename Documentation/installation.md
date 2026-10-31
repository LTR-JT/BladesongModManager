# Installation

These instructions describe the **unpublished split-component candidate**. Existing public 0.1.7 packages still combine the manager with the runtime.

## Optional in-game manager: easiest bootstrap

1. Close Bladesong.
2. Extract `BladesongModManager_0.1.0_Easy_Install_With_UE4SS.zip` completely.
3. Open the extracted folder and run `INSTALL.cmd`.
4. Select the Steam Bladesong folder if asked.
5. Start Bladesong and click Mods above Options.

This one-time package includes configured UE4SS, one framework installation and the separate manager mod. Debug windows are disabled. It is an installer, not a player-facing launcher. Existing saves and libraries are preserved; replaced files are backed up in BMF_Backups. Bootstrap transfers maintenance of these two components to the in-game manager through their deployment records.

If UE4SS is already installed, the smaller Bootstrap ZIP contains just the runtime and manager. Copy its Bladesong folder into the Steam game folder, then enable BladesongModFramework and BladesongModManager in `Bladesong/Binaries/Win64/ue4ss/Mods/mods.txt`. Put the framework first. The package contains separate folders, never a framework copy inside each mod.

## Runtime without the manager

Install compatible UE4SS, then copy the framework Runtime ZIP's Bladesong folder into the Steam game folder. Enable BladesongModFramework in UE4SS. Install PCL or another SDK mod and enable it after the framework. Do not install BladesongModManager. PCL's Forge button, hotkeys and Creative provider remain framework services and work without a manager.

Runtime.zip is a manual deployment overlay. Package.zip is the portable hashed archive for compatible managers. GitHub Source code is for development. A third-party manager should resolve the runtime dependency and use its own deployment ownership; no Vortex extension is currently supplied.

## Updating an existing combined installation

Back up saves, framework Data and PCL libraries first. The new runtime replaces the combined main.lua and offline helper; the manager is installed into its own folder. Old unused manager files and old pending jobs under framework Data are preserved and never automatically executed by the new runtime. Finish old approved transactions with the old manager before migrating. Do not transplant pending job files into the new manager. Manual ownership adoption requires a matching receipt and explicit confirmation. Older combined receipts did not track the shared LogicMods assets; use the verified bootstrap redeployment for that transition rather than silently claiming those files in an in-game update.

This source candidate has automated validation but still needs in-game testing before a release is approved.

Bootstrap packages and installation source are maintained at https://github.com/LTR-JT/BladesongModManager. Runtime-only packages remain in BladesongModFramework. SDK tools are maintained separately at https://github.com/LTR-JT/BladesongSDK.
