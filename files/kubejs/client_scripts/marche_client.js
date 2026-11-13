// marche_client.js - menus de vente / d'achat et compteur d'Éclats reçus du serveur (09/11).
//   - canal shonen_marche (server_scripts/marche.js) : le menu en JSON -> global.shonenMarcheJson, et un numéro qui
//     change à chaque envoi (global.shonenMarcheN) ;
//   - canal shonen_eclats (server_scripts/eclats_solde.js) : le solde (global.shonenEclatsSolde) et le dernier gain ou
//     dépense (global.shonenEclatsGain, numéro global.shonenEclatsGainN).
// Shonen Core les lit par réflexion sur le global de KubeJS (fr.shonen.core.client.marche.MarcheClient) : il ouvre
// l'écran du menu et dessine le compteur en haut à droite. Les valeurs sont gardées en texte (pas de Map Java).
// Rhino : var seulement.

if (global.shonenMarcheN === undefined) global.shonenMarcheN = '0'
if (global.shonenMarcheJson === undefined) global.shonenMarcheJson = ''
if (global.shonenEclatsSolde === undefined) global.shonenEclatsSolde = ''
if (global.shonenEclatsGainN === undefined) global.shonenEclatsGainN = '0'
if (global.shonenEclatsGain === undefined) global.shonenEclatsGain = '0'

NetworkEvents.dataReceived('shonen_marche', function (event) {
  var d = event.data
  global.shonenMarcheJson = d == null ? '' : String(d.getString('j'))
  global.shonenMarcheN = String(Number(global.shonenMarcheN) + 1)
})

NetworkEvents.dataReceived('shonen_eclats', function (event) {
  var d = event.data
  if (d == null) return
  global.shonenEclatsSolde = String(d.getInt('n'))
  var g = d.getInt('g')
  if (g !== 0) {
    global.shonenEclatsGain = String(g)
    global.shonenEclatsGainN = String(Number(global.shonenEclatsGainN) + 1)
  }
})

ClientEvents.loggedOut(function (event) {
  global.shonenMarcheJson = ''
  global.shonenEclatsSolde = ''
})
