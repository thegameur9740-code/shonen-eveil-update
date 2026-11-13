<#
.SYNOPSIS
    Builds the dynamic music of an instance (mod Ambience Mini): free tracks + the player's "Mes musiques" folder.

.DESCRIPTION
    build-music.ps1 -InstanceDir <instance> -StageDir <folder> [-Tracks music\tracks.json] [-CacheDir cache\music]
                    [-FfmpegPath <ffmpeg.exe>]
    Called by sync-client.ps1 BEFORE anything in the instance is touched: this script never writes into the instance.
    It only reads <instance>\mes-musiques\<categorie>\ (menu, jour, nuit, village, mer, donjon, combat, boss, taverne) and
    fills -StageDir, which sync-client then mirrors into the instance root like the client overrides:
      <stage>\ambience_music\music_config.txt                    generated schedule (ASCII)
      <stage>\ambience_music\music\shonen\<categorie>\<id>.ogg   free tracks used by the config
      <stage>\ambience_music\music\mes-musiques\<categorie>\...  the player's files (normalised .ogg copies)
      <stage>\mes-musiques\LISEZ-MOI.txt                         French how-to (music\LISEZ-MOI.txt)
    Per category: when the player's folder holds at least one audio file (.ogg .mp3 .wav .flac .m4a .aac .opus .wma,
    subfolders included) only those files are used, otherwise the free tracks of that category.
    Per Grand Ennemi (mes-musiques\boss-<cle>\, the 12 keys of grands_ennemis.js): the player's files only; when the
    folder holds audio, a rule above the generic "boss" rule plays them while that boss's bar is shown or that boss
    fights / targets the player; an empty folder adds nothing (the generic boss rule applies). No free track.
    Free tracks: downloaded from tracks.json (sha1-checked, cache <CacheDir>\src), processed once with the 'ambiance'
    sound (softer highs, EBU R128 -22 LUFS = half the level of the player's files, -27 for the tavern, Vorbis) into
    <CacheDir>\ogg. Exploration tracks (jour, nuit, village, mer, donjon; the player's too) end with 50 s of silence:
    with the mod's 10 s delay that is 60 s between two tracks there and 10 s in a fight, a boss fight, the tavern. The player's files: copied first under an ASCII name (<CacheDir>\tmp\<sha1><ext>, so
    ffmpeg never sees a Japanese / accented path), converted / normalised into <CacheDir>\user\<sha1>-<v>.ogg, staged
    under a stable ASCII name (<name>-<sha1 8>.ogg, "musique-<sha1 8>.ogg" for a name without any Latin letter);
    <stage>\ambience_music\music\mes-musiques\INDEX.txt (UTF-8) maps every staged name to the player's file. The
    originals are only read (never moved, renamed, rewritten or deleted).
    Without ffmpeg (checked once, before any download, one French message): degraded mode, never a silent menu:
    already-normalised cached files are used, otherwise the original file when Ambience Mini can play it as is
    (.ogg .mp3 .flac, volume not normalised); other formats are skipped (a category left without file falls through
    to the next rule). Every ffmpeg call has a time limit (10 min).
    A track that cannot be downloaded or whose sha1 differs is skipped with a warning (never used unverified).
    -StageDir must be inside -CacheDir; it is emptied and rebuilt (hard links to the cache, copies as a fallback).
    Exit code: 0 = OK (warnings possible), 1 = error (bad tracks.json, unsafe stage folder...).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$InstanceDir,
    [Parameter(Mandatory = $true)][string]$StageDir,
    [string]$Tracks,
    [string]$CacheDir,
    [string]$FfmpegPath
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'music-lib.ps1')

function Stop-Music {
    param([string]$Message)
    [Console]::Error.WriteLine("ERROR: $Message")
    exit 1
}

function Write-MusicWarning {
    param([string]$Message)
    Write-Host "ATTENTION musique : $Message"
}

function Test-Reparse {
    param([string]$Path)
    return [bool]((Get-Item -LiteralPath $Path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)
}

function Add-StageFile {
    # Hard link (same volume, no copy) or copy of $Source at $Destination.
    param([string]$Source, [string]$Destination)
    $dir = [IO.Path]::GetDirectoryName($Destination)
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    try { New-Item -ItemType HardLink -Path $Destination -Value $Source -ErrorAction Stop | Out-Null }
    catch { Copy-Item -LiteralPath $Source -Destination $Destination -Force }
}

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    if (-not $Tracks) { $Tracks = Join-Path $repo 'music\tracks.json' }
    if (-not $CacheDir) { $CacheDir = Join-Path $repo 'cache\music' }
    $readme = Join-Path ([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Tracks))) 'LISEZ-MOI.txt'

    $trackList = @(Get-MusicTracks -Path $Tracks)
    if (-not (Test-Path -LiteralPath $readme -PathType Leaf)) { Stop-Music "Missing $readme (copied into <instance>\mes-musiques)." }
    if (-not (Test-Path -LiteralPath $InstanceDir -PathType Container)) { Stop-Music "Instance folder not found: $InstanceDir" }

    # ---- Stage folder: inside the cache, never a junction, emptied and rebuilt ----
    $cacheFull = [IO.Path]::GetFullPath($CacheDir).TrimEnd('\')
    $stageFull = [IO.Path]::GetFullPath($StageDir).TrimEnd('\')
    if (-not $stageFull.StartsWith($cacheFull + '\', [StringComparison]::OrdinalIgnoreCase)) { Stop-Music "The stage folder must be inside the music cache ($cacheFull): $stageFull" }
    if (-not (Test-Path -LiteralPath $cacheFull)) { New-Item -ItemType Directory -Path $cacheFull -Force | Out-Null }
    if (Test-Reparse $cacheFull) { Stop-Music "The music cache is a junction/symlink: $cacheFull" }
    $cur = $cacheFull
    foreach ($part in $stageFull.Substring($cacheFull.Length + 1).Split('\')) {
        $cur = Join-Path $cur $part
        if ((Test-Path -LiteralPath $cur) -and (Test-Reparse $cur)) { Stop-Music "Junction/symlink in the stage path: $cur" }
    }
    if (Test-Path -LiteralPath $stageFull) { Remove-Item -LiteralPath $stageFull -Recurse -Force }
    New-Item -ItemType Directory -Path $stageFull -Force | Out-Null
    foreach ($d in 'src', 'ogg', 'user') { New-Item -ItemType Directory -Path (Join-Path $cacheFull $d) -Force | Out-Null }

    foreach ($d in 'tmp') { New-Item -ItemType Directory -Path (Join-Path $cacheFull $d) -Force | Out-Null }
    $eA = [string][char]0xE9; $aG = [string][char]0xE0   # French accents, file kept ASCII

    # ---- ffmpeg: checked once, before any download ----
    $ffmpeg = Find-MusicFfmpeg -Explicit $FfmpegPath -RepoRoot $repo
    if (-not $ffmpeg) {
        Write-Host ("ATTENTION musique : ffmpeg est introuvable. La musique marche quand m" + [char]0xEA + "me : les morceaux sont jou" + $eA +
            "s tels quels (volume non r" + $eA + "gl" + $eA + "), les fichiers .wav .m4a .aac .opus .wma sont ignor" + $eA + "s. Pour tout avoir : " +
            "winget install Gyan.FFmpeg, puis relance la synchronisation.")
    }

    $userRoot = Join-Path $InstanceDir 'mes-musiques'
    if ((Test-Path -LiteralPath $userRoot) -and (Test-Reparse $userRoot)) { Stop-Music "mes-musiques is a junction/symlink: $userRoot" }
    $plan = Resolve-MusicPlan -Tracks $trackList -UserRoot $userRoot
    $files = [ordered]@{}
    $sources = @{}
    $index = New-Object 'Collections.Generic.List[string]'
    $musicStage = Join-Path $stageFull 'ambience_music\music'

    foreach ($c in $script:MusicUserCategories) {
        $entry = $plan[$c]
        $sources[$c] = $entry.Source
        if ($entry.Source -eq 'none') { $files[$c] = @(); continue }   # empty boss-<key> folder: generic boss rule
        $list = New-Object 'Collections.Generic.List[string]'
        foreach ($item in @($entry.Items)) {
            try {
                if ($entry.Source -eq 'free') {
                    $sha = ([string]$item.sha1).ToLowerInvariant()
                    $ext = Get-MusicUrlExtension ([string]$item.url)
                    $how = Get-MusicTreatment -Category $c -Source 'free'
                    $ready = Join-Path $cacheFull ("ogg\{0}-{1}-{2}.ogg" -f $item.id, $sha.Substring(0, 12), $how.Version)
                    $readyExt = '.ogg'
                    if (-not (Test-Path -LiteralPath $ready -PathType Leaf)) {
                        if (-not $ffmpeg -and $script:MusicNativeExtensions -notcontains $ext) { throw "format $ext illisible sans ffmpeg" }
                        $src = Join-Path $cacheFull ('src\' + $item.id + $ext)
                        $ok = (Test-Path -LiteralPath $src -PathType Leaf) -and ((Get-FileHash -Algorithm SHA1 -LiteralPath $src).Hash -ieq $sha)
                        if (-not $ok) {
                            $part = Join-Path $cacheFull ('src\dl-' + [guid]::NewGuid().ToString('N') + '.part')
                            try {
                                Write-Host "Download music $($item.id) ($($item.url))"
                                Invoke-WebRequest -UseBasicParsing -Uri $item.url -OutFile $part -UserAgent 'modpack-shonen/1.0'
                                $got = (Get-FileHash -Algorithm SHA1 -LiteralPath $part).Hash
                                if ($got -ine $sha) { throw "sha1 mismatch (expected $sha, got $($got.ToLowerInvariant()))" }
                                Move-Item -LiteralPath $part -Destination $src -Force
                            }
                            finally { if (Test-Path -LiteralPath $part) { Remove-Item -LiteralPath $part -Force -ErrorAction SilentlyContinue } }
                        }
                        if ($ffmpeg) {
                            Write-Host "Normalise music $($item.id)"
                            Convert-MusicToOgg -Ffmpeg $ffmpeg -Source $src -Destination $ready -Sound $how.Sound -PadSeconds $how.Pad
                        }
                        else { $ready = $src; $readyExt = $ext }   # degraded mode: the verified original, played as is
                    }
                    $rel = "shonen/$c/$($item.id)$readyExt"
                    Add-StageFile -Source $ready -Destination (Join-Path $musicStage ($rel -replace '/', '\'))
                    $list.Add($rel)
                }
                else {
                    $sha = (Get-FileHash -Algorithm SHA1 -LiteralPath $item.Path).Hash.ToLowerInvariant()
                    $how = Get-MusicTreatment -Category $c -Source 'user'
                    $ready = Join-Path $cacheFull ("user\{0}-{1}.ogg" -f $sha, $how.Version)
                    $readyExt = '.ogg'
                    $copyOnly = $false
                    if (-not (Test-Path -LiteralPath $ready -PathType Leaf)) {
                        if ($ffmpeg) {
                            # ffmpeg only ever sees an ASCII path: a temporary copy named after the content
                            $tmpSrc = Join-Path $cacheFull ('tmp\' + $sha + $item.Extension)
                            try {
                                [IO.File]::Copy($item.Path, $tmpSrc, $true)
                                Write-Host "Convert mes-musiques\$c\$($item.Rel)"
                                Convert-MusicToOgg -Ffmpeg $ffmpeg -Source $tmpSrc -Destination $ready -Sound $how.Sound -PadSeconds $how.Pad
                            }
                            finally { if (Test-Path -LiteralPath $tmpSrc) { Remove-Item -LiteralPath $tmpSrc -Force -ErrorAction SilentlyContinue } }
                        }
                        elseif ($script:MusicNativeExtensions -contains $item.Extension) {
                            $ready = $item.Path; $readyExt = $item.Extension; $copyOnly = $true   # as is, read only, copied
                        }
                        else { throw "format $($item.Extension) illisible sans ffmpeg" }
                    }
                    $name = ConvertTo-MusicFileName -Name ([IO.Path]::GetFileName($item.Path)) -Sha1 $sha -Extension $readyExt
                    $rel = "mes-musiques/$c/$name"
                    if ($list -contains $rel) { continue }   # the same file twice (same content and name)
                    $dest = Join-Path $musicStage ($rel -replace '/', '\')
                    if ($copyOnly) {
                        New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($dest)) -Force | Out-Null
                        [IO.File]::Copy($ready, $dest, $true)
                    }
                    else { Add-StageFile -Source $ready -Destination $dest }
                    $list.Add($rel)
                    $index.Add("$c/$name`t<- mes-musiques\$c\$($item.Rel)")
                }
            }
            catch {
                $what = if ($entry.Source -eq 'free') { "morceau libre '$($item.id)'" } else { "mes-musiques\$c\$($item.Rel)" }
                Write-MusicWarning "$what ignor$eA ($($_.Exception.Message))."
            }
        }
        $files[$c] = @($list)
        $label = if ($entry.Source -eq 'user') { 'Mes musiques' } else { 'morceaux libres' }
        Write-Host ("Musique {0,-8}: {1} fichier(s) ({2})" -f $c, $list.Count, $label)
        if ($entry.Source -eq 'user' -and $list.Count -eq 0 -and $script:MusicCategories -cnotcontains $c) {
            Write-MusicWarning ("aucun fichier lisible dans mes-musiques\$c : la musique boss g$eA" + "n$eA" + "rale sera jou$eA" + 'e.')
        }
    }
    if ($index.Count -gt 0) {
        $indexPath = Join-Path $musicStage 'mes-musiques\INDEX.txt'
        New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($indexPath)) -Force | Out-Null
        $head = "# Mes musiques : nom utilis$eA par la musique du jeu <- ton fichier (g$eA" + "n" + $eA + "r" + $eA + " $aG chaque synchronisation)"
        [IO.File]::WriteAllText($indexPath, (@($head) + @($index) -join "`r`n") + "`r`n", (New-Object Text.UTF8Encoding($false)))
    }

    $config = New-AmbienceConfig -Files $files -Sources $sources
    $configPath = Join-Path $stageFull 'ambience_music\music_config.txt'
    [IO.File]::WriteAllText($configPath, $config, (New-Object Text.UTF8Encoding($false)))
    $readmeDest = Join-Path $stageFull 'mes-musiques\LISEZ-MOI.txt'
    New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($readmeDest)) -Force | Out-Null
    Copy-Item -LiteralPath $readme -Destination $readmeDest -Force
    Write-Host "Musique : configuration prete ($stageFull)."
    exit 0
}
catch {
    Stop-Music $_.Exception.Message
}
