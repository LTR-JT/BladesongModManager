from pathlib import Path
import json,zipfile,hashlib
from sdk_tools import SDK_ROOT
from validate_manifest import validate_manifest
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'Releases';meta=json.loads((ROOT/'mod.json').read_text());id=meta['id'];version=meta['version']
with zipfile.ZipFile(OUT/f'{id}_{version}_Package.zip')as z:
 m=validate_manifest(json.loads(z.read('mod.json')));assert m['id']==id
 for file in m['files']:assert len(z.read(file['path']))==file['size']and hashlib.sha256(z.read(file['path'])).hexdigest()==file['sha256']
 assert len(z.namelist())==len(m['files'])+1
 assert not any(name.startswith('shared/')for name in z.namelist())and m['dependencies']['BladesongModFramework']
bootstrap=OUT/f'{id}_{version}_Bootstrap.zip'
if bootstrap.exists():
 with zipfile.ZipFile(bootstrap)as z:
  for component in ['BladesongModFramework','BladesongModManager']:
   prefix='Bladesong/Binaries/Win64/ue4ss/Mods/'+component+'/'
   assert prefix+'Scripts/main.lua'in z.namelist();assert json.loads(z.read(prefix+'deployment.json'))['owner']=='bladesong-in-game'
  assert len([name for name in z.namelist()if name.endswith('/BladesongModFramework/Scripts/main.lua')])==1
 easy=OUT/f'{id}_{version}_Easy_Install_With_UE4SS.zip'
 with zipfile.ZipFile(easy)as z:assert b'ConsoleEnabled = 0'in z.read('Bladesong/Binaries/Win64/ue4ss/UE4SS-settings.ini')
print('PASS: manager package hashes, separate framework dependency, and optional one-time bootstrap')
