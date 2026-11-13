// musculation.js (startup) - le bloc des machines de la salle de musculation de la pagode (lot S4, docs/ecole.md « Salle de musculation, machines »).
// UN seul bloc, `shonen:machine_musculation`, avec 3 propriétés : machine (0..7 = l'une des 8 machines), part (0..15 = une cellule de la machine),
// repos (vrai = les pièces mobiles sont dans le modèle ; faux = une séance tourne, le serveur les montre en entités d'affichage).
// SANS COLLISION : le joueur assis est dans l'emprise de la machine, une collision pleine l'étouffait (retour de Admin, 12/11). Modèles, textures et blockstate faits maison : tools/gym/make_machines.py (client/overrides/kubejs/assets/shonen). Le bloc est posé par
// kubejs/server_scripts/musculation.js (jamais par un joueur : pas d'objet). Côté serveur ET client. Rhino : var seulement.

var GYS_ENTIER = Java.loadClass('net.minecraft.world.level.block.state.properties.IntegerProperty')
var GYS_BOOL = Java.loadClass('net.minecraft.world.level.block.state.properties.BooleanProperty')

StartupEvents.registry('block', function (event) {
  event.create('shonen:machine_musculation')
    .displayName('Machine de musculation')
    .hardness(50.0)
    .resistance(3600000.0)
    .soundType('metal')
    .notSolid()
    .opaque(false)
    .renderType('cutout')
    .box(0, 0, 0, 16, 16, 16)
    .noCollision()
    .noItem()
    .property(GYS_ENTIER.create('machine', 0, 7))
    .property(GYS_ENTIER.create('part', 0, 15))
    .property(GYS_BOOL.create('tourne'))
    .property(GYS_BOOL.create('repos'))
})
