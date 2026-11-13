<#
    music-lib.ps1 - functions shared by build-music.ps1 and its Pester tests (dot-source this file).
    Keep this file ASCII-only: PS 5.1 reads BOM-less scripts as ANSI.

    Music mod: Ambience Mini (client). It reads <game dir>\ambience_music\music_config.txt and plays the files under
    <game dir>\ambience_music\music\ (paths in the config are relative to that folder). The config is parsed by a
    Coco/R scanner that only decodes UTF-8 when the file has a BOM, so everything we write into it is ASCII
    (generated names for the player's files, no accents in comments).
#>

# Categories, in the order of the "Mes musiques" folders. Their priority in the schedule is set in New-AmbienceConfig.
# 'taverne' (11/11): the room of Orin's big shop, played while the server gives shonencore:taverne (taverne_musique.js).
$script:MusicCategories = @('menu', 'jour', 'nuit', 'village', 'mer', 'donjon', 'combat', 'boss', 'taverne')

# Audio files picked up in the player's folders. .ogg is used as is (after loudness normalisation when ffmpeg is
# there); the others are converted to .ogg with ffmpeg (the original file is never touched).
$script:MusicAudioExtensions = @('.ogg', '.mp3', '.wav', '.flac', '.m4a', '.aac', '.opus', '.wma')
# Formats Ambience Mini plays by itself (used as is when ffmpeg is missing).
$script:MusicNativeExtensions = @('.ogg', '.mp3', '.flac')

# Licences accepted for the free tracks (redistribution in a modpack allowed; CC-BY needs the credit in
# docs/credits-musique.md).
$script:MusicLicences = @('CC0-1.0', 'CC-BY-4.0', 'CC-BY-3.0')

# One music folder per Grand Ennemi (kubejs/server_scripts/grands_ennemis.js, docs/grands-ennemis.md): folder key ->
# entity types and Bar = an ASCII part of the French title of its boss bar. Their boss bars already trigger
# @boss_fight; the entity types are a second trigger for a fight without bar (barreMod, script disabled).
# Folder key = the Grand Ennemi key without the "histoire_" prefix (boss-pain, boss-orochimaru...; boss-grand_fisher and
# boss-fleau_ruelle for histoire_hollow / histoire_kuchisake). Admin's exception (07/11): a variant whose title
# already contains the Bar of a boss that has its folder (sealed Aizen and story Aizen in "Sosuke Aizen", the story
# versions of Sukuna, Broly, Freezer, Cell, Kaido, Itachi, Igris, the Ant King, Yhwach) has no folder of its own: it
# plays that boss's folder (its entity type is added to that entry).
# What Ambience Mini sees of a boss bar ($bosses, CombatState.getBosses): the bar NAME only (root component: literal
# text, or translation key), never the server-side bar id shonen:boss/<type>_<uuid8>. Our bars are named with the
# literal French title (e.g. "Ryomen Sukuna"), so a per-boss rule matches "name contains Bar" (operator ~~ =
# String.contains, case-sensitive; the config file is ASCII, hence an ASCII part of titles such as "Sosuke Aizen").
# A Pester test keeps folders, types and titles equal to the KubeJS table (every key in exactly one folder).
$script:MusicBosses = [ordered]@{
    # the final boss (docs/boss/coeur_convergence.md) FIRST (Admin, 08/11): its bar is shown during the whole fight, so
    # only boss-coeur plays, Anchor echoes included ("Echo de Kaido" bar, minepiece:kaidou fighting: the coeur rule wins,
    # first matching rule of the same priority). Its hands' rule comes right after it: boss-mains_du_coeur only plays
    # if the Heart's bar is not shown.
    coeur         = @{ Types = @('shonencore:coeur_convergence'); Bar = 'Convergence' }
    mains_du_coeur = @{ Types = @('shonencore:main_appel', 'shonencore:main_fin'); Bar = 'Main qui' }
    igris         = @{ Types = @('sololeveling:blood_red_com_igris'); Bar = 'Igris' }   # aussi histoire_igris
    toji          = @{ Types = @('jujutsucraft:fushiguro_toji'); Bar = 'Toji' }
    akainu        = @{ Types = @('minepiece:akainu'); Bar = 'Akainu' }
    roi_fourmis   = @{ Types = @('sololeveling:beru_boss'); Bar = 'Roi des Fourmis' }   # aussi histoire_roi_fourmis
    aizen         = @{ Types = @('bleachreborn:aizen', 'shonencore:corps_aizen_scelle'); Bar = 'Aizen' }   # aussi aizen_scelle, histoire_aizen
    freezer       = @{ Types = @('dragonminez:saga_frieza_fp', 'dragonminez:saga_frieza_first'); Bar = 'Freezer' }   # aussi histoire_freezer
    cell          = @{ Types = @('dragonminez:saga_cell_perfect', 'dragonminez:saga_cell_imperfect'); Bar = 'Cell' }   # aussi histoire_cell
    kaido         = @{ Types = @('minepiece:kaidou'); Bar = 'Kaido' }   # aussi histoire_kaido
    sukuna        = @{ Types = @('jujutsucraft:sukuna_perfect', 'jujutsucraft:sukuna_fushiguro'); Bar = 'Sukuna' }   # aussi histoire_sukuna
    mahoraga      = @{ Types = @('jujutsucraft:eight_handled_sword_divergent_sila_divine_general_mahoraga'); Bar = 'Mahoraga' }
    yhwach        = @{ Types = @('bleachreborn:yhwach'); Bar = 'Yhwach' }   # aussi histoire_yhwach
    broly         = @{ Types = @('dragonminez:saga_broly_base'); Bar = 'Broly' }   # aussi histoire_broly
    shukaku       = @{ Types = @('ninshuorigins:shukaku'); Bar = 'Shukaku' }
    matatabi      = @{ Types = @('ninshuorigins:matatabi'); Bar = 'Matatabi' }
    isobu         = @{ Types = @('ninshuorigins:isobu'); Bar = 'Isobu' }
    son_goku      = @{ Types = @('ninshuorigins:songoku'); Bar = 'Son Goku' }
    kokuo         = @{ Types = @('ninshuorigins:kukuo'); Bar = 'Kokuo' }
    saiken        = @{ Types = @('ninshuorigins:saiken'); Bar = 'Saiken' }
    chomei        = @{ Types = @('ninshuorigins:chomei'); Bar = 'Chomei' }
    gyuki         = @{ Types = @('ninshuorigins:gyuki'); Bar = 'Gyuki' }
    itachi        = @{ Types = @('ninshuorigins:itachi'); Bar = 'Itachi' }   # aussi histoire_itachi
    moonfish      = @{ Types = @('shonencore:corps_moonfish'); Bar = 'Moonfish' }
    stain         = @{ Types = @('shonencore:corps_stain'); Bar = 'Stain' }
    muscular      = @{ Types = @('shonencore:corps_muscular'); Bar = 'Muscular' }
    nomu_usj      = @{ Types = @('shonencore:corps_nomu_usj'); Bar = 'USJ' }
    overhaul      = @{ Types = @('quirksunchained:overhaul'); Bar = 'Overhaul' }
    dabi          = @{ Types = @('shonencore:corps_dabi'); Bar = 'Dabi' }
    all_for_one   = @{ Types = @('shonencore:corps_all_for_one'); Bar = 'All For One' }
    histoire_nomu = @{ Types = @('shonencore:corps_histoire_nomu'); Bar = 'Nomu errant' }
    toga          = @{ Types = @('shonencore:corps_toga'); Bar = 'Toga' }
    twice         = @{ Types = @('shonencore:corps_twice'); Bar = 'Twice' }
    mr_compress   = @{ Types = @('shonencore:corps_mr_compress'); Bar = 'Compress' }
    re_destro     = @{ Types = @('quirksunchained:re_destro'); Bar = 'Re-Destro' }
    gigantomachia = @{ Types = @('shonencore:corps_gigantomachia'); Bar = 'Gigantomachia' }
    hood          = @{ Types = @('shonencore:corps_hood'); Bar = 'Hood' }
    shigaraki     = @{ Types = @('shonencore:corps_shigaraki'); Bar = 'Shigaraki' }
    gojo          = @{ Types = @('jujutsucraft:gojo_satoru'); Bar = 'Gojo' }
    roi_gobelin   = @{ Types = @('sololeveling:goblin_king'); Bar = 'gobelin' }
    fleau_ruelle  = @{ Types = @('jujutsucraft:cursed_spirit_grade_14'); Bar = 'ruelle' }
    danzo         = @{ Types = @('ninshuorigins:danzo'); Bar = 'Danz' }
    madara        = @{ Types = @('shonencore:corps_madara'); Bar = 'Madara' }
    kaguya        = @{ Types = @('shonencore:corps_kaguya'); Bar = 'Kaguya' }
    juubi         = @{ Types = @('shonencore:juubi'); Bar = 'Dix-Queues' }
    buggy         = @{ Types = @('minepiece:buggy'); Bar = 'Buggy' }
    alvida        = @{ Types = @('minepiece:alvida'); Bar = 'Alvida' }
    zabuza        = @{ Types = @('ninshuorigins:zabuza'); Bar = 'Zabuza' }
    haku          = @{ Types = @('shonencore:corps_haku'); Bar = 'Haku' }
    raditz        = @{ Types = @('dragonminez:saga_raditz'); Bar = 'Raditz' }
    arlong        = @{ Types = @('minepiece:arlong'); Bar = 'Arlong' }
    orochimaru    = @{ Types = @('ninshuorigins:orochimaru'); Bar = 'Orochimaru' }
    menos         = @{ Types = @('bleachreborn:hollow_menos'); Bar = 'Menos' }
    kasaka        = @{ Types = @('sololeveling:kasaka'); Bar = 'Kasaka' }
    nappa         = @{ Types = @('dragonminez:saga_nappa'); Bar = 'Nappa' }
    vegeta        = @{ Types = @('dragonminez:saga_vegeta'); Bar = 'Vegeta' }
    hanami        = @{ Types = @('jujutsucraft:hanami'); Bar = 'Hanami' }
    dagon         = @{ Types = @('jujutsucraft:dagon'); Bar = 'Dagon' }
    ginyu         = @{ Types = @('dragonminez:saga_ginyu'); Bar = 'Ginyu' }
    jogo          = @{ Types = @('jujutsucraft:jogo'); Bar = 'Jogo' }
    mahito        = @{ Types = @('jujutsucraft:mahito'); Bar = 'Mahito' }
    crocodile     = @{ Types = @('minepiece:crocodile'); Bar = 'Crocodile' }
    grimmjow      = @{ Types = @('bleachreborn:grimmjow'); Bar = 'Grimmjow' }
    katakuri      = @{ Types = @('minepiece:charlotte_katakuri'); Bar = 'Katakuri' }
    megumi        = @{ Types = @('jujutsucraft:fushiguro_megumi_shibuya'); Bar = 'Megumi' }
    king          = @{ Types = @('minepiece:king'); Bar = 'King' }
    queen         = @{ Types = @('minepiece:queen'); Bar = 'Queen' }
    jack          = @{ Types = @('minepiece:jack'); Bar = 'Jack' }
    pain          = @{ Types = @('ninshuorigins:pain'); Bar = 'Pain' }
    obito         = @{ Types = @('ninshuorigins:warobito'); Bar = 'Obito' }
    kenjaku       = @{ Types = @('jujutsucraft:kenjaku'); Bar = 'Kenjaku' }
    buu           = @{ Types = @('dragonminez:saga_buufat'); Bar = 'Buu' }
    baran         = @{ Types = @('sololeveling:baran'); Bar = 'Baran' }
    kamish        = @{ Types = @('sololeveling:kamish'); Bar = 'Kamish' }
    # the S+ final exams of 08/11 (docs/boss/barbe_noire.md, ulquiorra.md, jiren.md, thomas_andre.md)
    barbe_noire   = @{ Types = @('minepiece:marshall_d_teach_four_emperors'); Bar = 'Barbe Noire' }
    ulquiorra     = @{ Types = @('shonencore:corps_ulquiorra'); Bar = 'Ulquiorra' }
    jiren         = @{ Types = @('shonencore:corps_jiren'); Bar = 'Jiren' }
    thomas_andre  = @{ Types = @('sololeveling:thomas_andre'); Bar = 'Thomas Andre' }
    kisame        = @{ Types = @('shonencore:corps_kisame'); Bar = 'Kisame' }
    deidara       = @{ Types = @('shonencore:corps_deidara'); Bar = 'Deidara' }
    sasori        = @{ Types = @('shonencore:corps_sasori'); Bar = 'Sasori' }
    konan         = @{ Types = @('shonencore:corps_konan'); Bar = 'Konan' }
    yuta          = @{ Types = @('jujutsucraft:okkotsu_yuta_culling_game'); Bar = 'Yuta' }
    hakari        = @{ Types = @('jujutsucraft:hakari_kinji'); Bar = 'Hakari' }
    grand_fisher  = @{ Types = @('bleachreborn:hollow_fisher'); Bar = 'Fisher' }
    kurama        = @{ Types = @('ninshuorigins:kurama'); Bar = 'Kurama' }
}
$script:MusicBossTypes = @(@(foreach ($k in $script:MusicBosses.Keys) { $script:MusicBosses[$k].Types }) | Select-Object -Unique)

# One "Mes musiques" folder per Grand Ennemi (boss-<key>): player's files only (no free track). When it holds audio,
# a rule above the generic "boss" rule plays it for that boss; empty = the generic boss rule applies.
$script:MusicBossCategories = @(foreach ($k in $script:MusicBosses.Keys) { 'boss-' + $k })
# Every folder of <instance>\mes-musiques (created by sync-client.ps1).
$script:MusicUserCategories = @($script:MusicCategories) + @($script:MusicBossCategories)

function Get-MusicPlaylistName {
    # Playlist identifier in the config for a category folder: boss-sukuna -> boss_sukuna.
    param([Parameter(Mandatory = $true)][string]$Category)
    return ($Category -replace '-', '_')
}

# Bump when the processing below changes: cached .ogg files get rebuilt.
$script:MusicProcessingVersion = 'n1'

# Sound of the FREE tracks of the pack only (Admin, 11/11: "the ambience music tires the ears"): half the level of
# the other sounds (-22 LUFS instead of -16, i.e. -6 dB; true peak -3 dBTP) and softer highs (high shelf -6 dB from
# 4 kHz, then a gentle 6 dB/octave low-pass at 12 kHz). The player's own files (mes-musiques, mes-sons) keep the
# 'standard' sound. Bump MusicAmbianceVersion when 'ambiance' changes: the cached free tracks get rebuilt.
# 'salle' = the free tavern tracks: same softer highs, 5 dB lower again (-27 LUFS): a quiet background in the room.
# Tag = part of the cache name; bump it when the sound changes: the cached files get rebuilt.
$script:MusicSounds = @{
    standard = @{ Target = 'I=-16:TP=-1.5:LRA=11'; Pre = ''; Tag = '' }
    ambiance = @{ Target = 'I=-22:TP=-3:LRA=11'; Pre = 'highshelf=f=4000:g=-6,lowpass=f=12000:p=1'; Tag = 'a1' }
    salle    = @{ Target = 'I=-27:TP=-3:LRA=11'; Pre = 'highshelf=f=4000:g=-6,lowpass=f=12000:p=1'; Tag = 's1' }
}
# Silence between two tracks (Admin, 11/11): about 60 s while exploring, about 10 s in a fight, a boss fight and the
# tavern. Ambience Mini only has ONE delay for every playlist (Next_Music_Delay, 10 s in our client config), so the
# exploration tracks (free ones and the player's) get MusicPadSeconds of silence appended to the file: 10 + 50 = 60 s.
# Not the menu (a silent title screen looks broken). Leaving the ambience during that silence still switches at once.
$script:MusicPadCategories = @('jour', 'nuit', 'village', 'mer', 'donjon')
$script:MusicPadSeconds = 50

function Get-MusicTreatment {
    # How a file of a category is processed: Sound (key of $MusicSounds), Pad (seconds of silence appended) and
    # Version = the tag in its cache name (free: <id>-<sha1 12>-<Version>.ogg, player: <sha1>-<Version>.ogg).
    # -Source 'free' (track of tracks.json) or 'user' (file of mes-musiques: always the 'standard' sound).
    param([Parameter(Mandatory = $true)][string]$Category, [ValidateSet('free', 'user')][string]$Source = 'free')
    $sound = if ($Source -eq 'user') { 'standard' } elseif ($Category -ceq 'taverne') { 'salle' } else { 'ambiance' }
    $pad = if ($script:MusicPadCategories -ccontains $Category) { [int]$script:MusicPadSeconds } else { 0 }
    $version = $script:MusicProcessingVersion + [string]$script:MusicSounds[$sound].Tag
    if ($pad -gt 0) { $version += "p$pad" }
    return [pscustomobject]@{ Sound = $sound; Pad = $pad; Version = $version }
}

function Get-MusicTracks {
    # Reads and validates music\tracks.json ({ "tracks": [ { id, category, title, author, licence, source, url, sha1 } ] }).
    # Throws on the first problem; every category must have at least one track.
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Music track list not found: $Path" }
    $parsed = ConvertFrom-Json ([IO.File]::ReadAllText([IO.Path]::GetFullPath($Path), (New-Object Text.UTF8Encoding($false))))
    $tracks = @(foreach ($t in @($parsed.tracks)) { if ($null -ne $t) { $t } })
    if ($tracks.Count -eq 0) { throw "No track in $Path" }
    $ids = @{}
    foreach ($t in $tracks) {
        foreach ($field in 'id', 'category', 'title', 'author', 'licence', 'source', 'url', 'sha1') {
            if (-not $t.$field) { throw "Track '$($t.id)': field '$field' is missing." }
        }
        if ([string]$t.id -cnotmatch '^[a-z0-9]+(-[a-z0-9]+)*$') { throw "Track id '$($t.id)': lowercase letters, digits and dashes only." }
        if ($ids.ContainsKey([string]$t.id)) { throw "Duplicate track id '$($t.id)'." }
        $ids[[string]$t.id] = $true
        if ($script:MusicCategories -cnotcontains [string]$t.category) { throw "Track '$($t.id)': unknown category '$($t.category)'." }
        if ($script:MusicLicences -cnotcontains [string]$t.licence) { throw "Track '$($t.id)': licence '$($t.licence)' is not accepted ($($script:MusicLicences -join ', '))." }
        if ([string]$t.sha1 -notmatch '^[0-9a-fA-F]{40}$') { throw "Track '$($t.id)': sha1 must be 40 hex digits." }
        if ([string]$t.url -notmatch '^https://' -or [string]$t.source -notmatch '^https://') { throw "Track '$($t.id)': url and source must be https:// links." }
        $ext = Get-MusicUrlExtension ([string]$t.url)
        if ($script:MusicAudioExtensions -notcontains $ext) { throw "Track '$($t.id)': unsupported file type '$ext' in its url." }
    }
    foreach ($c in $script:MusicCategories) {
        if (-not ($tracks | Where-Object { $_.category -ceq $c })) { throw "No free track for the category '$c'." }
    }
    return $tracks
}

function Get-MusicUrlExtension {
    param([string]$Url)
    return [IO.Path]::GetExtension(([uri]$Url).AbsolutePath).ToLowerInvariant()
}

function Get-UserMusicFiles {
    # Audio files of one "Mes musiques" category folder (subfolders included, junctions/symlinks skipped), sorted by
    # relative path. A missing folder = no file.
    param([Parameter(Mandatory = $true)][string]$Folder)
    if (-not (Test-Path -LiteralPath $Folder -PathType Container)) { return @() }
    if ((Get-Item -LiteralPath $Folder -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { return @() }
    $result = New-Object 'Collections.Generic.List[object]'
    $queue = New-Object 'Collections.Generic.Queue[string]'
    $queue.Enqueue([IO.Path]::GetFullPath($Folder).TrimEnd('\'))
    $root = [IO.Path]::GetFullPath($Folder).TrimEnd('\')
    while ($queue.Count -gt 0) {
        $dir = $queue.Dequeue()
        foreach ($item in @(Get-ChildItem -LiteralPath $dir -Force)) {
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
            if ($item.PSIsContainer) { $queue.Enqueue($item.FullName); continue }
            if ($script:MusicAudioExtensions -contains $item.Extension.ToLowerInvariant()) {
                $result.Add([pscustomobject]@{ Path = $item.FullName; Rel = $item.FullName.Substring($root.Length + 1); Extension = $item.Extension.ToLowerInvariant() })
            }
        }
    }
    return @($result | Sort-Object Rel)
}

function Resolve-MusicPlan {
    # For each category: the player's files when its folder holds at least one audio file, the free tracks otherwise.
    # Then each per-boss folder (boss-<key>): the player's files, or nothing (Source 'none': the generic boss rule).
    # Returns an ordered dictionary category -> [pscustomobject]@{ Source = 'user'|'free'|'none'; Items = @(...) }
    # where an item is a user file (Get-UserMusicFiles) or a track of tracks.json.
    param([Parameter(Mandatory = $true)]$Tracks, [Parameter(Mandatory = $true)][string]$UserRoot)
    $plan = [ordered]@{}
    foreach ($c in $script:MusicUserCategories) {
        $user = @(Get-UserMusicFiles -Folder (Join-Path $UserRoot $c))
        if ($user.Count -gt 0) {
            $plan[$c] = [pscustomobject]@{ Source = 'user'; Items = $user }
        }
        elseif ($script:MusicCategories -ccontains $c) {
            $plan[$c] = [pscustomobject]@{ Source = 'free'; Items = @($Tracks | Where-Object { $_.category -ceq $c }) }
        }
        else {
            $plan[$c] = [pscustomobject]@{ Source = 'none'; Items = @() }
        }
    }
    return $plan
}

function ConvertTo-MusicFileName {
    # ASCII file name for a player's file in the generated config: accents dropped, other characters -> '_',
    # plus the first 8 hex digits of its sha1 (two files with the same name never collide); "musique" when nothing is
    # left (a Japanese title). Stable: same name + same content = same result. Extension: -Extension (default .ogg).
    param([Parameter(Mandatory = $true)][string]$Name, [Parameter(Mandatory = $true)][string]$Sha1, [string]$Extension = '.ogg')
    $base = [IO.Path]::GetFileNameWithoutExtension($Name).Normalize([Text.NormalizationForm]::FormD)
    $sb = New-Object Text.StringBuilder
    foreach ($ch in $base.ToCharArray()) {
        $cat = [Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch)
        if ($cat -eq [Globalization.UnicodeCategory]::NonSpacingMark) { continue }
        if (($ch -ge 'a' -and $ch -le 'z') -or ($ch -ge 'A' -and $ch -le 'Z') -or ($ch -ge '0' -and $ch -le '9') -or $ch -eq '-' -or $ch -eq '_') { [void]$sb.Append($ch) }
        else { [void]$sb.Append('_') }
    }
    $clean = ($sb.ToString() -replace '_{2,}', '_').Trim('_')
    if ($clean.Length -gt 60) { $clean = $clean.Substring(0, 60) }
    if (-not $clean) { $clean = 'musique' }
    return $clean + '-' + $Sha1.Substring(0, 8).ToLowerInvariant() + $Extension.ToLowerInvariant()
}

function Find-MusicFfmpeg {
    # ffmpeg.exe: -Explicit when given (must exist), else PATH, else the winget package (Gyan.FFmpeg), else
    # <repo>\cache\tools\ffmpeg\**\ffmpeg.exe. $null when not found.
    # -Explicit 'none' = behave as if ffmpeg were missing (degraded mode, used by the tests).
    param([string]$Explicit, [string]$RepoRoot)
    if ($Explicit -eq 'none') { return $null }
    if ($Explicit) {
        if (Test-Path -LiteralPath $Explicit -PathType Leaf) { return (Resolve-Path -LiteralPath $Explicit).Path }
        throw "ffmpeg not found: $Explicit"
    }
    $cmd = Get-Command ffmpeg.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { return $cmd.Source }
    $candidates = @()
    $winget = if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages' } else { $null }
    if ($winget -and (Test-Path -LiteralPath $winget -PathType Container)) {
        $candidates += @(Get-ChildItem -LiteralPath $winget -Directory -Force -Filter 'Gyan.FFmpeg*' -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
    }
    if ($RepoRoot) {
        $tools = Join-Path $RepoRoot 'cache\tools\ffmpeg'
        if (Test-Path -LiteralPath $tools -PathType Container) { $candidates += $tools }
    }
    foreach ($c in $candidates) {
        $exe = Get-ChildItem -LiteralPath $c -Recurse -Filter 'ffmpeg.exe' -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($exe) { return $exe.FullName }
    }
    return $null
}

function ConvertTo-MusicCommandLineArg {
    # One argument quoted for a Windows command line (CommandLineToArgvW rules).
    param([string]$Arg)
    if ($Arg.Length -gt 0 -and $Arg -notmatch '[\s"]') { return $Arg }
    $sb = New-Object Text.StringBuilder
    [void]$sb.Append('"')
    $slashes = 0
    foreach ($ch in $Arg.ToCharArray()) {
        if ($ch -eq '\') { $slashes++; continue }
        if ($ch -eq '"') { [void]$sb.Append([char]92, 2 * $slashes + 1); [void]$sb.Append('"') }
        else { if ($slashes) { [void]$sb.Append([char]92, $slashes) }; [void]$sb.Append($ch) }
        $slashes = 0
    }
    if ($slashes) { [void]$sb.Append([char]92, 2 * $slashes) }
    [void]$sb.Append('"')
    return $sb.ToString()
}

function Invoke-MusicFfmpeg {
    # Runs ffmpeg (mocked in the tests) with a time limit: past -TimeoutSec the process is killed and ExitCode = -1.
    # Returns @{ ExitCode; Output (stdout + stderr lines); TimedOut }.
    param([Parameter(Mandatory = $true)][string]$Ffmpeg, [Parameter(Mandatory = $true)][AllowEmptyString()][string[]]$Arguments, [int]$TimeoutSec = 600)
    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = $Ffmpeg
    $psi.Arguments = (@($Arguments | ForEach-Object { ConvertTo-MusicCommandLineArg ([string]$_) }) -join ' ')
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.RedirectStandardInput = $true
    $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [Text.Encoding]::UTF8
    $p = [Diagnostics.Process]::Start($psi)
    try {
        $p.StandardInput.Close()
        $outTask = $p.StandardOutput.ReadToEndAsync()
        $errTask = $p.StandardError.ReadToEndAsync()
        $timedOut = -not $p.WaitForExit($TimeoutSec * 1000)
        if ($timedOut) {
            try { $p.Kill() } catch { }
            [void]$p.WaitForExit(10000)
        }
        else { $p.WaitForExit() }   # flushes the redirected streams
        $text = ''
        if ($outTask.Wait(10000)) { $text += $outTask.Result }
        if ($errTask.Wait(10000)) { $text += "`n" + $errTask.Result }
        $code = if ($timedOut) { -1 } else { $p.ExitCode }
        $lines = @($text -split "`r?`n" | Where-Object { $_ -ne '' })
        if ($timedOut) { $lines += "ffmpeg stopped after $TimeoutSec s (time limit)" }
        return [pscustomobject]@{ ExitCode = $code; Output = $lines; TimedOut = $timedOut }
    }
    finally { $p.Dispose() }
}

function Convert-MusicToOgg {
    # Two-pass EBU R128 loudness normalisation to -16 LUFS (true peak -1.5 dBTP, linear gain when possible) and
    # Vorbis encoding (q5, 44.1 kHz stereo, audio stream only: cover art is dropped). Writes <Destination> through
    # a temporary "<name>.tmp.ogg" renamed at the end; the source is only read. Throws on an ffmpeg error.
    # -Sound 'ambiance' / 'salle' (free tracks of the pack): softer highs first, then -22 / -27 LUFS (see
    # $script:MusicSounds). -PadSeconds: silence appended after the music (see $script:MusicPadCategories).
    param([Parameter(Mandatory = $true)][string]$Ffmpeg, [Parameter(Mandatory = $true)][string]$Source, [Parameter(Mandatory = $true)][string]$Destination,
        [ValidateSet('standard', 'ambiance', 'salle')][string]$Sound = 'standard', [ValidateRange(0, 600)][int]$PadSeconds = 0)
    $target = [string]$script:MusicSounds[$Sound].Target
    $pre = [string]$script:MusicSounds[$Sound].Pre
    if ($pre) { $pre += ',' }   # the tone filter runs before the measure and before the gain: the final level is exact
    $m = Invoke-MusicFfmpeg -Ffmpeg $Ffmpeg -Arguments @('-hide_banner', '-nostdin', '-i', $Source, '-map', '0:a:0', '-af', "$($pre)loudnorm=$($target):print_format=json", '-f', 'null', '-')
    if ($m.ExitCode -ne 0) { throw "ffmpeg could not read '$Source': $((@($m.Output) | Select-Object -Last 3) -join ' ')" }
    $text = (@($m.Output) -join "`n")
    $filter = "$($pre)loudnorm=$target"
    $start = $text.LastIndexOf('{'); $end = $text.LastIndexOf('}')
    if ($start -ge 0 -and $end -gt $start) {
        try {
            $j = ConvertFrom-Json $text.Substring($start, $end - $start + 1)
            $vals = @($j.input_i, $j.input_tp, $j.input_lra, $j.input_thresh, $j.target_offset)
            if (-not ($vals | Where-Object { "$_" -notmatch '^-?\d+(\.\d+)?$' })) {
                $filter = "$($pre)loudnorm=$($target):measured_I=$($j.input_i):measured_TP=$($j.input_tp):measured_LRA=$($j.input_lra):measured_thresh=$($j.input_thresh):offset=$($j.target_offset):linear=true"
            }
        }
        catch { }   # unreadable measure (silent file...): one-pass normalisation
    }
    if ($PadSeconds -gt 0) { $filter += ",apad=pad_dur=$PadSeconds" }   # after the gain: the measure never sees it
    $dir = [IO.Path]::GetDirectoryName($Destination)
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $tmp = Join-Path $dir ([IO.Path]::GetFileNameWithoutExtension($Destination) + '.tmp.ogg')
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force }
    $r = Invoke-MusicFfmpeg -Ffmpeg $Ffmpeg -Arguments @('-hide_banner', '-nostdin', '-y', '-i', $Source, '-map', '0:a:0', '-af', $filter,
        '-ar', '44100', '-ac', '2', '-c:a', 'libvorbis', '-q:a', '5', $tmp)
    if ($r.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $tmp -PathType Leaf)) {
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
        throw "ffmpeg could not convert '$Source': $((@($r.Output) | Select-Object -Last 3) -join ' ')"
    }
    Move-Item -LiteralPath $tmp -Destination $Destination -Force
}

function New-AmbienceConfig {
    # Text of ambience_music\music_config.txt (ASCII, LF). $Files = ordered dictionary category -> paths relative to
    # ambience_music\music (forward slashes); $Sources = category -> 'user'|'free' (comments only).
    # A category without any file is left out of the schedule (the next rule applies); "jour" without file = silence.
    # Schedule (first matching rule wins; priorities: boss 2 > combat 1 > the rest 0, so a fight pauses the
    # exploration music and it resumes afterwards):
    #   menu    : title screen, joining, disconnected, credits
    #   boss-<key> (only when mes-musiques\boss-<key> holds files; one rule per boss, in the order of $MusicBosses):
    #             a boss bar whose name contains that boss's Bar text is shown, OR that boss's entity type fights /
    #             targets the player (priority 2, like the generic boss rule it stands above)
    #   boss    : a boss bar is shown (the shonen:boss/... bars of the Grands Ennemis at 48 blocks, dragon, wither,
    #             Gateways portals...) except a raid bar, OR one of the 12 boss types fights / targets the player
    #   combat  : fighting hostile mobs (hit or got hit, 15 s timeout + 10 s grace in our client config), warden nearby,
    #             raid, OR the hidden effect shonencore:en_combat (given by the server while a monster nearby targets
    #             the player, combat_musique.js: the client alone cannot see who a monster targets)
    #   taverne : the hidden effect shonencore:taverne (given by the server inside the room, taverne_musique.js)
    #   donjon  : cave (cave score >= 0.45), the Nether, a When Dungeons Arise structure (server support only)
    #   village : 3+ villagers nearby, or a Japanese village / Edo structure (structures: server support only)
    #   mer     : in a boat or in an ocean biome
    #   nuit    : dusk and night
    #   jour    : everything else
    param([Parameter(Mandatory = $true)]$Files, $Sources, [string[]]$BossTypes = $script:MusicBossTypes)
    $nl = "`n"
    $sb = New-Object Text.StringBuilder
    [void]$sb.Append('// Shonen Eveil - musique dynamique (mod Ambience Mini).' + $nl)
    [void]$sb.Append('// FICHIER GENERE par scripts/build-music.ps1 a chaque synchronisation : ne pas le modifier ici, il serait ecrase.' + $nl)
    [void]$sb.Append('// Tes propres musiques : dossier "mes-musiques" de l''instance (voir mes-musiques/LISEZ-MOI.txt).' + $nl)
    [void]$sb.Append('// Ordre des regles = priorite : boss-<cle> (tes musiques par boss) > boss > combat > taverne > donjon > village > mer > nuit > jour.' + $nl + $nl)
    $has = @{}
    $bossVides = New-Object 'Collections.Generic.List[string]'
    foreach ($c in $script:MusicUserCategories) {
        $list = @($Files[$c] | Where-Object { $_ })
        foreach ($p in $list) {
            if ($p -notmatch '^[A-Za-z0-9_./-]+$' -or $p -match '\.\.') { throw "Unsafe music path for the config: '$p'" }
        }
        $has[$c] = $list.Count -gt 0
        $perBoss = $script:MusicCategories -cnotcontains $c
        if ($perBoss -and -not $has[$c]) { $bossVides.Add($c); continue }   # empty boss-<key> folder: no playlist, no rule
        $src = if ($Sources -and $Sources[$c]) { [string]$Sources[$c] } elseif ($perBoss) { 'user' } else { 'free' }
        $label = if ($src -eq 'user') { 'fichiers de mes-musiques/' + $c } else { 'morceaux libres (music/tracks.json)' }
        [void]$sb.Append("// $c : $($list.Count) fichier(s), $label" + $nl)
        $quoted = @($list | ForEach-Object { '"' + $_ + '"' })
        [void]$sb.Append("playlist $(Get-MusicPlaylistName $c) = [ " + ($quoted -join ', ') + ' ];' + $nl)
    }
    if ($bossVides.Count -gt 0) {
        [void]$sb.Append('// sans fichier (regle boss generale) : ' + ($bossVides -join ', ') + $nl)
    }
    $bossCond = (@($BossTypes | ForEach-Object { 'c.type_id == "' + $_ + '"' }) -join ' || ')
    $rules = @()
    foreach ($k in $script:MusicBosses.Keys) {
        $b = $script:MusicBosses[$k]
        if ([string]$b.Bar -notmatch '^[A-Za-z0-9 _.-]+$') { throw "Unsafe boss entry for the config: '$k'" }
        foreach ($t in @($b.Types)) { if ([string]$t -notmatch '^[a-z0-9_.-]+:[a-z0-9_./-]+$') { throw "Unsafe boss entry for the config: '$k'" } }
        $typeCond = (@($b.Types | ForEach-Object { 'c.type_id == "' + $_ + '"' }) -join ' || ')
        $rules += @{ c = "boss-$k"; w = "any b in `$bosses has b ~~ `"$($b.Bar)`" end || any c in `$combatants has $typeCond end"; p = ' priority 2' }
    }
    $rules += @(
        @{ c = 'boss'; w = '@boss_fight && any b in $bosses has !(b ~~ "raid") end'; p = ' priority 2' },
        @{ c = 'boss'; w = "any c in `$combatants has $bossCond end"; p = ' priority 2' },
        @{ c = 'combat'; w = '@in_combat || @warden_nearby || @boss_fight || any e in $effects has e == "shonencore:en_combat" end'; p = ' priority 1' },
        @{ c = 'taverne'; w = 'any e in $effects has e == "shonencore:taverne" end'; p = '' },
        @{ c = 'donjon'; w = '$dimension == "minecraft:the_nether" || any s in $structures has s ~~ "dungeons_arise:" end || $cave_score >= 0.45'; p = '' },
        @{ c = 'village'; w = '@village || any s in $structures has s ~~ "qrafty:" || s ~~ "edo_japan:" || s ~~ "village" end'; p = '' },
        @{ c = 'mer'; w = '@boat || $biome ~~ "ocean"'; p = '' },
        @{ c = 'nuit'; w = '@night || @dusk'; p = '' }
    )
    [void]$sb.Append($nl + 'begin' + $nl)
    if ($has['menu']) { [void]$sb.Append('    when ( @main_menu || @joining || @disconnected || @credits ) play menu;' + $nl) }
    [void]$sb.Append('    when ( @in_game ) begin' + $nl)
    foreach ($r in $rules) {
        if ($has[$r.c]) { [void]$sb.Append('        when ( ' + $r.w + ' ) play ' + (Get-MusicPlaylistName $r.c) + $r.p + ';' + $nl) }
    }
    if ($has['jour']) { [void]$sb.Append('        play jour;' + $nl) } else { [void]$sb.Append('        play [ ];' + $nl) }
    [void]$sb.Append('    end' + $nl + 'end' + $nl)
    return $sb.ToString()
}
