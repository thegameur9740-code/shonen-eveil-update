# skins-lib.ps1 - the "mes-skins" table (P3-3): which boss texture a player's own PNG replaces. Dot-sourced by
# sync-skins.ps1 and its tests. Keep this file ASCII-only (PS 5.1 reads BOM-less scripts as ANSI).
#
# One entry per boss key (the key of kubejs/server_scripts/grands_ennemis.js): <instance>\mes-skins\<key>.png replaces
# Texture (a path inside the resource pack, = the texture the base model's renderer uses, checked with javap) for this
# player only. Width / Height: size of the default texture (the replacement must keep the same aspect ratio; any
# size from Width/4 to 4096 wide). Jar: file name pattern of the mod jar (in the client cache) holding the default
# texture, copied once into mes-skins\modeles\<key>.png as a starting point.
# A boss built later on a GENERIC body (a model shared with other mobs) needs its own texture path first (otherwise
# the skin would also change every other mob of that model): add its entry only once it has one.
$script:SkinBosses = [ordered]@{
    # ninshuorigins:itachi: ItachiModel -> ninshuorigins:textures/entity/npc/itachi/texture.png (512 x 512)
    itachi = @{ Texture = 'assets/ninshuorigins/textures/entity/npc/itachi/texture.png'; Width = 512; Height = 512; Jar = 'ninshuorigins-*.jar' }
}
# Player bodies of Shonen Core 1.11.0 (shonencore:corps_<key>, docs/plans/mha-plan-code.md task 1): a classic 64 x 64
# Minecraft skin. No default texture ships (the game draws Steve / Alex), except aizen_scelle (our neutral base skin,
# design/boss/aizen_scelle_skin_base.png) and the S+ finals ulquiorra / jiren of 08/11 (design/boss/<key>_skin_base.png,
# tools/examens/make_skins.py): Jar = '' (no model copied to modeles). The five Paths of Pain (09/11): skins of Admin.
foreach ($k in @('moonfish', 'stain', 'muscular', 'nomu_usj', 'overhaul', 'dabi', 'all_for_one', 'histoire_nomu', 'toga',
        'twice', 're_destro', 'gigantomachia', 'hood', 'shigaraki', 'mr_compress', 'haku', 'kisame', 'deidara', 'sasori',
        'konan', 'madara', 'kaguya', 'aizen_scelle', 'ulquiorra', 'jiren', 'maitre_mha', 'maitre_bleach', 'maitre_solo', 'comptoir',
        'pain_voie_asura', 'pain_voie_humains', 'pain_voie_animaux', 'pain_voie_preta', 'pain_voie_naraka')) {
    $script:SkinBosses[$k] = @{ Texture = "assets/shonencore/textures/entity/corps/$k.png"; Width = 64; Height = 64; Jar = '' }
}
$script:SkinPackName = 'Shonen Mes Skins'
$script:SkinPackFormat = 15   # Minecraft 1.20.1

# "mes-sons" (08/11, docs/plans/pain-shinra-tensei.md section 5): <instance>\mes-sons\<key>.<mp3|ogg|wav|flac|m4a|opus>
# replaces the pack's base sound Path (inside the same "Shonen Mes Skins" pack) for this player only, converted by
# ffmpeg to a normalised .ogg (44.1 kHz stereo). Impact: when the impact must fall, from the start of the file (the
# boss ability is timed on the base sound), told in the LISEZ-MOI. The base sounds ship in
# client\overrides\kubejs\assets\shonen\sounds\boss\ (originals, design\sons\*_defaut.ogg).
$script:SonsPerso = [ordered]@{
    pain_discours      = @{ Path = 'assets/shonen/sounds/boss/pain_discours.ogg'; Impact = '38,3 s'; Quoi = 'Pain, Grand Shinra Tensei (version longue, avec le discours)' }
    pain_shinra_tensei = @{ Path = 'assets/shonen/sounds/boss/pain_shinra_tensei.ogg'; Impact = '10,8 s'; Quoi = 'Pain, Grand Shinra Tensei (version courte)' }
}
$script:SonsExtensions = @('.mp3', '.ogg', '.wav', '.flac', '.m4a', '.opus')
