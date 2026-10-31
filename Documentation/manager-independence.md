# Runtime and manager independence

The framework owns the Creative/Story menu base, PCL provider host, public SDK and compatibility adapters. The separate Mod Manager is a standalone UE4SS mod. Neither requires the other to start.

The manager bundles only private management services, JSON parsing and its own generic tabs. Its page uses a new stock game tutorial-frame widget with its own root, not a framework/PCL asset. It does not import framework API code. Optional SDK page and settings access exchanges serialized messages only if the runtime is available.

The portable `standalone: true` field permits a UE4SS mod without an `api` range. SDK-integrated mods still require an API range and their declared runtime dependencies. Installing PCL resolves a shared framework; installing the manager does not. Runtime game capabilities are checked by that runtime after launch rather than blocking installation before the runtime exists. Raw-native exceptions still compare the actual executable hash.

Tests cover manager startup and panel construction with no framework or PCL assets, legacy Mods button suppression, a dependency-free standalone plan, automatic framework inclusion for an SDK mod, and removal of an unused framework. Existing ownership, conflicts, archive safety, hidden launcher and update-status tests remain in place. UI tests mock UE4SS; live Main/Bleeding Edge testing remains necessary.

The manager bootstrap includes UE4SS and the manager only. Its CI no longer checks out or compiles framework code. The framework remains a single shared dependency when SDK mods require it.
