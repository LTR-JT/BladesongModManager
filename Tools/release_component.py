from pathlib import Path
import argparse,json
ROOT=Path(__file__).resolve().parents[1];p=argparse.ArgumentParser();p.add_argument('tag');a=p.parse_args()
meta=json.loads((ROOT/'mod.json').read_text());version=meta['version'];id=meta['id'];names=[f'{id}_{version}_Package.zip',f'{id}_{version}_Runtime.zip','mod.json']
names += [f'{id}_{version}_Bootstrap.zip',f'{id}_{version}_Easy_Install_With_UE4SS.zip']
assert a.tag=='v'+version,'Tag must match this repository component version'
for name in names:
 path=ROOT/'Releases'/name;assert path.is_file();print(path)
