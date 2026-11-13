# Shonen Éveil - programme de mise à jour des collègues (Windows PowerShell 5.1, rien à installer).
# Lancé par "Mettre a jour Shonen Eveil.cmd" (double-clic), jeu fermé. Il vit DANS l'instance du pack.
#   1. télécharge index.json depuis l'adresse de base de shonen-update.json (fichiers bruts GitHub) ;
#   2. compare les sha256 avec ce qui est dans l'instance ;
#   3. télécharge seulement ce qui a changé (dossier temporaire), vérifie chaque sha256 AVANT de remplacer ;
#   4. remplace de façon sûre (fichier temporaire puis renommage), supprime les fichiers retirés du pack
#      (liste fermée : seulement des fichiers que le pack a lui-même installés) ;
#   5. ne touche JAMAIS à options.txt, servers.dat, aux touches, aux sauvegardes, aux captures, à mes-musiques,
#      mes-skins, mes-sons, aux musiques générées (ambience_music).
# Le programme n'exécute aucun fichier téléchargé. Il se met à jour lui-même : le nouveau fichier est posé à côté
# (shonen-update.ps1.new) et remplacé par le .cmd au lancement suivant.
# Relancer après une coupure reprend sans rien casser (rien n'est remplacé tant que tout n'est pas téléchargé et vérifié).
# Journal : shonen-update.log (à côté du .cmd). Le jeton d'accès éventuel n'est jamais affiché ni écrit.
# -InstanceDir, -ConfigFile, -GameProcessFile, -NoPause, -LockRetries, -LockWaitSeconds : réservés aux tests.
param(
    [string]$InstanceDir,
    [string]$ConfigFile,
    [string]$GameProcessFile,
    [switch]$NoPause,
    [int]$LockRetries = 4,
    [int]$LockWaitSeconds = 2
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

$script:AllowedRoots = @('mods', 'config', 'kubejs', 'patchouli_books', 'resourcepacks', 'shaderpacks', 'shonen-outils')
$script:AllowedRootFiles = @('CREDITS-MUSIQUE.md', 'Mettre a jour mes musiques et skins.bat')
# jamais touchés, même si l'index le demande (l'index entier est alors refusé)
$script:ProtectedPrefixes = @('resourcepacks/shonen mes skins/', 'shonen-outils/update-tmp/', 'config/shonen-eveil/', 'config/dragonminez/general-user.json')
$script:ProtectedFiles = @('shonen-outils/update-state.json', 'options.txt', 'servers.dat')
$script:ValidModes = @('strict', 'tracked', 'once')
$script:Token = $null
$script:BaseUrl = $null
$script:LogFile = $null
$script:SelfRel = 'shonen-outils/shonen-update.ps1'

function Write-Log([string]$Text, [string]$Color) {
    if ($Color) { Write-Host $Text -ForegroundColor $Color } else { Write-Host $Text }
    if ($script:LogFile) {
        try { Add-Content -LiteralPath $script:LogFile -Value ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + '  ' + $Text) -Encoding UTF8 } catch {}
    }
}

function Wait-Key {
    if ($NoPause) { return }
    Write-Host ''
    Write-Host 'Appuie sur une touche pour fermer cette fenêtre...'
    try { [void][Console]::ReadKey($true) } catch { try { [void](Read-Host) } catch {} }
}

function Find-InstanceGameProcess([string]$Dir, [string]$CommandLinesFile) {
    # même contrôle que scripts\client-game-running.ps1 : un java/javaw dont la ligne de commande contient le dossier
    $lines = @()
    if ($CommandLinesFile) { $lines = @([IO.File]::ReadAllLines([IO.Path]::GetFullPath($CommandLinesFile))) }
    else {
        try {
            $lines = @(Get-CimInstance Win32_Process -Filter "Name = 'java.exe' OR Name = 'javaw.exe'" |
                ForEach-Object { '{0}|{1}' -f $_.ProcessId, $_.CommandLine })
        } catch { $lines = @() }
    }
    $path = [IO.Path]::GetFullPath($Dir).TrimEnd('\', '/')
    $pattern = (($path -split '[\\/]') | ForEach-Object { [regex]::Escape($_) }) -join '[\\/]+'
    $rx = New-Object Text.RegularExpressions.Regex(($pattern + '(?=["\\/\s]|$)'), 'IgnoreCase')
    foreach ($l in $lines) { if ($l -and $rx.IsMatch($l)) { return $l } }
    return $null
}

function Test-LoopbackHost([string]$HostName) {
    return ($HostName -eq '127.0.0.1' -or $HostName -eq 'localhost' -or $HostName -eq '[::1]' -or $HostName -eq '::1')
}

function Test-AllowedUrl([string]$Url) {
    # https partout ; http seulement vers la machine locale (tests)
    $u = $null
    if (-not [Uri]::TryCreate($Url, [UriKind]::Absolute, [ref]$u)) { return $false }
    if ($u.Scheme -eq 'https') { return $true }
    if ($u.Scheme -eq 'http' -and (Test-LoopbackHost $u.Host)) { return $true }
    return $false
}

function Get-PathProblem([string]$Rel) {
    # $Rel : chemin relatif de l'index, séparateur '/'. Retourne un texte d'erreur ou $null.
    if ([string]::IsNullOrEmpty($Rel)) { return 'chemin vide' }
    if ($Rel.Contains('\')) { return "séparateur '\' interdit" }
    if ($Rel.StartsWith('/') -or $Rel.Contains(':')) { return 'chemin absolu interdit' }
    $parts = $Rel.Split('/')
    foreach ($p in $parts) {
        if ($p -eq '' -or $p -eq '.' -or $p -eq '..') { return "segment interdit ('$p')" }
        if ($p.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0) { return 'caractère interdit' }
        if ($p.EndsWith('.') -or $p.EndsWith(' ')) { return 'nom se terminant par un point ou une espace' }
        if ($p -match '^(?i:con|prn|aux|nul|com[1-9]|lpt[1-9])(\..*)?$') { return 'nom réservé de Windows' }
    }
    if ($parts.Count -eq 1) {
        if ($script:AllowedRootFiles -cnotcontains $Rel) { return 'fichier à la racine non prévu' }
    }
    elseif ($script:AllowedRoots -cnotcontains $parts[0]) { return "dossier '$($parts[0])' non prévu" }
    $low = $Rel.ToLowerInvariant()
    if ($script:ProtectedFiles -contains $low) { return 'fichier protégé' }
    foreach ($pre in $script:ProtectedPrefixes) { if ($low.StartsWith($pre) -or $low -eq $pre.TrimEnd('/')) { return 'fichier protégé' } }
    if ($parts[0] -ceq 'mods' -and (-not $Rel.EndsWith('.jar', [StringComparison]::OrdinalIgnoreCase) -or $parts.Count -ne 2)) { return 'seuls les .jar vont dans mods' }
    return $null
}

function Test-Reparse([string]$Path) {
    return [bool]((Get-Item -LiteralPath $Path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)
}

function Resolve-InstancePath([string]$Inst, [string]$Rel) {
    # chemin complet dans l'instance ; refuse tout ce qui sort de l'instance ou passe par un lien (junction/symlink)
    $full = [IO.Path]::GetFullPath((Join-Path $Inst ($Rel -replace '/', '\')))
    if (-not $full.StartsWith($Inst.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw "chemin hors de l'instance : $Rel" }
    $cur = $Inst.TrimEnd('\')
    $parts = $Rel.Split('/')
    for ($i = 0; $i -lt $parts.Count; $i++) {
        $cur = Join-Path $cur $parts[$i]
        if (Test-Path -LiteralPath $cur) {
            if ($i -lt $parts.Count - 1 -and -not (Test-Path -LiteralPath $cur -PathType Container)) { throw "'$cur' est un fichier : un dossier est attendu pour $Rel" }
            if ($i -eq $parts.Count - 1 -and (Test-Path -LiteralPath $cur -PathType Container)) { throw "'$cur' est un dossier : un fichier est attendu pour $Rel" }
            if (Test-Reparse $cur) { throw "'$cur' est un raccourci de dossier (junction/symlink) : refusé" }
        }
    }
    return $full
}

function Get-Sha256([string]$Path) { return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant() }

function Get-UrlOrigin([string]$Url) {
    $u = [Uri]$Url
    return ($u.Scheme + '://' + $u.Authority).ToLowerInvariant()
}

function Invoke-Download([string]$Url, [string]$OutFile, [bool]$WithAuth) {
    # GET vers un fichier. Redirections suivies à la main : le jeton n'est envoyé qu'à l'adresse de base, jamais ailleurs.
    $cur = $Url
    for ($hop = 0; $hop -lt 6; $hop++) {
        if (-not (Test-AllowedUrl $cur)) { throw "adresse refusée (https seulement) : $cur" }
        $req = [Net.HttpWebRequest]::Create($cur)
        $req.UserAgent = 'ShonenEveilUpdate/1'
        $req.AllowAutoRedirect = $false
        $req.Timeout = 30000
        $req.ReadWriteTimeout = 60000
        if ($WithAuth -and $script:Token -and ((Get-UrlOrigin $cur) -eq (Get-UrlOrigin $script:BaseUrl))) {
            $req.Headers.Add('Authorization', 'token ' + $script:Token)
        }
        $resp = $null
        try { $resp = $req.GetResponse() }
        catch [Net.WebException] { $resp = $_.Exception.Response; if (-not $resp) { throw } }
        try {
            $code = [int]$resp.StatusCode
            if ($code -in 301, 302, 303, 307, 308) {
                $loc = $resp.Headers['Location']
                if (-not $loc) { throw "redirection sans adresse (HTTP $code)" }
                $cur = (New-Object Uri((New-Object Uri $cur), $loc)).AbsoluteUri
                continue
            }
            if ($code -ne 200) { throw "HTTP $code" }
            $in = $resp.GetResponseStream()
            $out = [IO.File]::Create($OutFile)
            try { $in.CopyTo($out) } finally { $out.Dispose(); $in.Dispose() }
            return
        }
        finally { $resp.Close() }
    }
    throw 'trop de redirections'
}

function Read-JsonFile([string]$Path) {
    return ConvertFrom-Json ([IO.File]::ReadAllText($Path, (New-Object Text.UTF8Encoding($false))))
}

function ConvertTo-StringMap($Obj) {
    $h = @{}
    if ($null -ne $Obj) { foreach ($p in $Obj.PSObject.Properties) { $h[[string]$p.Name] = [string]$p.Value } }
    return $h
}

$exitCode = 0
$state = @{ version = ''; files = @{}; once = @{} }
$stateFile = $null
$stateDirty = $false
$instance = $null

try {
    # ---------- 0. l'instance ----------
    if (-not $InstanceDir) { $InstanceDir = Join-Path $PSScriptRoot '..' }
    $instance = [IO.Path]::GetFullPath($InstanceDir).TrimEnd('\')
    $isInstance = (Test-Path -LiteralPath (Join-Path $instance 'mods') -PathType Container) -and
        ((Test-Path -LiteralPath (Join-Path $instance 'config\shonen-eveil\version-pack.txt')) -or (Test-Path -LiteralPath (Join-Path $instance 'shonen-outils\version.txt')))
    if (-not $isInstance) {
        throw "Ce programme doit rester dans le dossier du pack Shonen Éveil (celui qui contient 'mods' et 'shonen-outils'). Dossier vu : $instance"
    }
    if (Test-Reparse $instance) { throw "Le dossier du pack est un raccourci (junction/symlink) : refusé." }
    $script:LogFile = Join-Path $instance 'shonen-update.log'
    try {
        if ((Test-Path -LiteralPath $script:LogFile) -and (Get-Item -LiteralPath $script:LogFile).Length -gt 1MB) { Remove-Item -LiteralPath $script:LogFile -Force }
    } catch {}
    Write-Log 'Shonen Éveil - mise à jour du pack'
    Write-Log ("Dossier : " + $instance)

    # ---------- 1. réglages ----------
    if (-not $ConfigFile) { $ConfigFile = Join-Path $instance 'shonen-update.json' }
    if (-not (Test-Path -LiteralPath $ConfigFile -PathType Leaf)) { throw "Fichier de réglages introuvable : $ConfigFile" }
    $cfg = Read-JsonFile $ConfigFile
    $base = [string]$cfg.baseUrl
    if (-not $base) { throw "shonen-update.json : 'baseUrl' manque." }
    if (-not $base.EndsWith('/')) { $base += '/' }
    if (-not (Test-AllowedUrl $base)) { throw "shonen-update.json : 'baseUrl' doit commencer par https:// ($base)" }
    $script:BaseUrl = $base
    $tokenFile = $null
    if ($cfg.PSObject.Properties['tokenFile'] -and $cfg.tokenFile) { $tokenFile = [string]$cfg.tokenFile }
    if ($tokenFile) {
        $tp = [IO.Path]::GetFullPath((Join-Path $instance $tokenFile))
        if (-not $tp.StartsWith($instance + '\', [StringComparison]::OrdinalIgnoreCase)) { throw "shonen-update.json : 'tokenFile' doit rester dans le dossier du pack." }
        if (Test-Path -LiteralPath $tp -PathType Leaf) {
            $line = @([IO.File]::ReadAllLines($tp) | Where-Object { $_.Trim() })
            if ($line.Count -gt 0) { $script:Token = $line[0].Trim() }
        }
    }

    # ---------- 2. le jeu doit être fermé ----------
    $game = Find-InstanceGameProcess $instance $GameProcessFile
    if ($game) { throw "Minecraft est ouvert sur ce pack (processus $(($game -split '\|', 2)[0])) : ferme le jeu, puis relance. Rien n'a été modifié." }

    # ---------- 3. l'index ----------
    $stateFile = Join-Path $instance 'shonen-outils\update-state.json'
    if (Test-Path -LiteralPath $stateFile -PathType Leaf) {
        try {
            $sj = Read-JsonFile $stateFile
            $state.version = [string]$sj.version
            $state.files = ConvertTo-StringMap $sj.files
            $state.once = ConvertTo-StringMap $sj.once
        } catch { Write-Log 'Le fichier d''état est illisible : on repart de zéro (rien n''est supprimé dans ce cas).' }
    }
    $tmpDir = Join-Path $instance 'shonen-outils\update-tmp'
    if (-not (Test-Path -LiteralPath $tmpDir)) { New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null }
    if (Test-Reparse $tmpDir) { throw "$tmpDir est un raccourci : refusé." }
    Write-Log 'Je regarde ce qui a changé...'
    $indexTmp = Join-Path $tmpDir 'index.json.part'
    if (Test-Path -LiteralPath $indexTmp) { Remove-Item -LiteralPath $indexTmp -Force }
    try { Invoke-Download ($base + 'index.json') $indexTmp $true }
    catch { throw "Impossible de lire la liste des mises à jour ($base) : $($_.Exception.Message). Vérifie ta connexion Internet." }
    $index = Read-JsonFile $indexTmp
    Remove-Item -LiteralPath $indexTmp -Force
    if ([int]$index.format -ne 1) { throw "Liste de mise à jour d'un format inconnu ($($index.format)) : le programme est peut-être trop ancien, demande à Admin." }
    $packVersion = [string]$index.version

    # ---------- 4. contrôle de l'index (tout est refusé si une seule ligne est douteuse) ----------
    $entries = @()
    $seen = @{}
    foreach ($e in @($index.files)) {
        $rel = [string]$e.path
        $pb = Get-PathProblem $rel
        if ($pb) { throw "Liste refusée : chemin '$rel' ($pb)." }
        if ($seen.ContainsKey($rel.ToLowerInvariant())) { throw "Liste refusée : '$rel' est là deux fois." }
        $seen[$rel.ToLowerInvariant()] = $true
        if ([string]$e.sha256 -notmatch '^[0-9a-fA-F]{64}$') { throw "Liste refusée : sha256 invalide pour '$rel'." }
        $mode = [string]$e.mode
        if ($script:ValidModes -cnotcontains $mode) { throw "Liste refusée : mode '$mode' inconnu pour '$rel'." }
        $src = [string]$e.source
        $urls = @()
        if ($src -eq 'url') {
            $urls = @($e.urls | ForEach-Object { [string]$_ })
            if ($urls.Count -eq 0) { throw "Liste refusée : aucune adresse pour '$rel'." }
            foreach ($u in $urls) { if (-not (Test-AllowedUrl $u)) { throw "Liste refusée : adresse non autorisée pour '$rel'." } }
        }
        elseif ($src -ne 'repo') { throw "Liste refusée : source '$src' inconnue pour '$rel'." }
        $entries += [pscustomobject]@{ Rel = $rel; Sha = ([string]$e.sha256).ToLowerInvariant(); Size = [int64]$e.size; Mode = $mode; Source = $src; Urls = $urls
            Dst = (Resolve-InstancePath $instance $rel); Self = ($rel -ceq $script:SelfRel) }
    }
    $removes = @()
    foreach ($r in @($index.remove)) {
        if ($null -eq $r) { continue }
        $rel = [string]$r.path
        $pb = Get-PathProblem $rel
        if ($pb) { throw "Liste refusée : chemin à supprimer '$rel' ($pb)." }
        if ([string]$r.sha256 -notmatch '^[0-9a-fA-F]{64}$') { throw "Liste refusée : sha256 invalide pour la suppression de '$rel'." }
        if ($seen.ContainsKey($rel.ToLowerInvariant())) { continue }   # toujours dans le pack : jamais supprimé
        $removes += [pscustomobject]@{ Rel = $rel; Sha = ([string]$r.sha256).ToLowerInvariant(); Dst = (Resolve-InstancePath $instance $rel) }
    }

    # ---------- 5. le plan ----------
    $toGet = New-Object Collections.Generic.List[object]
    $onceMarks = @{}
    $kept = 0; $same = 0
    foreach ($e in $entries) {
        $exists = Test-Path -LiteralPath $e.Dst -PathType Leaf
        if ($e.Self) { $exists = Test-Path -LiteralPath $e.Dst -PathType Leaf }
        $localSha = $null
        if ($exists) {
            $len = (Get-Item -LiteralPath $e.Dst -Force).Length
            if ($len -eq $e.Size) { $localSha = Get-Sha256 $e.Dst }
            else { $localSha = '' }
        }
        $isEqual = ($exists -and $localSha -eq $e.Sha)
        $need = $false
        if ($e.Mode -eq 'strict') { $need = -not $isEqual }
        elseif ($e.Mode -eq 'tracked') {
            if ($isEqual) { $need = $false }
            elseif (-not $exists) { $need = $true }
            elseif ($state.files.ContainsKey($e.Rel) -and $state.files[$e.Rel] -eq $e.Sha) { $need = $false; $kept++ }   # réglé par le joueur ou par le mod : gardé
            else { $need = $true }
        }
        else {
            # once : appliqué une seule fois par contenu publié ; ce que le joueur a changé ensuite est gardé
            if ($state.once.ContainsKey($e.Rel) -and $state.once[$e.Rel] -eq $e.Sha) { $need = $false; $kept++ }
            elseif ($isEqual) { $need = $false; $onceMarks[$e.Rel] = $e.Sha }
            elseif ($exists -and -not $state.once.ContainsKey($e.Rel)) { $need = $false; $onceMarks[$e.Rel] = $e.Sha; $kept++ }   # fichier déjà là, d'avant le programme : gardé
            else { $need = $true }
        }
        if ($need) { $toGet.Add($e) } else { $same++ }
    }
    # le programme lui-même : s'il est déjà prêt dans .new, rien à télécharger
    $selfNew = Join-Path $instance 'shonen-outils\shonen-update.ps1.new'
    foreach ($e in $toGet.ToArray()) {
        if ($e.Self -and (Test-Path -LiteralPath $selfNew -PathType Leaf) -and (Get-Sha256 $selfNew) -eq $e.Sha) { [void]$toGet.Remove($e) }
    }
    $selfEntry = @($entries | Where-Object { $_.Self }) | Select-Object -First 1
    if ($selfEntry -and (Test-Path -LiteralPath $selfNew) -and (Test-Path -LiteralPath $selfEntry.Dst) -and (Get-Sha256 $selfEntry.Dst) -eq $selfEntry.Sha) { Remove-Item -LiteralPath $selfNew -Force -ErrorAction SilentlyContinue }

    $toRemove = @()
    foreach ($r in $removes) {
        if (-not (Test-Path -LiteralPath $r.Dst -PathType Leaf)) { continue }
        $inState = $state.files.ContainsKey($r.Rel)
        if ($inState -or (Get-Sha256 $r.Dst) -eq $r.Sha) { $toRemove += $r }   # liste fermée : installé par le pack avant
    }

    $todo = $toGet.Count + $toRemove.Count
    Write-Log ("Version installée : " + $(if ($state.version) { $state.version } else { 'inconnue' }) + " ; version publiée : " + $packVersion)
    if ($todo -eq 0) {
        foreach ($k in $onceMarks.Keys) { $state.once[$k] = $onceMarks[$k]; $stateDirty = $true }
        foreach ($e in $entries) { if ($e.Mode -ne 'once' -and -not $e.Self) { if (-not ($state.files.ContainsKey($e.Rel) -and $state.files[$e.Rel] -eq $e.Sha)) { $state.files[$e.Rel] = $e.Sha; $stateDirty = $true } } }
        $state.version = $packVersion; $stateDirty = $true
        Write-Log ("À jour : version " + $packVersion) 'Green'
    }
    else {
        Write-Log ("$($toGet.Count) fichier(s) à mettre à jour, $($toRemove.Count) à retirer ($same déjà à jour, $kept gardé(s) comme tu les as réglés).")

        # ---------- 6. téléchargement (rien n'est remplacé avant que tout soit vérifié) ----------
        $byHash = @{}
        foreach ($e in $toGet) { if (-not $byHash.ContainsKey($e.Sha)) { $byHash[$e.Sha] = $e } }
        $n = 0; $total = $byHash.Count
        foreach ($sha in @($byHash.Keys)) {
            $e = $byHash[$sha]
            $n++
            $dl = Join-Path $tmpDir ($sha + '.dl')
            if ((Test-Path -LiteralPath $dl) -and (Get-Sha256 $dl) -eq $sha) { continue }   # déjà téléchargé (reprise)
            if ($total -le 40 -or ($n % 25) -eq 0 -or $n -eq 1) { Write-Log ("Téléchargement $n / $total : " + $e.Rel) }
            $part = Join-Path $tmpDir ($sha + '.part')
            $sources = @()
            if ($e.Source -eq 'repo') {
                $esc = (($e.Rel.Split('/') | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/')
                $sources += ($base + 'files/' + $esc)
            }
            else { $sources = @($e.Urls) }
            $ok = $false; $lastErr = ''
            foreach ($u in $sources) {
                try {
                    if (Test-Path -LiteralPath $part) { Remove-Item -LiteralPath $part -Force }
                    Invoke-Download $u $part ($e.Source -eq 'repo')
                    if ((Get-Sha256 $part) -ne $sha) { $lastErr = 'empreinte sha256 différente (fichier corrompu ou modifié)'; Remove-Item -LiteralPath $part -Force; continue }
                    Move-Item -LiteralPath $part -Destination $dl -Force
                    $ok = $true; break
                }
                catch { $lastErr = $_.Exception.Message }
            }
            if (-not $ok) { throw "Téléchargement impossible : $($e.Rel) ($lastErr). Rien n'a été remplacé ; relance plus tard." }
        }

        # ---------- 7. remplacement ----------
        $left = @{}
        foreach ($e in $toGet) { if ($left.ContainsKey($e.Sha)) { $left[$e.Sha]++ } else { $left[$e.Sha] = 1 } }
        $done = 0
        foreach ($e in $toGet) {
            $dl = Join-Path $tmpDir ($e.Sha + '.dl')
            $target = $e.Dst
            if ($e.Self) { $target = $selfNew }
            $dir = [IO.Path]::GetDirectoryName($target)
            if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
            $src = $dl
            if ($left[$e.Sha] -gt 1) {
                $src = Join-Path $tmpDir ('use-' + [guid]::NewGuid().ToString('N') + '.tmp')
                Copy-Item -LiteralPath $dl -Destination $src
            }
            $left[$e.Sha]--
            $placed = $false; $lastErr = ''
            for ($try = 1; $try -le [Math]::Max(1, $LockRetries); $try++) {
                try {
                    if (Test-Path -LiteralPath $target -PathType Leaf) { [IO.File]::Replace($src, $target, [NullString]::Value) }
                    else { [IO.File]::Move($src, $target) }
                    $placed = $true; break
                }
                catch [IO.IOException] { $lastErr = $_.Exception.Message; if ($try -lt $LockRetries) { Start-Sleep -Seconds $LockWaitSeconds } }
                catch [UnauthorizedAccessException] { $lastErr = $_.Exception.Message; if ($try -lt $LockRetries) { Start-Sleep -Seconds $LockWaitSeconds } }
            }
            if (-not $placed) {
                if ($src -ne $dl -and (Test-Path -LiteralPath $src)) { Remove-Item -LiteralPath $src -Force -ErrorAction SilentlyContinue }
                throw "Le fichier '$($e.Rel)' est utilisé par un autre programme (Minecraft, CurseForge ou un antivirus ?) et n'a pas pu être remplacé. Ferme-les puis relance ce programme : il reprend où il s'était arrêté."
            }
            if ($e.Mode -eq 'once') { $state.once[$e.Rel] = $e.Sha } elseif (-not $e.Self) { $state.files[$e.Rel] = $e.Sha }
            $stateDirty = $true
            $done++
            if ($e.Self) { Write-Log 'Le programme de mise à jour a lui-même une nouvelle version : elle sera utilisée au prochain lancement.' }
        }
        # ---------- 8. suppression des fichiers retirés du pack ----------
        foreach ($r in $toRemove) {
            try { Remove-Item -LiteralPath $r.Dst -Force; Write-Log ("Retiré : " + $r.Rel); $state.files.Remove($r.Rel); $stateDirty = $true }
            catch { throw "Le fichier '$($r.Rel)' n'a pas pu être supprimé ($($_.Exception.Message)). Ferme le jeu et relance." }
        }
        foreach ($k in $onceMarks.Keys) { $state.once[$k] = $onceMarks[$k] }
        foreach ($e in $entries) { if ($e.Mode -ne 'once' -and -not $e.Self -and (Test-Path -LiteralPath $e.Dst -PathType Leaf)) { if ((Get-Item -LiteralPath $e.Dst -Force).Length -eq $e.Size) { if (-not ($state.files.ContainsKey($e.Rel) -and $state.files[$e.Rel] -eq $e.Sha) -and (Get-Sha256 $e.Dst) -eq $e.Sha) { $state.files[$e.Rel] = $e.Sha } } } }
        $state.version = $packVersion; $stateDirty = $true
        Get-ChildItem -LiteralPath $tmpDir -Force -ErrorAction SilentlyContinue | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
        Write-Log ("Terminé : $($toGet.Count) fichier(s) mis à jour, $($toRemove.Count) retiré(s). Version " + $packVersion + '.') 'Green'
    }
}
catch {
    $msg = $_.Exception.Message
    # le jeton ne doit jamais apparaître dans un message
    if ($script:Token) { $msg = $msg.Replace($script:Token, '***') }
    if ($script:LogFile) { Write-Log ('PROBLÈME : ' + $msg) 'Red' } else { Write-Host ('PROBLÈME : ' + $msg) -ForegroundColor Red }
    try { if ($script:LogFile) { Add-Content -LiteralPath $script:LogFile -Value ('   (détail technique : ' + ($_.ScriptStackTrace -replace '\s+',' ') + ')') -Encoding UTF8 } } catch {}
    $exitCode = 1
}
finally {
    if ($stateDirty -and $stateFile) {
        try {
            $o = [ordered]@{ version = $state.version; updated = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'); files = $state.files; once = $state.once }
            $tmpState = $stateFile + '.tmp'
            [IO.File]::WriteAllText($tmpState, ((ConvertTo-Json -InputObject $o -Depth 4) -replace "`r`n", "`n"), (New-Object Text.UTF8Encoding($false)))
            if (Test-Path -LiteralPath $stateFile) { [IO.File]::Replace($tmpState, $stateFile, [NullString]::Value) } else { [IO.File]::Move($tmpState, $stateFile) }
        } catch { Write-Host 'Attention : l''état de la mise à jour n''a pas pu être enregistré.' -ForegroundColor Yellow }
    }
}
Wait-Key
exit $exitCode
