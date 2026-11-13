<#
.SYNOPSIS
    Repairs the client settings of DragonMine Z (config\dragonminez\general-user.json) and turns its over-the-shoulder
    camera off ONCE (Admin, 11/11/2026: in 3rd person that camera aims at the enemies and makes the hits miss).

.DESCRIPTION
    set-dmz-user-config.ps1 -ConfigFile <instance>\config\dragonminez\general-user.json
                            -DefaultsFile <pack values: client\pack\shonen-outils\dmz\general-user.json>
                            -MarkerDir <instance>\config\shonen-eveil
    Called by sync-client.ps1 (Admin's instance), by shonen-outils\mettre-a-jour.ps1 (the colleagues' instances) and
    by export-pack.ps1 (the file shipped in the zip). The game must be closed (the callers check it).
      - file absent or empty: written from the pack values (overShoulderMode 0);
      - broken file (Admin's case: "fals", false where a number is expected): every setting of the pack list is read
        again one by one; a value that is valid JSON of the right type is KEPT (the player's own settings), the others
        take the pack value. Not valid JSON at all = same thing, read key by key from the text. The broken file is
        kept beside as general-user.json.avant-reparation (first time only);
      - settings the pack does not list (hudLayout...) are kept as they are when the file is valid JSON;
      - overShoulderMode is forced to 0 once: marker <MarkerDir>\dmz-user-config-v1 (like the key scheme and the
        ".once" files, the player's later choice is kept);
      - a healthy file with nothing to force is not rewritten (same bytes).
    Exit code 0 = OK (a line says what was done), 1 = error (French message, nothing modified).
    ASCII file (PowerShell 5.1 reads scripts as ANSI).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ConfigFile,
    [Parameter(Mandatory = $true)][string]$DefaultsFile,
    [Parameter(Mandatory = $true)][string]$MarkerDir
)
$ErrorActionPreference = 'Stop'
$utf8 = New-Object Text.UTF8Encoding($false)
$inv = [Globalization.CultureInfo]::InvariantCulture
# forced once per marker version: name of the setting -> value
$MarkerName = 'dmz-user-config-v1'
$Forced = [ordered]@{ overShoulderMode = 0 }

function Stop-Dmz([string]$Message) { [Console]::Error.WriteLine("ERREUR : $Message"); exit 1 }

function Test-Number($v) { return ($v -is [int] -or $v -is [long] -or $v -is [decimal] -or $v -is [double] -or $v -is [single]) }
function Test-Whole($v) {
    if ($v -is [int] -or $v -is [long]) { return $true }
    if ($v -is [decimal]) { return ([decimal]::Truncate($v) -eq $v) }
    if ($v -is [double] -or $v -is [single]) { return (-not [double]::IsNaN($v) -and -not [double]::IsInfinity($v) -and [math]::Truncate($v) -eq $v) }
    return $false
}
function Test-DmzValue([string]$Key, $Default, $Value) {
    # is $Value a valid value for a setting whose pack value is $Default (same JSON type)?
    if ($null -eq $Value) { return $false }
    if ($Default -is [bool]) { return ($Value -is [bool]) }
    if ($Default -is [string]) { return ($Value -is [string] -and $Value.Trim().Length -gt 0) }
    if ($Default -is [array]) {
        if ($Value -isnot [array]) { return $false }
        foreach ($x in $Value) { if ($x -isnot [string]) { return $false } }
        return $true
    }
    if ($Default -is [int] -or $Default -is [long]) {
        if ($Value -is [bool] -or -not (Test-Number $Value) -or -not (Test-Whole $Value)) { return $false }
        if ($Key -eq 'overShoulderMode') { return ([double]$Value -ge 0 -and [double]$Value -le 2) }
        return $true
    }
    if (Test-Number $Default) {
        if ($Value -is [bool] -or -not (Test-Number $Value)) { return $false }
        if (($Value -is [double] -or $Value -is [single]) -and ([double]::IsNaN($Value) -or [double]::IsInfinity($Value))) { return $false }
        return $true
    }
    return $false
}

function ConvertTo-DmzJson($Value, [int]$Depth = 0) {
    # Gson-like pretty print (2 spaces), invariant numbers
    $pad = '  ' * $Depth
    $pad1 = '  ' * ($Depth + 1)
    if ($null -eq $Value) { return 'null' }
    if ($Value -is [bool]) { if ($Value) { return 'true' } else { return 'false' } }
    if ($Value -is [string]) {
        $sb = New-Object Text.StringBuilder
        [void]$sb.Append('"')
        foreach ($c in $Value.ToCharArray()) {
            $n = [int]$c
            if ($c -eq '"') { [void]$sb.Append('\"') }
            elseif ($c -eq '\') { [void]$sb.Append('\\') }
            elseif ($n -eq 10) { [void]$sb.Append('\n') }
            elseif ($n -eq 13) { [void]$sb.Append('\r') }
            elseif ($n -eq 9) { [void]$sb.Append('\t') }
            elseif ($n -lt 32) { [void]$sb.Append(('\u{0:x4}' -f $n)) }
            else { [void]$sb.Append($c) }
        }
        [void]$sb.Append('"')
        return $sb.ToString()
    }
    if ($Value -is [int] -or $Value -is [long]) { return $Value.ToString($inv) }
    if ($Value -is [decimal]) { return $Value.ToString($inv) }
    if ($Value -is [double] -or $Value -is [single]) {
        $t = ([double]$Value).ToString('R', $inv)
        if ($t -notmatch '[.eE]') { $t += '.0' }
        return $t
    }
    if ($Value -is [array]) {
        if ($Value.Count -eq 0) { return '[]' }
        $items = @(foreach ($x in $Value) { $pad1 + (ConvertTo-DmzJson $x ($Depth + 1)) })
        return "[`n" + ($items -join ",`n") + "`n$pad]"
    }
    # (values are passed straight as arguments: a script block or the pipeline would unroll the arrays)
    $lines = @()
    if ($Value -is [Collections.IDictionary]) {
        foreach ($k in @($Value.Keys)) { $lines += $pad1 + (ConvertTo-DmzJson ([string]$k) 0) + ': ' + (ConvertTo-DmzJson $Value[$k] ($Depth + 1)) }
    }
    else {
        foreach ($p in @($Value.PSObject.Properties)) { $lines += $pad1 + (ConvertTo-DmzJson ([string]$p.Name) 0) + ': ' + (ConvertTo-DmzJson $p.Value ($Depth + 1)) }
    }
    if ($lines.Count -eq 0) { return '{}' }
    return "{`n" + ($lines -join ",`n") + "`n$pad}"
}

function Read-DmzToken([string]$Text, [string]$Key) {
    # the value written after "Key": in a text that is not valid JSON; returns @{ Found; Ok; Value }
    $rx = '"' + [regex]::Escape($Key) + '"\s*:\s*(\[[^\]]*\]|"(?:[^"\\]|\\.)*"|[^,\r\n}\]]+)'
    $m = [regex]::Match($Text, $rx)
    if (-not $m.Success) { return @{ Found = $false; Ok = $false; Value = $null } }
    try {
        $o = ('{"v":' + $m.Groups[1].Value.Trim() + '}') | ConvertFrom-Json
        return @{ Found = $true; Ok = $true; Value = $o.v }
    }
    catch { return @{ Found = $true; Ok = $false; Value = $null } }
}

try {
    # ---- pack values ----
    if (-not (Test-Path -LiteralPath $DefaultsFile -PathType Leaf)) { Stop-Dmz "valeurs du pack introuvables : $DefaultsFile" }
    $def = $null
    try { $def = [IO.File]::ReadAllText($DefaultsFile, $utf8) | ConvertFrom-Json } catch { Stop-Dmz "valeurs du pack illisibles ($DefaultsFile) : $($_.Exception.Message)" }
    if ($null -eq $def -or $def -isnot [Management.Automation.PSCustomObject]) { Stop-Dmz "valeurs du pack illisibles : $DefaultsFile" }
    $defNames = @($def.PSObject.Properties | ForEach-Object { $_.Name })
    foreach ($k in $Forced.Keys) { if ($defNames -notcontains $k) { Stop-Dmz "le reglage force '$k' manque dans $DefaultsFile" } }

    # ---- the player's file ----
    $full = [IO.Path]::GetFullPath($ConfigFile)
    if (Test-Path -LiteralPath $full -PathType Container) { Stop-Dmz "'$full' est un dossier." }
    $state = 'absent'
    $text = ''
    $player = $null
    if (Test-Path -LiteralPath $full -PathType Leaf) {
        $text = [IO.File]::ReadAllText($full, $utf8)
        if ($text.Trim().Length -gt 0) {
            $state = 'json'
            try { $player = $text | ConvertFrom-Json } catch { $player = $null }
            if ($null -eq $player -or $player -isnot [Management.Automation.PSCustomObject]) { $state = 'casse'; $player = $null }
        }
    }

    # ---- every pack setting: the player's valid value, else the pack value ----
    $out = [ordered]@{}
    $repaired = @()
    $missing = 0
    foreach ($k in $defNames) {
        $d = $def.PSObject.Properties[$k].Value
        $found = $false; $val = $null; $okJson = $true
        if ($state -eq 'json') {
            $pp = $player.PSObject.Properties[$k]
            if ($null -ne $pp) { $found = $true; $val = $pp.Value }
        }
        elseif ($state -eq 'casse') {
            $tk = Read-DmzToken $text $k
            $found = $tk.Found; $val = $tk.Value; $okJson = $tk.Ok
        }
        if ($found -and $okJson -and (Test-DmzValue $k $d $val)) { $out[$k] = $val }
        else {
            $out[$k] = $d
            if ($found) { $repaired += $k } else { $missing++ }
        }
    }
    # settings the pack does not list: kept (valid JSON only)
    if ($state -eq 'json') {
        foreach ($pp in $player.PSObject.Properties) { if ($defNames -notcontains $pp.Name) { $out[$pp.Name] = $pp.Value } }
    }

    # ---- forced once ----
    $marker = Join-Path $MarkerDir $MarkerName
    $forcedNow = @()
    $markerNeeded = -not (Test-Path -LiteralPath $marker -PathType Leaf)
    if ($markerNeeded) {
        foreach ($k in $Forced.Keys) {
            if ("$($out[$k])" -ne "$($Forced[$k])") { $forcedNow += $k }
            $out[$k] = $Forced[$k]
        }
    }

    # ---- write (only when something changes) ----
    $rewrite = ($state -ne 'json') -or ($repaired.Count -gt 0) -or ($forcedNow.Count -gt 0)
    if ($rewrite) {
        $dir = [IO.Path]::GetDirectoryName($full)
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        if ($state -eq 'casse' -or $repaired.Count -gt 0) {
            $bak = $full + '.avant-reparation'
            if (-not (Test-Path -LiteralPath $bak)) { Copy-Item -LiteralPath $full -Destination $bak }
        }
        $tmp = $full + '.part'
        [IO.File]::WriteAllText($tmp, (ConvertTo-DmzJson $out 0), $utf8)
        # read back before replacing the player's file: never leave a file the mod cannot read
        try { $check = [IO.File]::ReadAllText($tmp, $utf8) | ConvertFrom-Json } catch { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue; Stop-Dmz "le fichier repare n'est pas du JSON valide (rien n'a ete modifie) : $($_.Exception.Message)" }
        Move-Item -LiteralPath $tmp -Destination $full -Force
    }
    if ($markerNeeded) {
        if (-not (Test-Path -LiteralPath $MarkerDir)) { New-Item -ItemType Directory -Path $MarkerDir -Force | Out-Null }
        [IO.File]::WriteAllText($marker, ((@($Forced.Keys | ForEach-Object { "$_=$($Forced[$_])" }) -join "`n") + "`n"), $utf8)
    }

    # ---- what was done ----
    $what = @()
    if ($state -eq 'absent') { $what += 'fichier cree avec les valeurs du pack' }
    if ($state -eq 'casse') { $what += "fichier casse (JSON invalide) repare, $($defNames.Count - $repaired.Count - $missing) reglage(s) du joueur garde(s)" }
    if ($repaired.Count -gt 0) { $what += "valeur(s) invalide(s) remise(s) a la valeur du pack : $($repaired -join ', ')" }
    if ($forcedNow.Count -gt 0) { $what += "camera par-dessus l'epaule coupee, une fois ($(@($forcedNow | ForEach-Object { "$_=$($Forced[$_])" }) -join ', '))" }
    if ($what.Count -eq 0) { $what += $(if ($markerNeeded) { 'deja bon (marqueur pose)' } else { 'deja bon, laisse comme le joueur l''a regle' }) }
    Write-Host ("DragonMine Z (general-user.json) : " + ($what -join ' ; ') + '.')
    exit 0
}
catch { Stop-Dmz $_.Exception.Message }
