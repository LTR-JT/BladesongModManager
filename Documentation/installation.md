# Standalone manager installation

The Mod Manager requires UE4SS only. It does not require or install the framework during its own bootstrap.

Close Bladesong. Extract the Easy Install With UE4SS ZIP and run INSTALL.cmd. Start the game and click Mods above Options. If UE4SS is already installed, copy the manager Runtime ZIP and enable BladesongModManager in Mods/mods.txt.

Select a mod in Browse. Review its dependency plan. PCL and other SDK mods can require BladesongModFramework; the manager resolves that as a dependency of the selected mod, then installs it once before its dependents. The framework provides shared Creative UI and game compatibility, not the manager's startup or panel.

The installer preserves framework files, saves and libraries. Legacy combined framework Mods buttons are collapsed in the current menu session to avoid duplicates. New packages are unpublished candidates and need in-game verification.
