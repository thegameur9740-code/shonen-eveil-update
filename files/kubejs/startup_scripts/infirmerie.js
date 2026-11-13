// infirmerie.js (startup) - les 7 objets de soin de l'infirmerie (un par univers), étape 4 de la vie de l'école (docs/plans/vie-ecole.md).
// Icônes et modèles : client/overrides/kubejs/assets/shonen/{textures,models}/item/soin_<univers>.png|json (lot P1). Noms et infobulles : ceux du
// champ « soin » de pnj_ecole_c.json (le test Node scripts/tests/infirmerie.test.js compare). L'EFFET est côté serveur (infirmerie.js, clic droit) :
// un soin modeste, le même pour les 7. Donnés par l'infirmière quand elle te soigne, jamais vendus. Côté serveur ET client. Rhino : var seulement.

var INFS_OBJETS = [
  ["shonen:soin_shinigami", "Baume des âmes", "Un pot de baume au lilas : on le dit doux pour les blessures, et pour les âmes."],
  ["shonen:soin_ninja", "Pansement d'herbes", "Un rouleau de bande propre, une feuille fraîche dessus. Ça pique un peu, ça soigne beaucoup."],
  ["shonen:soin_heros", "Trousse de secours", "La petite valise des héros : un plus bien net sur le couvercle, et de quoi remettre debout."],
  ["shonen:soin_exorciste", "Talisman de purification", "Un sceau de papier et une plaquette de bois : il chasse la fatigue des mauvais jours."],
  ["shonen:soin_pirate", "Rhum de soin", "Une bouteille brune au bouchon de liège. Pour la plaie, pas pour la soif (ou presque)."],
  ["shonen:soin_combattant", "Tonique du dojo", "Une gourde d'orange et de miel : le tonique que les élèves boivent après l'entraînement."],
  ["shonen:soin_chasseur", "Cristal de soin", "Un éclat de cristal bleu de la guilde : il brille doucement tant qu'il reste de quoi guérir."]
]

StartupEvents.registry('item', function (event) {
  var i = 0
  while (i < INFS_OBJETS.length) {
    event.create(INFS_OBJETS[i][0]).displayName(INFS_OBJETS[i][1]).maxStackSize(8).rarity('uncommon').tooltip(Text.gray(INFS_OBJETS[i][2]))
    i = i + 1
  }
})
