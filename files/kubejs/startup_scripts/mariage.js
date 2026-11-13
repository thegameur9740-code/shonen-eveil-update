// mariage.js (startup) - l'objet du mariage (étape 6 de la vie de l'école, docs/plans/vie-ecole.md « Drague et mariage ») : la Bague de mariage,
// vendue 1 500 Éclats par Orin (comptoir.js), donnée à la demande en mariage (kubejs/server_scripts/mariage.js). Texture : tools/mariage/make_bague.py.
// Côté serveur ET client (le registre doit être le même). Rhino : var seulement.

StartupEvents.registry('item', function (event) {
  event.create('shonen:bague_mariage').maxStackSize(1).rarity('rare').displayName('Bague de mariage')
})
