"""Real worker/filesystem fixtures; release metadata is local, never GitHub."""
import json,unittest,pathlib,hashlib
from install_test import Installer
class Dependencies(Installer):
 def metadata(self,id,dependencies=None,version='1.0.0',api='^1.0.0'):
  data=b'fixture';m={'schema_version':1,'id':id,'name':id,'version':version,'api':api,'dependencies':dependencies or {},'files':[{'path':'Scripts/main.lua','size':len(data),'sha256':hashlib.sha256(data).hexdigest()}]}
  path=self.root/(id+'-'+version+'.json');path.write_text(json.dumps(m));return path
 def graph(self,root,sources):return self.job('plan-local',{'path':str(root),'sources':{k:[str(p)for p in values]for k,values in sources.items()}})
 def test_recursive_shared_dependency_and_order(self):
  framework=self.metadata('BladesongModFramework',version='0.1.8');a=self.metadata('A',{'BladesongModFramework':'>=0.1.4 <1.0.0'});b=self.metadata('B',{'BladesongModFramework':'^0.1.4'});root=self.metadata('Root',{'A':'^1.0.0','B':'^1.0.0'})
  result=self.graph(root,{'A':[a],'B':[b],'BladesongModFramework':[framework]});self.assertEqual(result['status'],'complete',result)
  ids=[x['id']for x in result['plan']['items']];self.assertEqual(ids.count('BladesongModFramework'),1);self.assertLess(ids.index('BladesongModFramework'),ids.index('A'));self.assertEqual(ids[-1],'Root')
 def test_cycle_and_version_conflict(self):
  a=self.metadata('A',{'B':'^1.0.0'});b=self.metadata('B',{'A':'^1.0.0'});result=self.graph(a,{'B':[b]});self.assertEqual(result['status'],'failed');self.assertIn('Circular',result['error'])
  a=self.metadata('A',{'Shared':'^1.0.0'});b=self.metadata('B',{'Shared':'^2.0.0'});root=self.metadata('Root',{'A':'*','B':'*'});shared=self.metadata('Shared')
  result=self.graph(root,{'A':[a],'B':[b],'Shared':[shared]});self.assertEqual(result['status'],'failed');self.assertIn('Shared',result['error'])
 def test_older_compatible_release_and_installed_reuse(self):
  old=self.metadata('Shared',version='1.0.0');new=self.metadata('Shared',version='2.0.0');root=self.metadata('Root',{'Shared':'^1.0.0'})
  result=self.graph(root,{'Shared':[new,old]});self.assertEqual(result['status'],'complete',result);self.assertEqual(result['plan']['items'][0]['version'],'1.0.0')
  folder=self.scripts.parent.parent/'Shared';folder.mkdir();(folder/'mod.json').write_bytes(old.read_bytes());(folder/'enabled.txt').write_text('')
  result=self.graph(root,{});self.assertEqual(result['status'],'complete',result);self.assertEqual(result['plan']['items'][0]['action'],'keep')
 def test_external_ownership_and_safe_manual_adoption(self):
  archive,manifest=self.archive();payload=self.validate(archive,manifest)['payload'];plan=self.root/'apply.json';plan.write_text(json.dumps({'schema_version':1,'approved':True,'id':'ownership','relaunch':False,'items':[{'manifest':str(manifest),'payload':payload}]}));self.assertEqual(self.job('apply',{'plan':str(plan)})['status'],'complete')
  folder=self.scripts.parent.parent/'FixtureMod';owner=folder/'deployment.json';owner.write_text(json.dumps({'schema_version':1,'owner':'vortex'}))
  self.assertEqual(self.job('uninstall',{'id':'FixtureMod'})['status'],'failed');self.assertEqual(self.job('inspect-adoption',{'id':'FixtureMod'})['status'],'failed')
  owner.unlink();library=folder/'Scripts/preconstructions/library.index';library.parent.mkdir();library.write_text('keep me')
  review=self.job('inspect-adoption',{'id':'FixtureMod'});self.assertEqual(review['status'],'complete',review)
  before=(folder/'Scripts/main.lua').read_bytes();result=self.job('adopt',{'id':'FixtureMod','fingerprint':review['fingerprint']});self.assertEqual(result['status'],'complete');self.assertEqual(library.read_text(),'keep me');self.assertEqual((folder/'Scripts/main.lua').read_bytes(),before)
 def test_independent_component_updates_do_not_use_repository_latest(self):
  meta=self.metadata('BladesongModManager');m=json.loads(meta.read_text());m['release_source']={'type':'github','repository':'https://github.com/LTR-JT/BladesongModFramework','tag_prefix':'manager-v','manifest_asset':'BladesongModManager.mod.json'};meta.write_text(json.dumps(m))
  releases=self.root/'releases.json';releases.write_text(json.dumps([{'tag_name':'v0.1.9','assets':[{'name':'mod.json','browser_download_url':'https://example.org/framework.json'}]},{'tag_name':'manager-v0.1.1','assets':[{'name':'BladesongModManager.mod.json','browser_download_url':'https://example.org/manager.json'}]}]))
  result=self.job('select-component-release-local',{'manifest':str(meta),'releases':str(releases)});self.assertEqual(result['url'],'https://example.org/manager.json')
 def test_api_contract_and_ue4ss_are_distinct(self):
  root=self.metadata('Root',api='^2.0.0');self.assertEqual(self.graph(root,{})['status'],'failed')
  root=self.metadata('Root');m=json.loads(root.read_text());m['runtime_components']={'UE4SS':'*'};root.write_text(json.dumps(m));result=self.graph(root,{});self.assertEqual(result['status'],'failed');self.assertIn('bootstrap',result['error'])
if __name__=='__main__':
 suite=unittest.TestSuite(Dependencies(name)for name in Dependencies.__dict__ if name.startswith('test_'));result=unittest.TextTestRunner().run(suite);raise SystemExit(not result.wasSuccessful())
