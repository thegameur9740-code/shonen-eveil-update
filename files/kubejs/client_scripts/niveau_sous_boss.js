// niveau_sous_boss.js - la ligne « Niv. N · x / y XP » descend sous les barres de boss (script client KubeJS).
// Rhino : var + while seulement.
//
// Qui dessine quoi : la ligne de niveau est un objet du Painter KubeJS envoye par le SERVEUR (niveaux.js, nvHud :
// shonen_niv_txt a y = 2, shonen_niv_fond et shonen_niv_barre a y = 10 ; coeur_convergence.js repeint shonen_niv_txt et
// shonen_niv_barre). La barre de boss de Minecraft est dessinee en haut au centre (premiere barre : barre a y = 12, titre a
// y = 3 ; 19 pixels par barre, BossHealthOverlay) : les deux se recouvraient.
// Correctif : Forge annonce chaque barre de boss (CustomizeGuiOverlayEvent$BossEventProgress : y de la barre + increment). On
// garde le bas de la derniere barre ; a chaque image, avant le dessin du Painter (ClientEvents.paintScreen), on rend aux objets
// niveau un y decale : y de base + (bas - 11). Une barre : 31 - 11 = 20 de decalage (texte a 22, apres la barre qui finit a 17) ;
// deux barres : 50 - 11 = 39. Sans barre de boss : decalage 0, rien ne change. Si le serveur repeint (y = 2), le decalage est
// remis a l'image suivante, avant le dessin. Si les barres stylisees (design-interface.md) changent l'increment (30), le
// calcul le suit : il lit l'increment de l'evenement.
// NON VERIFIE EN JEU (ecrit sans client).

var SNB_BASE = { shonen_niv_txt: 2, shonen_niv_fond: 10, shonen_niv_barre: 10 }
var SNB_NOMS = ['shonen_niv_txt', 'shonen_niv_fond', 'shonen_niv_barre']
var SNB_Painter = Java.loadClass('dev.latvian.mods.kubejs.client.painter.Painter')
var SNB_Fixe = Java.loadClass('dev.latvian.mods.unit.FixedNumberUnit')
var SNB_Forge = Java.loadClass('net.minecraftforge.common.MinecraftForge')
var SNB_Priorite = Java.loadClass('net.minecraftforge.eventbus.api.EventPriority')
var SNB_Pre = Java.loadClass('net.minecraftforge.client.event.RenderGuiOverlayEvent$Pre')
var SNB_Barre = Java.loadClass('net.minecraftforge.client.event.CustomizeGuiOverlayEvent$BossEventProgress')
var SNB_Overlays = Java.loadClass('net.minecraftforge.client.gui.overlay.VanillaGuiOverlay')

// global.shonenNivBossBas : bas de la derniere barre de boss de l'image en cours (0 = aucune). Nombre simple dans global.
if (global.shonenNivBossBas === undefined) global.shonenNivBossBas = 0
if (global.shonenNivBossErr === undefined) global.shonenNivBossErr = 0

// Les ecouteurs Forge ne se retirent pas : un seul enregistrement, meme apres /kubejs reload (F3+T).
if (global.shonenNivBossHook === undefined) {
  global.shonenNivBossHook = 1
  var SNB_ID = SNB_Overlays.BOSS_EVENT_PROGRESS.id()
  // debut du dessin des barres : on repart de zero (si un mod annule l'overlay, il reste a zero)
  SNB_Forge.EVENT_BUS.addListener(SNB_Priorite.LOWEST, true, SNB_Pre, function (ev) {
    try { if (SNB_ID.equals(ev.getOverlay().id())) global.shonenNivBossBas = 0 } catch (e) { }
  })
  // une barre : son bas (y + increment) ; on garde le plus grand (y est cumulatif, mais ne supposons rien)
  SNB_Forge.EVENT_BUS.addListener(SNB_Priorite.LOWEST, true, SNB_Barre, function (ev) {
    try {
      var bas = ev.getY() + ev.getIncrement()
      if (bas > Number(global.shonenNivBossBas)) global.shonenNivBossBas = bas
    } catch (e) { }
  })
}

// Pose le y des objets niveau (appele a chaque image juste avant le dessin du Painter).
function snbAppliquer() {
  var bas = Number(global.shonenNivBossBas)
  var decalage = bas > 0 ? Math.max(0, bas - 11) : 0
  var i = 0
  while (i < SNB_NOMS.length) {
    var o = SNB_Painter.INSTANCE.getObject(SNB_NOMS[i])
    if (o != null) o.y = SNB_Fixe.of(SNB_BASE[SNB_NOMS[i]] + decalage)
    i = i + 1
  }
}

ClientEvents.paintScreen(function (event) {
  try { snbAppliquer() } catch (e) {
    if (global.shonenNivBossErr < 3) console.error('niveau_sous_boss: ' + e)
    global.shonenNivBossErr = global.shonenNivBossErr + 1
  }
})
