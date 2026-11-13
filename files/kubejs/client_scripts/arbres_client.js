// arbres_client.js - état des arbres façon Skyrim reçu du serveur (competences.js, canal shonen_arbres).
// Garde le texte JSON dans global.shonenArbresEtat : l'écran des constellations de Shonen Core le lit
// (fr.shonen.core.client.arbres.ArbresEtat, par réflexion sur le global de KubeJS). "" = rien reçu.
// Rhino : var seulement.

if (global.shonenArbresEtat === undefined) global.shonenArbresEtat = ''

NetworkEvents.dataReceived('shonen_arbres', function (event) {
  var d = event.data
  global.shonenArbresEtat = d == null ? '' : String(d.getString('j'))
})

ClientEvents.loggedOut(function (event) { global.shonenArbresEtat = '' })
