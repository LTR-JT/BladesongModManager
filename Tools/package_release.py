from pathlib import Path
from sdk_tools import SDK_ROOT
from package_runtime import build
ROOT=Path(__file__).resolve().parents[1]
assert (ROOT/'Manager/BladesongModManager/Scripts/bmm-worker.exe').is_file(),'Build the manager helper first'
build(ROOT/'Manager/BladesongModManager',ROOT/'Releases','https://github.com/LTR-JT/BladesongModManager',ROOT/'LICENSE',ROOT/'THIRD_PARTY_NOTICES.md')
print('Prepared manager-only packages; use build_bootstrap.py separately for first-time installation')
