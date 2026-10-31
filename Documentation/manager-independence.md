# Manager-independent platform

This is an unpublished source candidate, continuing the existing repositories and frozen SDK contracts. It does not replace the published 0.1.7 release or claim new in-game verification.

## Audit before changes

Already separated: API 1.0.0, historical contract facade, exact-executable compatibility profiles and native adapters, cross-state messaging, shared Creative/Story UI, and PCL's provider. PCL depends only on BladesongModFramework. Its source and library formats did not need a rewrite.

Remaining coupling: framework main.lua unconditionally created the manager, browsed GitHub, checked updates, discovered installations and ran deployment jobs. One C# helper handled both runtime identity and downloads/installations. The old dependency check only accepted dependencies already installed. Manual receipts did not identify the installer. There was no recursive plan review or safe manager-ownership transfer.

## Current component boundaries

- **BladesongModFramework 0.1.8 candidate**: stable API 1.0.0, build detection, compatibility translations, configuration, diagnostics, messaging, and shared game UI. Framework/ and RuntimeHelper/ contain no catalog, network, deployment or restart implementation.
- **BladesongModManager 0.1.0 candidate**: The separate BladesongModManager repository contains the optional Mods page, catalog, installer, resolver, updates, uninstall, ownership and restart. It depends on the runtime. The runtime never imports the manager.
- **Developer SDK 1.0.1 candidate**: the separate BladesongSDK repository contains schemas, developer documentation, examples and packaging/validation tools. No manager or runtime binary is required to develop a mod.
- **PCL 15.18.2**: unchanged Lua/native behavior and saved-data format; only portable metadata is extended in its own repository. No manager dependency.

The components now live in three repositories: LTR-JT/BladesongModFramework, LTR-JT/BladesongModManager, and LTR-JT/BladesongSDK. The original framework history and the manager repository initial commit are preserved. Extracted source records its upstream provenance. PCL remains in its fourth, existing repository.

Runtime initialization is fully offline: UE4SS loads the runtime, an offline helper identifies this executable, compatibility profiles are selected, and dependent mods bind to the stable API. Shared Creative services remain available without the optional manager. Unknown native executables remain gated.

## Dependency installation

Select Install in Browse or an Update on an installed mod. The manager resolves metadata first and displays **Install / Update / Enable / Keep** for each selected dependency. Confirm installation to download and verify the complete plan. A shared dependency appears once, before its dependents. All archives must validate before a pending transaction is committed. The existing normal-exit, backup, apply and restart mechanism is retained.

Required dependencies are resolved recursively. Installed compatible versions are preferred. The resolver checks other installed mods' declared constraints, rejects cycles, attempts compatible candidates, and reports conflicts. GitHub searches are bounded to the newest 20 stable release records; dependencies outside that window require an explicit release/manifest URL. It cannot guarantee a solution across an unbounded release history.

Package version ranges and framework API ranges are separate: dependencies constrain runtime package versions; `api` selects the historical SDK contract. API 1.0.0 remains supported by runtime 0.1.8. Main/Bleeding Edge declarations are unnecessary for ordinary SDK mods. Required game capabilities remain checked against the active framework/game; installing a package cannot promise capabilities on an unknown game.

`runtime_components.UE4SS` is separate from mod dependencies. `*` checks presence; a version requirement also needs a readable matching DLL version. The manager cannot repair a failed UE4SS startup. Bootstrap is performed outside the game.

## Ownership and migration

`mod.json` describes the mod. `bmf-installed.json` is the existing portable content receipt. `deployment.json` is a separate deployment record identifying an owner, for example `manual`, `bladesong-in-game`, or `vortex` (a simulated external owner, not a verified Vortex integration).

The manager can use compatible externally installed dependencies without modifying them. Updating, enabling/disabling or uninstalling someone else's installation is blocked. Review adoption is available for manual installations with a complete matching receipt. The confirmation fingerprint must still match every owned payload file. Adoption changes only deployment metadata; code, libraries and settings stay untouched. Locally modified or unreceipted installations require controlled redeployment.

To switch managers: close the game, back up saves, runtime Data, each mod's libraries/configuration and deployment records; inventory portable manifests and hashes; resolve conflicts; then ask the current manager to stop deploying its files. Use the new manager's supported redeployment/import mechanism, restore user data, verify hashes and test the game. Do not manipulate another application's private deployment records or treat copying files as an ownership transfer. Keep the backup until verified. If redeployment fails, restore the previous files and deployment through the original manager.

Uninstall archives the whole mod folder and checks enabled dependents. It never automatically removes the shared runtime when removing a dependent mod. The manager cannot uninstall the runtime that it currently requires.

## Actual verification and limits

Automated checks cover mocked UE4SS runtime startup without manager imports; actual .NET worker filesystem installs/rollback/relaunch fixtures; local-metadata dependency graphs (shared dependencies, order, cycles, conflicts, compatible older candidate, installed reuse, API conflict, UE4SS absence); simulated external ownership and manual adoption; frozen SDK contract compatibility; existing Creative/PCL-provider UI and cache fixtures; installer safety and hidden worker launch.

These tests are not a new live-game certification. The split manager entry point and plan confirmation need in-game testing on Main and Bleeding Edge. No Vortex extension is implemented or verified. No release has been authorized or published for this split. Existing PCL libraries and the current live installation are not modified by building this candidate.


## Local candidate validation record

The complete check runner passed: 20 real worker install/rollback/target fixtures, 6 dependency/ownership/component-release fixtures using local metadata, 4 disposable bootstrap installer fixtures, 1 exact-install identity fixture, and 1 hidden-launch fixture. The Lua suite also passed syntax, manager-free mocked lifecycle, API/compatibility, optional manager UI, Creative/provider ownership and performance, and frozen historical SDK preservation. PCL's own syntax and Parts/Blades Forge-mode checks passed with its runtime source unchanged. Package checks verified hashed payloads, the absence of manager code in the runtime archive, one framework in the bootstrap, the SDK without binaries, and disabled UE4SS debug consoles.

Framework developer-mode configuration stays registered. Existing combined auto-check and registry preferences are copied into the optional manager's per-mod settings only when those settings are absent; original values are preserved. Pending install plans are not migrated or executed automatically.
