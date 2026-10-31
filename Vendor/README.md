# Bundled UE4SS runtime

This is the preserved, tested Bladesong-configured UE4SS 3.0.1 Beta 0 snapshot
reporting commit a1e7f571. Its UE4SS.dll is byte-identical to the working local
runtime used for the Main/Bleeding Edge checks. The ZIP hash is pinned in
ue4ss.json. The original UE4SS MIT license remains at ue4ss/LICENSE in the
archive and in every easy-install release.

Upstream: https://github.com/UE4SS-RE/RE-UE4SS
This is a community game-specific configuration, not an official UE4SS release.
The snapshot includes its standard support mods and the Bladesong FName override.
Debug windows, hot reload, automatic Lua reload and the UObject array cache are off.
No logs, dumps, personal saves or PCL library files are included.
