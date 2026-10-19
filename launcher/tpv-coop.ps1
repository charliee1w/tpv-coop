# The Pink Valley - tag-along co-op launcher (co-op add-on by gore).
# Started by "Host co-op.bat", "Join co-op.bat" and "Try it on this PC (two windows).bat".
#
# Before every start it checks for a newer version of the co-op files and installs it, so everyone
# who plays together has the same files. Your choices (friends, character, where the game is) are
# kept in launcher\settings.json next to this file. Delete that file to start over.
#
# Keep this file plain ASCII: Windows PowerShell 5.1 reads scripts without a BOM as ANSI.

param(
    [ValidateSet('host', 'join', 'try')]
    [string]$Mode = 'host',
    [switch]$NoUpdate,
    [switch]$Updated
)

$ErrorActionPreference = 'Stop'
$LauncherDir = $PSScriptRoot

# Everything this window shows also goes to launcher\last-run.txt, so someone whose launcher fails
# can send that file.
$script:Logging = $false
try { Start-Transcript -LiteralPath (Join-Path $LauncherDir 'last-run.txt') -Force | Out-Null; $script:Logging = $true } catch { }

# Any error nobody planned for: say what it was and keep the window open. Without this the window
# just closes and nobody can see why. Exit code 0 tells the .bat the message was already shown.
trap {
    $msg = $_.Exception.Message
    $line = $_.InvocationInfo.ScriptLineNumber
    try {
        Write-Host ''
        Write-Host ("Something went wrong: {0} (launcher line {1})" -f $msg, $line) -ForegroundColor Red
        Write-Host 'Send a screenshot of this window (or the file launcher\last-run.txt) to whoever gave you the co-op files.' -ForegroundColor Yellow
    } catch { }
    if ($script:Logging) { try { Stop-Transcript | Out-Null } catch { } }
    try { Read-Host 'Press Enter to close' | Out-Null } catch { }
    exit 0
}
$Root = Split-Path -Parent $LauncherDir
$SettingsFile = Join-Path $LauncherDir 'settings.json'
$Repo = 'charliee1w/tpv-coop'
$CoopPk3 = Join-Path $Root 'TPV_TagAlong_Coop.pk3'

$Characters = @(
    @('tilin', 'Tilin'), @('betatilin', 'Beta Tilin'), @('ella', 'Ella'), @('frida', 'Frida'),
    @('man', 'Civilian (man)'), @('woman', 'Civilian (woman)'), @('boy', 'Kid (boy)'), @('girl', 'Kid (girl)'),
    @('paco', 'Paco'), @('paca', 'Paca'), @('riotpaco', 'Riot Paco'), @('perropaco', 'Perro Paco'),
    @('odio', 'ODIO'), @('bipedo', 'Bipedo'), @('bipeda', 'Bipeda'), @('cuadrupedo', 'Cuadrupedo'),
    @('oppressive', 'The Oppressive'), @('lovemachine', 'Love Machine')
)
$Skills = @('SNOWFLAKE', 'RAGE QUIT', 'COMPETENT PEOPLE', 'COMPETENT AND A LITTLE TRY HARD PEOPLE', 'CORROSION', 'MORE CORROSION')

# ---------------------------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------------------------

function Say([string]$Text = '', [string]$Color = 'Gray') { Write-Host $Text -ForegroundColor $Color }

# A problem the launcher understands: explain it and wait. Exit code 0: the .bat only pauses on
# its own when PowerShell stopped without a word.
function Quit([string]$Why) {
    Say ''
    Say $Why 'Red'
    if ($script:Logging) { try { Stop-Transcript | Out-Null } catch { } }
    Read-Host 'Press Enter to close' | Out-Null
    exit 0
}

function Ask([string]$Question, [string]$Default = '') {
    $prompt = $Question
    if ($Default -ne '') { $prompt = "$Question [$Default]" }
    $a = Read-Host $prompt
    if ($a -eq $null) { $a = '' }
    $a = $a.Trim().Trim([char]0xFEFF)
    if ($a -eq '') { return $Default }
    return $a
}

function Load-Settings {
    $s = $null
    if (Test-Path -LiteralPath $SettingsFile) {
        try { $s = Get-Content -LiteralPath $SettingsFile -Raw | ConvertFrom-Json } catch { $s = $null }
    }
    if ($s -eq $null) { $s = New-Object PSObject }
    foreach ($k in @('engine', 'iwad', 'pv', 'name', 'character', 'skill', 'lastFriend', 'friendCharacter', 'nameAsked')) {
        if (-not ($s.PSObject.Properties.Name -contains $k)) { $s | Add-Member -NotePropertyName $k -NotePropertyValue '' }
    }
    if (-not ($s.PSObject.Properties.Name -contains 'friends')) { $s | Add-Member -NotePropertyName friends -NotePropertyValue @() }
    if (-not ($s.PSObject.Properties.Name -contains 'autoUpdate')) { $s | Add-Member -NotePropertyName autoUpdate -NotePropertyValue $true }
    $s.friends = @($s.friends | Where-Object { $_ -ne $null -and $_.address })
    return $s
}

function Save-Settings($s) {
    try { $s | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $SettingsFile -Encoding UTF8 } catch { }
}

# .NET only, no modules: when this runs from a PowerShell 7 window, Windows PowerShell can be
# handed the wrong module path and then Get-FileHash and friends don't exist.
function Get-Sha256([string]$Path) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $fs = [System.IO.File]::OpenRead($Path)
    try { return ([BitConverter]::ToString($sha.ComputeHash($fs))).Replace('-', '') }
    finally { $fs.Dispose(); $sha.Dispose() }
}

function Short-Hash([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return '------' }
    return (Get-Sha256 $Path).Substring(0, 6)
}

function Local-Version {
    $f = Join-Path $LauncherDir 'version.txt'
    if (Test-Path -LiteralPath $f) { return (Get-Content -LiteralPath $f -Raw).Trim() }
    return '?'
}

# ---------------------------------------------------------------------------------------------
# Updates: the latest release on GitHub lists every file with its SHA-256. Anything that differs
# here is downloaded, checked and swapped in. If this script itself changed, it restarts.
# ---------------------------------------------------------------------------------------------

function Update-CoopFiles {
    Say 'Checking for updates...' 'DarkGray'
    $tmp = $null
    try {
        # A scratch folder for the downloads: Windows' temp folder, or next to this file if that
        # one can't be used.
        try {
            $tmp = Join-Path ([IO.Path]::GetTempPath()) ('tpv-coop-' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        }
        catch {
            $tmp = Join-Path $LauncherDir ('tmp-' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        }
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        $ProgressPreference = 'SilentlyContinue'
        $mf = Join-Path $tmp 'manifest.json'
        Invoke-WebRequest -Uri "https://github.com/$Repo/releases/latest/download/manifest.json" -OutFile $mf -TimeoutSec 15 -UseBasicParsing
        $m = Get-Content -LiteralPath $mf -Raw | ConvertFrom-Json
        $need = @()
        foreach ($f in @($m.files)) {
            $dest = Join-Path $Root ($f.path -replace '/', '\')
            $have = ''
            if (Test-Path -LiteralPath $dest) { $have = Get-Sha256 $dest }
            if ($have -ne $f.sha256.ToUpper()) { $need += $f }
        }
        if ($need.Count -eq 0) { Say ("Up to date (version {0})." -f $m.version) 'DarkGray'; return $false }
        Say ("Updating to version {0} ({1} file(s))..." -f $m.version, $need.Count) 'Yellow'
        $selfChanged = $false
        foreach ($f in $need) {
            $dl = Join-Path $tmp $f.asset
            Invoke-WebRequest -Uri ("https://github.com/{0}/releases/download/{1}/{2}" -f $Repo, $m.tag, $f.asset) -OutFile $dl -TimeoutSec 60 -UseBasicParsing
            if ((Get-Sha256 $dl) -ne $f.sha256.ToUpper()) { throw "the download of $($f.path) was damaged" }
            $dest = Join-Path $Root ($f.path -replace '/', '\')
            New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force | Out-Null
            try { Copy-Item -LiteralPath $dl -Destination $dest -Force }
            catch { throw "couldn't replace $($f.path). Close the game if it's still open and try again" }
            if ($f.path -eq 'launcher/tpv-coop.ps1') { $selfChanged = $true }
            Say ("  updated {0}" -f $f.path) 'DarkGray'
        }
        Say ("Updated to version {0}." -f $m.version) 'Green'
        return $selfChanged
    }
    catch {
        Say ("Couldn't check for updates ({0}). Starting with the files you have." -f $_.Exception.Message) 'DarkYellow'
        return $false
    }
    finally {
        if ($tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

# ---------------------------------------------------------------------------------------------
# Finding the game, the IWAD and The Pink Valley
# ---------------------------------------------------------------------------------------------

function First-Existing($Paths) {
    foreach ($p in $Paths) {
        if ($p -and (Test-Path -LiteralPath $p -PathType Leaf)) { return (Resolve-Path -LiteralPath $p).Path }
    }
    return $null
}

function Search-Near([string[]]$Names) {
    # Common places people keep Doom ports, two folders deep.
    $places = @("$env:USERPROFILE\Desktop", "$env:USERPROFILE\OneDrive\Desktop", "$env:USERPROFILE\Downloads",
        "$env:USERPROFILE\Documents", "$env:USERPROFILE\Games", 'C:\Games', "$env:ProgramFiles", "${env:ProgramFiles(x86)}")
    foreach ($n in $Names) {
        foreach ($pl in $places) {
            if (-not $pl -or -not (Test-Path -LiteralPath $pl)) { continue }
            $hit = Get-ChildItem -LiteralPath $pl -Filter $n -File -Recurse -Depth 2 -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($hit) { return $hit.FullName }
        }
    }
    return $null
}

function Pick-File([string]$Title, [string]$Filter) {
    Add-Type -AssemblyName System.Windows.Forms
    $d = New-Object System.Windows.Forms.OpenFileDialog
    $d.Title = $Title
    $d.Filter = $Filter
    $owner = New-Object System.Windows.Forms.Form
    $owner.TopMost = $true
    $ok = $d.ShowDialog($owner)
    $owner.Dispose()
    if ($ok -eq [System.Windows.Forms.DialogResult]::OK) { return $d.FileName }
    return $null
}

function Find-GameFiles($s) {
    $parent = Split-Path -Parent $Root

    $engine = First-Existing @($s.engine, "$Root\uzdoom.exe", "$parent\uzdoom.exe", "$Root\gzdoom.exe", "$parent\gzdoom.exe")
    if (-not $engine) { $engine = Search-Near @('uzdoom.exe', 'gzdoom.exe') }
    if (-not $engine) {
        Say "Can't find UZDoom (uzdoom.exe). Pick it in the window that opens." 'Yellow'
        $engine = Pick-File 'Where is uzdoom.exe (or gzdoom.exe)?' 'UZDoom or GZDoom|uzdoom.exe;gzdoom.exe|Programs|*.exe'
        if (-not $engine) { Quit "No game picked. Install UZDoom 5.0.3 and try again." }
    }
    $engineDir = Split-Path -Parent $engine

    # Everyone needs the same IWAD. DOOM2.WAD wins over freedoom2.wad in the same folder.
    $iwad = First-Existing @($s.iwad, "$Root\DOOM2.WAD", "$Root\freedoom2.wad", "$parent\DOOM2.WAD", "$parent\freedoom2.wad",
        "$engineDir\DOOM2.WAD", "$engineDir\freedoom2.wad")
    if (-not $iwad) { $iwad = Search-Near @('DOOM2.WAD', 'freedoom2.wad') }
    if (-not $iwad) {
        Say "Can't find DOOM2.WAD or freedoom2.wad. Pick it in the window that opens." 'Yellow'
        $iwad = Pick-File 'Where is DOOM2.WAD (or freedoom2.wad)?' 'Doom 2 IWAD|*.wad'
        if (-not $iwad) { Quit "No IWAD picked." }
    }

    $pvName = 'THE_PINK_VALLEY - ENG.pk3'
    $pv = First-Existing @($s.pv, "$Root\$pvName", "$parent\$pvName", "$engineDir\$pvName")
    if (-not $pv) { $pv = Search-Near @($pvName) }
    if (-not $pv) {
        Say "Can't find $pvName. Pick it in the window that opens." 'Yellow'
        $pv = Pick-File "Where is $pvName ?" 'The Pink Valley|*.pk3'
        if (-not $pv) { Quit "The Pink Valley wasn't picked. Get version 1.1 from ModDB." }
    }

    if (-not (Test-Path -LiteralPath $CoopPk3)) { Quit "TPV_TagAlong_Coop.pk3 is missing next to the .bat files. Unzip the whole TPV co-op folder again." }

    $s.engine = $engine; $s.iwad = $iwad; $s.pv = $pv
    Save-Settings $s
    return @{ Engine = $engine; Iwad = $iwad; Pv = $pv; IsUZ = ((Split-Path -Leaf $engine) -like 'uzdoom*') }
}

# ---------------------------------------------------------------------------------------------
# Questions
# ---------------------------------------------------------------------------------------------

function Ask-Character($s, [string]$Who = 'your') {
    $last = $s.character
    if ($Who -ne 'your') { $last = $s.friendCharacter; if (-not $last) { $last = 'ella' } }
    $lastLabel = 'keep the one you had'
    foreach ($c in $Characters) { if ($c[0] -eq $last) { $lastLabel = $c[1] } }
    Say ''
    if ($Who -eq 'your') { Say 'Pick your character: what everyone else sees you as. You still play as Tilin.' }
    else { Say "Pick the second window's character." }
    # Three columns, as many rows as the list needs.
    $rows = [int][Math]::Ceiling($Characters.Count / 3)
    for ($i = 0; $i -lt $rows; $i++) {
        $line = ''
        foreach ($col in @($i, ($i + $rows), ($i + 2 * $rows))) {
            if ($col -lt $Characters.Count) { $line += ('  {0,2} {1,-18}' -f ($col + 1), $Characters[$col][1]) }
        }
        Say $line
    }
    $a = Ask 'Character' $lastLabel
    if ($a -eq $lastLabel) { return $last }
    $n = 0
    if ([int]::TryParse($a, [ref]$n) -and $n -ge 1 -and $n -le $Characters.Count) { return $Characters[$n - 1][0] }
    foreach ($c in $Characters) { if ($c[0] -ieq $a -or ($c[1] -replace ' ', '') -ieq ($a -replace ' ', '')) { return $c[0] } }
    Say "  (don't know that one, keeping $lastLabel)" 'DarkYellow'
    return $last
}

function Ask-Name($s) {
    if ($s.nameAsked) { return $s.name }
    Say ''
    $n = Ask 'Your name in the game (Enter = keep the one the game has)' ''
    $s.name = $n
    $s.nameAsked = 'yes'
    return $n
}

function Get-SavedGamesDir {
    try {
        $p = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' -ErrorAction Stop).'{4C5C32FF-BB9D-43b0-B5B4-2D72E54EAAA4}'
        if ($p) { return [Environment]::ExpandEnvironmentVariables($p) }
    } catch { }
    return (Join-Path $env:USERPROFILE 'Saved Games')
}

# Co-op saves of The Pink Valley made with this IWAD, newest first. UZDoom keeps net game saves
# apart, in a NetGame folder (Saved Games\UZDoom\NetGame\<game>); GZDoom keeps them with the rest.
function Find-Saves($g) {
    $exeDir = Split-Path -Parent $g.Engine
    if ($g.IsUZ) { $dirs = @((Join-Path (Get-SavedGamesDir) 'UZDoom\NetGame'), (Join-Path $exeDir 'Save\NetGame')) }
    else { $dirs = @((Join-Path (Get-SavedGamesDir) 'GZDoom'), (Join-Path $exeDir 'Save')) }
    $files = @()
    foreach ($d in $dirs) {
        if (Test-Path -LiteralPath $d) { $files += Get-ChildItem -LiteralPath $d -Filter *.zds -File -Recurse -Depth 1 -ErrorAction SilentlyContinue }
    }
    $files = @($files | Sort-Object LastWriteTime -Descending | Select-Object -First 40)
    $pvLeaf = Split-Path -Leaf $g.Pv
    $iwadLeaf = Split-Path -Leaf $g.Iwad
    $out = @()
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    foreach ($f in $files) {
        try {
            $z = [IO.Compression.ZipFile]::OpenRead($f.FullName)
            try {
                $e = $z.GetEntry('info.json')
                if (-not $e) { continue }
                $r = New-Object IO.StreamReader($e.Open())
                $info = $r.ReadToEnd() | ConvertFrom-Json
                $r.Close()
            } finally { $z.Dispose() }
            if ($info.'Map WAD' -ne $pvLeaf -or $info.'Game WAD' -ine $iwadLeaf) { continue }
            $out += [pscustomobject]@{ File = $f.Name; Path = $f.FullName; Title = $info.Title; Map = $info.'Current Map'; When = $f.LastWriteTime }
        } catch { }
        if ($out.Count -ge 9) { break }
    }
    return $out
}

function Ask-Save($g, [string]$Intro) {
    $saves = @(Find-Saves $g)
    if ($saves.Count -eq 0) { Say '  (no co-op saves of The Pink Valley found yet)' 'DarkYellow'; return $null }
    Say $Intro
    for ($i = 0; $i -lt $saves.Count; $i++) {
        Say ('  {0}) {1}  -  {2}  ({3:MMM d, h:mm tt})' -f ($i + 1), $saves[$i].Title, $saves[$i].Map, $saves[$i].When)
    }
    $a = Ask 'Which one' '1'
    $n = 0
    if ([int]::TryParse($a, [ref]$n) -and $n -ge 1 -and $n -le $saves.Count) { return $saves[$n - 1] }
    return $saves[0]
}

function Get-MyAddresses {
    $list = @()
    $ips = @()
    try {
        foreach ($nic in [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()) {
            if ($nic.OperationalStatus -ne 'Up') { continue }
            foreach ($u in $nic.GetIPProperties().UnicastAddresses) {
                if ($u.Address.AddressFamily -eq 'InterNetwork') {
                    $ips += [pscustomobject]@{ IPAddress = $u.Address.ToString(); InterfaceAlias = $nic.Name + ' ' + $nic.Description }
                }
            }
        }
    } catch { $ips = @() }
    foreach ($ip in $ips) {
        $a = $ip.IPAddress
        $alias = $ip.InterfaceAlias
        if ($a -like '127.*' -or $a -like '169.254.*' -or $alias -like 'vEthernet*' -or $alias -like '*Loopback*') { continue }
        $rank = 4; $kind = $alias
        if ($alias -like '*Radmin*') { $rank = 0; $kind = 'Radmin VPN' }
        elseif ($alias -like '*Tailscale*') { $rank = 1; $kind = 'Tailscale' }
        elseif ($alias -like '*ZeroTier*') { $rank = 2; $kind = 'ZeroTier' }
        elseif ($alias -like '*Hamachi*') { $rank = 3; $kind = 'Hamachi' }
        elseif ($a -like '192.168.*' -or $a -like '10.*' -or $a -match '^172\.(1[6-9]|2\d|3[01])\.') { $rank = 5; $kind = 'same house only' }
        $list += [pscustomobject]@{ Address = $a; Kind = $kind; Rank = $rank }
    }
    return @($list | Sort-Object Rank)
}

function Show-HostAddress {
    $addrs = @(Get-MyAddresses)
    Say ''
    if ($addrs.Count -gt 0 -and $addrs[0].Rank -lt 5) {
        $best = $addrs[0]
        $copied = ''
        if (-not $env:TPVC_LAUNCHER_DRYRUN) {
            try { Set-Clipboard -Value $best.Address; $copied = ' (copied: paste it to your friends)' }
            catch {
                try { Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.Clipboard]::SetText($best.Address); $copied = ' (copied: paste it to your friends)' } catch { }
            }
        }
        Say ("Your address for friends: {0}  [{1}]{2}" -f $best.Address, $best.Kind, $copied) 'Green'
        foreach ($o in $addrs | Select-Object -Skip 1) { Say ("  also {0}  [{1}]" -f $o.Address, $o.Kind) 'DarkGray' }
    }
    else {
        Say "You're not on a VPN (Radmin VPN, Tailscale, ZeroTier)." 'Yellow'
        foreach ($o in $addrs) { Say ("  Friends in your house can use {0}" -f $o.Address) }
        try {
            $pub = (Invoke-WebRequest -Uri 'https://api.ipify.org' -TimeoutSec 4 -UseBasicParsing).Content.Trim()
            Say ("  Friends elsewhere can use {0} only if you forwarded UDP port 5029 on your router." -f $pub)
        } catch { }
        Say '  Easiest: everyone installs Radmin VPN and joins the same network.' 'DarkGray'
    }
}

# ---------------------------------------------------------------------------------------------
# Start
# ---------------------------------------------------------------------------------------------

$Host.UI.RawUI.WindowTitle = 'The Pink Valley co-op'
Say ''
switch ($Mode) {
    'host' { Say '  THE PINK VALLEY co-op - HOST (you drive the story, your friends tag along)' 'Magenta' }
    'join' { Say "  THE PINK VALLEY co-op - JOIN (you tag along in a friend's game)" 'Magenta' }
    'try'  { Say '  THE PINK VALLEY co-op - try it on this PC (two windows)' 'Magenta' }
}
Say '  ----------------------------------------------------------------' 'DarkMagenta'

$s = Load-Settings
if (-not $NoUpdate -and -not $Updated -and $s.autoUpdate -ne $false) {
    if (Update-CoopFiles) {
        Say 'Restarting with the new launcher...' 'DarkGray'
        if ($script:Logging) { try { Stop-Transcript | Out-Null } catch { } }
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $LauncherDir 'tpv-coop.ps1') $Mode -Updated
        exit $LASTEXITCODE
    }
}

$g = Find-GameFiles $s
Say ("Co-op version {0}, files code {1}. Everyone playing together should see the same code." -f (Local-Version), (Short-Hash $CoopPk3)) 'Cyan'
Say ("Game: {0}   IWAD: {1}" -f (Split-Path -Leaf $g.Engine), (Split-Path -Leaf $g.Iwad)) 'DarkGray'

$common = @('-iwad', ('"{0}"' -f $g.Iwad), '-file', ('"{0}"' -f $g.Pv), ('"{0}"' -f $CoopPk3))
$hostRules = @('+sv_noplayerclip 1', '+alwaysapplydmflags 1', '+sv_weaponstay 0', '+sv_cooploseinventory 0', '+sv_cooplosekeys 0',
    '+sv_cooploseweapons 0', '+sv_cooplosearmor 0', '+sv_cooplosepowerups 0', '+sv_cooploseammo 0', '+sv_coophalveammo 0')

# TPVC_LAUNCHER_EXTRA / _DRYRUN / _LOG / _MIN are only for testing the launcher.
function Start-Game([string[]]$GameArgs) {
    $line = $GameArgs -join ' '
    if ($env:TPVC_LAUNCHER_EXTRA) { $line += ' ' + $env:TPVC_LAUNCHER_EXTRA }
    if ($env:TPVC_LAUNCHER_DRYRUN) { Say ("WOULD RUN: {0} {1}" -f $g.Engine, $line) 'DarkGray'; return }
    $p = @{ FilePath = $g.Engine; ArgumentList = $line; WorkingDirectory = (Split-Path -Parent $g.Engine) }
    if ($env:TPVC_LAUNCHER_MIN) { $p.WindowStyle = 'Minimized' }
    if ($env:TPVC_LAUNCHER_LOG) {
        $script:logN = 1 + [int]$script:logN
        $p.RedirectStandardOutput = ('{0}.{1}.log' -f $env:TPVC_LAUNCHER_LOG, $script:logN)
    }
    Start-Process @p | Out-Null
}

if ($Mode -eq 'host') {
    Show-HostAddress
    Say ''
    Say 'What do you want to play?'
    Say '  1) New game'
    Say '  2) Continue (pick a save)'
    Say '  3) New game on a map of your choice'
    $what = Ask 'Choice' '1'
    $load = $null
    $map = 'A_NEW_DAY'
    if ($what -eq '2') {
        $load = Ask-Save $g 'Saves (newest first). Everyone else loads the same one automatically:'
        if (-not $load) { Say '  Starting a new game instead.' 'DarkYellow' }
    }
    elseif ($what -eq '3') {
        $map = (Ask 'Map name (for example HOME, I_WANT_MY_MONONO, __)' 'A_NEW_DAY').ToUpper()
    }

    $gameArgs = @() + $common
    if ($load) {
        $gameArgs += @('-loadgame', ('"{0}"' -f $load.File))
    }
    else {
        Say ''
        for ($i = 0; $i -lt $Skills.Count; $i++) { Say ('  {0} {1}' -f ($i + 1), $Skills[$i]) }
        $sk = Ask 'Difficulty' $(if ($s.skill) { $s.skill } else { '3' })
        if ($sk -notmatch '^[1-6]$') { $sk = '3' }
        $s.skill = $sk
        Say ''
        Say 'Enemy multiplier: how many of each enemy the maps place (1 = normal, 2 = double, 1.5 works too).'
        Say 'Bosses, story enemies and civilians are never copied.'
        $mult = Ask 'Enemy multiplier' 'one per player'
        if ($mult -eq 'one per player') { $mult = '0' }
        $mv = 0.0
        if (-not [double]::TryParse($mult, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$mv) -or $mv -lt 0 -or $mv -gt 8) { $mv = 0 }
        $gameArgs += @('-skill', $sk, '+tpvc_startmap', $map, '+tpvc_enemymult', $mv.ToString([Globalization.CultureInfo]::InvariantCulture))
    }

    $s.character = Ask-Character $s
    $name = Ask-Name $s
    Save-Settings $s

    if ($g.IsUZ) {
        # 4 spots, started from the waiting window. net_limitsaves 0: anyone can save, not just the host.
        $gameArgs += @('-host', '4', '+net_limitsaves 0')
    }
    else {
        $n = Ask 'How many players in total, including you? 2-4' '2'
        if ($n -notmatch '^[2-4]$') { $n = '2' }
        $gameArgs += @('-host', $n)
    }
    $gameArgs += $hostRules
    if ($s.character) { $gameArgs += @('+tpvc_character', ('"{0}"' -f $s.character)) }
    if ($name) { $gameArgs += @('+name', ('"{0}"' -f $name)) }

    Say ''
    Say 'Starting. Your friends run "Join co-op.bat" and pick you (or type your address).' 'Green'
    if ($g.IsUZ) { Say 'When everyone shows up in the waiting window, click "Start Game".' 'Green' }
    if ($load) { Say ("Everyone loads {0} automatically." -f $load.File) 'Green' }
    Say 'In the game, J pulls everyone over to you.' 'DarkGray'
    Start-Game $gameArgs
    Start-Sleep -Seconds 4
    exit 0
}

if ($Mode -eq 'join') {
    $friends = @($s.friends)
    $pick = $null
    if ($friends.Count -gt 0) {
        Say ''
        Say 'Whose game are you joining?'
        $def = '1'
        for ($i = 0; $i -lt $friends.Count; $i++) {
            $tag = ''
            if ($friends[$i].name -eq $s.lastFriend) { $tag = '  (last time)'; $def = [string]($i + 1) }
            Say ('  {0}) {1}  {2}{3}' -f ($i + 1), $friends[$i].name, $friends[$i].address, $tag)
        }
        Say '  N) someone new'
        if ($friends.Count -gt 0) { Say '  D) remove someone from this list' }
        $a = Ask 'Choice' $def
        if ($a -ieq 'D') {
            $d = Ask 'Remove which number' ''
            $dn = 0
            if ([int]::TryParse($d, [ref]$dn) -and $dn -ge 1 -and $dn -le $friends.Count) {
                $gone = $friends[$dn - 1].name
                $s.friends = @($friends | Where-Object { $_.name -ne $gone })
                Save-Settings $s
                Say "  Removed $gone." 'DarkGray'
            }
            $friends = @($s.friends)
            $a = 'N'
            if ($friends.Count -gt 0) { $a = Ask 'Join which number (N = someone new)' '1' }
        }
        $n = 0
        if ([int]::TryParse($a, [ref]$n) -and $n -ge 1 -and $n -le $friends.Count) { $pick = $friends[$n - 1] }
    }
    if (-not $pick) {
        Say ''
        $fn = Ask "Friend's name (just for this list)" 'Friend'
        $fa = ''
        while (-not $fa) {
            $fa = Ask "Their address (they see it when they run Host co-op.bat, like 26.81.178.37)" ''
            if ($fa -and $fa -notmatch '^[A-Za-z0-9.\-:]+$') { Say '  That doesnt look like an address.' 'DarkYellow'; $fa = '' }
        }
        $pick = [pscustomobject]@{ name = $fn; address = $fa }
        $s.friends = @(@($s.friends | Where-Object { $_.name -ne $fn }) + $pick)
    }
    $s.lastFriend = $pick.name

    $s.character = Ask-Character $s
    $name = Ask-Name $s
    Save-Settings $s

    $gameArgs = @() + $common + @('-join', $pick.address)
    if ($s.character) { $gameArgs += @('+tpvc_character', ('"{0}"' -f $s.character)) }
    if ($name) { $gameArgs += @('+name', ('"{0}"' -f $name)) }
    if (-not $g.IsUZ) {
        # GZDoom doesn't pass the host's save along, so pick the same one here.
        Say ''
        $yn = Ask 'Is the host continuing a save? y/n' 'n'
        if ($yn -ieq 'y') {
            $load = Ask-Save $g 'Pick the same save the host picked:'
            if ($load) { $gameArgs += @('-loadgame', ('"{0}"' -f $load.File)) }
        }
    }

    Say ''
    Say ("Joining {0} at {1}. The game waits until {0} starts." -f $pick.name, $pick.address) 'Green'
    Say "If it stays on 'Contacting host', check you're both on the same VPN network and both have the same files code." 'DarkGray'
    Start-Game $gameArgs
    Start-Sleep -Seconds 4
    exit 0
}

if ($Mode -eq 'try') {
    $fc = Ask-Character $s 'friend'
    $s.friendCharacter = $fc
    Save-Settings $s
    $local = Join-Path $LauncherDir 'local'
    New-Item -ItemType Directory -Path (Join-Path $local 'saves') -Force | Out-Null
    $hostArgs = @() + $common + @('-host', '2', '-skill', '3', '+vid_fullscreen 0') + $hostRules
    Start-Game $hostArgs
    Start-Sleep -Seconds 3
    $friendArgs = @() + $common + @('-config', ('"{0}"' -f (Join-Path $local 'friend.ini')), '-savedir', ('"{0}"' -f (Join-Path $local 'saves')),
        '-join', '127.0.0.1', '+vid_fullscreen 0', '+name Friend', '+tpvc_character', ('"{0}"' -f $fc))
    Start-Game $friendArgs
    Say ''
    Say 'Two windows are opening. Only the one you click on gets your keyboard.' 'Green'
    Start-Sleep -Seconds 4
    exit 0
}
