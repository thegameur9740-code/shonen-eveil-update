// tenue.js - la tenue de l'Éveillé et la ration de l'école (docs/progression.md section 16, aide 4 ; dessins de Cowork,
// design/tenue, validés par Admin le 06/11).
//   - 7 jeux de 4 pièces (une matière par univers, pour sa texture portée) : protection 2 / 4 / 3 / 1 (total 10, entre
//     le cuir à 7 et les mailles à 12), solidité de l'armure en fer (x15), sans robustesse ; le plafond de réduction du
//     budget (Shonen Core, Puissance) s'applique par-dessus comme pour toute armure.
//   - la ration de l'école : 6 PV rendus en 2 s (Régénération IV pendant 40 ticks : un PV toutes les 6 ticks), se mange
//     même rassasié ; Orin en vend (comptoir.js) ; 5 dans chaque kit (kits.js).
// Textures et noms : client/overrides/kubejs/assets/shonen (textures/item, textures/models/armor, lang).
// Côté serveur ET client (le registre doit être le même). Rhino : var seulement.

var TENUE_UNIVERS = ['jjk', 'onepiece', 'bleach', 'dbz', 'sololeveling', 'naruto', 'mha']
// [suffixe, type KubeJS, nom en jeu]
var TENUE_PIECES = [
  ['casque', 'helmet', "Bandeau de l'Éveillé"],
  ['plastron', 'chestplate', "Veste de l'Éveillé"],
  ['jambieres', 'leggings', "Pantalon de l'Éveillé"],
  ['bottes', 'boots', "Guêtres de l'Éveillé"]
]

ItemEvents.armorTierRegistry(function (event) {
  var i = 0
  while (i < TENUE_UNIVERS.length) {
    event.add('shonen:tenue_eveille_' + TENUE_UNIVERS[i], function (tier) {
      tier.durabilityMultiplier = 15        // fer
      tier.slotProtections = [1, 3, 4, 2]   // pieds, jambes, torse, tête
      tier.enchantmentValue = 12
      tier.equipSound = 'minecraft:item.armor.equip_leather'
      tier.repairIngredient = 'minecraft:leather'
      tier.toughness = 0.0
      tier.knockbackResistance = 0.0
    })
    i++
  }
})

StartupEvents.registry('item', function (event) {
  var i = 0
  while (i < TENUE_UNIVERS.length) {
    var u = TENUE_UNIVERS[i]
    var k = 0
    while (k < TENUE_PIECES.length) {
      event.create('shonen:tenue_eveille_' + u + '_' + TENUE_PIECES[k][0], TENUE_PIECES[k][1])
        .tier('shonen:tenue_eveille_' + u)
        .displayName(TENUE_PIECES[k][2])
      k++
    }
    i++
  }
  event.create('shonen:ration_ecole').displayName("Ration de l'école").maxStackSize(16)
    .food(function (food) {
      food.hunger(4).saturation(0.3).alwaysEdible().fastToEat().effect('minecraft:regeneration', 40, 3, 1.0)
    })
})
