// musculation_coach.js (startup) - les objets du coach de la salle de musculation (docs/ecole.md « Le coach »). Côté serveur ET client. Rhino : var seulement.
//   - Wonster (3 saveurs, même effet) : la boisson énergisante de la salle (nom inventé, aucune marque réelle) ; bue avant une séance, elle la raccourcit ;
//   - 4 accessoires gardés dans l'inventaire, sans durabilité : gants de musculation (force), ceinture de force (jambes), sangles de tirage (tirage),
//     serviette et gourde (le bonus dure 40 min). L'effet est dans kubejs/server_scripts/musculation.js / musculation_coach.js.
// Icônes et modèles d'objet : ceux de la fabrique des PNJ (client/overrides/kubejs/assets/shonen/{textures,models}/item/<id>), même ids que le champ `vend` du coach (pnj_ecole_c.json).
// Wonster : nom parodique assumé de Admin (un W à la place du M), aucun logo ni graphisme d'une marque réelle.

var GYS_OBJETS = [
  ['shonen:wattage_citron', 'Wonster citron', 'La boisson énergisante de la salle. Bois-la avant une séance : la prochaine ne dure que 10 secondes (5 minutes pour t\'y mettre).', 16],
  ['shonen:wattage_baies', 'Wonster baies', 'La boisson énergisante de la salle. Bois-la avant une séance : la prochaine ne dure que 10 secondes (5 minutes pour t\'y mettre).', 16],
  ['shonen:wattage_lime', 'Wonster lime', 'La boisson énergisante de la salle. Bois-la avant une séance : la prochaine ne dure que 10 secondes (5 minutes pour t\'y mettre).', 16],
  ['shonen:sport_gants', 'Gants de musculation', 'Gardés dans l\'inventaire : les séances de force durent 5 secondes de moins.', 1],
  ['shonen:sport_ceinture', 'Ceinture de force', 'Gardée dans l\'inventaire : les séances de jambes durent 5 secondes de moins.', 1],
  ['shonen:sport_sangles', 'Sangles de tirage', 'Gardées dans l\'inventaire : les séances de tirage durent 5 secondes de moins.', 1],
  ['shonen:sport_serviette_gourde', 'Serviette et gourde', 'Gardées dans l\'inventaire : le bonus d\'une séance dure 40 minutes au lieu de 30.', 1]
]

StartupEvents.registry('item', function (event) {
  var i = 0
  while (i < GYS_OBJETS.length) {
    var o = GYS_OBJETS[i]
    event.create(o[0]).displayName(o[1]).maxStackSize(o[3]).rarity('uncommon').tooltip(Text.gray(o[2]))
    i = i + 1
  }
})
