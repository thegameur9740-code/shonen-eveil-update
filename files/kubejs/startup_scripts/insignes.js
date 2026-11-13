// insignes.js - les deux objets de la boîte à insignes (A9, 11/11 ; docs/plans/insignes.md ;
// kubejs/server_scripts/insignes_boite.js) : la « Boîte à insignes » (clic droit : ouvre la boîte, donnée à tous) et
// l'« Insigne » (la copie d'un insigne ressorti de la boîte : son pin est choisi par CustomModelData, son nom et son
// propriétaire sont dans le NBT). Textures et modèles : tools/insignes/make_pins.py --installer
// (client/overrides/kubejs/assets/shonen). Côté serveur ET client (le registre doit être le même). Rhino : var seulement.

StartupEvents.registry('item', function (event) {
  event.create('shonen:boite_insignes').maxStackSize(1).rarity('uncommon').displayName('Boîte à insignes')
  event.create('shonen:insigne').maxStackSize(1).rarity('rare').displayName('Insigne')
})
