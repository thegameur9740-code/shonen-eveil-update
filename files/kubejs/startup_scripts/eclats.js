// eclats.js - les objets de la monnaie commune (docs/plans/monnaies.md, validée par Admin le 03/11) : Éclat (1),
// Éclat taillé (10), Éclat pur (100), en piles de 64 ; et les deux objets du Comptoir de l'école : la Clé de revanche
// (refaire un Grand Ennemi déjà vaincu, sa clé de boss dans le NBT `shonen_cle`) et le Parchemin d'oubli (remise à zéro
// d'un arbre, son arbre dans le NBT `shonen_arbre`). Ce que font ces objets : kubejs/server_scripts/comptoir.js.
// Côté serveur ET client (le registre des objets doit être le même) ; textures (pièces : dessins de Cowork validés par
// Admin, design/eclats ; clé et parchemin : tools/eclats/make_textures.ps1) et noms dans
// client/overrides/kubejs/assets/shonen (textures/item, lang).
// Rhino : var seulement.

StartupEvents.registry('item', function (event) {
  event.create('shonen:eclat').maxStackSize(64).displayName('Éclat')
  event.create('shonen:eclat_taille').maxStackSize(64).displayName('Éclat taillé')
  event.create('shonen:eclat_pur').maxStackSize(64).rarity('uncommon').displayName('Éclat pur')
  event.create('shonen:cle_revanche').maxStackSize(16).rarity('rare').displayName('Clé de revanche')
  event.create('shonen:parchemin_oubli').maxStackSize(1).rarity('uncommon').displayName("Parchemin d'oubli")
})
