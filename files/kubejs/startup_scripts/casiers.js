// casiers.js (startup) - les deux blocs de l'école pour les tenues à venir (lot R3 point E, docs/ecole.md « Casiers et paravents ») :
//   - shonen:casier_ecole  : un casier de lycée (acier, 2 portes, 2 blocs de haut : le modèle monte dans la case du dessus, qui doit rester libre), orienté (facing) ;
//   - shonen:paravent_ecole : un paravent de six panneaux en zigzag (2 de haut, 3 de large plié : le modèle déborde d'une case de chaque côté, qui doivent rester libres), derrière lequel un élève se change.
// Posés par le générateur de l'école (tools/ecole/build_ecole_v2.py : tour-dortoir, onsen, terrain, salle de sport), jamais par un joueur : pas d'objet.
// Modèles statiques (13/11 : refaits en grand), textures faites maison : tools/casiers/make_casiers.py (client/overrides/kubejs/assets/shonen).
// Côté serveur ET client (le registre doit être le même). Rhino : var seulement ; préfixe csr.

var CSR_PROPS = Java.loadClass('net.minecraft.world.level.block.state.properties.BlockStateProperties')

StartupEvents.registry('block', function (event) {
  event.create('shonen:casier_ecole')
    .displayName('Casier')
    .hardness(50.0)
    .resistance(3600000.0)
    .soundType('metal')
    .notSolid()
    .opaque(false)
    .renderType('cutout')
    .property(CSR_PROPS.HORIZONTAL_FACING)
    .noItem()
  event.create('shonen:paravent_ecole')
    .displayName('Paravent')
    .hardness(50.0)
    .resistance(3600000.0)
    .soundType('wood')
    .notSolid()
    .opaque(false)
    .renderType('cutout')
    .box(0, 0, 4, 16, 16, 12)
    .noCollision()
    .noItem()
})
