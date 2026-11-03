"""Startup updater runs without a game UI and never changes loaded files."""
import json,hashlib,subprocess,time,unittest,os
from install_test import Installer
class Startup(Installer):
 def fixture(self):
  self.mod=self.scripts.parent;old=b'old manager UI';main=self.mod/'Scripts/main.lua';main.write_bytes(old)
  meta={'schema_version':1,'id':'BladesongModManager','name':'Manager','version':'1.0.0','standalone':True,'dependencies':{},'files':[{'path':'Scripts/main.lua','size':len(old),'sha256':hashlib.sha256(old).hexdigest()}]}
  for name in ['mod.json','bmf-installed.json']:(self.mod/name).write_text(json.dumps(meta))
  (self.mod/'deployment.json').write_text(json.dumps({'schema_version':1,'owner':'bladesong-in-game'}))
  archive,manifest=self.archive(data=b'new manager UI');m=json.loads(manifest.read_text());m.update(id='BladesongModManager',name='Manager',version='1.1.0',standalone=True,dependencies={});m.pop('api',None);manifest.write_text(json.dumps(m));return archive,manifest
 def stage(self,archive,manifest):return self.job('startup-update-local',{'archive':str(archive),'manifest':str(manifest)})
 def test_stages_without_ui_then_applies_after_exit(self):
  archive,manifest=self.fixture();result=self.stage(archive,manifest);self.assertEqual(result['state'],'ready',result)
  self.assertEqual((self.mod/'Scripts/main.lua').read_bytes(),b'old manager UI')
  plan=json.loads(__import__('pathlib').Path(result['plan']).read_text());self.assertTrue(plan['startup_auto']);self.assertFalse(plan['relaunch'])
  pending=self.mod/'Data/pending.json';pending.write_text(json.dumps({'schema_version':1,'approved':False,'items':[]}));before=pending.read_bytes()
  applied=self.job('apply',{'plan':result['plan']});self.assertEqual(applied['status'],'complete',applied)
  self.assertEqual((self.mod/'Scripts/main.lua').read_bytes(),b'new manager UI');self.assertEqual(pending.read_bytes(),before)
  self.assertEqual(json.loads((self.mod/'bmf-installed.json').read_text())['version'],'1.1.0')
 def test_pending_user_actions_take_priority(self):
  archive,manifest=self.fixture();result=self.stage(archive,manifest);self.assertEqual(result['state'],'ready')
  pending=self.mod/'Data/pending.json';pending.write_text(json.dumps({'schema_version':1,'approved':True,'items':[],'toggles':[{'id':'OtherMod'}]}));before=pending.read_bytes()
  applied=self.job('apply',{'plan':result['plan']});self.assertEqual(applied['status'],'failed');self.assertIn('take priority',applied['error']);self.assertEqual(pending.read_bytes(),before)
  self.assertEqual((self.mod/'Scripts/main.lua').read_bytes(),b'old manager UI');self.assertEqual(self.stage(archive,manifest)['state'],'deferred')
 def test_disabled_manual_and_current_installations(self):
  archive,manifest=self.fixture();settings=self.mod/'Data/settings.json';settings.parent.mkdir(exist_ok=True);settings.write_text(json.dumps({'preferences':{'auto_update_manager':False}}))
  self.assertEqual(self.stage(archive,manifest)['state'],'disabled');settings.unlink()
  (self.mod/'deployment.json').write_text(json.dumps({'schema_version':1,'owner':'manual'}));self.assertEqual(self.stage(archive,manifest)['state'],'manual')
  (self.mod/'deployment.json').write_text(json.dumps({'schema_version':1,'owner':'bladesong-in-game'}));m=json.loads(manifest.read_text());m['version']='1.0.0';manifest.write_text(json.dumps(m));self.assertEqual(self.stage(archive,manifest)['state'],'current')
 def test_unrelated_mod_and_bad_hash_rejected(self):
  archive,manifest=self.fixture();m=json.loads(manifest.read_text());m['id']='OtherMod';manifest.write_text(json.dumps(m));self.assertEqual(self.stage(archive,manifest)['status'],'failed')
  m['id']='BladesongModManager';m['files'][0]['sha256']='0'*64;manifest.write_text(json.dumps(m));self.assertEqual(self.stage(archive,manifest)['status'],'failed');self.assertEqual((self.mod/'Scripts/main.lua').read_bytes(),b'old manager UI')
 def test_changed_installation_is_not_overwritten(self):
  archive,manifest=self.fixture();result=self.stage(archive,manifest);self.assertEqual(result['state'],'ready')
  (self.mod/'Scripts/main.lua').write_bytes(b'personal edit')
  applied=self.job('apply',{'plan':result['plan']});self.assertEqual(applied['status'],'failed');self.assertEqual((self.mod/'Scripts/main.lua').read_bytes(),b'personal edit')
 def test_disabling_auto_updates_cancels_staged_apply(self):
  archive,manifest=self.fixture();result=self.stage(archive,manifest);self.assertEqual(result['state'],'ready')
  settings=self.mod/'Data/settings.json';settings.write_text(json.dumps({'preferences':{'auto_update_manager':False}}))
  applied=self.job('apply',{'plan':result['plan']});self.assertEqual(applied['status'],'failed');self.assertIn('disabled',applied['error']);self.assertEqual((self.mod/'Scripts/main.lua').read_bytes(),b'old manager UI')
 def test_apply_waits_for_game_process_to_exit(self):
  archive,manifest=self.fixture();result=self.stage(archive,manifest)
  exe=self.scripts.parents[3]/'Bladesong-Win64-Shipping.exe';source=self.root/'fake-game.cs';source.write_text('class Game { static void Main(){System.Threading.Thread.Sleep(2500);} }')
  compiler=__import__('pathlib').Path(os.environ.get('WINDIR','C:/Windows'))/'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
  subprocess.run([str(compiler),'/nologo','/target:winexe','/out:'+str(exe),str(source)],capture_output=True,check=True)
  game=subprocess.Popen([str(exe)],creationflags=subprocess.CREATE_NO_WINDOW)
  try:
   time.sleep(.2);job=self.root/'background-apply.json';job.write_text(json.dumps({'id':'background_apply','operation':'apply','args':{'plan':result['plan']}}))
   worker=subprocess.Popen([str(self.scripts/'bmm-worker.exe'),str(job)],creationflags=subprocess.CREATE_NO_WINDOW)
   time.sleep(.5);self.assertIsNone(game.poll());self.assertIsNone(worker.poll());self.assertEqual((self.mod/'Scripts/main.lua').read_bytes(),b'old manager UI')
   game.wait(timeout=5);worker.wait(timeout=8);applied=json.loads(__import__('pathlib').Path(str(job)+'.result.json').read_text(encoding='utf-8-sig'));self.assertEqual(applied['status'],'complete',applied)
   self.assertEqual((self.mod/'Scripts/main.lua').read_bytes(),b'new manager UI')
  finally:
   game.wait(timeout=5)
if __name__=='__main__':
 suite=unittest.TestSuite(Startup(name)for name in Startup.__dict__ if name.startswith('test_'));result=unittest.TextTestRunner().run(suite);raise SystemExit(not result.wasSuccessful())
