import hashlib,json,pathlib,shutil,subprocess,tempfile,unittest,zipfile,os,time
ROOT=pathlib.Path(__file__).resolve().parents[1]
SERVICE=ROOT/'Manager/BladesongModManager/Scripts/bmm-worker.exe'
class Installer(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory(dir=ROOT/'Tests');self.root=pathlib.Path(self.tmp.name).resolve();assert self.root.is_relative_to((ROOT/'Tests').resolve())
  self.scripts=self.root/'Bladesong/Binaries/Win64/ue4ss/Mods/BladesongModManager/Scripts';self.scripts.mkdir(parents=True)
  shutil.copyfile(SERVICE,self.scripts/'bmm-worker.exe');self.sequence=0
 def tearDown(self):
  # The background helper writes its result just before exiting. Windows may
  # retain its executable mapping briefly after the result becomes visible.
  deadline=time.monotonic()+5
  while True:
   try:self.tmp.cleanup();return
   except PermissionError:
    if time.monotonic()>=deadline:raise
    time.sleep(.05)
 def job(self,op,args,capabilities=None):
  self.sequence+=1;job=self.root/f'job{self.sequence}.json';job.write_text(json.dumps({'id':f'test_{self.sequence}','operation':op,'args':args,'capabilities':capabilities or []}),encoding='utf8')
  run=subprocess.run([str(self.scripts/'bmm-worker.exe'),str(job)],capture_output=True,text=True,timeout=30)
  result=pathlib.Path(str(job)+'.result.json');self.assertTrue(result.exists(),run.stderr);return json.loads(result.read_text(encoding='utf-8-sig'))
 def archive(self,name='Scripts/main.lua',data=b'print("fixture")',hash_override=None):
  self.sequence+=1;p=self.root/f'archive{self.sequence}.zip';m={'schema_version':1,'id':'FixtureMod','name':'Fixture','version':'1.0.0','api':'^1.0.0','files':[{'path':name,'size':len(data),'sha256':hash_override or hashlib.sha256(data).hexdigest()}]}
  with zipfile.ZipFile(p,'w',zipfile.ZIP_DEFLATED)as z:z.writestr(name,data)
  manifest=p.with_suffix('.json');manifest.write_text(json.dumps(m));return p,manifest
 def validate(self,p,m):return self.job('validate-local',{'archive':str(p),'manifest':str(m)})
 def test_valid_archive_and_fresh_install(self):
  p,m=self.archive();result=self.validate(p,m);self.assertEqual(result['status'],'complete',result)
  plan=self.root/'plan.json';plan.write_text(json.dumps({'schema_version':1,'approved':True,'id':'test_install','relaunch':False,'items':[{'manifest':str(m),'payload':result['payload']}]}))
  result=self.job('apply',{'plan':str(plan)});self.assertEqual(result['status'],'complete',result)
  installed=self.scripts.parent.parent/'FixtureMod/Scripts/main.lua';self.assertEqual(installed.read_bytes(),b'print("fixture")')
 def test_pcl_owns_assets_and_incomplete_pcl_release_rejected(self):
  files={'Scripts/main.lua':b'print("framework")','Scripts/library.lua':b'return {}'}
  files.update({'assets/logicmods/PCLAnchor.'+ext:b'cooked '+ext.encode() for ext in ['pak','ucas','utoc']})
  files['assets/logicmods/PCLAnchor/config.lua']=b'Mods["PCLAnchor"]={AssetName="ModActor_C"}'
  m={'schema_version':1,'id':'PreconstructionLibraryProbe','name':'Framework','version':'0.1.8','api':'^1.0.0','files':[{'path':k,'size':len(v),'sha256':hashlib.sha256(v).hexdigest()}for k,v in files.items()]}
  archive=self.root/'framework.zip';manifest=self.root/'framework.json'
  with zipfile.ZipFile(archive,'w')as z:
   for k,v in files.items():z.writestr(k,v)
  manifest.write_text(json.dumps(m));validated=self.validate(archive,manifest);self.assertEqual(validated['status'],'complete',validated)
  mods=self.scripts.parent.parent;(mods/'mods.txt').write_text('Keybinds : 1\n')
  plan=self.root/'framework-plan.json';plan.write_text(json.dumps({'schema_version':1,'approved':True,'id':'framework_assets','relaunch':False,'items':[{'manifest':str(manifest),'payload':validated['payload']}],'toggles':[{'id':'PreconstructionLibraryProbe','enabled':True,'marker':False,'mods_hash':hashlib.sha256((mods/'mods.txt').read_bytes()).hexdigest()}]}))
  self.assertEqual(self.job('apply',{'plan':str(plan)})['status'],'complete')
  self.assertEqual((self.scripts.parents[5]/'Content/Paks/LogicMods/PCLAnchor/config.lua').read_bytes(),files['assets/logicmods/PCLAnchor/config.lua'])
  self.assertEqual(json.loads((mods/'PreconstructionLibraryProbe/mod.json').read_text())['version'],'0.1.8')
  self.assertEqual((mods/'mods.txt').read_text().strip().splitlines()[-1],'Keybinds : 1')
  m['files']=[f for f in m['files']if not f['path'].startswith('assets/')];manifest.write_text(json.dumps(m));result=self.validate(archive,manifest)
  self.assertEqual(result['status'],'failed');self.assertIn('Incomplete Preconstruction Library release',result['error'])
 def test_portable_logicmods_target_and_reserved_ownership_records(self):
  archive,manifest=self.archive('assets/logicmods/Fixture.pak',b'fixture asset');result=self.validate(archive,manifest);self.assertEqual(result['status'],'complete')
  plan=self.root/'asset-plan.json';plan.write_text(json.dumps({'schema_version':1,'approved':True,'id':'asset_target','relaunch':False,'items':[{'manifest':str(manifest),'payload':result['payload']}]}))
  self.assertEqual(self.job('apply',{'plan':str(plan)})['status'],'complete');self.assertEqual((self.scripts.parents[5]/'Content/Paks/LogicMods/Fixture.pak').read_bytes(),b'fixture asset')
  for name in ['deployment.json','bmf-installed.json']:
   archive,manifest=self.archive(name);self.assertEqual(self.validate(archive,manifest)['status'],'failed')
 def apply_fixture(self,archive,manifest,token):
  result=self.validate(archive,manifest);self.assertEqual(result['status'],'complete',result)
  plan=self.root/(token+'.json');plan.write_text(json.dumps({'schema_version':1,'approved':True,'id':token,'relaunch':False,'items':[{'manifest':str(manifest),'payload':result['payload']}]}))
  return self.job('apply',{'plan':str(plan)})
 def test_reinstall_reuses_identical_orphaned_assets(self):
  archive,manifest=self.archive('assets/logicmods/Fixture.pak',b'matching asset')
  asset=self.scripts.parents[5]/'Content/Paks/LogicMods/Fixture.pak';asset.parent.mkdir(parents=True);asset.write_bytes(b'matching asset')
  self.assertEqual(self.apply_fixture(archive,manifest,'orphan_asset')['status'],'complete')
  self.assertEqual(asset.read_bytes(),b'matching asset')
 def test_reinstall_preserves_different_or_foreign_assets(self):
  archive,manifest=self.archive('assets/logicmods/Fixture.pak',b'new asset')
  asset=self.scripts.parents[5]/'Content/Paks/LogicMods/Fixture.pak';asset.parent.mkdir(parents=True);asset.write_bytes(b'personal asset')
  self.assertEqual(self.apply_fixture(archive,manifest,'different_asset')['status'],'failed');self.assertEqual(asset.read_bytes(),b'personal asset')
  asset.write_bytes(b'new asset');other=self.scripts.parent.parent/'OtherMod';other.mkdir()
  meta=json.loads(manifest.read_text());meta['id']='OtherMod';(other/'mod.json').write_text(json.dumps(meta));(other/'bmf-installed.json').write_text(json.dumps(meta))
  self.assertEqual(self.apply_fixture(archive,manifest,'foreign_asset')['status'],'failed');self.assertEqual(asset.read_bytes(),b'new asset')
 def test_library_survives_uninstall_and_reinstall(self):
  archive,manifest=self.archive();self.assertEqual(self.apply_fixture(archive,manifest,'first_install')['status'],'complete')
  mod=self.scripts.parent.parent/'FixtureMod';personal={'Scripts/preconstructions/library.index':b'my parts','Scripts/preconstructions/blades/library.index':b'my blades','Scripts/preconstructions/preview.png':b'preview','Data/settings.json':b'{"choice":true}'}
  for rel,value in personal.items():p=mod/rel;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(value)
  result=self.job('uninstall',{'id':'FixtureMod'});self.assertEqual(result['status'],'waiting_for_exit',result)
  complete=self.scripts.parent/'Data/last-apply.json';self.wait_for(complete.exists);self.assertEqual(json.loads(complete.read_text())['status'],'complete');self.assertFalse(mod.exists())
  saved=self.scripts.parents[3]/'BMF_UserData/FixtureMod'
  for rel,value in personal.items():self.assertEqual((saved/rel).read_bytes(),value)
  self.assertEqual(self.apply_fixture(archive,manifest,'reinstall_data')['status'],'complete')
  for rel,value in personal.items():self.assertEqual((mod/rel).read_bytes(),value)
 def test_legacy_uninstall_archive_recovers_library(self):
  archive,manifest=self.archive();legacy=self.scripts.parents[3]/'BMF_Uninstalled/012345abcdef';legacy.mkdir(parents=True)
  (legacy/'bmf-installed.json').write_bytes(manifest.read_bytes());index=legacy/'Scripts/preconstructions/library.index';index.parent.mkdir(parents=True);index.write_text('legacy library')
  self.assertEqual(self.apply_fixture(archive,manifest,'legacy_restore')['status'],'complete')
  self.assertEqual((self.scripts.parent.parent/'FixtureMod/Scripts/preconstructions/library.index').read_text(),'legacy library');self.assertEqual(index.read_text(),'legacy library')
 def test_manual_dependency_manifest_and_disabled_state(self):
  _,manifest=self.archive();metadata=json.loads(manifest.read_text());metadata['dependencies']={'BladesongModFramework':'^0.1.4'};manifest.write_text(json.dumps(metadata))
  folder=self.scripts.parent.parent/'BladesongModFramework';folder.mkdir();current={'schema_version':1,'id':'BladesongModFramework','name':'Framework','version':'0.1.5','api':'^1.0.0'}
  (folder/'mod.json').write_text(json.dumps(current));(folder/'enabled.txt').write_text('')
  self.assertEqual(self.job('validate-dependencies-local',{'path':str(manifest)})['status'],'complete')
  (folder/'bmf-installed.json').write_text(json.dumps(dict(current,version='0.1.2')))
  self.assertEqual(self.job('validate-dependencies-local',{'path':str(manifest)})['status'],'complete')
  (folder/'enabled.txt').unlink()
  self.assertEqual(self.job('validate-dependencies-local',{'path':str(manifest)})['status'],'failed')
  current['version']='0.1.2';(folder/'mod.json').write_text(json.dumps(current));(folder/'enabled.txt').write_text('')
  self.assertEqual(self.job('validate-dependencies-local',{'path':str(manifest)})['status'],'failed')
 def test_traversal_and_hash(self):
  for path in ['../outside.lua','Scripts/../outside.lua','C:/outside.lua','Scripts/main.lua:evil','Scripts/CON.lua']:
   p,m=self.archive(path);self.assertEqual(self.validate(p,m)['status'],'failed',path)
  p,m=self.archive(hash_override='0'*64);self.assertEqual(self.validate(p,m)['status'],'failed')
 def test_unlisted_link_and_duplicate(self):
  p,m=self.archive()
  with zipfile.ZipFile(p,'a')as z:z.writestr('extra.lua',b'extra')
  self.assertEqual(self.validate(p,m)['status'],'failed')
  p,m=self.archive()
  with zipfile.ZipFile(p,'a')as z:
   i=zipfile.ZipInfo('link');i.create_system=3;i.external_attr=(0o120777<<16);z.writestr(i,b'../escape')
  self.assertEqual(self.validate(p,m)['status'],'failed')
  p,m=self.archive()
  with zipfile.ZipFile(p,'a')as z:z.writestr('SCRIPTS/MAIN.LUA',b'print("fixture")')
  self.assertEqual(self.validate(p,m)['status'],'failed')
 def test_save_path_and_unapproved_plan(self):
  p,m=self.archive('SaveGames/test.sav');self.assertEqual(self.validate(p,m)['status'],'failed')
  plan=self.root/'bad-plan.json';plan.write_text(json.dumps({'schema_version':1,'approved':False,'items':[]}));self.assertEqual(self.job('apply',{'plan':str(plan)})['status'],'failed')
 def test_toggle_is_staged_and_applies_after_exit(self):
  mods=self.scripts.parent.parent;mod=mods/'FixtureMod';mod.mkdir();(mod/'deployment.json').write_text(json.dumps({'schema_version':1,'owner':'bladesong-in-game'}));(mod/'enabled.txt').write_text('');(mods/'mods.txt').write_text('FixtureMod : 1\n')
  result=self.job('toggle',{'id':'FixtureMod','enabled':False});self.assertEqual(result['status'],'complete',result)
  self.assertTrue((mod/'enabled.txt').exists());self.assertIn(': 1',(mods/'mods.txt').read_text())
  plan=self.scripts.parent/'Data/pending.json';data=json.loads(plan.read_text());data['relaunch']=False;plan.write_text(json.dumps(data))
  result=self.job('apply',{'plan':str(plan)});self.assertEqual(result['status'],'complete',result)
  self.assertFalse((mod/'enabled.txt').exists());self.assertIn(': 0',(mods/'mods.txt').read_text())
 def test_restart_preflight_rejects_local_edits_before_exit(self):
  archive,manifest=self.archive();validated=self.validate(archive,manifest);self.assertEqual(validated['status'],'complete')
  target=self.scripts.parent.parent/'FixtureMod/Scripts/main.lua';target.parent.mkdir(parents=True);target.write_text('personal edit')
  data=self.scripts.parent/'Data';data.mkdir(exist_ok=True);pending=data/'pending.json'
  pending.write_text(json.dumps({'schema_version':1,'approved':True,'id':'preflight_fixture','relaunch':False,'items':[{'manifest':str(manifest),'payload':validated['payload']}]}))
  result=self.job('restart',{});self.assertEqual(result['status'],'failed');self.assertIn('explicit adoption',result['error'])
  self.assertEqual(target.read_text(),'personal edit');self.assertEqual(list(data.glob('apply-*.exe')),[])
 def wait_for(self,predicate):
  import time
  deadline=time.monotonic()+10
  while time.monotonic()<deadline:
   if predicate():return
   time.sleep(.05)
  self.fail('Background apply did not finish')
 def test_completed_plan_does_not_break_next_change(self):
  archive,manifest=self.archive();validated=self.validate(archive,manifest)
  pending=self.scripts.parent/'Data/pending.json';pending.parent.mkdir(exist_ok=True)
  pending.write_text(json.dumps({'schema_version':1,'approved':False,'items':[]}))
  mod=self.scripts.parent.parent/'FixtureMod';mod.mkdir();(mod/'deployment.json').write_text(json.dumps({'schema_version':1,'owner':'bladesong-in-game'}));(mod/'enabled.txt').write_text('')
  result=self.job('toggle',{'id':'FixtureMod','enabled':False});self.assertEqual(result['status'],'complete')
  plan=json.loads(pending.read_text());self.assertTrue(plan['id'])
  plan['relaunch']=False;pending.write_text(json.dumps(plan));self.assertEqual(self.job('apply',{'plan':str(pending)})['status'],'complete')
  # An already-approved legacy plan without ID must also be repaired before restart.
  pending.write_text(json.dumps({'schema_version':1,'approved':True,'relaunch':False,'items':[{'manifest':str(manifest),'payload':validated['payload']}]}))
  self.assertEqual(self.job('restart',{})['status'],'waiting_for_exit')
  record=mod/'bmf-installed.json';self.wait_for(record.exists);self.assertEqual(json.loads(record.read_text())['version'],'1.0.0')
 def test_uninstall_archives_all_data_and_removes_active_mod(self):
  mod=self.scripts.parent.parent/'FixtureMod';(mod/'Scripts/preconstructions').mkdir(parents=True)
  (mod/'deployment.json').write_text(json.dumps({'schema_version':1,'owner':'bladesong-in-game'}));(mod/'Scripts/main.lua').write_text('code');(mod/'Scripts/preconstructions/library.index').write_text('my library');(mod/'enabled.txt').write_text('')
  mods=self.scripts.parent.parent/'mods.txt';mods.write_text('FixtureMod : 1\nOtherMod : 0\n')
  result=self.job('uninstall',{'id':'FixtureMod'});self.assertEqual(result['status'],'waiting_for_exit',result)
  complete=self.scripts.parent/'Data/last-apply.json';self.wait_for(complete.exists)
  self.assertEqual(json.loads(complete.read_text())['status'],'complete');self.assertFalse(mod.exists())
  archives=[p for p in (self.scripts.parents[3]/'BMF_Uninstalled').glob('*')if p.is_dir()];self.assertEqual(len(archives),1)
  self.assertEqual((archives[0]/'Scripts/preconstructions/library.index').read_text(),'my library')
  self.assertIn('OtherMod : 0',mods.read_text());self.assertNotIn('FixtureMod : 1',mods.read_text())
 def test_uninstall_dependency_and_framework_guards(self):
  mods=self.scripts.parent.parent;target=mods/'FixtureMod';target.mkdir();(target/'deployment.json').write_text(json.dumps({'schema_version':1,'owner':'bladesong-in-game'}));(target/'enabled.txt').write_text('')
  dependent=mods/'Dependent';dependent.mkdir();(dependent/'enabled.txt').write_text('')
  (dependent/'mod.json').write_text(json.dumps({'schema_version':1,'id':'Dependent','name':'Dependent','version':'1.0.0','api':'^1.0.0','dependencies':{'FixtureMod':'^1.0.0'}}))
  result=self.job('uninstall',{'id':'FixtureMod'});self.assertEqual(result['status'],'failed');self.assertIn('depends',result['error']);self.assertTrue(target.exists())
  self.assertEqual(self.job('uninstall',{'id':'BladesongModFramework'})['status'],'failed')
 def test_failed_uninstall_restores_original_folder(self):
  mod=self.scripts.parent.parent/'FixtureMod';mod.mkdir();(mod/'deployment.json').write_text(json.dumps({'schema_version':1,'owner':'bladesong-in-game'}));(mod/'personal.json').write_text('keep me')
  # A conflicting directory must never be deleted, and the archived mod must return.
  (self.scripts.parent.parent/'mods.txt').mkdir()
  self.assertEqual(self.job('uninstall',{'id':'FixtureMod'})['status'],'waiting_for_exit')
  complete=self.scripts.parent/'Data/last-apply.json';self.wait_for(complete.exists)
  self.assertEqual(json.loads(complete.read_text())['status'],'failed');self.assertEqual((mod/'personal.json').read_text(),'keep me')
 def test_failure_rolls_back_prior_write(self):
  p,m=self.archive();manifest=json.loads(m.read_text());data=b'second';manifest['files'].append({'path':'blocked/second.lua','size':len(data),'sha256':hashlib.sha256(data).hexdigest()})
  m.write_text(json.dumps(manifest))
  with zipfile.ZipFile(p,'a')as z:z.writestr('blocked/second.lua',data)
  result=self.validate(p,m);self.assertEqual(result['status'],'complete',result)
  mod=self.scripts.parent.parent/'FixtureMod';mod.mkdir();(mod/'deployment.json').write_text(json.dumps({'schema_version':1,'owner':'bladesong-in-game'}));(mod/'blocked').write_text('existing file')
  plan=self.root/'rollback-plan.json';plan.write_text(json.dumps({'schema_version':1,'approved':True,'id':'rollback_test','relaunch':False,'items':[{'manifest':str(m),'payload':result['payload']}]}))
  result=self.job('apply',{'plan':str(plan)});self.assertEqual(result['status'],'failed',result);self.assertFalse((mod/'Scripts/main.lua').exists());self.assertEqual((mod/'blocked').read_text(),'existing file')
 def test_unmanaged_files_are_preserved(self):
  p,m=self.archive();result=self.validate(p,m);mod=self.scripts.parent.parent/'FixtureMod/Scripts';mod.mkdir(parents=True);(mod/'main.lua').write_text('personal edit')
  plan=self.root/'unmanaged-plan.json';plan.write_text(json.dumps({'schema_version':1,'approved':True,'id':'unmanaged_test','relaunch':False,'items':[{'manifest':str(m),'payload':result['payload']}]}))
  result=self.job('apply',{'plan':str(plan)});self.assertEqual(result['status'],'failed');self.assertEqual((mod/'main.lua').read_text(),'personal edit')
 def test_framework_capabilities_replace_normal_build_lists(self):
  p,m=self.archive();metadata=json.loads(m.read_text());metadata['game_builds']=['0'*64];m.write_text(json.dumps(metadata))
  result=self.job('compatibility-local',{'path':str(m)});self.assertEqual(result['compatibility'],'framework-ready')
  metadata['capabilities']=['forge.read'];m.write_text(json.dumps(metadata))
  self.assertEqual(self.job('compatibility-local',{'path':str(m)})['compatibility'],'framework-ready')
  self.assertEqual(self.job('compatibility-local',{'path':str(m)},['forge.read'])['compatibility'],'framework-ready')
  metadata['raw_integration']={'reason':'Native fixture','game_builds':['0'*64]};m.write_text(json.dumps(metadata))
  exe=self.scripts.parents[3]/'Bladesong-Win64-Shipping.exe';exe.write_bytes(b'fixture executable')
  self.assertEqual(self.job('compatibility-local',{'path':str(m)},['forge.read'])['compatibility'],'raw-build-mismatch')
 def test_simple_index_validation(self):
  p=self.root/'index.json';p.write_text(json.dumps({'mods':[{'name':'Fixture','url':'https://github.com/example/fixture'}]}))
  self.assertEqual(self.job('validate-index-local',{'path':str(p)})['status'],'complete')
  for entry in [{'name':'Fixture','url':'http://github.com/example/fixture'},{'name':'Fixture','url':'https://github.com/example/fixture','version':'1.0.0'}]:
   p.write_text(json.dumps({'mods':[entry]}));self.assertEqual(self.job('validate-index-local',{'path':str(p)})['status'],'failed')
 def test_offline_catalogue_isolates_missing_repository(self):
  url='https://example.com/mod-index.json';repos=['https://github.com/example/good','https://github.com/example/missing']
  cache=self.scripts.parent/'Data/catalogue';cache.mkdir(parents=True)
  key=lambda s:hashlib.sha256(s.encode()).hexdigest()
  (cache/(key(url)+'.index.json')).write_text(json.dumps({'mods':[{'name':'Good','url':repos[0]},{'name':'Missing','url':repos[1]}]}))
  (cache/(key(repos[0])+'.mod.json')).write_text(json.dumps({'id':'Good','name':'Author supplied name','version':'1.0.0','api':'^1.0.0'}))
  result=self.job('browse',{'index_url':url,'offline':True});self.assertEqual(result['status'],'complete')
  self.assertEqual(len(result['entries']),2);entries={x['repository']:x for x in result['entries']}
  self.assertEqual(entries[repos[0]]['manifest']['name'],'Author supplied name');self.assertTrue(entries[repos[0]]['cached'])
  self.assertEqual(entries[repos[1]]['status'],'unavailable')
 def test_fresh_catalogue_avoids_network(self):
  import time
  url='https://invalid.invalid/index.json';repository='https://github.com/example/cached'
  cache=self.scripts.parent/'Data/catalogue';cache.mkdir(parents=True)
  key=lambda value:hashlib.sha256(value.encode()).hexdigest()
  (cache/(key(url)+'.index.json')).write_text(json.dumps({'mods':[{'name':'Cached','url':repository}]}))
  (cache/(key(repository)+'.mod.json')).write_text(json.dumps({'schema_version':1,'id':'Cached','name':'Cached','version':'1.0.0','api':'^1.0.0'}))
  started=time.perf_counter();result=self.job('browse',{'index_url':url});elapsed=time.perf_counter()-started
  self.assertEqual(result['status'],'complete',result);self.assertTrue(result['cached_index']);self.assertFalse('Using cached index' in result['message']);self.assertEqual(result['entries'][0]['manifest']['id'],'Cached')
  print('Cached catalogue worker: %.0f ms (no network)'%(elapsed*1000))
 def test_update_check_reports_unavailable_and_pinned_per_mod(self):
  mods=self.scripts.parent.parent
  for name,extra in [('NoFeed',{}),('Pinned',{'repository':'https://github.com/example/pinned','pinned_version':'1.0.0'})]:
   folder=mods/name;folder.mkdir();metadata={'schema_version':1,'id':name,'name':name,'version':'1.0.0','api':'^1.0.0'};metadata.update(extra);(folder/'mod.json').write_text(json.dumps(metadata))
  result=self.job('updates',{});self.assertEqual(result['status'],'complete');self.assertEqual(result['checks']['NoFeed']['state'],'unavailable');self.assertEqual(result['checks']['Pinned']['state'],'pinned')
 def test_automatic_manifest_and_ordinary_discovery(self):
  mods=self.scripts.parent.parent
  for name in ['Ordinary','Declared','Broken']:(mods/name/'Scripts').mkdir(parents=True);(mods/name/'Scripts/main.lua').write_text('')
  (mods/'Declared/mod.json').write_text(json.dumps({'schema_version':1,'id':'Declared','name':'Declared metadata','version':'1.0.0','api':'^1.0.0'}))
  (mods/'Broken/mod.json').write_text('{broken')
  result=self.job('discover',{});self.assertEqual(result['status'],'complete');found={m['id']:m for m in result['mods']}
  self.assertEqual(found['Ordinary']['integration'],'ordinary');self.assertEqual(found['Declared']['integration'],'manifest');self.assertEqual(found['Broken']['integration'],'invalid-manifest')
if __name__=='__main__':unittest.main()
