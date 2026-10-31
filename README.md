# Bladesong Mod Manager

Optional in-game mod management for Bladesong: discovery, reviewed dependency plans, install/update, enable/disable, uninstall and safe manual adoption. Source candidate 0.1.0.

Requires [BladesongModFramework](https://github.com/LTR-JT/BladesongModFramework) 0.1.8 or newer on API 1.0.0 and working UE4SS. The framework and PCL operate without this manager.

## Player installation

Close Bladesong, extract the Easy Install With UE4SS package, and run INSTALL.cmd. It installs configured UE4SS, one shared framework and this optional manager. Debug windows are disabled. If UE4SS is installed already, use the smaller Bootstrap ZIP. This is one-time setup, not a player-facing launcher. These split packages are currently unpublished candidates.

## Building

Clone BladesongSDK beside this checkout for build-time schema and packaging tools. Manager helper compilation and ordinary manager-only packaging do not rebuild the framework. UI integration fixtures additionally use a framework source checkout. Both reviewed source revisions are recorded in BuildDependencies.json; use BMF_SDK_ROOT and BMF_FRAMEWORK_ROOT for alternate local locations.

```powershell
python Tools/run_checks.py --lua C:/path/to/lua.exe
python Tools/package_release.py
```

To build a first-install bootstrap, first build a verified framework Runtime ZIP from its repository, then:

```powershell
python Tools/build_bootstrap.py --framework-archive ../BladesongModFramework/Releases/BladesongModFramework_0.1.8_Runtime.zip
python Tools/build_easy_install.py
python Tools/check_packages.py
```

The UE4SS snapshot is hash-pinned to an immutable historical source URL and fetched only by the packaging tool if absent. No runtime code depends on another manager. Vortex integration is future work and is not claimed as verified.

The existing implementation was extracted from BladesongModFramework, preserving attribution and its original repository history. See UPSTREAM.md. Releases require explicit manual dispatch; pushing source does not publish a release. MIT license.
