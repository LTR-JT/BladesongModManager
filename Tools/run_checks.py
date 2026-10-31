from pathlib import Path
import argparse,json,os,subprocess,sys,tempfile
from sdk_tools import SDK_ROOT
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--lua',required=True);a=p.parse_args();lua=str(Path(a.lua).resolve())
os.environ.update(BMF_TEST_ROOT=str(ROOT),BMF_TEST_LUA=lua)

def run(*cmd):subprocess.run([str(x)for x in cmd],cwd=ROOT,check=True)
from validate_manifest import validate_manifest
validate_manifest(json.loads((ROOT/'mod.json').read_text()))
assert json.loads((ROOT/'mod.json').read_text())==json.loads((ROOT/'Manager/BladesongModManager/mod.json').read_text())
with tempfile.TemporaryDirectory(dir=ROOT/'Tests')as tmp:
 path=Path(tmp)/'syntax.lua';path.write_text('\n'.join('assert(loadfile('+json.dumps(str(f).replace('\\','/'))+'))'for f in (ROOT/'Manager').rglob('*.lua')),encoding='utf-8');run(lua,path)
for name in ['manager_startup.lua','catalogue.lua','menu.lua','manager_open.lua','browse.lua']:run(lua,ROOT/'Tests'/name)
run(sys.executable,ROOT/'Tools/build_worker.py')
for name in ['install_test.py','dependency_test.py','installer_test.py']:run(sys.executable,ROOT/'Tests'/name)
print('All optional manager checks passed')
