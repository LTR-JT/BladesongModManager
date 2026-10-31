from pathlib import Path
import os,subprocess
from msvc import build
ROOT=Path(__file__).resolve().parents[1];fx=Path(os.environ.get('WINDIR',r'C:\Windows'))/'Microsoft.NET/Framework64/v4.0.30319'
subprocess.run([str(fx/'csc.exe'),'/nologo','/optimize+','/target:winexe','/out:'+str(ROOT/'Manager/BladesongModManager/Scripts/bmm-worker.exe'),*['/reference:'+str(fx/name)for name in ['System.Web.Extensions.dll','System.IO.Compression.dll','System.IO.Compression.FileSystem.dll']],str(ROOT/'ManagerHelper/Worker.cs'),str(ROOT/'ManagerHelper/Resolver.cs')],check=True)
build(ROOT/'NativeSource/common/worker_launch.cpp',ROOT/'Manager/BladesongModManager/Scripts/bmm-launch.dll',ROOT/'Build/manager-launch')
