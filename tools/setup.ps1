# One-click setup for the Shufflepuck Cafe static recompilation.
# Run it by double-clicking Setup.cmd in the repo folder; the README's "Step by
# step" is the same thing by hand, command for command.
#
# It checks Python, the macrecomp toolkit and MSYS2's mingw toolchain (asking
# before installing any of them), finds your game disk image, runs build.sh,
# and leaves a shortcut (Shufflepuck.cmd) that runs the result. Steps whose
# output already exists are skipped (-Force redoes them). Everything it does
# goes to setup.log.
param([switch]$Force, [string]$Image = "")

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Msys = if ($env:MSYS2_ROOT) { $env:MSYS2_ROOT } else { 'C:\msys64' }
$Log = Join-Path $Root 'setup.log'
Set-Location $Root
function Log($t) { Add-Content -Path $Log -Value $t -Encoding UTF8 }
Log "==== setup $(Get-Date -Format s)"

function Say($t, $c = 'Gray') { Write-Host $t -ForegroundColor $c; Log $t }
function Step($n, $t) { Write-Host ""; Say "[$n/5] $t" 'Cyan' }
function Fail($t) {
  Say "" ; Say "Setup stopped: $t" 'Red'
  Say "The details are in $Log. Fix that and run Setup.cmd again; finished steps are skipped." 'Yellow'
  Read-Host "Press Enter to close" | Out-Null; exit 1
}
function Ask($q) { $a = Read-Host "$q [Y/n]"; return -not ($a -match '^[nN]') }   # Enter = yes
function Refresh-Path {
  $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}
# Run a program with its output in the log. Windows PowerShell turns a native
# program's stderr into errors, so 'Stop' is off while it runs.
function Exec([string[]]$cmd) {
  $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  $rest = @($cmd | Select-Object -Skip 1)   # @(): a one-element slice would splat as characters
  & $cmd[0] @rest 2>&1 | ForEach-Object { Log "$_" }
  $code = $LASTEXITCODE
  $ErrorActionPreference = $old
  return $code
}
function Run($what, [string[]]$cmd) {
  Say "  $what..."
  $code = Exec $cmd
  if ($code -ne 0) { Fail "$what failed (exit code $code)." }
}

Clear-Host
Say "Shufflepuck Cafe - static recompilation setup" 'White'
Say "You need your own disk image of Shufflepuck Cafe v1.0 (the game disk, .dc42)."
Say "Building takes about a minute once the tools are in place."

# ---------------------------------------------------------------- tools
Step 1 "Checking Python and the macrecomp toolkit"
# A Python that answers "Python 3.x". The Store's placeholder "python" (the
# one that opens the Store) answers nothing, so asking is the reliable test.
function Find-Python {
  foreach ($c in @(@('py', '-3'), @('python'), @('python3'))) {
    if (-not (Get-Command $c[0] -ErrorAction SilentlyContinue)) { continue }
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $rest = @($c | Select-Object -Skip 1)
    $v = (& $c[0] @rest --version 2>&1 | Out-String).Trim()
    $ErrorActionPreference = $old
    if ($v -match '^Python 3\.(\d+)' -and [int]$Matches[1] -ge 10) { return ,$c }
  }
  return $null
}
$pyargs = Find-Python
if (-not $pyargs) {
  Say "  Python 3.10 or newer is not installed."
  if (-not (Ask "  Install Python 3.12 now (winget, for your user only, about 30 MB)?")) { Fail "Python 3 is required." }
  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Fail "winget is missing. Install 'App Installer' from the Microsoft Store, or install Python yourself."
  }
  Exec @('winget', 'install', '-e', '--id', 'Python.Python.3.12', '--scope', 'user', '--accept-package-agreements', '--accept-source-agreements') | Out-Null
  Refresh-Path
  $pyargs = Find-Python
  if (-not $pyargs) { Fail "Python installed, but Windows has not picked it up yet: close this window and run Setup.cmd again." }
}
$rest = @($pyargs | Select-Object -Skip 1)
$PyExe = (& $pyargs[0] @rest -c "import sys; print(sys.executable)").Trim()
Say "  Python: $PyExe"

if (-not (Test-Path 'ext\macrecomp\tools\lift68k.py')) {
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Fail "git is needed to fetch macrecomp. Install Git for Windows, then run Setup.cmd again." }
  if (Test-Path '.git') {
    Run "Fetching the macrecomp submodule" @('git', 'submodule', 'update', '--init', '--recursive')
  } else {
    # ponytail: a plain zip download has no submodule pin, so this takes macrecomp's main;
    # a clone (git clone --recursive) gets the exact pinned toolkit.
    if (-not (Ask "  The macrecomp toolkit is missing. Download it now (git, about 5 MB)?")) { Fail "macrecomp is required in ext\macrecomp." }
    Run "Cloning macrecomp" @('git', 'clone', '--depth', '1', 'https://github.com/sp00nznet/macrecomp', 'ext\macrecomp')
  }
}
Say "  macrecomp: ext\macrecomp"

if ((Exec @($PyExe, '-c', 'import macresources, machfs, capstone')) -ne 0) {
  Say "  The Python packages macresources, machfs and capstone are missing (about 10 MB)."
  if (-not (Ask "  Install them now (pip, for your user only)?")) { Fail "macresources, machfs and capstone are required." }
  Run "Installing the Python packages" @($PyExe, '-m', 'pip', 'install', '--user', '-r', 'ext\macrecomp\tools\requirements.txt')
}

# ---------------------------------------------------------------- compiler
Step 2 "Checking MSYS2's mingw64 compiler and SDL2"
$Bash = Join-Path $Msys 'usr\bin\bash.exe'
if (-not (Test-Path $Bash)) {
  Say "  MSYS2 is not installed at $Msys (set MSYS2_ROOT if it is elsewhere)."
  if (-not (Ask "  Install MSYS2 now (winget, about 400 MB)?")) { Fail "MSYS2 is required to compile." }
  Exec @('winget', 'install', '-e', '--id', 'MSYS2.MSYS2', '--accept-package-agreements', '--accept-source-agreements') | Out-Null
  if (-not (Test-Path $Bash)) { Fail "MSYS2 did not install to $Msys. Install it from https://www.msys2.org, then run Setup.cmd again." }
}
$Mingw = Join-Path $Msys 'mingw64\bin'
if (-not ((Test-Path "$Mingw\gcc.exe") -and (Test-Path "$Mingw\SDL2.dll") -and (Test-Path "$Mingw\pkg-config.exe"))) {
  Say "  The mingw64 gcc, SDL2 and pkg-config packages are missing (about 250 MB)."
  if (-not (Ask "  Install them now (pacman)?")) { Fail "gcc, SDL2 and pkg-config are required to compile." }
  Run "Installing gcc, SDL2 and pkg-config" @($Bash, '-lc', 'pacman -S --needed --noconfirm mingw-w64-x86_64-gcc mingw-w64-x86_64-SDL2 mingw-w64-x86_64-pkgconf')
}
Say "  mingw64: $Mingw"

# ---------------------------------------------------------------- the game
Step 3 "Finding your Shufflepuck Cafe game disk"
function Is-Image([string]$p) { return ($p -and (Test-Path -LiteralPath $p -PathType Leaf) -and ($p -match '\.(dc42|img|dsk|image)$')) }
$Image = $Image.Trim('"', ' ')
if (-not (Is-Image $Image)) {
  $Image = (Get-ChildItem 'original' -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Game.*\.dc42$|Disk 2.*\.dc42$' } | Select-Object -First 1).FullName
}
if (-not (Is-Image $Image)) {
  $Image = (Get-ChildItem (Join-Path $env:USERPROFILE 'Downloads') -Recurse -File -Depth 2 -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match 'shufflepuck.*(game|disk ?2).*\.dc42$' } | Select-Object -First 1).FullName
  if ($Image) { Say "  Found it in Downloads: $Image" }
}
while (-not (Is-Image $Image)) {
  $Image = (Read-Host "  Path to the game disk image (.dc42), or drag the file here").Trim('"', ' ')
  if (-not $Image) { Fail "the game disk image is required (bring your own copy; see the README)." }
}
New-Item -ItemType Directory -Force 'original' | Out-Null
$Local = Join-Path 'original' (Split-Path -Leaf $Image)
if ((Resolve-Path -LiteralPath $Image).Path -ne (Join-Path $Root $Local)) { Copy-Item -LiteralPath $Image $Local -Force }
Say "  Disk image: $Local"

# ---------------------------------------------------------------- build
Step 4 "Extracting, unprotecting, lifting and compiling"
if ((Test-Path 'build\shufflepuck.exe') -and -not $Force) {
  Say "  Already built (skipping; Setup.cmd -Force rebuilds)."
} else {
  # build.sh runs under MSYS2's bash with mingw64 first on PATH and the Windows
  # Python passed in, exactly as Step by step does it.
  $env:MSYSTEM = 'MINGW64'; $env:CHERE_INVOKING = '1'
  $env:PYTHON = ($PyExe -replace '\\', '/')
  Run "Running build.sh" @($Bash, '-lc', "./build.sh '$($Local -replace '\\', '/')'")
}
Copy-Item "$Mingw\SDL2.dll" 'build\' -Force

# ---------------------------------------------------------------- shortcut
Step 5 "Making the shortcut"
Set-Content -Path 'Shufflepuck.cmd' -Encoding ASCII -Value "@echo off`r`ncd /d `"%~dp0`"`r`nbuild\shufflepuck.exe work\unpacked %*"
Say "  Done. Double-click Shufflepuck.cmd to run it." 'Green'
Say "  It is not playable yet: it boots, draws, and stops in the intro (see the README)."
Read-Host "Press Enter to close" | Out-Null
