# Shonen Eveil - mise a jour locale d'une instance du pack (P4-D). Lance par "Mettre a jour mes musiques et skins.bat"
# (dossier de l'instance), jeu ferme, sans droits administrateur. Fichier ASCII (PowerShell 5.1 lit en ANSI).
#   1. mods a telecharger (shonen-outils\mods-a-telecharger.json) : mods dont la licence interdit de les mettre dans le
#      zip ; telecharges depuis leur site officiel, empreinte sha1 verifiee, poses dans mods\ (deja la = rien).
#   2. musique : build-music.ps1 lit mes-musiques\ (jamais modifie) et refait ambience_music\ (musiques libres du pack
#      + tes fichiers, convertis avec ffmpeg s'il est installe, sinon .ogg / .mp3 / .flac tels quels).
#   3. skins et sons : sync-skins.ps1 copie mes-skins\<boss>.png et mes-sons\<son>.<ext> dans le pack de ressources
#      "Shonen Mes Skins" (active).
#   3 bis. reglages de DragonMine Z : set-dmz-user-config.ps1 repare config\dragonminez\general-user.json s'il est casse
#      (les reglages valides du joueur sont gardes) et coupe une fois la camera par-dessus l'epaule (elle fait rater
#      les coups en 3e personne).
#   4. bilan : mods, skins, musiques, sons, ffmpeg, et une ligne qui dit s'il manque quelque chose.
# ffmpeg absent alors que mes-musiques ou mes-sons contient des fichiers : l'outil propose de l'installer (winget).
# Zip "outil" decompresse dans un sous-dossier (Windows "Extraire tout") : l'outil le recopie dans le dossier du pack.
# Rien n'est envoye nulle part ; tes fichiers de mes-musiques, mes-skins et mes-sons ne sont que lus.
# -FfmpegPath : chemin de ffmpeg.exe (sinon PATH / winget), ou 'none' pour faire comme s'il manquait (tests).
# -SansQuestion : ne pose aucune question (tests).
param([string]$FfmpegPath, [switch]$SansQuestion)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$here = $PSScriptRoot
$inst = (Resolve-Path (Join-Path $here '..')).Path
# zip outil decompresse dans un sous-dossier du pack : on recopie tout un cran plus haut (dossier du profil CurseForge)
$parent = Split-Path -Parent $inst
if (-not (Test-Path -LiteralPath (Join-Path $inst 'minecraftinstance.json')) -and $parent -and (Test-Path -LiteralPath (Join-Path $parent 'minecraftinstance.json'))) {
    Write-Host ('Le zip outil est dans un sous-dossier : copie de son contenu dans ' + $parent + ' ...')
    foreach ($f in @(Get-ChildItem -LiteralPath $inst -Recurse -File -Force)) {
        $dst = Join-Path $parent $f.FullName.Substring($inst.Length + 1)
        $dd = [IO.Path]::GetDirectoryName($dst)
        if (-not (Test-Path -LiteralPath $dd)) { New-Item -ItemType Directory -Path $dd -Force | Out-Null }
        Copy-Item -LiteralPath $f.FullName -Destination $dst -Force
    }
    foreach ($d in @(Get-ChildItem -LiteralPath $inst -Recurse -Directory -Force)) { New-Item -ItemType Directory -Path (Join-Path $parent $d.FullName.Substring($inst.Length + 1)) -Force | Out-Null }
    Write-Host ('Fait. Tu peux supprimer le dossier ' + (Split-Path -Leaf $inst) + ' plus tard.')
    $inst = $parent
    $here = Join-Path $inst 'shonen-outils'
}
$psExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$e = [string][char]0xE9; $ag = [string][char]0xE0; $eg = [string][char]0xE8
function Say([string]$t) { Write-Host $t }
function Fail([string]$t) { Write-Host ''; Write-Host ('PROBL' + [char]0xC8 + 'ME : ' + $t) -ForegroundColor Red; exit 1 }
function Run-Child([string]$Script, [string[]]$Arguments) {
    $ErrorActionPreference = 'Continue'
    & $psExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $here $Script) @Arguments 2>&1 | ForEach-Object { Write-Host "  $_" }
    $code = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    return $code
}
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Say ('Shonen ' + [char]0xC9 + 'veil - mise ' + $ag + ' jour de l''instance : ' + $inst)
# ---- 0. le jeu doit etre ferme (il bloque les mods et reecrit options.txt en quittant) ----
$jeu = @(Get-CimInstance Win32_Process -Filter "Name='javaw.exe' OR Name='java.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -and $_.CommandLine.IndexOf($inst, [StringComparison]::OrdinalIgnoreCase) -ge 0 })
if ($jeu.Count -gt 0) { Fail ('Minecraft est ouvert sur cette instance : ferme le jeu, puis relance ce fichier.') }

# ---- 1. mods a telecharger depuis leur site officiel ----
$mods = Join-Path $inst 'mods'
$liste = Join-Path $here 'mods-a-telecharger.json'
$manque = @()
$dl = @()
$modsOk = 0
if (Test-Path -LiteralPath $liste) {
    $dl = @((Get-Content -LiteralPath $liste -Raw -Encoding UTF8 | ConvertFrom-Json) | ForEach-Object { $_ } | Where-Object { $_ })
    foreach ($m in $dl) {
        $dst = Join-Path $mods ([IO.Path]::GetFileName([string]$m.fichier))
        if ((Test-Path -LiteralPath $dst) -and ((Get-FileHash -Algorithm SHA1 -LiteralPath $dst).Hash -ieq [string]$m.sha1)) { $modsOk++; Say ("Mod $($m.nom) : d" + $e + 'j' + $ag + ' l' + $ag + '.'); continue }
        $part = $dst + '.part'
        try {
            Say ("Mod $($m.nom) : t" + $e + "l" + $e + "chargement depuis $(([uri]$m.url).Host) ...")
            Invoke-WebRequest -UseBasicParsing -Uri ([string]$m.url) -OutFile $part -UserAgent 'shonen-eveil-pack/1.0'
            if ((Get-FileHash -Algorithm SHA1 -LiteralPath $part).Hash -ine [string]$m.sha1) { throw ('empreinte diff' + $e + 'rente (fichier modifi' + $e + ' ?)') }
            Move-Item -LiteralPath $part -Destination $dst -Force
            Say ("Mod $($m.nom) : install" + $e + '.')
            $modsOk++
        }
        catch {
            $manque += ('le mod ' + $m.nom + ' (relance plus tard)')
            if (Test-Path -LiteralPath $part) { Remove-Item -LiteralPath $part -Force -ErrorAction SilentlyContinue }
            Say ("ATTENTION : le mod $($m.nom) n'a pas pu " + $e + 'tre t' + $e + 'l' + $e + "charg" + $e + " ($($_.Exception.Message)). Le serveur marche sans lui ; en solo il manque seulement ses villages. R" + $e + 'essaie plus tard.')
        }
    }
}

# ---- 1 bis. ffmpeg (convertit .m4a, .wav, .aac, .opus... et regle le volume) ----
. (Join-Path $here 'music-lib.ps1')
function Get-PersoCount([string]$Dir, [switch]$Top) {
    if (-not (Test-Path -LiteralPath $Dir)) { return 0 }
    $all = if ($Top) { @(Get-ChildItem -LiteralPath $Dir -File -Force) } else { @(Get-ChildItem -LiteralPath $Dir -Recurse -File -Force) }
    return @($all | Where-Object { $_.Name -ine 'LISEZ-MOI.txt' }).Count
}
$nMus = Get-PersoCount (Join-Path $inst 'mes-musiques')
$nSons = Get-PersoCount (Join-Path $inst 'mes-sons') -Top
$nSonsConv = 0   # sons a convertir (tout sauf .ogg : un .ogg est copie tel quel, sans ffmpeg)
if (Test-Path -LiteralPath (Join-Path $inst 'mes-sons')) { $nSonsConv = @(Get-ChildItem -LiteralPath (Join-Path $inst 'mes-sons') -File -Force | Where-Object { $_.Name -ine 'LISEZ-MOI.txt' -and $_.Extension.ToLowerInvariant() -ne '.ogg' }).Count }
$nSkins = 0
if (Test-Path -LiteralPath (Join-Path $inst 'mes-skins')) { $nSkins = @(Get-ChildItem -LiteralPath (Join-Path $inst 'mes-skins') -File -Filter '*.png' -Force).Count }
$aConvertir = 0
if (Test-Path -LiteralPath (Join-Path $inst 'mes-musiques')) {
    $aConvertir = @(Get-ChildItem -LiteralPath (Join-Path $inst 'mes-musiques') -Recurse -File -Force | Where-Object { $_.Name -ine 'LISEZ-MOI.txt' -and @('.ogg', '.mp3', '.flac') -notcontains $_.Extension.ToLowerInvariant() }).Count
}
$ffmpeg = $null
if ($FfmpegPath -ne 'none') {
    try { $ffmpeg = Find-MusicFfmpeg -Explicit $FfmpegPath } catch { $ffmpeg = $null }
    if (-not $ffmpeg) {
        $local = Get-ChildItem -LiteralPath (Join-Path $here 'ffmpeg') -Recurse -Filter 'ffmpeg.exe' -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($local) { $ffmpeg = $local.FullName }
    }
    if (-not $ffmpeg -and ($nMus + $nSonsConv) -gt 0 -and -not $SansQuestion) {
        Say ''
        $r = Read-Host 'ffmpeg manque pour convertir tes musiques : l''installer maintenant ? O/N'
        if ($r -match '^\s*[oOyY]') {
            $wg = Get-Command winget.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $wg) {
                Say ('winget est absent de ce PC. T' + $e + 'l' + $e + 'charge ffmpeg ici : https://www.gyan.dev/ffmpeg/builds/ (ffmpeg-release-essentials.zip),')
                Say ('d' + $e + 'compresse-le dans le dossier shonen-outils\ffmpeg du pack, puis relance ce fichier.')
            }
            else {
                $ErrorActionPreference = 'Continue'
                & $wg.Source install --id Gyan.FFmpeg -e --accept-package-agreements --accept-source-agreements
                $ErrorActionPreference = 'Stop'
                $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
                try { $ffmpeg = Find-MusicFfmpeg } catch { $ffmpeg = $null }
                if ($ffmpeg) { Say ('ffmpeg install' + $e + ' : ' + $ffmpeg) }
                else { Say ('ffmpeg n''a pas pu ' + $e + 'tre install' + $e + ' : les .ogg / .mp3 / .flac marchent quand m' + [char]0xEA + 'me.') }
            }
        }
    }
}
$ffArg = if ($FfmpegPath -eq 'none') { 'none' } elseif ($ffmpeg) { $ffmpeg } else { '' }

# ---- 2. musique ----
$tracks = Join-Path $here 'musique\tracks.json'
$cache = Join-Path $here 'cache'
foreach ($d in 'ogg', 'src') { New-Item -ItemType Directory -Path (Join-Path $cache $d) -Force | Out-Null }
# les musiques libres livrees dans le zip servent de cache : pas de telechargement, pas besoin de ffmpeg pour elles
foreach ($t in @(Get-MusicTracks -Path $tracks)) {
    $sha = ([string]$t.sha1).ToLowerInvariant()
    $dir = Join-Path $inst ("ambience_music\music\shonen\" + $t.category)
    $ogg = Join-Path $dir ($t.id + '.ogg')
    $cOgg = Join-Path $cache ("ogg\{0}-{1}-{2}.ogg" -f $t.id, $sha.Substring(0, 12), (Get-MusicTreatment -Category ([string]$t.category) -Source 'free').Version)
    if ((Test-Path -LiteralPath $ogg) -and -not (Test-Path -LiteralPath $cOgg)) { Copy-Item -LiteralPath $ogg -Destination $cOgg; continue }
    $ext = Get-MusicUrlExtension ([string]$t.url)
    $orig = Join-Path $dir ($t.id + $ext)
    $cSrc = Join-Path $cache ('src\' + $t.id + $ext)
    if ($ext -ne '.ogg' -and (Test-Path -LiteralPath $orig) -and -not (Test-Path -LiteralPath $cSrc) -and ((Get-FileHash -Algorithm SHA1 -LiteralPath $orig).Hash -ieq $sha)) { Copy-Item -LiteralPath $orig -Destination $cSrc }
}
$stage = Join-Path $cache 'stage'
Say 'Musique : lecture de mes-musiques et configuration ...'
$margs = @('-InstanceDir', $inst, '-StageDir', $stage, '-CacheDir', $cache, '-Tracks', $tracks)
if ($ffArg) { $margs += @('-FfmpegPath', $ffArg) }
$code = Run-Child 'build-music.ps1' $margs
if ($code -ne 0) { Fail ('la musique n''a pas pu ' + $e + 'tre pr' + $e + 'par' + $e + 'e (voir les lignes au-dessus). Rien n''a ' + $e + 't' + $e + ' modifi' + $e + ' dans le jeu.') }
$stageFull = [IO.Path]::GetFullPath($stage).TrimEnd('\')
$n = 0
foreach ($f in @(Get-ChildItem -LiteralPath $stageFull -Recurse -File -Force)) {
    $rel = $f.FullName.Substring($stageFull.Length + 1)
    $dst = Join-Path $inst $rel
    $dd = [IO.Path]::GetDirectoryName($dst)
    if (-not (Test-Path -LiteralPath $dd)) { New-Item -ItemType Directory -Path $dd -Force | Out-Null }
    if ((Test-Path -LiteralPath $dst) -and ((Get-FileHash -Algorithm SHA1 -LiteralPath $dst).Hash -eq (Get-FileHash -Algorithm SHA1 -LiteralPath $f.FullName).Hash)) { continue }
    Copy-Item -LiteralPath $f.FullName -Destination $dst -Force
    $n++
}
foreach ($c in $script:MusicUserCategories) { New-Item -ItemType Directory -Path (Join-Path $inst "mes-musiques\$c") -Force | Out-Null }
Say ("Musique : $n fichier(s) mis " + $ag + ' jour (dossier ambience_music).')

# ---- 3. skins ----
Say 'Skins et sons : mes-skins, mes-sons -> pack "Shonen Mes Skins" ...'
$sargs = @('-InstanceDir', $inst, '-JarDir', $mods, '-ReadmeFile', (Join-Path $here 'skins\LISEZ-MOI.txt'), '-SonsReadmeFile', (Join-Path $here 'skins\LISEZ-MOI-sons.txt'))
if ($ffArg) { $sargs += @('-FfmpegPath', $ffArg) }
$code = Run-Child 'sync-skins.ps1' $sargs
if ($code -ne 0) { Fail ('les skins n''ont pas pu ' + $e + 'tre copi' + $e + 's (voir les lignes au-dessus).') }
$code = Run-Child 'set-client-options.ps1' @('-OptionsFile', (Join-Path $inst 'options.txt'), '-PackName', 'Shonen Mes Skins', '-DefaultVolumes')
if ($code -ne 0) { Fail ('options.txt n''a pas pu ' + $e + 'tre mis ' + $ag + ' jour.') }

# ---- 3 bis. reglages de DragonMine Z : fichier casse repare, camera par-dessus l'epaule coupee une fois ----
$code = Run-Child 'set-dmz-user-config.ps1' @('-ConfigFile', (Join-Path $inst 'config\dragonminez\general-user.json'), '-DefaultsFile', (Join-Path $here 'dmz\general-user.json'), '-MarkerDir', (Join-Path $inst 'config\shonen-eveil'))
if ($code -ne 0) { $manque += ('les r' + $e + 'glages de DragonMine Z (config\dragonminez\general-user.json) n''ont pas pu ' + $e + 'tre r' + $e + 'par' + $e + 's') }

# ---- 4. bilan ----
if (@(Get-ChildItem -LiteralPath $mods -Filter 'shonencore-*.jar' -File -ErrorAction SilentlyContinue).Count -eq 0) { $manque += ('Shonen Core dans mods (refais l''' + $e + 'tape 3 du guide INSTALLER.txt)') }
if (@(Get-ChildItem -LiteralPath (Join-Path $inst 'kubejs\server_scripts') -Filter '*.js' -File -ErrorAction SilentlyContinue).Count -eq 0) { $manque += ('les scripts KubeJS (refais l''' + $e + 'tape 3 du guide INSTALLER.txt)') }
if (-not $ffmpeg -and ($aConvertir + $nSonsConv) -gt 0) { $manque += ('ffmpeg : ' + ($aConvertir + $nSonsConv) + ' fichier(s) de mes-musiques / mes-sons ignor' + $e + '(s) (relance et r' + $e + 'ponds O)') }
Say ''
Say 'Bilan :'
Say ('  Mods t' + $e + 'l' + $e + 'charg' + $e + 's : ' + $modsOk + ' sur ' + $dl.Count)
Say ('  Skins    : ' + $nSkins + ' image(s) dans mes-skins')
Say ('  Musiques : ' + $nMus + ' fichier(s) dans mes-musiques')
Say ('  Sons     : ' + $nSons + ' fichier(s) dans mes-sons')
Say ('  ffmpeg   : ' + $(if ($ffmpeg) { 'pr' + $e + 'sent' } else { 'absent' }))
if ($manque.Count -eq 0) { Write-Host ('Rien ne manque. Lance le jeu depuis CurseForge.') -ForegroundColor Green }
else { Write-Host ('Il manque : ' + ($manque -join ' ; ')) -ForegroundColor Yellow }
exit 0
