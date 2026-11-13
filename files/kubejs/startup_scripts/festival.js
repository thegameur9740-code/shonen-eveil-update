// festival.js (startup) - les objets du festival de nuit (Matsuri), docs/plans/festival.md. Textures : tools/ecole/festival/textures.py.
// Nourriture sous les plafonds de docs/progression.md (section 13 : Régénération et Rapidité jusqu'au II avant le niveau 100, Absorption II) :
//   - Brochette (8 Éclats) : Régénération I 8 s ; Ramen (14) : Absorption I 2 min ; Dango (5) : Rapidité I 1 min ; Thé glacé (6) : Célérité I 2 min.
//   - Ticket de loterie : donné par les jeux et les quêtes du soir, échangeable à la loterie (festival.js, côté serveur).
//   - 8 masques cosmétiques (casque sans protection : une matière d'armure propre à chacun, pour sa texture portée).
// Côté serveur ET client (le registre doit être le même). Rhino : var seulement.

var FVS_MASQUES = [
  ['kitsune', 'Masque de renard'], ['oni', "Masque d'oni"], ['tengu', 'Masque de tengu'], ['hyottoko', 'Masque de hyottoko'],
  ['okame', "Masque d'okame"], ['kappa', 'Masque de kappa'], ['dore', 'Masque doré du Matsuri'], ['lune', 'Masque de la lune du Matsuri']
]

ItemEvents.armorTierRegistry(function (event) {
  var i = 0
  while (i < FVS_MASQUES.length) {
    event.add('shonen:masque_' + FVS_MASQUES[i][0], function (tier) {
      tier.durabilityMultiplier = 100
      tier.slotProtections = [0, 0, 0, 0]
      tier.enchantmentValue = 0
      tier.equipSound = 'minecraft:item.armor.equip_leather'
      tier.repairIngredient = 'minecraft:paper'
      tier.toughness = 0.0
      tier.knockbackResistance = 0.0
    })
    i++
  }
})

StartupEvents.registry('item', function (event) {
  var i = 0
  while (i < FVS_MASQUES.length) {
    event.create('shonen:masque_' + FVS_MASQUES[i][0], 'helmet').tier('shonen:masque_' + FVS_MASQUES[i][0]).displayName(FVS_MASQUES[i][1])
    i++
  }
  event.create('shonen:ticket_festival').displayName('Ticket de loterie').maxStackSize(64)
  event.create('shonen:brochette').displayName('Brochette grillée').maxStackSize(16)
    .food(function (food) { food.hunger(6).saturation(0.6).effect('minecraft:regeneration', 160, 0, 1.0) })
  event.create('shonen:ramen').displayName('Bol de ramen').maxStackSize(16)
    .food(function (food) { food.hunger(10).saturation(0.8).effect('minecraft:absorption', 2400, 0, 1.0) })
  event.create('shonen:dango').displayName('Dango').maxStackSize(16)
    .food(function (food) { food.hunger(3).saturation(0.3).fastToEat().effect('minecraft:speed', 1200, 0, 1.0) })
  event.create('shonen:the_glace').displayName('Thé glacé').maxStackSize(16).useAnimation('drink')
    .food(function (food) { food.hunger(1).saturation(0.1).alwaysEdible().effect('minecraft:haste', 2400, 0, 1.0) })
})
