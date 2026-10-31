"""Combine explicit runtime and manager packages for a one-time bootstrap."""
from pathlib import Path,PurePosixPath
import argparse,json,zipfile,hashlib
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'Releases';p=argparse.ArgumentParser();p.add_argument('--framework-archive',required=True);a=p.parse_args();framework=Path(a.framework_archive).resolve();meta=json.loads((ROOT/'mod.json').read_text());version=meta['version'];manager=OUT/f'BladesongModManager_{version}_Runtime.zip';assert manager.exists()
files={};found=set()
for archive in [framework,manager]:
 with zipfile.ZipFile(archive)as z:
  assert z.testzip()is None
  for name in z.namelist():
   assert not name.startswith('/')and '\\'not in name and ':'not in name and '..'not in PurePosixPath(name).parts
   assert not any(part in ['Data','SaveGames','preconstructions','blades']for part in PurePosixPath(name).parts)
   data=z.read(name)
   if name.endswith('/mod.json')and '/ue4ss/Mods/'in name:
    m=json.loads(data);found.add(m['id'])
    if m['id']=='BladesongModFramework':assert tuple(map(int,m['version'].split('.'))) >= (0,1,8)and m['api']=='^1.0.0','Bootstrap requires framework 0.1.8 or later on API 1'
   if name.endswith('/deployment.json'):
    owner=json.loads(data);owner['owner']='bladesong-in-game';data=json.dumps(owner).encode('utf-8')
   assert name not in files or files[name]==data,'Bootstrap file collision';files[name]=data
assert found=={'BladesongModFramework','BladesongModManager'},found
files['BOOTSTRAP.txt']=b'Close Bladesong. Copy Bladesong into the Steam game folder. Enable BladesongModFramework and BladesongModManager in UE4SS Mods/mods.txt, framework first. Use Easy Install if UE4SS is missing.\n'
out=OUT/f'BladesongModManager_{version}_Bootstrap.zip'
with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED)as z:
 for name,data in sorted(files.items()):z.writestr(name,data)
print('Prepared bootstrap with one shared framework:',out)
