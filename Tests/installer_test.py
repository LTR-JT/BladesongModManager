"""Exercise the installer only against disposable fake game folders."""
from pathlib import Path
import hashlib,json,os,subprocess,tempfile,unittest
ROOT=Path(__file__).resolve().parents[1]
SCRIPT=(ROOT/'Installer/install.ps1').read_text(encoding='utf-8')
class Installer(unittest.TestCase):
 def setup_fixture(self,folder):
  source=folder/'package';game=folder/'game';exe=game/'Bladesong/Binaries/Win64/Bladesong-Win64-Shipping.exe';exe.parent.mkdir(parents=True);exe.write_bytes(b'fixture, never executed')
  files={'Bladesong/Binaries/Win64/dwmapi.dll':b'new proxy','Bladesong/Binaries/Win64/ue4ss/UE4SS.dll':b'new runtime','Bladesong/Binaries/Win64/ue4ss/Mods/mods.txt':b'BPModLoaderMod : 1\nKeybinds : 1\n','Bladesong/Binaries/Win64/ue4ss/Mods/BladesongModManager/Scripts/main.lua':b'framework','Bladesong/Content/Paks/LogicMods/PCLAnchor.pak':b'own asset'}
  for relative,data in files.items():
   p=source/relative;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)
  (source/'INSTALL_MANIFEST.json').write_text(json.dumps({'files':[{'path':p,'sha256':hashlib.sha256(data).hexdigest()}for p,data in files.items()]}))
  return source,game,files
 def run_installer(self,source,game):
  env=os.environ.copy();env.update(BMF_INSTALL_SOURCE=str(source),BMF_INSTALL_TARGET=str(game),BMF_INSTALL_UNATTENDED='1')
  return subprocess.run(['powershell.exe','-NoLogo','-NoProfile','-STA','-Command','& { '+SCRIPT+' }'],env=env,capture_output=True,text=True,timeout=30)
 def test_install_and_preserve_other_mods(self):
  with tempfile.TemporaryDirectory(dir=ROOT/'Tests')as temp:
   source,game,files=self.setup_fixture(Path(temp));proxy=game/'Bladesong/Binaries/Win64/dwmapi.dll';proxy.write_bytes(b'old proxy')
   mods=game/'Bladesong/Binaries/Win64/ue4ss/Mods/mods.txt';mods.parent.mkdir(parents=True);mods.write_text('OtherMod : 0\nPreconstructionLibraryProbe : 0\nBPModLoaderMod : 0\n')
   library=mods.parent/'PreconstructionLibraryProbe/Scripts/preconstructions/library.index';library.parent.mkdir(parents=True);library.write_text('keep this')
   result=self.run_installer(source,game);self.assertEqual(result.returncode,0,result.stdout+result.stderr)
   self.assertEqual(proxy.read_bytes(),b'new proxy');self.assertEqual(library.read_text(),'keep this')
   text=mods.read_text();self.assertIn('OtherMod : 0',text);self.assertIn('PreconstructionLibraryProbe : 0',text);self.assertIn('BPModLoaderMod : 1',text);self.assertTrue(text.rstrip().endswith('Keybinds : 1'))
   backups=list((game/'BMF_Backups').glob('*/Bladesong/Binaries/Win64/dwmapi.dll'));self.assertEqual(len(backups),1);self.assertEqual(backups[0].read_bytes(),b'old proxy')
 def test_bootstrap_does_not_take_over_external_deployment(self):
  with tempfile.TemporaryDirectory(dir=ROOT/'Tests')as temp:
   source,game,_=self.setup_fixture(Path(temp));mod=game/'Bladesong/Binaries/Win64/ue4ss/Mods/BladesongModManager';mod.mkdir(parents=True);(mod/'deployment.json').write_text(json.dumps({'schema_version':1,'owner':'vortex'}))
   result=self.run_installer(source,game);self.assertNotEqual(result.returncode,0);self.assertFalse((game/'BMF_Backups').exists());self.assertEqual(json.loads((mod/'deployment.json').read_text())['owner'],'vortex')
 def test_bad_package_is_refused_before_writes(self):
  with tempfile.TemporaryDirectory(dir=ROOT/'Tests')as temp:
   source,game,_=self.setup_fixture(Path(temp));(source/'Bladesong/Binaries/Win64/dwmapi.dll').write_bytes(b'changed')
   result=self.run_installer(source,game);self.assertNotEqual(result.returncode,0);self.assertFalse((game/'BMF_Backups').exists());self.assertFalse((game/'Bladesong/Binaries/Win64/dwmapi.dll').exists())
 def test_wrong_game_folder_is_refused(self):
  with tempfile.TemporaryDirectory(dir=ROOT/'Tests')as temp:
   source,game,_=self.setup_fixture(Path(temp));wrong=Path(temp)/'wrong';wrong.mkdir()
   result=self.run_installer(source,wrong);self.assertNotEqual(result.returncode,0);self.assertEqual(list(wrong.iterdir()),[])
if __name__=='__main__':unittest.main()
