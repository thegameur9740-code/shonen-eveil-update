// lounge_verres.js (startup) - les trois verres que les femmes du salon gothique apportent au joueur (13/11/2026, docs/ecole.md « Gestes du salon »). Cote serveur ET client. Rhino : var seulement.
// Chacun se boit (animation « drink »), petit effet sage, noms inventes. Icones et modeles : client/overrides/kubejs/assets/shonen/{textures,models}/item/<id> (tools/vendeuses/lounge_verres_icones.py).
StartupEvents.registry('item', function (event) {
  event.create('shonen:verre_ombre').displayName('Verre des ombres').maxStackSize(8).useAnimation('drink').rarity('uncommon')
    .tooltip(Text.gray('Le cocktail violet du salon gothique. Régénération pendant 8 secondes.'))
    .food(function (food) { food.hunger(1).saturation(0.2).alwaysEdible().effect('minecraft:regeneration', 160, 0, 1.0) })
  event.create('shonen:verre_cuivre').displayName('Verre de cuivre').maxStackSize(8).useAnimation('drink').rarity('uncommon')
    .tooltip(Text.gray('La coupe ambrée de Barkhatka. Absorption pendant 20 secondes.'))
    .food(function (food) { food.hunger(1).saturation(0.2).alwaysEdible().effect('minecraft:absorption', 400, 0, 1.0) })
  event.create('shonen:verre_rappel').displayName('Rappel').maxStackSize(8).useAnimation('drink').rarity('uncommon')
    .tooltip(Text.gray('Le shot orange de Gromka. Vitesse pendant 15 secondes.'))
    .food(function (food) { food.hunger(1).saturation(0.2).alwaysEdible().effect('minecraft:speed', 300, 0, 1.0) })
})
