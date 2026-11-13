// bar.js - les objets du bar de la grande boutique d'Orin (lot B2 du 11/11, docs/plans/boutique-orin-catalogues.md).
// Objets et textures à nous (tools/ecole/textures_bar.py) ; rien d'une vraie marque. Prix : tools/ecole/catalogues/bar.json.
// Tout reste sous les plafonds de docs/progression.md (section 13 : Rapidité permise II, Régénération II) et sous la
// ration de l'école (6 PV, 20 Éclats) :
//   - Canette W : se boit même rassasié ; l'effet (Rapidité I + Célérité I, 3 min) et la recharge de 5 min sont donnés
//     par kubejs/server_scripts/catalogues.js (pas ici : la recharge doit survivre à une déconnexion) ;
//   - Soda cerise : 4 PV (soin instantané I) ; Jus de baies : Régénération I 10 s (environ 4 PV) ;
//   - Sandwich du bar : 8 de faim ; Chips : 3 de faim, vite mangé.
StartupEvents.registry('item', function (event) {
  event.create('shonen:canette_w').displayName('Canette W').maxStackSize(16).useAnimation('drink')
    .food(function (food) { food.hunger(0).saturation(0).alwaysEdible() })
  event.create('shonen:soda_cerise').displayName('Soda cerise').maxStackSize(16).useAnimation('drink')
    .food(function (food) { food.hunger(1).saturation(0.1).alwaysEdible().effect('minecraft:instant_health', 1, 0, 1.0) })
  event.create('shonen:jus_baies').displayName('Jus de baies').maxStackSize(16).useAnimation('drink')
    .food(function (food) { food.hunger(1).saturation(0.1).alwaysEdible().effect('minecraft:regeneration', 200, 0, 1.0) })
  event.create('shonen:sandwich_bar').displayName('Sandwich du bar').maxStackSize(16)
    .food(function (food) { food.hunger(8).saturation(0.6) })
  event.create('shonen:chips').displayName('Chips').maxStackSize(16)
    .food(function (food) { food.hunger(3).saturation(0.2).fastToEat() })
})
