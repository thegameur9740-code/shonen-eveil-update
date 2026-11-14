// priority: 50
// touches_auto.js - touches automatiques selon la voie (P2-5). Script client KubeJS (instance joueur).
// Rhino : var + while seulement, pas de let/const/fonctions fléchées/gabarits.
//
// Quand l'Éveil est accompli, le serveur envoie les univers de la voie (shonen_univers.js -> global.shonenUnivers,
// ordre Pouvoir > Arme > Race). Ce script calcule alors un PROFIL de touches sans conflit et l'écrit dans
// options.txt (KeyMapping.setKeyModifierAndCode + resetMapping + options.save) :
//   - actions PRINCIPALES : W R X C V, dans l'ordre d'importance des actions de l'univers (la 1re = « utiliser », la
//     2e = « choisir »...) ; 1er univers sans modificateur, 2e univers avec Ctrl (décision de Admin du 05/11 : tout
//     le 2e univers sur Ctrl) ;
//   - actions SECONDAIRES : F6 F7 F8 F9 F10 F12 ; 1er univers sans modificateur, 2e avec Ctrl
//     (Forge ne déclenche que la version avec modificateur quand il est tenu : pas de double action) ;
//   - actions LIÉES : même touche qu'une autre action du même univers + modificateur (ex. Alt + choisir) ; pour le 2e
//     univers, dont la touche de base a déjà Ctrl, le modificateur de la liée est gardé s'il est libre, sinon l'autre
//     (Maj ou Alt), sinon aucune touche (Forge ne prend qu'un modificateur par touche) ;
//   - actions FIXES (Bleach Début/Fin..., pavé numérique Solo, souris JoJo, flèches...) : leur touche habituelle ;
//     si deux univers du joueur la veulent, le second prend Ctrl, puis Maj, puis Alt + cette touche ;
//   - actions des univers que le joueur n'a PAS : sans touche (elles ne volent plus de touche), SAUF les actions
//     « garées » (TA_GAREES) : un mod les lit directement au clavier à chaque tick sans tester « aucune touche »
//     (InputConstants.isKeyDown(fenêtre, -1) -> erreur GLFW « Invalid key -1 » en boucle dans le journal) ; elles
//     vont sur une touche qu'aucun clavier n'a (F20 à F25, une différente par action) au lieu de « aucune » ;
//   - touches « pour tout le monde » du schéma (TA_COMMUNES) : leur touche du schéma ;
//   - touches vanilla et touches miroir JujutsuCraft / MinePiece : jamais touchées.
// Appliqué UNE fois par voie : marqueur config/shonen-eveil/touches-auto.json (uuid -> univers + version du profil).
// Même voie à la connexion suivante : le profil n'est pas réappliqué (les changements du joueur sont gardés), seule
// la GARDE passe (taGarde : univers absents sans touche, touches d'autres mods posées sur la voie remises).
// Voie changée : profil réappliqué. /touches auto : réapplique tout de suite ; /touches : liste les touches.
// La partie « calcul » (tables + taProfil) ne dépend pas de Minecraft : testée par scripts/tests/touches-auto.test.js
// (node) et décrite dans docs/touches.md (« Touches automatiques selon ta voie »).

// 2 : utility_menu de DragonMine Z garé sur F24 au lieu de « aucune » (fin de l'erreur GLFW « Invalid key -1 »)
// 3 : univers Naruto (Ninshu: Origins, P3-1) : ses 19 actions sans touche pour tout le monde
// 4 : (P4-C, « la mini-carte se met sur W et Naruto sur , ») les touches « pour tout le monde » du schéma
//     (TA_COMMUNES) font partie du profil, et une GARDE passe à chaque connexion (taGarde) : actions des univers
//     absents remises sans touche / garées, et toute autre touche de mod posée sur une touche de la voie libérée.
//     Cause : Minecraft efface d'options.txt les lignes d'un mod absent au moment où il enregistre (Ninshu ajouté
//     après coup) ; les marqueurs « déjà appliqué » empêchaient ensuite de les remettre : Ninshu et Xaero
//     revenaient à leurs touches d'origine (Ninshu : Permutation Z = W, Menu ninja M = « , » ; Xaero : agrandir
//     la mini-carte Z = W, carte du monde M = « , »).
// 5 : Éveil v2 (05/11) : 2 univers au plus (le 3e groupe et la banque Maj disparaissent), JoJo remplacé par My Hero
//     Academia (Quirks Unchained), Naruto devient jouable
// 6 : (Admin, 05/11 soir) tout le 2e univers sur Ctrl : Ctrl + W R X C V (plus H Y G B N) et Ctrl + F6 à F12
// 7 : (Admin, 10/11, combos de JJK au zanpakutō) Bleach sans JJK : W / R lancent et choisissent les attaques de JJK
//     (Attack, Knockback, Barrage) ; le shunpo passe sur G et le Shikai sur H, pour TOUT joueur Bleach (avec ou sans
//     JJK : toujours au même endroit). Voir TA_UNIVERS.bleach.touchesPrincipales / emprunts.
// 8 : (14/11, « toutes mes touches sont revenues à celles des mods ») AUCUNE table changée : la version sert à réparer.
//     Cause (docs/touches.md, « 14/11 ») : une ressource cassée du pack (animation GeckoLib de Shonen Core 1.50.0) a fait
//     échouer le 1er chargement des ressources ; Minecraft a alors vidé la liste des packs ET réécrit options.txt AVANT
//     d'avoir relu les touches des mods : toutes les touches de mods sont revenues à leur valeur d'origine, et les
//     marqueurs « déjà appliqué » (profil, schéma) empêchaient de les remettre. La version 8 est DOUCE (TA_DOUCES) : la
//     voie déjà réglée n'est réappliquée qu'aux touches qui sont exactement à leur valeur d'origine ; toute autre
//     valeur est un choix du joueur, gardé. Voir taRestaurer / taSignature (+ la garde de réinitialisation).
var TA_VERSION = 8
// Versions « douces » : pour une voie déjà réglée, la montée de version ne remplace que les touches revenues à la
// valeur d'origine du mod (au lieu de tout écraser). À n'utiliser que si les tables n'ont pas changé depuis la version
// précédente (sinon les joueurs n'auraient pas les nouvelles touches).
var TA_DOUCES = { 8: true }
// Garde de réinitialisation : au moins ce nombre de touches du schéma / de la voie (dont la valeur voulue n'est pas
// celle d'origine du mod) sont EXACTEMENT à leur valeur d'origine en même temps = les touches ont été réinitialisées
// (quelques touches remises à la main sur l'origine ne déclenchent rien).
var TA_SEUIL_RESET = 6
// Au plus ce nombre de restaurations par jour et par instance (pas de boucle si un mod remet tout à zéro à chaque lancement).
var TA_MAX_RESTAURATIONS = 3
// Actions qui sont au joueur, jamais touchées par la garde ni par la restauration (hors tables) : Shonen Core
// (check, verrouillage de cible, billard...). Seule la boîte à insignes est dans le schéma (TA_COMMUNES).
var TA_JOUEUR = ['key.shonencore.']

// Groupes de touches principales (noms options.txt : positions QWERTY ; touche AZERTY en commentaire)
// (un seul groupe depuis la version 6 : le 2e univers le reprend avec Ctrl, banque TA_BANQUES)
var TA_GROUPES = [
  ['key.keyboard.z', 'key.keyboard.r', 'key.keyboard.x', 'key.keyboard.c', 'key.keyboard.v']             // W R X C V
]
var TA_F = ['key.keyboard.f6', 'key.keyboard.f7', 'key.keyboard.f8', 'key.keyboard.f9', 'key.keyboard.f10', 'key.keyboard.f12']
var TA_BANQUES = ['NONE', 'CONTROL']
var TA_REPLIS = ['CONTROL', 'SHIFT', 'ALT']
var TA_AUCUNE = 'key.keyboard.unknown'

// Actions jamais laissées sans touche : le mod lit leur touche avec InputConstants.isKeyDown(fenêtre,
// getKey().getValue()) à chaque tick, sans tester « aucune touche » (-1). Vérifié avec javap (P2-5b) :
//   - DragonMine Z 2.2.1 : ForgeClientEvents.isUtilityMenuKeyHeld (UTILITY_MENU) ; KeyBinds.isPhysicallyDown teste
//     « aucune touche » avant (sans danger) ; les autres touches DMZ passent par consumeClick / isDown ;
//   - JujutsuCraft, MinePiece, Bleach Reborn, Solo Leveling, JCraft : aucune lecture de ce genre sur leurs actions
//     (Bleach lit la touche X en dur, pas une action).
// Quand leur univers est absent, elles vont sur une touche qu'aucun clavier n'a (F20 à F25, une par action).
var TA_GAREES = { 'key.dragonminez.utility_menu': 'key.keyboard.f24' }

// Touches à ne jamais donner sans modificateur (vanilla + « pour tout le monde » de docs/touches.md + miroirs)
var TA_RESERVEES = ['key.keyboard.w', 'key.keyboard.a', 'key.keyboard.s', 'key.keyboard.d', 'key.keyboard.space',
  'key.keyboard.left.shift', 'key.keyboard.left.control', 'key.keyboard.q', 'key.keyboard.e', 'key.keyboard.f',
  'key.keyboard.t', 'key.keyboard.p', 'key.keyboard.l', 'key.keyboard.tab', 'key.keyboard.slash',
  'key.keyboard.1', 'key.keyboard.2', 'key.keyboard.3', 'key.keyboard.4', 'key.keyboard.5', 'key.keyboard.6',
  'key.keyboard.7', 'key.keyboard.8', 'key.keyboard.9', 'key.keyboard.f1', 'key.keyboard.f2', 'key.keyboard.f3',
  'key.keyboard.f5', 'key.keyboard.f11', 'key.keyboard.k', 'key.keyboard.semicolon', 'key.keyboard.u',
  'key.keyboard.minus', 'key.keyboard.right.bracket', 'key.keyboard.equal', 'key.keyboard.o', 'key.keyboard.i',
  'key.keyboard.apostrophe', 'key.keyboard.insert', 'key.keyboard.caps.lock', 'key.keyboard.backslash',
  'key.keyboard.left.bracket', 'key.keyboard.keypad.subtract', 'key.keyboard.keypad.multiply',
  'key.keyboard.keypad.divide', 'key.keyboard.keypad.decimal', 'key.keyboard.pause',
  'key.mouse.left', 'key.mouse.right', 'key.mouse.middle',
  'key.keyboard.f21', 'key.keyboard.f22', 'key.keyboard.f23',   // (Oculus, 08/11)
  'key.keyboard.world.2']   // (boîte à insignes de Shonen Core, 11/11 : la touche < >)

// Paires qui partagent volontairement une touche (même mod, mêmes touches par défaut dans le mod)
var TA_PARTAGES = [['key.bleachreborn.mask_up', 'key.bleachreborn.zanpakato_up'],
  ['key.dragonminez.instant_transmission', 'key.dragonminez.spacepod_menu'],
  ['key.quirksunchained.space', 'key.supercrooks.space']]
// Actions que leur mod veut sur la touche de saut (Quirks Unchained : vol) : seules exceptions aux touches réservées
var TA_SUR_SAUT = ['key.quirksunchained.space', 'key.supercrooks.space']

// Touches « pour tout le monde » du schéma (client/overrides/shonen-keybinds.txt, sections [v1] commun et [v2]
// musique ; valeur finale) : [action, touche, modificateur]. Elles font partie du profil (role 'commun') : quand le
// profil est (ré)appliqué, elles reprennent la touche du schéma (Minecraft a pu effacer leur ligne, le mod revient
// alors à sa touche d'origine). Le test vérifie que cette table est exactement celle du schéma.
var TA_COMMUNES = [
  ['key.puffish_skills.open', 'key.keyboard.k', 'NONE'],
  ['key.shonencore.insignes', 'key.keyboard.world.2', 'NONE'],   // boîte à insignes (11/11)
  ['key.dungeonconfig.open', 'key.keyboard.unknown', 'NONE'],
  ['gui.xaero_open_map', 'key.keyboard.semicolon', 'NONE'],
  ['gui.xaero_open_settings', 'key.keyboard.unknown', 'NONE'],
  ['gui.xaero_enlarge_map', 'key.keyboard.unknown', 'NONE'],
  ['gui.xaero_minimap_settings', 'key.keyboard.right.bracket', 'NONE'],
  ['gui.xaero_waypoints_key', 'key.keyboard.u', 'NONE'],
  ['gui.xaero_new_waypoint', 'key.keyboard.minus', 'NONE'],
  ['key.ftbchunks.map', 'key.keyboard.equal', 'NONE'],
  ['key.ftbchunks.minimap.zoomIn', 'key.keyboard.unknown', 'NONE'],
  ['key.ftbchunks.minimap.zoomOut', 'key.keyboard.unknown', 'NONE'],
  ['key.origins.view_origin', 'key.keyboard.o', 'NONE'],
  ['key.origins.primary_active', 'key.keyboard.unknown', 'NONE'],
  ['key.curios.open.desc', 'key.keyboard.i', 'NONE'],
  ['key.sophisticatedbackpacks.open_backpack', 'key.keyboard.apostrophe', 'NONE'],
  ['key.sophisticatedbackpacks.toggle_upgrade_1', 'key.keyboard.unknown', 'NONE'],
  ['key.sophisticatedbackpacks.toggle_upgrade_2', 'key.keyboard.unknown', 'NONE'],
  ['key.corpse.death_history', 'key.keyboard.insert', 'NONE'],
  ['key.push_to_talk', 'key.keyboard.caps.lock', 'NONE'],
  ['key.mute_microphone', 'key.keyboard.backslash', 'NONE'],
  ['key.voice_chat', 'key.keyboard.left.bracket', 'NONE'],
  ['key.disable_voice_chat', 'key.keyboard.unknown', 'NONE'],
  ['key.hide_icons', 'key.keyboard.unknown', 'NONE'],
  ['key.voice_chat_group', 'key.keyboard.unknown', 'NONE'],
  ['key.cataclysm.ability', 'key.keyboard.keypad.subtract', 'NONE'],
  ['key.cataclysm.helmet_ability', 'key.keyboard.keypad.multiply', 'NONE'],
  ['key.cataclysm.chestplate_ability', 'key.keyboard.keypad.divide', 'NONE'],
  ['key.cataclysm.boots_ability', 'key.keyboard.keypad.decimal', 'NONE'],
  ['key.jade.show_overlay', 'key.keyboard.unknown', 'NONE'],
  ['key.jade.toggle_liquid', 'key.keyboard.unknown', 'NONE'],
  ['key.jade.show_recipes', 'key.keyboard.unknown', 'NONE'],
  ['key.jade.show_uses', 'key.keyboard.unknown', 'NONE'],
  ['key.jade.narrate', 'key.keyboard.unknown', 'NONE'],
  ['placebo.toggleTrails', 'key.keyboard.unknown', 'NONE'],
  ['placebo.toggleWings', 'key.keyboard.unknown', 'NONE'],
  ['key.play_pause', 'key.keyboard.pause', 'NONE'],
  ['key.next_music', 'key.keyboard.unknown', 'NONE'],
  ['key.reload', 'key.keyboard.unknown', 'NONE'],
  ['key.print_all', 'key.keyboard.unknown', 'NONE'],
  ['key.toggle_areas', 'key.keyboard.unknown', 'NONE'],
  ['key.area_confirm', 'key.keyboard.unknown', 'NONE'],
  ['key.area_cancel', 'key.keyboard.unknown', 'NONE'],
  // Oculus (shaders, 08/11) : K, O et R étaient pris (arbres, Origins, JJK) : garées sur F21-F23 (schéma v6)
  ['iris.keybind.toggleShaders', 'key.keyboard.f21', 'NONE'],
  ['iris.keybind.shaderPackSelection', 'key.keyboard.f22', 'NONE'],
  ['iris.keybind.reload', 'key.keyboard.f23', 'NONE']]

// Tables par univers. principales / secondaires : [action, libellé] dans l'ordre d'importance.
// liees : [action, action de base, modificateur, libellé]. fixes : [action, touche, modificateur, libellé, faible]
// (faible = cède sa touche à l'action fixe d'un autre univers).
var TA_UNIVERS = {
  jjk: {
    nom: 'Jujutsu Kaisen', court: 'JJK',
    principales: [
      ['key.jujutsucraft.key_start_technique', 'Utiliser la technique sélectionnée'],
      ['key.jujutsucraft.key_change_technique', 'Changer de technique occulte'],
      ['key.jujutsucraft.key_use_main_skill', 'Technique principale'],
      ['key.jujutsucraft.key_reverse_cursed_technique', 'Technique occulte inversée'],
      ['key.jujutsucraft.key_simple_domain', 'Territoire simple']],
    liees: [],
    secondaires: [
      ['key.jujutsucraft.key_domain_amplification', 'Amplification du territoire'],
      ['key.jujutsucraft.key_switch_cursed_technique', 'Passer à la 1re / 2e technique'],
      ['key.jujutsucraft.key_reset_technique', 'Réinitialiser le choix de technique']],
    fixes: []
  },
  onepiece: {
    nom: 'One Piece', court: 'One Piece',
    principales: [
      ['key.minepiece.key_start_technique', 'Utiliser la technique choisie'],
      ['key.minepiece.key_change_technique', 'Choisir une technique (Maj : en arrière)'],
      ['key.minepiece.key_battle_mode', 'Mode combat'],
      ['key.minepiece.key_transform', 'Se transformer'],
      ['key.minepiece.key_haoshoku_haki', 'Haki des rois']],
    liees: [['key.minepiece.key_switch_technique', 'key.minepiece.key_change_technique', 'ALT', 'Basculer technique de base / du fruit']],
    secondaires: [
      ['key.minepiece.key_reset_technique', 'Réinitialiser le choix de technique'],
      ['key.minepiece.key_p', "Paramètres de l'équipage"],
      ['key.minepiece.key_for_orca', 'Touche pour Orca-san']],
    fixes: []
  },
  dbz: {
    nom: 'Dragon Ball', court: 'Dragon Ball',
    principales: [
      ['key.dragonminez.ki_charge', 'Charger le ki'],
      ['key.dragonminez.action_key', 'Action / transformation'],
      ['key.dragonminez.fly_key', 'Voler'],
      ['key.dragonminez.dash_key', 'Esquive'],
      ['key.dragonminez.stats_menu', 'Menu des stats']],
    liees: [
      ['key.dragonminez.descend', 'key.dragonminez.action_key', 'ALT', 'Redescendre (forme inférieure)'],
      ['key.dragonminez.lower_release', 'key.dragonminez.ki_charge', 'ALT', 'Réduire la libération'],
      ['key.dragonminez.spacepod_menu', 'key.dragonminez.instant_transmission', 'NONE', 'Menu de la capsule']],
    secondaires: [
      ['key.dragonminez.lock_on', 'Verrouiller la cible'],
      ['key.dragonminez.utility_menu', 'Menu utilitaire'],
      ['key.dragonminez.instant_transmission', 'Téléportation instantanée']],
    fixes: [
      ['key.dragonminez.second_function_key', 'key.keyboard.left.alt', 'NONE', 'Seconde fonction', false],
      ['key.dragonminez.ki_sense', 'key.keyboard.f4', 'NONE', 'Détection du ki', false],
      ['key.dragonminez.rhythm_left', 'key.keyboard.left', 'NONE', 'Rythme : piste 1', false],
      ['key.dragonminez.rhythm_down', 'key.keyboard.down', 'NONE', 'Rythme : piste 2', false],
      ['key.dragonminez.rhythm_up', 'key.keyboard.up', 'NONE', 'Rythme : piste 3', false],
      ['key.dragonminez.rhythm_right', 'key.keyboard.right', 'NONE', 'Rythme : piste 4', false]]
  },
  bleach: {
    nom: 'Bleach', court: 'Bleach',
    // (10/11, option (a) de Admin) touches des principales à la place de W R X C V : shunpo G, Shikai H
    // (pas B : Prefab garde Alt + B, « Build Current Structure », que prendrait la Résurrection en 2e place)
    // (revenir à W / R pour le shunpo et le Shikai = supprimer cette ligne ET la ligne « emprunts » ci-dessous)
    touchesPrincipales: ['key.keyboard.g', 'key.keyboard.h', 'key.keyboard.x', 'key.keyboard.c', 'key.keyboard.v'],
    // actions d'un autre univers reprises quand le joueur n'a PAS cet univers : [action, touche, univers prêteur, libellé],
    // modificateur = celui de la place de Bleach (aucun en 1re voie, Ctrl en 2e). Combos de JJK au zanpakutō (Shonen Core
    // ZanpakutoCombo) : mêmes touches que JJK en 1re voie.
    emprunts: [['key.jujutsucraft.key_start_technique', 'key.keyboard.z', 'jjk', "Combo au zanpakutō : lancer l'attaque (tenir = charger)"], ['key.jujutsucraft.key_change_technique', 'key.keyboard.r', 'jjk', "Combo au zanpakutō : choisir Attack / Knockback / Barrage"]],
    principales: [
      ['key.bleachreborn.flash', 'Pas éclair (shunpo)'],
      ['key.bleachreborn.activate', 'Activer le shikai'],
      ['key.bleachreborn.cero', 'Cero'],
      ['key.bleachreborn.active_skill', 'Compétence active'],
      ['key.bleachreborn.kido', 'Kidō']],
    liees: [
      ['key.bleachreborn.mask_up', 'key.bleachreborn.activate', 'SHIFT', 'Masque de Vizard'],
      ['key.bleachreborn.zanpakato_up', 'key.bleachreborn.activate', 'SHIFT', "Résurrection d'Arrancar"]],
    secondaires: [
      ['key.bleachreborn.spirit_pressure', 'Pression spirituelle'],
      ['key.bleachreborn.meditation', 'Méditation'],
      ['key.bleachreborn.hollow_bite', 'Morsure de Hollow'],
      ['key.bleachreborn.reishi_bow', 'Arc reishi'],
      ['key.bleachreborn.playcard', 'Carte du joueur']],
    fixes: [
      ['key.bleachreborn.deactivate', 'key.keyboard.home', 'NONE', 'Désactiver les objets', false],
      ['key.bleachreborn.zanpakato_down', 'key.keyboard.home', 'SHIFT', 'Désactiver la Résurrection', false],
      ['key.bleachreborn.hollow', 'key.keyboard.delete', 'NONE', 'Interface Hollow', false],
      ['key.bleachreborn.jump', 'key.keyboard.page.up', 'NONE', 'Bascule saut', false],
      ['key.bleachreborn.speed', 'key.keyboard.page.down', 'NONE', 'Bascule vitesse', false],
      ['key.bleachreborn.fly', 'key.keyboard.end', 'NONE', 'Bascule vol', false],
      ['key.bleachreborn.party_target_1', 'key.keyboard.left', 'NONE', 'Cibler le membre du groupe 1', true],
      ['key.bleachreborn.party_target_2', 'key.keyboard.down', 'NONE', 'Cibler le membre du groupe 2', true],
      ['key.bleachreborn.party_target_3', 'key.keyboard.right', 'NONE', 'Cibler le membre du groupe 3', true]]
  },
  sololeveling: {
    nom: 'Solo Leveling', court: 'Solo Leveling',
    principales: [
      ['key.sololeveling.use_skill', 'Utiliser la compétence sélectionnée'],
      ['key.sololeveling.skill_cycle_button', 'Changer de compétence'],
      ['key.sololeveling.ability_1', 'Capacité de classe 1'],
      ['key.sololeveling.ability_2', 'Capacité de classe 2'],
      ['key.sololeveling.open_panel', 'Ouvrir le panneau']],
    liees: [],
    secondaires: [
      ['key.sololeveling.ability_3', 'Capacité de classe 3'],
      ['key.sololeveling.ability_4', 'Capacité de classe 4'],
      ['key.sololeveling.quest_info', 'Infos de quête']],
    fixes: [
      ['key.sololeveling.ab_1', 'key.keyboard.keypad.1', 'NONE', 'Capacité 1', false],
      ['key.sololeveling.ab_2', 'key.keyboard.keypad.2', 'NONE', 'Capacité 2', false],
      ['key.sololeveling.ab_3', 'key.keyboard.keypad.3', 'NONE', 'Capacité 3', false],
      ['key.sololeveling.ab_4', 'key.keyboard.keypad.4', 'NONE', 'Capacité 4', false],
      ['key.sololeveling.ab_5', 'key.keyboard.keypad.5', 'NONE', 'Capacité 5', false],
      ['key.sololeveling.ab_6', 'key.keyboard.keypad.6', 'NONE', 'Capacité 6', false],
      ['key.sololeveling.ab_7', 'key.keyboard.keypad.7', 'NONE', 'Capacité 7', false],
      ['key.sololeveling.ab_8', 'key.keyboard.keypad.8', 'NONE', 'Capacité 8', false]]
  },
  mha: {
    nom: 'My Hero Academia', court: 'MHA',
    principales: [
      ['key.quirksunchained.z', 'Capacité 1'],
      ['key.quirksunchained.r', "Spécial de l'Alter"],
      ['key.quirksunchained.x', 'Capacité 2'],
      ['key.quirksunchained.c', 'Capacité 3'],
      ['key.quirksunchained.v', 'Capacité 4']],
    // supercrooks : 2e jeu de touches du même mod (méchants), mêmes rôles
    liees: [
      ['key.supercrooks.z', 'key.quirksunchained.z', 'ALT', 'Capacité 1 (méchant)'],
      ['key.supercrooks.r', 'key.quirksunchained.r', 'ALT', 'Changer de barre (méchant)'],
      ['key.supercrooks.x', 'key.quirksunchained.x', 'ALT', 'Capacité 2 (méchant)'],
      ['key.supercrooks.c', 'key.quirksunchained.c', 'ALT', 'Capacité 3 (méchant)'],
      ['key.supercrooks.v', 'key.quirksunchained.v', 'ALT', 'Capacité 4 (méchant)']],
    secondaires: [
      ['key.quirksunchained.m', 'Menu des capacités'],
      ['key.quirksunchained.alt', 'Changer de barre'],
      ['key.supercrooks.m', 'Menu des capacités (méchant)']],
    fixes: [
      ['key.quirksunchained.space', 'key.keyboard.space', 'NONE', 'Vol (touche de saut)', false],
      ['key.supercrooks.space', 'key.keyboard.space', 'NONE', 'Vol (méchant)', false]]
  },
  // P3-1 : Ninshu: Origins est là pour ses boss ; AUCUNE voie ne donne Naruto (TA_SANS_VOIE) : ses actions sont donc
  // toujours sans touche. Ordre prévu pour une voie Naruto (étape 2, à revérifier avec le test en la mettant dans TA_ORDRE).
  naruto: {
    nom: 'Naruto', court: 'Naruto',
    principales: [
      ['key.ninshuorigins.use_jutsu', 'Utiliser le jutsu'],
      ['key.ninshuorigins.next_jutsu', 'Jutsu suivant'],
      ['key.ninshuorigins.charge_chakra', 'Charger le chakra'],
      ['key.ninshuorigins.subuse_jutsu', 'Permutation'],
      ['key.ninshuorigins.mainmenu', 'Menu ninja']],
    liees: [
      ['key.ninshuorigins.prev_jutsu', 'key.ninshuorigins.next_jutsu', 'SHIFT', 'Jutsu précédent'],
      ['key.ninshuorigins.next_release', 'key.ninshuorigins.use_jutsu', 'ALT', 'Rouleau suivant'],
      ['key.ninshuorigins.prev_release', 'key.ninshuorigins.use_jutsu', 'SHIFT', 'Rouleau précédent'],
      ['key.ninshuorigins.charge_naturechakra', 'key.ninshuorigins.charge_chakra', 'SHIFT', 'Chakra naturel'],
      ['key.ninshuorigins.giveup', 'key.ninshuorigins.subuse_jutsu', 'ALT', 'Abandonner (à terre)'],
      ['key.ninshuorigins.toggle_hair', 'key.ninshuorigins.mainmenu', 'ALT', 'Coiffure'],
      ['key.ninshuorigins.pluckeye', 'key.ninshuorigins.mainmenu', 'SHIFT', 'Arracher un œil']],
    secondaires: [
      ['key.ninshuorigins.dojutsu', 'Dôjutsu'],
      ['key.ninshuorigins.chakra_control', 'Contrôle du chakra'],
      ['key.ninshu.toggle_taijutsu', 'Taijutsu'],
      ['key.ninshuorigins.taijutsu_block', 'Parade'],
      ['key.ninshuorigins.transformationwheel', 'Roue des transformations'],
      ['key.ninshuorigins.sagemode', 'Mode ermite']],
    fixes: [
      ['key.ninshuorigins.activate_chakramode', 'key.keyboard.f4', 'SHIFT', 'Manteau de chakra (jinchûriki)', false]]
  }
}
var TA_ORDRE = ['dbz', 'bleach', 'jjk', 'onepiece', 'sololeveling', 'naruto', 'mha']
// Univers des tables qu'aucune voie ne donne aujourd'hui : leurs actions sont toujours « absentes » (sans touche ou
// garées), ils ne comptent jamais dans la voie du joueur.
var TA_SANS_VOIE = []

/** Univers connus de `liste` (texte 'a,b' ou tableau), sans doublon, 3 au plus, dans l'ordre donné. */
function taNettoyer(liste) {
  var brut = (typeof liste === 'string') ? (liste === '' ? [] : liste.split(',')) : liste
  var res = []
  var i = 0
  while (i < brut.length && res.length < TA_BANQUES.length) {
    var u = String(brut[i])
    if (TA_UNIVERS[u] !== undefined && TA_SANS_VOIE.indexOf(u) < 0 && res.indexOf(u) < 0) res.push(u)
    i = i + 1
  }
  return res
}

function taPartage(a, b) {
  var i = 0
  while (i < TA_PARTAGES.length) {
    var p = TA_PARTAGES[i]
    if ((p[0] === a && p[1] === b) || (p[0] === b && p[1] === a)) return true
    i = i + 1
  }
  return false
}

/**
 * Le profil de touches pour la voie `liste` (ordre de priorité). Retourne
 * { univers: [...], touches: { action: { key, mod, univers, role, libelle } }, conflits: [texte] }.
 * Toutes les actions des 6 univers y sont : celles des univers absents avec key = key.keyboard.unknown.
 */
function taProfil(liste) {
  var univers = taNettoyer(liste)
  var touches = {}
  var prises = {}   // 'touche|mod' -> action
  var conflits = []
  function poser(action, key, mod, u, role, libelle) {
    touches[action] = { key: key, mod: mod, univers: u, role: role, libelle: libelle }
    if (key === TA_AUCUNE) return
    var cle = key + '|' + mod
    if (prises[cle] !== undefined && !taPartage(prises[cle], action)) conflits.push(cle + ' : ' + prises[cle] + ' / ' + action)
    else if (prises[cle] === undefined) prises[cle] = action
  }
  function libre(key, mod) { return prises[key + '|' + mod] === undefined }
  var i = 0
  var k = 0
  // univers absents : tout sans touche (posé d'abord, remplacé par rien puisque leurs actions sont à eux seuls)
  var tousUnivers = TA_ORDRE.concat(TA_SANS_VOIE)
  i = 0
  while (i < tousUnivers.length) {
    var ua = tousUnivers[i]
    if (univers.indexOf(ua) < 0) {
      var ta = TA_UNIVERS[ua]
      var listes = [ta.principales, ta.liees, ta.secondaires, ta.fixes]
      var l = 0
      while (l < listes.length) {
        k = 0
        while (k < listes[l].length) {
          var e = listes[l][k]
          touches[e[0]] = { key: TA_AUCUNE, mod: 'NONE', univers: ua, role: 'absent', libelle: e[e.length === 2 ? 1 : 3] }
          k = k + 1
        }
        l = l + 1
      }
    }
    i = i + 1
  }
  // 0. touches « pour tout le monde » du schéma (touches réservées : aucune action de voie ne les prend)
  i = 0
  while (i < TA_COMMUNES.length) {
    poser(TA_COMMUNES[i][0], TA_COMMUNES[i][1], TA_COMMUNES[i][2], null, 'commun', TA_COMMUNES[i][0])
    i = i + 1
  }
  // 1. principales : groupe de la place de l'univers
  i = 0
  while (i < univers.length) {
    var tp = TA_UNIVERS[univers[i]]
    var groupe = tp.touchesPrincipales !== undefined ? tp.touchesPrincipales : TA_GROUPES[0]
    k = 0
    while (k < tp.principales.length) {
      if (k < groupe.length) poser(tp.principales[k][0], groupe[k], TA_BANQUES[i], univers[i], 'principale', tp.principales[k][1])
      else poser(tp.principales[k][0], TA_AUCUNE, 'NONE', univers[i], 'principale', tp.principales[k][1])
      k = k + 1
    }
    i = i + 1
  }
  // 1 bis. emprunts : actions d'un univers ABSENT de la voie reprises par celui-ci (touche + modificateur de sa place)
  i = 0
  while (i < univers.length) {
    var te = TA_UNIVERS[univers[i]].emprunts
    k = 0
    while (te !== undefined && k < te.length) {
      if (univers.indexOf(te[k][2]) < 0) poser(te[k][0], te[k][1], TA_BANQUES[i], univers[i], 'principale', te[k][3])
      k = k + 1
    }
    i = i + 1
  }
  // 2. secondaires : F6..F12, banque de la place de l'univers
  i = 0
  while (i < univers.length) {
    var ts = TA_UNIVERS[univers[i]]
    k = 0
    while (k < ts.secondaires.length) {
      if (k < TA_F.length) poser(ts.secondaires[k][0], TA_F[k], TA_BANQUES[i], univers[i], 'secondaire', ts.secondaires[k][1])
      else poser(ts.secondaires[k][0], TA_AUCUNE, 'NONE', univers[i], 'secondaire', ts.secondaires[k][1])
      k = k + 1
    }
    i = i + 1
  }
  // 3. liées : touche de l'action de base + modificateur
  i = 0
  while (i < univers.length) {
    var tl = TA_UNIVERS[univers[i]]
    k = 0
    while (k < tl.liees.length) {
      var li = tl.liees[k]
      var base = touches[li[1]]
      if (base === undefined || base.key === TA_AUCUNE) poser(li[0], TA_AUCUNE, 'NONE', univers[i], 'liee', li[3])
      else if (li[2] === 'NONE') poser(li[0], base.key, base.mod, univers[i], 'liee', li[3])
      else if (base.mod === 'NONE') poser(li[0], base.key, li[2], univers[i], 'liee', li[3])
      else {
        // 2e univers (touche de base avec Ctrl) : le modificateur de la liée s'il est libre, sinon l'autre, sinon rien
        var essais = [li[2], li[2] === 'ALT' ? 'SHIFT' : 'ALT']
        var lm = null
        var q = 0
        while (q < essais.length && lm === null) { if (libre(base.key, essais[q])) lm = essais[q]; q = q + 1 }
        if (lm !== null) poser(li[0], base.key, lm, univers[i], 'liee', li[3])
        else {
          // repli : une touche F encore libre avec Ctrl (celles que ses secondaires n'ont pas prises)
          // (puis Maj + F, puis Alt + F)
          var fl = null
          var fm = null
          var bq = ['CONTROL', 'SHIFT', 'ALT']
          var b2 = 0
          while (b2 < bq.length && fl === null) {
            q = 0
            while (q < TA_F.length && fl === null) { if (libre(TA_F[q], bq[b2])) { fl = TA_F[q]; fm = bq[b2] }; q = q + 1 }
            b2 = b2 + 1
          }
          if (fl === null) poser(li[0], TA_AUCUNE, 'NONE', univers[i], 'liee', li[3])
          else poser(li[0], fl, fm, univers[i], 'liee', li[3])
        }
      }
      k = k + 1
    }
    i = i + 1
  }
  // 4. fixes : fortes d'abord, puis faibles ; touche prise -> Ctrl, Maj, Alt + la même touche, sinon aucune
  var passe = 0
  while (passe < 2) {
    i = 0
    while (i < univers.length) {
      var tf = TA_UNIVERS[univers[i]]
      k = 0
      while (k < tf.fixes.length) {
        var f = tf.fixes[k]
        if ((f[4] === true) === (passe === 1)) {
          var mod = f[2]
          if (!libre(f[1], mod)) {
            mod = null
            var r = 0
            while (r < TA_REPLIS.length && mod === null) {
              if (libre(f[1], TA_REPLIS[r])) mod = TA_REPLIS[r]
              r = r + 1
            }
          }
          if (mod === null) poser(f[0], TA_AUCUNE, 'NONE', univers[i], 'fixe', f[3])
          else poser(f[0], f[1], mod, univers[i], 'fixe', f[3])
        }
        k = k + 1
      }
      i = i + 1
    }
    passe = passe + 1
  }
  // 5. actions garées : jamais « aucune » (univers absent, ou pas de place) -> leur touche que personne n'a
  var garees = Object.keys(TA_GAREES)
  i = 0
  while (i < garees.length) {
    var tg = touches[garees[i]]
    if (tg !== undefined && tg.key === TA_AUCUNE) {
      tg.key = TA_GAREES[garees[i]]
      tg.mod = 'NONE'
      var cg = tg.key + '|NONE'
      if (prises[cg] !== undefined) conflits.push(cg + ' : ' + prises[cg] + ' / ' + garees[i])
      else prises[cg] = garees[i]
    }
    i = i + 1
  }
  return { univers: univers, touches: touches, conflits: conflits }
}

var TA_ROLES_VOIE = ['principale', 'liee', 'secondaire', 'fixe']

/**
 * La garde (à chaque connexion, profil déjà appliqué ou non) : ce qu'il faut corriger dans les touches ACTUELLES.
 * `actuelles` : { action: { key, mod, jeu, vanilla } } (jeu = la touche agit en jeu, pas seulement dans un écran ;
 * vanilla = action de Minecraft). Retourne [{ action, key, mod, raison }] :
 *   - action d'un univers ABSENT de la voie (Naruto compris) : remise à sa valeur du profil (aucune, ou garée) ;
 *   - toute autre action de mod (« pour tout le monde » ou d'un mod hors des tables), active en jeu, posée sur la
 *     MÊME touche + modificateur que la touche du PROFIL d'une action de la voie : remise à sa touche du schéma si
 *     elle en a une, sinon sans touche. Les autres choix du joueur sont gardés (une action de voie que le joueur a
 *     lui-même déplacée sur la touche d'un autre mod ne déclenche rien).
 * Les actions de la voie elles-mêmes, les touches vanilla et les touches d'écran (JEI, sacs...) ne sont jamais
 * touchées.
 */
function taGarde(profil, actuelles) {
  var res = []
  var voie = {}   // 'touche|mod' -> action de la voie
  var noms = Object.keys(profil.touches)
  var i = 0
  while (i < noms.length) {
    var t = profil.touches[noms[i]]
    if (TA_ROLES_VOIE.indexOf(t.role) >= 0 && t.key !== TA_AUCUNE) voie[t.key + '|' + t.mod] = noms[i]
    i = i + 1
  }
  var acts = Object.keys(actuelles)
  i = 0
  while (i < acts.length) {
    var n = acts[i]
    var cur = actuelles[n]
    var p = profil.touches[n]
    if (p !== undefined && TA_ROLES_VOIE.indexOf(p.role) >= 0) { i = i + 1; continue }
    if (p === undefined && taDuJoueur(n)) { i = i + 1; continue }
    if (p !== undefined && p.role === 'absent') {
      if (cur.key !== p.key || cur.mod !== p.mod) res.push({ action: n, key: p.key, mod: p.mod, raison: 'univers absent' })
    } else if (cur.vanilla !== true && cur.jeu !== false && cur.key !== TA_AUCUNE) {
      var prise = voie[cur.key + '|' + cur.mod]
      if (prise !== undefined && !taPartage(prise, n)) {
        if (p !== undefined && p.role === 'commun' && (p.key + '|' + p.mod) !== (cur.key + '|' + cur.mod)) {
          res.push({ action: n, key: p.key, mod: p.mod, raison: 'prenait la touche de ' + prise })
        } else {
          res.push({ action: n, key: TA_AUCUNE, mod: 'NONE', raison: 'prenait la touche de ' + prise })
        }
      }
    }
    i = i + 1
  }
  return res
}

/** Action qui est au joueur (hors tables) : jamais touchée par la garde ni par la restauration. */
function taDuJoueur(action) {
  var i = 0
  while (i < TA_JOUEUR.length) { if (action.indexOf(TA_JOUEUR[i]) === 0) return true; i = i + 1 }
  return false
}

/** Les touches « voulues » d'un profil pour la restauration : la voie et le schéma commun (pas les univers absents). */
function taCibles(profil) {
  var res = {}
  var noms = Object.keys(profil.touches)
  var i = 0
  while (i < noms.length) {
    var t = profil.touches[noms[i]]
    if (TA_ROLES_VOIE.indexOf(t.role) >= 0 || t.role === 'commun') res[noms[i]] = { key: t.key, mod: t.mod }
    i = i + 1
  }
  return res
}

/** Le schéma commun seul (joueur sans voie encore : avant l'Éveil). */
function taCiblesCommunes() {
  var res = {}
  var i = 0
  while (i < TA_COMMUNES.length) { res[TA_COMMUNES[i][0]] = { key: TA_COMMUNES[i][1], mod: TA_COMMUNES[i][2] }; i = i + 1 }
  return res
}

function taMeme(a, b) { return a.key === b.key && a.mod === b.mod }

/**
 * Signature d'une réinitialisation : les actions (parmi les touches voulues) dont la valeur voulue n'est PAS l'origine
 * du mod et qui sont EXACTEMENT à l'origine du mod. `actuelles[action]` = { key, mod, jeu, vanilla, defaut: { key, mod } | null }.
 * Retourne { aDefaut: [actions], total } (total = nombre d'actions voulues connues du jeu, avec leur origine lue).
 */
function taSignature(cibles, actuelles) {
  var aDefaut = []
  var total = 0
  var noms = Object.keys(cibles)
  var i = 0
  while (i < noms.length) {
    var cur = actuelles[noms[i]]
    if (cur !== undefined && cur.defaut !== null && cur.defaut !== undefined && !taMeme(cibles[noms[i]], cur.defaut)) {
      total = total + 1
      if (taMeme(cur, cur.defaut)) aDefaut.push(noms[i])
    }
    i = i + 1
  }
  return { aDefaut: aDefaut, total: total }
}

/**
 * La restauration douce : parmi les touches voulues (`cibles` : { action: { key, mod } }), ne corrige QUE celles qui sont
 * exactement à l'origine du mod (valeur que Minecraft remet quand il a perdu la ligne d'options.txt). Toute autre valeur
 * = choix du joueur : gardée. Une touche voulue déjà bonne ne bouge pas. Une action qui n'a pas d'origine lue (null) ou
 * qui n'existe pas (mod absent) est ignorée. Une correction qui poserait la touche sur celle qu'un AUTRE choix du joueur
 * occupe (action ni corrigée ni à l'origine) est sautée. Retourne [{ action, key, mod, raison }].
 */
function taRestaurer(cibles, actuelles) {
  var res = []
  var changees = {}
  var noms = Object.keys(cibles)
  var i = 0
  while (i < noms.length) {
    var n = noms[i]
    var cur = actuelles[n]
    var cb = cibles[n]
    i = i + 1
    if (cur === undefined || cur.defaut === null || cur.defaut === undefined) continue
    if (taDuJoueur(n)) continue
    if (taMeme(cur, cb)) continue
    if (!taMeme(cur, cur.defaut)) continue
    res.push({ action: n, key: cb.key, mod: cb.mod, raison: 'revenue a la touche du mod' })
    changees[n] = true
  }
  // une touche posée par le joueur sur la touche visée : on ne la lui prend pas
  var gardees = []
  var k = 0
  while (k < res.length) {
    var c = res[k]
    k = k + 1
    var conflit = null
    if (c.key !== TA_AUCUNE) {
      var autres = Object.keys(actuelles)
      var a = 0
      while (a < autres.length && conflit === null) {
        var o = actuelles[autres[a]]
        if (autres[a] !== c.action && changees[autres[a]] !== true && o.key === c.key && o.mod === c.mod &&
            o.defaut !== null && o.defaut !== undefined && !taMeme(o, o.defaut) && !taPartage(autres[a], c.action)) conflit = autres[a]
        a = a + 1
      }
    }
    if (conflit === null) gardees.push(c)
  }
  return gardees
}

/** Y a-t-il eu une réinitialisation ? (assez de touches voulues exactement à l'origine) */
function taResetDetecte(cibles, actuelles) {
  return taSignature(cibles, actuelles).aDefaut.length >= TA_SEUIL_RESET
}

/** Compteur de restaurations du jour (marqueur) : peut-on encore restaurer ? `jour` = 'AAAA-MM-JJ'. */
function taPeutRestaurer(marqueur, jour) {
  var r = marqueur.restaurations
  if (r === undefined || r === null || r.jour !== jour) return true
  return r.n < TA_MAX_RESTAURATIONS
}
function taCompterRestauration(marqueur, jour) {
  var r = marqueur.restaurations
  if (r === undefined || r === null || r.jour !== jour) marqueur.restaurations = { jour: jour, n: 1 }
  else r.n = r.n + 1
}

// Noms affichés (AZERTY) des touches utilisées par les profils, pour la doc et les tests
var TA_NOMS_TOUCHES = {
  'key.keyboard.z': 'W', 'key.keyboard.r': 'R', 'key.keyboard.x': 'X', 'key.keyboard.c': 'C', 'key.keyboard.v': 'V',
  'key.keyboard.h': 'H', 'key.keyboard.y': 'Y', 'key.keyboard.g': 'G', 'key.keyboard.b': 'B', 'key.keyboard.n': 'N',
  'key.keyboard.world.2': '<', 'key.keyboard.grave.accent': '²', 'key.keyboard.j': 'J', 'key.keyboard.comma': ';',
  'key.keyboard.m': ',', 'key.keyboard.f4': 'F4', 'key.keyboard.f6': 'F6', 'key.keyboard.f7': 'F7',
  'key.keyboard.f8': 'F8', 'key.keyboard.f9': 'F9', 'key.keyboard.f10': 'F10', 'key.keyboard.f12': 'F12',
  'key.keyboard.left': '←', 'key.keyboard.down': '↓', 'key.keyboard.up': '↑', 'key.keyboard.right': '→',
  'key.keyboard.home': 'Début', 'key.keyboard.end': 'Fin', 'key.keyboard.delete': 'Suppr',
  'key.keyboard.page.up': 'Pg. préc.', 'key.keyboard.page.down': 'Pg. suiv.', 'key.keyboard.left.alt': 'Alt gauche',
  'key.keyboard.right.alt': 'Alt Gr', 'key.mouse.4': 'souris 4', 'key.mouse.5': 'souris 5',
  'key.keyboard.f20': 'F20 (garée)', 'key.keyboard.f21': 'F21 (garée)', 'key.keyboard.f22': 'F22 (garée)',
  'key.keyboard.f23': 'F23 (garée)', 'key.keyboard.f24': 'F24 (garée)', 'key.keyboard.f25': 'F25 (garée)',
  'key.keyboard.unknown': 'aucune'
}
var TA_NOMS_MODS = { NONE: '', CONTROL: 'Ctrl + ', SHIFT: 'Maj + ', ALT: 'Alt + ' }
function taNomTouche(t) {
  var n = TA_NOMS_TOUCHES[t.key]
  if (n === undefined && t.key.indexOf('key.keyboard.keypad.') === 0) n = 'pavé num. ' + t.key.substring(20)
  if (n === undefined) n = t.key
  return (t.key === TA_AUCUNE ? '' : TA_NOMS_MODS[t.mod]) + n
}
function taNomsUnivers(univers) {
  var noms = []
  var i = 0
  while (i < univers.length) { noms.push(TA_UNIVERS[univers[i]].court); i = i + 1 }
  return noms.join(' + ')
}

if (typeof module !== 'undefined') {
  module.exports = { surSaut: TA_SUR_SAUT, profil: taProfil, nettoyer: taNettoyer, univers: TA_UNIVERS, ordre: TA_ORDRE, sansVoie: TA_SANS_VOIE, groupes: TA_GROUPES,
    f: TA_F, banques: TA_BANQUES, reservees: TA_RESERVEES, partage: taPartage, nomTouche: taNomTouche,
    nomsUnivers: taNomsUnivers, version: TA_VERSION, garees: TA_GAREES, aucune: TA_AUCUNE, communes: TA_COMMUNES,
    garde: taGarde, cibles: taCibles, ciblesCommunes: taCiblesCommunes, signature: taSignature, restaurer: taRestaurer,
    resetDetecte: taResetDetecte, peutRestaurer: taPeutRestaurer, compterRestauration: taCompterRestauration,
    douces: TA_DOUCES, seuilReset: TA_SEUIL_RESET, maxRestaurations: TA_MAX_RESTAURATIONS, duJoueur: taDuJoueur }
}

// ======================= partie Minecraft (client KubeJS seulement) =======================
if (typeof NetworkEvents !== 'undefined') {
  var TA_MARQUEUR_DOSSIER = 'config/shonen-eveil'
  var TA_MARQUEUR = 'config/shonen-eveil/touches-auto.json'
  var TaKeyMapping = Java.loadClass('net.minecraft.client.KeyMapping')
  var TaInput = Java.loadClass('com.mojang.blaze3d.platform.InputConstants')
  var TaKeyModifier = Java.loadClass('net.minecraftforge.client.settings.KeyModifier')
  var taEnAttente = null   // null, ou { force: true|false } : traité au prochain tick client

  var taLireMarqueur = function () {
    try {
      var s = JsonIO.readString(TA_MARQUEUR)
      var m = JSON.parse(String(s))
      if (m !== null && typeof m === 'object' && m.joueurs !== undefined) return m
    } catch (e) { }
    return { version: 1, joueurs: {} }
  }

  var taEcrireMarqueur = function (m) {
    try { Java.loadClass('net.minecraft.FileUtil').createDirectoriesSafe(TA_MARQUEUR_DOSSIER) } catch (e) { }
    JsonIO.write(TA_MARQUEUR, m)
  }

  /** Les KeyMapping du jeu par nom d'action. */
  var taMappings = function () {
    var res = {}
    var kms = Client.options.keyMappings
    var i = 0
    while (i < kms.length) {
      res[String(kms[i].getName())] = kms[i]
      i = i + 1
    }
    return res
  }

  /** Écrit le profil dans les touches du jeu et options.txt ; retourne le nombre d'actions réglées. */
  var taAppliquer = function (profil) {
    var kms = taMappings()
    var n = 0
    var absentes = []
    var noms = Object.keys(profil.touches)
    var i = 0
    while (i < noms.length) {
      var t = profil.touches[noms[i]]
      var km = kms[noms[i]]
      if (km === undefined) absentes.push(noms[i])
      else {
        km.setKeyModifierAndCode(TaKeyModifier.valueFromString(t.mod), TaInput.getKey(t.key))
        n = n + 1
      }
      i = i + 1
    }
    TaKeyMapping.resetMapping()
    Client.options.save()
    if (absentes.length > 0) console.warn('touches_auto: actions absentes du jeu (mod manquant ?) : ' + absentes.join(' '))
    return n
  }

  // uuid du joueur (Rhino ne trouve pas LocalPlayer.getUUID() : propriété KubeJS `uuid`, sinon le profil)
  var taUuid = function () {
    var v = null
    try { v = Client.player.uuid } catch (e) { v = null }
    if (v === null || v === undefined) {
      try { v = Client.player.getGameProfile().getId() } catch (e2) { v = null }
    }
    if (v === null || v === undefined) v = Client.player.getName().getString()
    return String(v)
  }

  var TaConflit = Java.loadClass('net.minecraftforge.client.settings.KeyConflictContext')

  /** Touches actuelles du jeu pour la garde : { action: { key, mod, jeu, vanilla } }. */
  var taActuelles = function () {
    var res = {}
    var kms = Client.options.keyMappings
    var i = 0
    while (i < kms.length) {
      var km = kms[i]
      var jeu = true
      try { jeu = km.getKeyConflictContext().conflicts(TaConflit.IN_GAME) === true } catch (e) { jeu = true }
      // la touche d'ORIGINE du mod (celle qu'il a quand options.txt n'a pas de ligne pour lui) ; null si illisible
      var defaut = null
      try {
        var dk = String(km.getDefaultKey().getName())
        var dm = 'NONE'
        try { dm = String(km.getKeyModifierDefault().name()) } catch (e3) { dm = 'NONE' }
        defaut = { key: dk, mod: dm }
      } catch (e2) { defaut = null }
      res[String(km.getName())] = {
        key: String(km.getKey().getName()),
        mod: String(km.getKeyModifier().name()),
        jeu: jeu,
        vanilla: String(km.getCategory()).indexOf('key.categories.') === 0,
        defaut: defaut
      }
      i = i + 1
    }
    return res
  }

  /** La garde : corrige les touches de mod posées sur la voie et les univers absents ; retourne le nombre. */
  var taGarder = function (profil) {
    var corr = taGarde(profil, taActuelles())
    if (corr.length === 0) return 0
    var kms = taMappings()
    var morceaux = []
    var i = 0
    while (i < corr.length) {
      var c = corr[i]
      var km = kms[c.action]
      if (km !== undefined) {
        km.setKeyModifierAndCode(TaKeyModifier.valueFromString(c.mod), TaInput.getKey(c.key))
        morceaux.push(c.action + ' -> ' + c.mod + ' ' + c.key + ' (' + c.raison + ')')
      }
      i = i + 1
    }
    TaKeyMapping.resetMapping()
    Client.options.save()
    console.info('touches_auto: garde, ' + morceaux.length + ' touche(s) corrigee(s) : ' + morceaux.join(' ; '))
    return morceaux.length
  }

  var taDire = function (texte, couleur) {
    Client.player.tell(Text.of(texte)[couleur]())
  }

  var taJour = function () {
    try { return String(new Date().toISOString()).substring(0, 10) } catch (e) { return '0000-00-00' }
  }

  /**
   * Restauration douce des touches voulues (`cibles`). `garde` = true : seulement si le jeu a l'air d'avoir réinitialisé
   * les touches (taResetDetecte) ; false : toujours (montée de version douce). Retourne le nombre de touches remises.
   * Au plus TA_MAX_RESTAURATIONS par jour (marqueur `m`, écrit ici). Ne touche que les touches exactement à l'origine
   * du mod : les choix du joueur sont gardés.
   */
  var taRestaurerJeu = function (cibles, garde, m) {
    var act = taActuelles()
    var sig = taSignature(cibles, act)
    if (sig.total === 0) {
      console.warn('touches_auto: restauration impossible (touche d\'origine des mods illisible ou aucune action voulue connue)')
      return 0
    }
    if (garde && sig.aDefaut.length < TA_SEUIL_RESET) return 0
    var jour = taJour()
    if (!taPeutRestaurer(m, jour)) {
      console.warn('touches_auto: ' + TA_MAX_RESTAURATIONS + ' restaurations deja faites aujourd\'hui, pas de nouvelle (' + sig.aDefaut.length + ' touche(s) a l\'origine)')
      return 0
    }
    var corr = taRestaurer(cibles, act)
    if (corr.length === 0) return 0
    var kms = taMappings()
    var morceaux = []
    var i = 0
    while (i < corr.length) {
      var c = corr[i]
      var km = kms[c.action]
      if (km !== undefined) {
        km.setKeyModifierAndCode(TaKeyModifier.valueFromString(c.mod), TaInput.getKey(c.key))
        morceaux.push(c.action + ' -> ' + c.mod + ' ' + c.key)
      }
      i = i + 1
    }
    TaKeyMapping.resetMapping()
    Client.options.save()
    taCompterRestauration(m, jour)
    try { taEcrireMarqueur(m) } catch (e) { console.error('touches_auto: marqueur non ecrit (' + TA_MARQUEUR + ') : ' + e) }
    console.info('touches_auto: restauration, ' + morceaux.length + ' touche(s) revenue(s) a celle du mod remise(s) (' + sig.aDefaut.length + ' a l\'origine sur ' + sig.total + ') : ' + morceaux.join(' ; '))
    return morceaux.length
  }

  var taCommunsFait = false   // la garde de réinitialisation a passé pour cette connexion

  var taTraiter = function (force) {
    var u = global.shonenUnivers
    if (u === undefined || u.recu !== true || u.complet !== true || u.liste.length === 0) {
      if (force) taDire("Ton Éveil n'est pas encore accompli : tes touches restent celles de départ.", 'red')
      return
    }
    var profil = taProfil(u.liste)
    if (profil.univers.length === 0) return
    var sig = profil.univers.join(',') + '#' + TA_VERSION
    var uuid = taUuid()
    var m = taLireMarqueur()
    taCommunsFait = true
    if (!force && m.joueurs[uuid] === sig) {
      console.info('touches_auto: profil "' + sig + '" deja applique pour ' + uuid + ', touches du joueur gardees')
      // garde de réinitialisation (14/11) : les touches du jeu sont revenues à celles des mods (options.txt réécrit par
      // Minecraft sans les lignes des mods) : on ne remet que celles qui sont exactement à l'origine
      var nr = taRestaurerJeu(taCibles(profil), true, m)
      if (nr > 0) taDire(nr + " touche(s) de ta voie et du schéma étaient revenues à celles des mods : remises en place. Tes propres changements sont gardés.", 'gold')
      var ng = taGarder(profil)
      if (ng > 0) taDire(ng + " touche(s) d'autres mods remise(s) en place : elles prenaient une touche de ta voie (ou d'un univers que tu n'as pas).", 'gray')
      return
    }
    if (profil.conflits.length > 0) console.error('touches_auto: conflits dans le profil : ' + profil.conflits.join(', '))
    var precedent = m.joueurs[uuid]
    var memeVoie = !force && precedent !== undefined && String(precedent).split('#')[0] === profil.univers.join(',')
    if (memeVoie && TA_DOUCES[TA_VERSION] === true) {
      // version douce (8) : même voie, tables inchangées -> seulement les touches revenues à l'origine du mod
      var nd = taRestaurerJeu(taCibles(profil), false, m)
      taGarder(profil)
      m.joueurs[uuid] = sig
      try { taEcrireMarqueur(m) } catch (e) { console.error('touches_auto: marqueur non ecrit (' + TA_MARQUEUR + ') : ' + e) }
      console.info('touches_auto: profil "' + sig + '" (version douce) : ' + nd + ' touche(s) remise(s) pour ' + uuid)
      if (nd > 0) taDire('Touches de ta voie remises en place (' + nd + ') : elles étaient revenues à celles des mods. Tes propres changements sont gardés.', 'gold')
      return
    }
    var n = taAppliquer(profil)
    taGarder(profil)
    m.joueurs[uuid] = sig
    try { taEcrireMarqueur(m) } catch (e) { console.error('touches_auto: marqueur non ecrit (' + TA_MARQUEUR + ') : ' + e) }
    console.info('touches_auto: profil "' + sig + '" applique (' + n + ' actions) pour ' + uuid)
    taDire('Touches réglées pour ta voie : ' + taNomsUnivers(profil.univers) + '. Tu peux les changer dans Options > Commandes.', 'gold')
    taDire('/touches : la liste de tes touches ; /touches auto : les remettre.', 'gray')
  }

  /** Joueur sans voie (avant l'Éveil, ou serveur qui n'envoie pas les univers) : la garde de réinitialisation sur le schéma commun. */
  var taTraiterCommuns = function () {
    var m = taLireMarqueur()
    var nr = taRestaurerJeu(taCiblesCommunes(), true, m)
    if (nr > 0) taDire(nr + " touche(s) du schéma étaient revenues à celles des mods : remises en place. Tes propres changements sont gardés.", 'gold')
  }

  /** /touches : les touches ACTUELLES (celles du joueur) des actions de chaque univers de sa voie. */
  var taLister = function () {
    var u = global.shonenUnivers
    if (u === undefined || u.recu !== true || u.liste.length === 0) {
      taDire("Ta voie n'est pas encore choisie : vois docs/touches.md ou Options > Commandes.", 'gray')
      return
    }
    var kms = taMappings()
    var univers = taNettoyer(u.liste)
    var i = 0
    while (i < univers.length) {
      var t = TA_UNIVERS[univers[i]]
      var empr = []
      var ke = 0
      while (t.emprunts !== undefined && ke < t.emprunts.length) {
        if (univers.indexOf(t.emprunts[ke][2]) < 0) empr.push([t.emprunts[ke][0], t.emprunts[ke][3]])
        ke = ke + 1
      }
      var groupes = [empr.concat(t.principales).concat(t.liees), t.secondaires]
      var g = 0
      while (g < groupes.length) {
        var morceaux = []
        var k = 0
        while (k < groupes[g].length) {
          var e = groupes[g][k]
          var km = kms[e[0]]
          var touche = km === undefined ? '?' : String(km.getTranslatedKeyMessage().getString())
          morceaux.push(touche + ' ' + e[e.length === 2 ? 1 : 3])
          k = k + 1
        }
        if (morceaux.length > 0) {
          Client.player.tell(Text.of(g === 0 ? t.nom + ' : ' : '   ').gold().append(Text.of(morceaux.join(' · ')).white()))
        }
        g = g + 1
      }
      i = i + 1
    }
  }

  if (global.shonenUniversEcouteurs === undefined) global.shonenUniversEcouteurs = []
  // un seul écouteur même après un rechargement des scripts client (l'ancien est retiré)
  var taAncien = global.shonenUniversEcouteurs.indexOf(global.shonenTouchesEcouteur)
  if (global.shonenTouchesEcouteur !== undefined && taAncien >= 0) global.shonenUniversEcouteurs.splice(taAncien, 1)
  global.shonenTouchesEcouteur = function (u) {
    if (u.recu === true && u.complet === true && u.liste.length > 0) taEnAttente = { force: false }
  }
  global.shonenUniversEcouteurs.push(global.shonenTouchesEcouteur)

  NetworkEvents.dataReceived('shonen_touches', function (event) {
    var action = event.data == null ? '' : String(event.data.getString('action'))
    if (action === 'auto') taEnAttente = { force: true }
    else if (action === 'liste') {
      try { taLister() } catch (e) { console.error('touches_auto: liste : ' + e) }
    }
  })

  var taTicksSansVoie = 0
  ClientEvents.tick(function (event) {
    if (Client.player == null) { taTicksSansVoie = 0; taCommunsFait = false; return }
    if (taEnAttente === null) {
      // 10 s après l'arrivée sans que la voie soit arrivée : la garde de réinitialisation passe sur le schéma commun seul
      if (!taCommunsFait) {
        taTicksSansVoie = taTicksSansVoie + 1
        if (taTicksSansVoie >= 200) {
          taCommunsFait = true
          try { taTraiterCommuns() } catch (e) { console.error('touches_auto: communs : ' + e) }
        }
      }
      return
    }
    var force = taEnAttente.force
    taEnAttente = null
    try { taTraiter(force) } catch (e) { console.error('touches_auto: ' + e) }
  })

  global.shonenTouchesAuto = { profil: taProfil, appliquer: taAppliquer, traiter: taTraiter, garder: taGarder, version: TA_VERSION }
}
