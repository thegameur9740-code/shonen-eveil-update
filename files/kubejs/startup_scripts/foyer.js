// foyer.js (startup) - les deux objets de la maison (étape 5 de la vie de l'école, docs/plans/vie-ecole.md « Maison et lit double ») :
//   - la Pierre de foyer (bloc) : posée dans le monde normal, elle fonde le foyer du joueur (kubejs/server_scripts/foyer.js) ;
//   - le Lit double (objet) : deux lits côte à côte, posé chez soi (même script).
// Côté serveur ET client (le registre doit être le même). Textures faites maison : tools/foyer/make_textures.py
// (client/overrides/kubejs/assets/shonen/textures/block et item). Rhino : var seulement.

StartupEvents.registry('block', function (event) {
  event.create('shonen:pierre_de_foyer')
    .displayName('Pierre de foyer')
    .hardness(3.0)
    .resistance(12.0)
    .tagBlock('minecraft:mineable/pickaxe')
    .soundType('stone')
    .textureAll('shonen:block/pierre_de_foyer_cote')
    .texture('up', 'shonen:block/pierre_de_foyer_haut')
    .texture('down', 'shonen:block/pierre_de_foyer_cote')
})

StartupEvents.registry('item', function (event) {
  event.create('shonen:lit_double').maxStackSize(16).rarity('uncommon').displayName('Lit double')
})
