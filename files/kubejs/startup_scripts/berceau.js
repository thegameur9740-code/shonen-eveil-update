// berceau.js (startup) - le berceau du bébé (étape 7 de la vie de l'école, docs/plans/vie-ecole.md « Les enfants »).
//   shonen:berceau : un berceau en bois à bascule, couverture bleu clair (neutre : la même pour tous). Posé par enfants.js près de la Pierre de foyer à la naissance,
//   retiré quand l'enfant n'est plus un bébé ; jamais un objet (noItem), presque indestructible (le foyer est protégé par FTB Chunks).
// Modèle statique fait de boîtes, textures du jeu (épicéa, laine) : client/overrides/kubejs/assets/shonen. Côté serveur ET client. Rhino : var seulement ; préfixe brc.

StartupEvents.registry('block', function (event) {
  event.create('shonen:berceau')
    .displayName('Berceau')
    .hardness(50.0)
    .resistance(3600000.0)
    .soundType('wood')
    .notSolid()
    .opaque(false)
    .renderType('cutout')
    .box(0, 0, 2, 16, 8, 14)
    .noItem()
})
