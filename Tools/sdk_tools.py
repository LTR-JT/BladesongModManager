"""Build-time SDK tools; never imported by an installed game mod."""
from pathlib import Path
import os,sys
SDK_ROOT=Path(os.environ.get('BMF_SDK_ROOT',Path(__file__).resolve().parents[2]/'BladesongSDK')).resolve()
assert (SDK_ROOT/'Tools/validate_manifest.py').is_file(),'Checkout BladesongSDK beside this repository or set BMF_SDK_ROOT'
sys.path.insert(0,str(SDK_ROOT/'Tools'))
