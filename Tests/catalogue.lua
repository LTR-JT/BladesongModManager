local TEST_ROOT=os.getenv('BMF_TEST_ROOT')or 'BladesongModdingPlatform'
local FRAMEWORK=os.getenv('BMF_FRAMEWORK_ROOT')or TEST_ROOT..'/../BladesongModFramework'
local C=assert(loadfile(TEST_ROOT..'/Manager/BladesongModManager/Scripts/catalogue.lua'))()
local mods={{id='ConsoleCommandsMod'},{id='PreconstructionLibraryProbe'},
 {id='BladesongModFramework'},{id='OtherCommunityMod',discovered=true},{id='BPModLoaderMod'}}
local community,utilities=C.partition(mods)
assert(#community==3 and #utilities==2)
assert(community[1]==mods[2] and community[3]==mods[4])
assert(utilities[1]==mods[1] and utilities[2]==mods[5])
print('PASS: bundled utilities grouped; PCL, framework and unknown community mods remain visible')

assert(C.installed({manifest={id='PreconstructionLibraryProbe'}},mods))
assert(C.installed({repository='https://github.com/example/mod/'},{{id='Disabled',enabled=false,repository='https://github.com/EXAMPLE/MOD.git'}}))
assert(not C.installed({name='OtherCommunityMod',repository='https://github.com/another/repo'},mods))
