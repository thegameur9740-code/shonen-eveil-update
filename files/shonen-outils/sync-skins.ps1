<#
.SYNOPSIS
    "Mes skins" (P3-3): copies the player's own boss textures from <instance>\mes-skins\ into a local resource pack.

.DESCRIPTION
    sync-skins.ps1 -InstanceDir <instance folder> [-JarDir <client mod cache>] [-ReadmeFile <LISEZ-MOI template>]
    Called by sync-client.ps1 (step "Mes skins", skipped with -NoSkins); can also be run alone, game closed.
      1. <instance>\mes-skins\<key>.png (key = a boss of scripts\skins-lib.ps1, e.g. itachi.png): a real PNG, same
         aspect ratio as the default texture, Width/4 to 4096 pixels wide, at most 16 MB. Anything else is reported
         (French line) and ignored: that boss keeps its default texture. Other files are left alone.
      2. <instance>\resourcepacks\Shonen Mes Skins\ (our own folder): pack.mcmeta + exactly the valid skins at the
         texture path of their boss. A texture of a skin that is no longer there (or no longer valid) is removed
         from the pack, so an empty mes-skins = default textures. Nothing outside that pack folder is ever deleted.
      3. <instance>\mes-skins\ (and modeles\) created when missing, LISEZ-MOI.txt written (French, from
         skins\LISEZ-MOI.txt); modeles\<key>.png = a copy of the default texture taken from the mod jar in -JarDir,
         written only when missing (a starting point to paint on; never read back).
    The player's files in mes-skins are only read, never modified or deleted. Copies go through a temporary .part
    name renamed into place; a junction/symlink in any folder written is refused (exit 1, nothing written).
    Enabling the pack in options.txt is done by sync-client.ps1 (set-client-options.ps1 -PackName).
    Exit code: 0 = OK (warnings included), 1 = error.
    Console lines are French without accents (this script runs as a child of sync-client.ps1, whose console would
    mangle them).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$InstanceDir,
    [string]$JarDir,
    [string]$ReadmeFile,
    # mes-sons: LISEZ-MOI template (default <repo>\skins\LISEZ-MOI-sons.txt) and ffmpeg.exe (default: Find-MusicFfmpeg)
    [string]$SonsReadmeFile,
    [string]$FfmpegPath
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'skins-lib.ps1')
. (Join-Path $PSScriptRoot 'music-lib.ps1')   # mes-sons: Find-MusicFfmpeg / Convert-MusicToOgg
$utf8 = New-Object Text.UTF8Encoding($false)

function Stop-Skins([string]$Message) { [Console]::Error.WriteLine("ERROR: $Message"); exit 1 }
function Test-Reparse([string]$Path) { return [bool]((Get-Item -LiteralPath $Path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) }
function Assert-RealFolder([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return }
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { Stop-Skins "'$Path' is a file, a folder is needed." }
    if (Test-Reparse $Path) { Stop-Skins "Refusing: '$Path' is a junction/symlink." }
}
# width / height of a PNG (signature + IHDR), or $null
function Get-PngSize([string]$Path) {
    $fs = [IO.File]::OpenRead($Path)
    try {
        $b = New-Object byte[] 24
        $n = $fs.Read($b, 0, 24)
        if ($n -lt 24) { return $null }
        $sig = @(0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A)
        for ($i = 0; $i -lt 8; $i++) { if ($b[$i] -ne $sig[$i]) { return $null } }
        if ([Text.Encoding]::ASCII.GetString($b, 12, 4) -cne 'IHDR') { return $null }
        $w = ([int]$b[16] -shl 24) -bor ([int]$b[17] -shl 16) -bor ([int]$b[18] -shl 8) -bor [int]$b[19]
        $h = ([int]$b[20] -shl 24) -bor ([int]$b[21] -shl 16) -bor ([int]$b[22] -shl 8) -bor [int]$b[23]
        if ($w -le 0 -or $h -le 0) { return $null }
        return [pscustomobject]@{ W = $w; H = $h }
    }
    finally { $fs.Dispose() }
}
# writes $Bytes to $Path through a .part file, only when the content differs; returns $true when written
function Write-IfDifferent([string]$Path, [byte[]]$Bytes) {
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        $old = [IO.File]::ReadAllBytes($Path)
        if ($old.Length -eq $Bytes.Length) {
            $sha = [Security.Cryptography.SHA1]::Create()
            try { if ([BitConverter]::ToString($sha.ComputeHash($old)) -eq [BitConverter]::ToString($sha.ComputeHash($Bytes))) { return $false } } finally { $sha.Dispose() }
        }
    }
    $dir = [IO.Path]::GetDirectoryName($Path)
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $tmp = Join-Path $dir ('skins-' + [guid]::NewGuid().ToString('N') + '.part')
    try {
        [IO.File]::WriteAllBytes($tmp, $Bytes)
        if (Test-Path -LiteralPath $Path) { [IO.File]::Replace($tmp, $Path, [NullString]::Value) } else { [IO.File]::Move($tmp, $Path) }
    }
    catch { if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }; throw }
    return $true
}

try {
    if (-not $JarDir) { $JarDir = Join-Path $repo 'cache\client' }
    if (-not $ReadmeFile) { $ReadmeFile = Join-Path $repo 'skins\LISEZ-MOI.txt' }
    if (-not (Test-Path -LiteralPath $InstanceDir -PathType Container)) { Stop-Skins "Instance introuvable : $InstanceDir" }
    $inst = [IO.Path]::GetFullPath($InstanceDir).TrimEnd('\')
    if (Test-Reparse $inst) { Stop-Skins "Refusing: the instance folder is a junction/symlink ($inst)." }
    $mes = Join-Path $inst 'mes-skins'
    $mesSons = Join-Path $inst 'mes-sons'
    Assert-RealFolder $mesSons
    $modeles = Join-Path $mes 'modeles'
    $packs = Join-Path $inst 'resourcepacks'
    $pack = Join-Path $packs $script:SkinPackName
    $assets = Join-Path $pack 'assets'
    foreach ($p in $mes, $modeles, $packs, $pack, $assets) { Assert-RealFolder $p }
    if (Test-Path -LiteralPath $assets) {
        foreach ($d in @(Get-ChildItem -LiteralPath $assets -Recurse -Force)) {
            if ($d.Attributes -band [IO.FileAttributes]::ReparsePoint) { Stop-Skins "Refusing: junction/symlink in the skins pack ($($d.FullName))." }
        }
    }

    # ---- plan: the valid skins of mes-skins (read only)
    $keys = @($script:SkinBosses.Keys)
    $plan = @()
    $notes = @()
    if (Test-Path -LiteralPath $mes) {
        foreach ($f in @(Get-ChildItem -LiteralPath $mes -File -Force | Sort-Object Name)) {
            if ($f.Extension -ine '.png') { continue }
            $key = $f.BaseName.ToLowerInvariant()
            if (-not $script:SkinBosses.Contains($key)) { $notes += "mes-skins\$($f.Name) : boss inconnu, ignore (noms possibles : $(($keys | ForEach-Object { $_ + '.png' }) -join ', '))."; continue }
            if ($f.Attributes -band [IO.FileAttributes]::ReparsePoint) { $notes += "mes-skins\$($f.Name) : lien/raccourci, ignore."; continue }
            $b = $script:SkinBosses[$key]
            if ($f.Length -gt 16MB) { $notes += "mes-skins\$($f.Name) : plus de 16 Mo, ignore."; continue }
            $sz = Get-PngSize $f.FullName
            if ($null -eq $sz) { $notes += "mes-skins\$($f.Name) : ce n'est pas une image PNG, ignore."; continue }
            if (($sz.W * $b.Height) -ne ($sz.H * $b.Width) -or $sz.W -lt ($b.Width / 4) -or $sz.W -gt 4096) {
                $notes += "mes-skins\$($f.Name) : $($sz.W) x $($sz.H), il faut la forme de l'image d'origine ($($b.Width) x $($b.Height), ou plus grand dans le meme rapport), ignore."
                continue
            }
            $plan += [pscustomobject]@{ Key = $key; Src = $f.FullName; Dst = (Join-Path $pack ($b.Texture -replace '/', '\')); W = $sz.W; H = $sz.H }
        }
    }

    # ---- plan: the player's own sounds of mes-sons (read only), converted later with ffmpeg
    $sonsPlan = @()
    if (Test-Path -LiteralPath $mesSons) {
        $vus = @{}
        foreach ($f in @(Get-ChildItem -LiteralPath $mesSons -File -Force | Sort-Object Name)) {
            if ($f.Name -ieq 'LISEZ-MOI.txt') { continue }
            $key = $f.BaseName.ToLowerInvariant()
            if (-not $script:SonsPerso.Contains($key)) { $notes += "mes-sons\$($f.Name) : son inconnu, ignore (noms possibles : $((@($script:SonsPerso.Keys) | ForEach-Object { $_ + '.mp3' }) -join ', '))."; continue }
            if ($script:SonsExtensions -notcontains $f.Extension.ToLowerInvariant()) { $notes += "mes-sons\$($f.Name) : format non lu (mp3, ogg, wav, flac, m4a, opus), ignore."; continue }
            if ($f.Attributes -band [IO.FileAttributes]::ReparsePoint) { $notes += "mes-sons\$($f.Name) : lien/raccourci, ignore."; continue }
            if ($f.Length -gt 64MB) { $notes += "mes-sons\$($f.Name) : plus de 64 Mo, ignore."; continue }
            if ($vus.ContainsKey($key)) { $notes += "mes-sons\$($f.Name) : deux fichiers pour $key, seul $($vus[$key]) est pris."; continue }
            $vus[$key] = $f.Name
            $sonsPlan += [pscustomobject]@{ Key = $key; Src = $f.FullName; Dst = (Join-Path $pack ($script:SonsPerso[$key].Path -replace '/', '\')) }
        }
    }

    # ---- apply
    foreach ($p in $mes, $modeles, $packs, $pack, $mesSons) { if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Path $p | Out-Null } }
    $readmeSons = if ($SonsReadmeFile) { $SonsReadmeFile } else { Join-Path $repo 'skins\LISEZ-MOI-sons.txt' }
    if (Test-Path -LiteralPath $readmeSons -PathType Leaf) {
        $listS = @(foreach ($k in $script:SonsPerso.Keys) { '  ' + $k + '.mp3 -> ' + $script:SonsPerso[$k].Quoi + ', impact a ' + $script:SonsPerso[$k].Impact + ' du debut' }) -join "`r`n"
        $txtS = ([IO.File]::ReadAllText($readmeSons, $utf8) -replace "`r?`n", "`r`n").Replace('{SONS}', $listS)
        [void](Write-IfDifferent (Join-Path $mesSons 'LISEZ-MOI.txt') ($utf8.GetBytes($txtS)))
    }
    if (Test-Path -LiteralPath $ReadmeFile -PathType Leaf) {
        $list = @(foreach ($k in $keys) { '  ' + $k + '.png -> ' + $k + ' (' + $script:SkinBosses[$k].Width + ' x ' + $script:SkinBosses[$k].Height + ')' }) -join "`r`n"
        $txt = ([IO.File]::ReadAllText($ReadmeFile, $utf8) -replace "`r?`n", "`r`n").Replace('{BOSS}', $list)
        [void](Write-IfDifferent (Join-Path $mes 'LISEZ-MOI.txt') ($utf8.GetBytes($txt)))
    }
    $meta = '{ "pack": { "pack_format": ' + $script:SkinPackFormat + ', "description": "Mes skins de boss (dossier mes-skins de l''instance)" } }' + "`n"
    [void](Write-IfDifferent (Join-Path $pack 'pack.mcmeta') ($utf8.GetBytes($meta)))
    $copied = 0; $kept = 0; $removed = 0
    $wanted = @{}
    foreach ($p in $plan) {
        $wanted[$p.Dst.ToLowerInvariant()] = $true
        if (Write-IfDifferent $p.Dst ([IO.File]::ReadAllBytes($p.Src))) { $copied++; Write-Host "Mes skins : $($p.Key).png ($($p.W) x $($p.H)) -> pack '$($script:SkinPackName)'" } else { $kept++ }
    }
    # mes-sons: a .ogg is copied as is (NO ffmpeg needed); any other format is converted once with ffmpeg
    # (cache\sons\<sha1 of the source>.ogg in the repo), then copied into the pack
    $sonsCopies = 0; $sonsOk = 0; $sonsMiss = @()
    if ($sonsPlan.Count -gt 0) {
        $ffmpeg = $null
        $needFf = @($sonsPlan | Where-Object { [IO.Path]::GetExtension($_.Src).ToLowerInvariant() -ne '.ogg' }).Count -gt 0
        if ($needFf) { try { $ffmpeg = Find-MusicFfmpeg -Explicit $FfmpegPath -RepoRoot $repo } catch { $ffmpeg = $null } }
        $cacheSons = Join-Path $repo 'cache\sons'
        foreach ($p in $sonsPlan) {
            $name = [IO.Path]::GetFileName($p.Src)
            try {
                if ([IO.Path]::GetExtension($p.Src).ToLowerInvariant() -eq '.ogg') { $ogg = $p.Src }
                elseif (-not $ffmpeg) {
                    $notes += "mes-sons\$name : ce n'est pas un .ogg et ffmpeg est introuvable, le son de base reste (donne un fichier .ogg, ou installe ffmpeg)."
                    $sonsMiss += "$name (ffmpeg manque)"
                    continue
                }
                else {
                    if (-not (Test-Path -LiteralPath $cacheSons)) { New-Item -ItemType Directory -Path $cacheSons -Force | Out-Null }
                    $sha = (Get-FileHash -LiteralPath $p.Src -Algorithm SHA1).Hash.ToLowerInvariant()
                    $ogg = Join-Path $cacheSons ($sha + '-' + $script:MusicProcessingVersion + '.ogg')
                    if (-not (Test-Path -LiteralPath $ogg -PathType Leaf)) { Convert-MusicToOgg -Ffmpeg $ffmpeg -Source $p.Src -Destination $ogg }
                }
                $wanted[$p.Dst.ToLowerInvariant()] = $true
                $sonsOk++
                if (Write-IfDifferent $p.Dst ([IO.File]::ReadAllBytes($ogg))) { $sonsCopies++; Write-Host "Mes sons : $name -> $($p.Key) (pack '$($script:SkinPackName)')" }
            }
            catch { $notes += "mes-sons\$name : conversion impossible ($($_.Exception.Message)), son de base garde."; $sonsMiss += "$name (conversion ratee)" }
        }
    }
    if (Test-Path -LiteralPath $assets) {
        foreach ($f in @(Get-ChildItem -LiteralPath $assets -Recurse -File -Force)) {
            if (-not $wanted.ContainsKey($f.FullName.ToLowerInvariant())) { Remove-Item -LiteralPath $f.FullName -Force; $removed++; Write-Host "Mes skins : retire du pack $($f.FullName.Substring($pack.Length + 1)) (apparence de base)" }
        }
        foreach ($d in @(Get-ChildItem -LiteralPath $assets -Recurse -Directory -Force | Sort-Object { $_.FullName.Length } -Descending)) {
            if (@(Get-ChildItem -LiteralPath $d.FullName -Force).Count -eq 0) { Remove-Item -LiteralPath $d.FullName -Force }
        }
        if (@(Get-ChildItem -LiteralPath $assets -Force).Count -eq 0) { Remove-Item -LiteralPath $assets -Force }
    }
    # default textures as a starting point (only when missing; never read back)
    $made = 0
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    foreach ($k in $keys) {
        $dst = Join-Path $modeles ($k + '.png')
        if (Test-Path -LiteralPath $dst) { continue }
        if (-not $script:SkinBosses[$k].Jar) { continue }   # a player body: any classic skin, no default to copy
        $jar = $null
        if (Test-Path -LiteralPath $JarDir) { $jar = Get-ChildItem -LiteralPath $JarDir -Filter $script:SkinBosses[$k].Jar -File -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -Last 1 }
        if ($null -eq $jar) { $notes += "modeles\$k.png : jar du mod introuvable dans $JarDir (image d'origine non copiee)."; continue }
        $z = [IO.Compression.ZipFile]::OpenRead($jar.FullName)
        try {
            $entry = $z.GetEntry($script:SkinBosses[$k].Texture)
            if ($null -eq $entry) { $notes += "modeles\$k.png : texture absente de $($jar.Name)."; continue }
            $ms = New-Object IO.MemoryStream
            $s = $entry.Open(); try { $s.CopyTo($ms) } finally { $s.Dispose() }
            [void](Write-IfDifferent $dst $ms.ToArray())
            $made++
        }
        finally { $z.Dispose() }
    }
    foreach ($n in $notes) { Write-Host "Mes skins : $n" }
    Write-Host "Mes skins : $copied copie(s), $kept deja en place, $removed retire(s), $made image(s) d'origine dans modeles. Dossier : $mes"
    Write-Host "Mes sons : $sonsCopies copie(s), $($sonsPlan.Count) fichier(s) dans $mesSons"
    $sonsLine = "Sons perso : $sonsOk installe(s)"
    if ($sonsMiss.Count -gt 0) { $sonsLine += ", $($sonsMiss.Count) manquant(s) : " + ($sonsMiss -join ', ') }
    elseif ($sonsPlan.Count -eq 0) { $sonsLine += ' (mes-sons est vide ou sans nom reconnu)' }
    Write-Host $sonsLine
    exit 0
}
catch { Stop-Skins $_.Exception.Message }
