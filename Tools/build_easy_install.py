"""Package the tested UE4SS snapshot and manager without personal runtime data."""
from pathlib import Path
import hashlib,json,re,zipfile
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'Releases';OUT.mkdir(exist_ok=True)
runtime=ROOT/'Vendor/UE4SS_Bladesong_Configured.zip';pin=json.loads((ROOT/'Vendor/ue4ss.json').read_text())
if not runtime.exists():
 import urllib.request
 runtime.parent.mkdir(exist_ok=True)
 with urllib.request.urlopen(pin['download'],timeout=60)as response:
  data=response.read(67108865);assert len(data)<=67108864
 assert hashlib.sha256(data).hexdigest()==pin['sha256'],'UE4SS snapshot hash mismatch'
 runtime.write_bytes(data)
assert hashlib.sha256(runtime.read_bytes()).hexdigest()==pin['sha256'],'UE4SS snapshot hash mismatch'
version=json.loads((ROOT/'Manager/BladesongModManager/mod.json').read_text())['version']
manager=OUT/f'BladesongModManager_{version}_Bootstrap.zip';assert manager.exists(),'Build framework release first'
files={}
with zipfile.ZipFile(runtime)as z:
 for name in z.namelist():
  if name.startswith('Bladesong/'):files[name]=z.read(name)
with zipfile.ZipFile(manager)as z:
 for name in z.namelist():files[name]=z.read(name)
ini='Bladesong/Binaries/Win64/ue4ss/UE4SS-settings.ini'
text=files[ini].decode('utf-8-sig')
for key,value in {'ConsoleEnabled':'0','GuiConsoleEnabled':'0','GuiConsoleVisible':'0','EnableHotReloadSystem':'0','EnableAutoReloadingLuaMods':'0','bUseUObjectArrayCache':'false'}.items():
 text,n=re.subn(r'(?m)^'+key+r'\s*=.*$',key+' = '+value,text);assert n==1,key
files[ini]=text.encode('utf-8')
mods='Bladesong/Binaries/Win64/ue4ss/Mods/mods.txt'
text=files[mods].decode('utf-8').replace('Keybinds : 1','BladesongModFramework : 1\nBladesongModManager : 1\nKeybinds : 1')
files[mods]=text.encode('utf-8')
ps=(ROOT/'Installer/install.ps1').read_text(encoding='utf-8')
assert '"'not in ps and '%'not in ps and 'ExecutionPolicy'not in ps
inline=' '.join(line.strip()for line in ps.splitlines()if line.strip())
command='powershell.exe -NoLogo -NoProfile -STA -Command "& { '+inline+' }"'
assert len(command)<7900,('Installer command too long',len(command))
cmd='@echo off\r\nsetlocal DisableDelayedExpansion\r\nset "BMF_INSTALL_SOURCE=%~dp0"\r\n'+command+'\r\nif errorlevel 1 echo Installation did not finish. Read the message above.\r\npause\r\n'
files['INSTALL.cmd']=cmd.encode('ascii')
files['START HERE.txt']=(ROOT/'Installer/START HERE.txt').read_bytes()
files['UE4SS_NOTICE.txt']=(ROOT/'Vendor/README.md').read_bytes()
manifest={'version':version,'files':[{'path':n,'sha256':hashlib.sha256(b).hexdigest(),'size':len(b)}for n,b in sorted(files.items())if n.startswith('Bladesong/')]}
files['INSTALL_MANIFEST.json']=(json.dumps(manifest,indent=2)+'\n').encode('utf-8')
assert not any(re.search(r'(^|/)(Data|preconstructions|SaveGames)(/|$)|\.(sav|log|dmp|jmap|usmap)$|Shipping\.exe$',n,re.I)for n in files)
bundle=OUT/f'BladesongModManager_{version}_Easy_Install_With_UE4SS.zip'
with zipfile.ZipFile(bundle,'w',zipfile.ZIP_DEFLATED,compresslevel=9)as z:
 for name,data in sorted(files.items()):z.writestr(name,data)
with zipfile.ZipFile(bundle)as z:assert z.testzip()is None
archives=sorted(OUT.glob('*.zip'))
(OUT/'SHA256SUMS.txt').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.name+'\n'for p in archives),encoding='utf-8')
print('Easy-install bundle:',bundle,'files:',len(files),'installer command:',len(command))
