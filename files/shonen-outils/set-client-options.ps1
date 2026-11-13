<#
.SYNOPSIS
    Makes a Minecraft options.txt use French and enable the Shonen Eveil FR resource pack.

.DESCRIPTION
    set-client-options.ps1 -OptionsFile <path to options.txt> [-PackName "Shonen Eveil FR"] [-Lang fr_fr] [-Before "file/A|file/B"]
    Edits the file in place, line by line; every line it does not own is kept byte for byte, in order:
      lang:<Lang>                       set (replaced, or appended when missing)
      resourcePacks:[...]               "file/<PackName>" is added once at the end (an empty list becomes
                                        ["vanilla","file/<PackName>"]); existing entries are kept as they are.
                                        With -Before ("|"-separated entries), a missing "file/<PackName>" is
                                        inserted just before the first of them found in the list (= below them:
                                        later in the list = higher priority), else appended
      incompatibleResourcePacks:[...]   "file/<PackName>" is removed when present, other entries kept
      tutorialStep:none                 always (09/11: vanilla's "open your inventory, punch a tree" hints showed up
                                        for a new player after the CurseForge import)
      soundCategory_hostile:0.6         with -DefaultVolumes, only while hostile is missing or still at vanilla's 1.0
      soundCategory_music:1.0           (the player never moved it): boss music (Ambience Mini plays it in the
                                        Music category) stays audible over our ability sounds (09/11). A player
                                        who already set hostile keeps both values.
    A missing file is created with just those lines. The line-ending style of an existing file (LF or CRLF) is
    kept, the file is written as UTF-8 without BOM, through a temporary file renamed over the target, and only
    when something actually changed. If resourcePacks cannot be parsed the file is left untouched (exit 1).
    Do not run it while the game is open: Minecraft rewrites options.txt when it quits.
    Exit code: 0 = OK, 1 = error.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$OptionsFile,
    [string]$PackName = 'Shonen Eveil FR',
    [string]$Lang = 'fr_fr',
    # "|"-separated resourcePacks entries the pack must stay below (one string: powershell -File cannot pass arrays)
    [string]$Before,
    [switch]$DefaultVolumes
)

$ErrorActionPreference = 'Stop'

function Stop-Opt {
    param([string]$Message)
    [Console]::Error.WriteLine("ERROR: $Message")
    exit 1
}

function ConvertTo-JsonString {
    param([string]$Text)
    $sb = New-Object Text.StringBuilder
    [void]$sb.Append('"')
    foreach ($ch in $Text.ToCharArray()) {
        if ($ch -eq '"') { [void]$sb.Append('\"') }
        elseif ($ch -eq '\') { [void]$sb.Append('\\') }
        elseif ([int]$ch -lt 32) { [void]$sb.Append(('\u{0:x4}' -f [int]$ch)) }
        else { [void]$sb.Append($ch) }
    }
    [void]$sb.Append('"')
    $sb.ToString()
}

function ConvertTo-JsonList {
    param([string[]]$Items)
    '[' + ((@($Items) | ForEach-Object { ConvertTo-JsonString $_ }) -join ',') + ']'
}

function ConvertFrom-JsonList {
    # Returns [string[]] or throws. Only a JSON array of strings is accepted.
    param([string]$Text)
    $t = $Text.Trim()
    if ($t.Length -lt 2 -or $t[0] -ne '[' -or $t[$t.Length - 1] -ne ']') { throw "not a JSON array: $Text" }
    Add-Type -AssemblyName System.Web.Extensions
    $ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
    $obj = $ser.DeserializeObject($t)
    $out = New-Object Collections.Generic.List[string]
    foreach ($o in $obj) {
        if ($o -isnot [string]) { throw "array entry is not a string: $Text" }
        $out.Add($o)
    }
    , $out.ToArray()
}

function Get-OptLine {
    param($Lines, [string]$Key)
    foreach ($l in $Lines) { if ($l.StartsWith($Key + ':')) { return $l.Substring($Key.Length + 1) } }
    return $null
}

function Set-OptLine {
    param($Lines, [string]$Key, [string]$Value)
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i].StartsWith($Key + ':')) { $Lines[$i] = $Key + ':' + $Value; return }
    }
    $Lines.Add($Key + ':' + $Value)
}

try {
    if ([string]::IsNullOrWhiteSpace($PackName) -or $PackName -match '[\x00-\x1f]') { Stop-Opt 'Invalid -PackName.' }
    $utf8 = New-Object Text.UTF8Encoding($false)
    $full = [IO.Path]::GetFullPath($OptionsFile)
    $parent = [IO.Path]::GetDirectoryName($full)
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) { Stop-Opt "Folder not found: $parent" }

    $exists = Test-Path -LiteralPath $full -PathType Leaf
    if ($exists -and ((Get-Item -LiteralPath $full -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        Stop-Opt "Refusing to edit a junction/symlink: $full"
    }

    $eol = "`n"
    $lines = New-Object Collections.Generic.List[string]
    $trailingEol = $true
    $original = ''
    if ($exists) {
        $original = [IO.File]::ReadAllText($full, $utf8)
        if ($original.Contains("`r`n")) { $eol = "`r`n" }
        $trailingEol = ($original.Length -eq 0) -or $original.EndsWith("`n")
        $parts = $original -split "`r?`n"
        if ($original.Length -gt 0 -and $trailingEol) { $parts = $parts[0..($parts.Count - 2)] }
        foreach ($p in @($parts)) { if ($original.Length -gt 0) { $lines.Add([string]$p) } }
    }

    $entry = 'file/' + $PackName
    $langIdx = -1; $packIdx = -1; $incompIdx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($langIdx -lt 0 -and $line.StartsWith('lang:', [StringComparison]::Ordinal)) { $langIdx = $i }
        elseif ($packIdx -lt 0 -and $line.StartsWith('resourcePacks:', [StringComparison]::Ordinal)) { $packIdx = $i }
        elseif ($incompIdx -lt 0 -and $line.StartsWith('incompatibleResourcePacks:', [StringComparison]::Ordinal)) { $incompIdx = $i }
    }

    # resourcePacks
    if ($packIdx -ge 0) {
        try { $packs = ConvertFrom-JsonList $lines[$packIdx].Substring('resourcePacks:'.Length) }
        catch { Stop-Opt "Cannot parse the resourcePacks line, options.txt left untouched ($($_.Exception.Message))." }
        if ($packs -cnotcontains $entry) {
            $at = -1
            if ($Before) {
                $anchors = @($Before.Split('|') | Where-Object { $_ })
                for ($k = 0; $k -lt $packs.Count; $k++) { if ($anchors -ccontains $packs[$k]) { $at = $k; break } }
            }
            if ($packs.Count -eq 0) { $packs = @('vanilla', $entry) }
            elseif ($at -ge 0) {
                $list = New-Object Collections.Generic.List[string]
                $list.AddRange([string[]]$packs)
                $list.Insert($at, $entry)
                $packs = $list.ToArray()
            }
            else { $packs = @($packs) + $entry }
            $lines[$packIdx] = 'resourcePacks:' + (ConvertTo-JsonList $packs)
        }
    }
    else {
        $lines.Add('resourcePacks:' + (ConvertTo-JsonList @('vanilla', $entry)))
    }

    # incompatibleResourcePacks: our pack must not be listed there
    if ($incompIdx -ge 0) {
        $inc = $null
        try { $inc = ConvertFrom-JsonList $lines[$incompIdx].Substring('incompatibleResourcePacks:'.Length) }
        catch { Write-Warning "incompatibleResourcePacks left as is (not parsable)." }
        if ($inc -and ($inc -ccontains $entry)) {
            $lines[$incompIdx] = 'incompatibleResourcePacks:' + (ConvertTo-JsonList @($inc | Where-Object { $_ -cne $entry }))
        }
    }

    # lang
    $langLine = 'lang:' + $Lang
    if ($langIdx -ge 0) { $lines[$langIdx] = $langLine } else { $lines.Add($langLine) }

    # vanilla tutorial hints off, and (with -DefaultVolumes) the pack's default volumes
    Set-OptLine $lines 'tutorialStep' 'none'
    if ($DefaultVolumes) {
        $hostile = Get-OptLine $lines 'soundCategory_hostile'
        if ($null -eq $hostile -or $hostile -eq '1.0') {
            Set-OptLine $lines 'soundCategory_hostile' '0.6'
            Set-OptLine $lines 'soundCategory_music' '1.0'
        }
    }

    $newText = ($lines -join $eol)
    if ($lines.Count -gt 0 -and $trailingEol) { $newText += $eol }

    if ($exists -and $newText -ceq $original) {
        Write-Host "options.txt already up to date: $full"
        exit 0
    }

    $tmp = Join-Path $parent ('options-' + [guid]::NewGuid().ToString('N') + '.part')
    try {
        [IO.File]::WriteAllText($tmp, $newText, $utf8)
        if ($exists) { [IO.File]::Replace($tmp, $full, [NullString]::Value) } else { [IO.File]::Move($tmp, $full) }
    }
    catch {
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
        throw
    }
    Write-Host "options.txt updated (lang:$Lang, resource pack '$PackName' enabled, tutorialStep:none): $full"
    exit 0
}
catch {
    Stop-Opt $_.Exception.Message
}
