from pathlib import Path
import json,zipfile,hashlib
from sdk_tools import SDK_ROOT
from validate_manifest import validate_manifest
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'Releases';meta=json.loads((ROOT/'mod.json').read_text());id=meta['id'];version=meta['version']
with zipfile.ZipFile(OUT/f'{id}_{version}_Package.zip')as z:
 m=validate_manifest(json.loads(z.read('mod.json')));assert m['id']==id
 for file in m['files']:assert len(z.read(file['path']))==file['size']and hashlib.sha256(z.read(file['path'])).hexdigest()==file['sha256']
 assert len(z.namelist())==len(m['files'])+1
 assert not any(name.startswith('shared/')for name in z.namelist())and m.get('standalone')is True and not m.get('dependencies')
 for name in ['Scripts/main.lua','Scripts/services.lua','Scripts/manager.lua']:
  source=z.read(name).decode('utf-8');assert 'shared/BladesongFramework/'not in source and '/Game/PCL/'not in source
bootstrap=OUT/f'{id}_{version}_Bootstrap.zip'
if bootstrap.exists():
 with zipfile.ZipFile(bootstrap)as z:
  for component in ['BladesongModManager']:
   prefix='Bladesong/Binaries/Win64/ue4ss/Mods/'+component+'/'
   assert prefix+'Scripts/main.lua'in z.namelist();assert json.loads(z.read(prefix+'deployment.json'))['owner']=='bladesong-in-game'
  assert not any('/Mods/BladesongModFramework/'in name or '/Mods/shared/BladesongFramework/'in name for name in z.namelist())
 easy=OUT/f'{id}_{version}_Easy_Install_With_UE4SS.zip'
 with zipfile.ZipFile(easy)as z:
  assert b'ConsoleEnabled = 0'in z.read('Bladesong/Binaries/Win64/ue4ss/UE4SS-settings.ini')
  assert not any('/Mods/BladesongModFramework/'in name or '/Mods/shared/BladesongFramework/'in name for name in z.namelist())
print('PASS: standalone manager package hashes, no framework or PCL assets, and UE4SS-only bootstrap')
