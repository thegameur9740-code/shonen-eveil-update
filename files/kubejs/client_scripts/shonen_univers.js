// priority: 100
// shonen_univers.js - les univers de la voie du joueur, côté client (P2-5). Script client KubeJS (instance joueur).
// Rhino : var + while seulement, pas de let/const/fonctions fléchées.
//
// Le serveur (kubejs/server_scripts/univers_client.js) envoie sur le canal « shonen_univers » la liste des univers
// de la voie (Pouvoir > Arme > Race), à la connexion et à chaque changement. Ce script la garde dans :
//
//   global.shonenUnivers = {
//     recu:    true dès que le serveur a parlé dans cette session (false avant, et après la déconnexion),
//     complet: true quand l'Éveil est accompli,
//     liste:   ['onepiece', 'bleach']   (tableau JS, ordre de priorité ; noms : dbz bleach jjk onepiece sololeveling naruto mha),
//     texte:   'onepiece,bleach',
//     n:       compteur, +1 à chaque mise à jour
//   }
//   global.shonenUniversA('bleach')   -> true / false
//   global.shonenUniversTexte         -> 'onepiece,bleach' (aussi lisible en Java :
//       String.valueOf(dev.latvian.mods.kubejs.BuiltinKubeJSPlugin.GLOBAL.get("shonenUniversTexte")) ; "" = rien reçu)
//   global.shonenUniversEcouteurs.push(function (u) { ... })   appelé à chaque mise à jour (u = global.shonenUnivers)
//
// Avant toute donnée du serveur (ou sans ce serveur), recu = false : ne rien masquer / ne rien changer dans ce cas.

// (06/11 : naruto et mha manquaient, un joueur Naruto ou MHA seul avait une liste vide : touches automatiques et HUD
// de sa voie jamais posés ; la liste suit celle du serveur, UC_UNIVERS de univers_client.js, contrôlé par touches-auto.test.js)
var SU_CONNUS = ['dbz', 'bleach', 'jjk', 'onepiece', 'jojo', 'sololeveling', 'naruto', 'mha']
if (global.shonenUniversEcouteurs === undefined) global.shonenUniversEcouteurs = []

function suMaj(recu, texte, complet) {
  var liste = []
  var morceaux = texte === '' ? [] : texte.split(',')
  var i = 0
  while (i < morceaux.length) {
    if (SU_CONNUS.indexOf(morceaux[i]) >= 0 && liste.indexOf(morceaux[i]) < 0) liste.push(morceaux[i])
    i = i + 1
  }
  var avant = global.shonenUnivers
  var u = { recu: recu, complet: complet, liste: liste, texte: liste.join(','), n: (avant === undefined ? 0 : avant.n) + 1 }
  global.shonenUnivers = u
  global.shonenUniversTexte = u.texte
  var e = global.shonenUniversEcouteurs
  var k = 0
  while (k < e.length) {
    try { e[k](u) } catch (err) { console.error('shonen_univers: ecouteur ' + k + ' : ' + err) }
    k = k + 1
  }
}

global.shonenUniversA = function (nom) {
  var u = global.shonenUnivers
  return u !== undefined && u.recu === true && u.liste.indexOf(String(nom)) >= 0
}

if (global.shonenUnivers === undefined) suMaj(false, '', false)

NetworkEvents.dataReceived('shonen_univers', function (event) {
  var d = event.data
  var texte = d == null ? '' : String(d.getString('univers'))
  var complet = d != null && d.getBoolean('complet') === true
  suMaj(true, texte, complet)
  console.info('shonen_univers: univers "' + global.shonenUnivers.texte + '" complet=' + complet)
})

ClientEvents.loggedOut(function (event) { suMaj(false, '', false) })
