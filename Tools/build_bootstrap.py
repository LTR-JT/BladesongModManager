"""Standalone manager bootstrap overlay; UE4SS is added by build_easy_install.py."""
from pathlib import Path
import json,zipfile
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'Releases';version=json.loads((ROOT/'mod.json').read_text())['version'];source=OUT/f'BladesongModManager_{version}_Runtime.zip';out=OUT/f'BladesongModManager_{version}_Bootstrap.zip'
with zipfile.ZipFile(source)as src,zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED)as dest:
 for name in src.namelist():
  assert '/Mods/BladesongModFramework/'not in name and '/Mods/shared/BladesongFramework/'not in name
  data=src.read(name)
  if name.endswith('/deployment.json'):
   record=json.loads(data);record['owner']='bladesong-in-game';data=json.dumps(record).encode('utf-8')
  dest.writestr(name,data)
 dest.writestr('BOOTSTRAP.txt','Close Bladesong. Copy Bladesong into the Steam game folder. Enable BladesongModManager in UE4SS Mods/mods.txt. No framework is needed. Use Easy Install if UE4SS is missing.\n')
print('Prepared standalone manager bootstrap:',out)
