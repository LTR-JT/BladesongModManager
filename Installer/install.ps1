$ErrorActionPreference='Stop';
function GameRoot($p) {
 if (!$p) { return $null; };
 $p=[IO.Path]::GetFullPath($p);
 foreach ($r in @($p,(Split-Path $p),(Split-Path (Split-Path $p)),(Split-Path (Split-Path (Split-Path $p))))) {
  if ($r -and (Test-Path -LiteralPath (Join-Path $r 'Bladesong/Binaries/Win64/Bladesong-Win64-Shipping.exe') -PathType Leaf)) { return $r; };
 };
 return $null;
};
function SafePath($root,$relative) {
 if ($relative -notmatch '^Bladesong/(Binaries/Win64/|Content/Paks/LogicMods/)' -or $relative -match '(^|/)\.\.(/|$)|:') { throw 'Invalid package path.'; };
 $p=[IO.Path]::GetFullPath((Join-Path $root $relative));
 if (!$p.StartsWith($root.TrimEnd([char]92)+[char]92,[StringComparison]::OrdinalIgnoreCase)) { throw 'Path leaves the game folder.'; };
 for ($q=$p; $q -and $q.Length -ge $root.Length; $q=Split-Path $q) {
  if (Test-Path -LiteralPath $q) { if ((Get-Item -LiteralPath $q -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Linked install folders are not supported.'; }; };
 };
 return $p;
};
function FileHash($path) {
 $stream=[IO.File]::OpenRead($path);$hash=[Security.Cryptography.SHA256]::Create();
 try { return [BitConverter]::ToString($hash.ComputeHash($stream)).Replace('-','').ToLowerInvariant(); } finally { $stream.Dispose();$hash.Dispose(); };
};
$source=$env:BMF_INSTALL_SOURCE;
if (!$source) { throw 'Extract the ZIP, then run INSTALL.cmd.'; };
$root=GameRoot $env:BMF_INSTALL_TARGET;
if (!$root -and !$env:BMF_INSTALL_TARGET) {
 $steam=@((Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath,(Join-Path ([Environment]::GetFolderPath('ProgramFilesX86')) 'Steam'));
 $libraries=@($steam);
 foreach ($s in $steam) {
  if ($s) {
   $vdf=Join-Path $s 'steamapps/libraryfolders.vdf';
   if (Test-Path -LiteralPath $vdf) {
    foreach ($line in (Get-Content -LiteralPath $vdf)) {
     if ($line -match '\x22path\x22\s+\x22([^\x22]+)\x22') { $libraries+=$matches[1].Replace('\\','\'); };
    };
   };
  };
 };
 $found=@(@(foreach ($lib in ($libraries | Select-Object -Unique)) { if ($lib) { $r=GameRoot (Join-Path $lib 'steamapps/common/Bladesong'); if ($r) { $r; }; }; }) | Select-Object -Unique);
 if ($found.Count -eq 1) { $root=$found[0]; };
};
$quiet=$env:BMF_INSTALL_UNATTENDED -eq '1';
if (!$root -and !$quiet) {
 Add-Type -AssemblyName System.Windows.Forms;
 $dialog=New-Object System.Windows.Forms.FolderBrowserDialog;
 $dialog.Description='Choose Bladesong: Steam > Bladesong > Manage > Browse local files';
 if ($dialog.ShowDialog() -ne 'OK') { exit 0; };
 $root=GameRoot $dialog.SelectedPath;
};
if (!$root) { throw 'Bladesong was not found. Choose the folder opened by Steam > Bladesong > Manage > Browse local files.'; };
foreach ($process in @(Get-Process -Name 'Bladesong-Win64-Shipping' -ErrorAction SilentlyContinue)) {
 if (!$process.Path -or $process.Path.StartsWith($root,[StringComparison]::OrdinalIgnoreCase)) { throw 'Close Bladesong, then run INSTALL.cmd again.'; };
};
if (!$quiet) {
 Write-Host ('Install Mod Manager + UE4SS into: '+$root);
 Write-Host 'Verified manual manager installations will be maintained by the in-game manager after installation.';
 if ((Read-Host 'Press Enter to install, or type N to cancel') -match '^[Nn]') { exit 0; };
};
$manifest=Get-Content -LiteralPath (Join-Path $source 'INSTALL_MANIFEST.json') -Raw | ConvertFrom-Json;
$files=@($manifest.files);
if (!$files.Count) { throw 'The package has no files.'; };
foreach ($file in $files) {
 $from=SafePath ([IO.Path]::GetFullPath($source)) $file.path;
 $to=SafePath $root $file.path;
 if (!(Test-Path -LiteralPath $from -PathType Leaf) -or (FileHash $from) -ne $file.sha256) { throw 'Package verification failed. Extract the ZIP again.'; };
 if (Test-Path -LiteralPath $to -PathType Container) { throw ('A folder blocks installation: '+$to); };
};
foreach ($id in @('BladesongModManager')) {
 $base='Bladesong/Binaries/Win64/ue4ss/Mods/'+$id+'/';
 $ownerPath=SafePath $root ($base+'deployment.json');
 $receiptPath=SafePath $root ($base+'bmf-installed.json');
 $entryPath=SafePath $root ($base+'Scripts/main.lua');
 if (Test-Path -LiteralPath $ownerPath -PathType Leaf) {
  $ownership=Get-Content -LiteralPath $ownerPath -Raw | ConvertFrom-Json;
  if ($ownership.owner -notin @('manual','bladesong-in-game')) { throw ('Managed by '+$ownership.owner+'. Remove its deployment using that manager first.'); };
 };
 if (Test-Path -LiteralPath $entryPath -PathType Leaf) {
  if (!(Test-Path -LiteralPath $receiptPath -PathType Leaf)) { throw 'Existing component has no portable receipt. Back up and redeploy it before using bootstrap.'; };
  $receipt=Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json;
  foreach ($owned in @($receipt.files)) {
   $relative=$base+$owned.path;
   if ($id -eq 'BladesongModFramework' -and $owned.path.StartsWith('shared/')) { $relative='Bladesong/Binaries/Win64/ue4ss/Mods/shared/BladesongFramework/'+$owned.path.Substring(7); };
   if ($owned.path.StartsWith('assets/logicmods/')) { $relative='Bladesong/Content/Paks/LogicMods/'+$owned.path.Substring(17); };
   $checked=SafePath $root $relative;
   if (!(Test-Path -LiteralPath $checked -PathType Leaf) -or (FileHash $checked) -ne $owned.sha256) { throw 'Existing component contains local changes. Back up and migrate those files explicitly.'; };
  };
 };
};
$backup=Join-Path $root ('BMF_Backups/'+[DateTime]::Now.ToString('yyyyMMdd_HHmmss_ffff'));
$records=@();
foreach ($file in $files) {
 $to=SafePath $root $file.path;
 $existed=Test-Path -LiteralPath $to -PathType Leaf;
 if ($existed) { $saved=Join-Path $backup $file.path; New-Item -ItemType Directory -Force -Path (Split-Path $saved) | Out-Null; Copy-Item -LiteralPath $to -Destination $saved; };
 $records+=@{path=$file.path;existed=$existed};
};
New-Item -ItemType Directory -Force -Path $backup | Out-Null;
$records | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $backup 'files.json') -Encoding UTF8;
$mods='Bladesong/Binaries/Win64/ue4ss/Mods/mods.txt';
$modsPath=SafePath $root $mods;
$oldMods=if (Test-Path -LiteralPath $modsPath) { Get-Content -LiteralPath $modsPath; } else { @(); };
try {
 foreach ($file in $files) {
  $to=SafePath $root $file.path;
  New-Item -ItemType Directory -Force -Path (Split-Path $to) | Out-Null;
  Copy-Item -LiteralPath (Join-Path $source $file.path) -Destination $to -Force;
 };
 $lines=if (@($oldMods).Count) { @($oldMods); } else { @(Get-Content -LiteralPath $modsPath); };
 foreach ($id in @('BPML_GenericFunctions','BPModLoaderMod','BladesongModManager')) {
  $pattern='^\s*'+[regex]::Escape($id)+'\s*:';
  $lines=@($lines | Where-Object { $_ -notmatch $pattern; });
  $lines+=($id+' : 1');
 };
 $lines=@($lines | Where-Object { $_ -notmatch '^\s*Keybinds\s*:'; });
 $lines+='Keybinds : 1';
 [IO.File]::WriteAllLines($modsPath,[string[]]$lines,(New-Object Text.UTF8Encoding($false)));
 foreach ($file in $files) { if ($file.path -ne $mods -and (FileHash (SafePath $root $file.path)) -ne $file.sha256) { throw 'Installed file verification failed.'; }; };
} catch {
 foreach ($record in $records) {
  $to=SafePath $root $record.path;
  if ($record.existed) { Copy-Item -LiteralPath (Join-Path $backup $record.path) -Destination $to -Force; } elseif (Test-Path -LiteralPath $to -PathType Leaf) { Remove-Item -LiteralPath $to; };
 };
 throw;
};
Write-Host 'Installed. Start Bladesong and click Mods above Options.';
Write-Host ('Replaced files were backed up in: '+$backup);
