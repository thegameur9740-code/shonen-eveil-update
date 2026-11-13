// Shonen Eveil - les energies au meme endroit (lot I5 section 4, idee 37 ; client uniquement : ce fichier n'est copie que
// dans l'instance joueur). En bas a gauche, au-dessus de la barre d'objets, une barre fine par univers du joueur (2 au
// plus), a la couleur de l'univers, avec le nom de l'energie et sa valeur :
//   Energie occulte (JujutsuCraft : PlayerCursePower / PlayerCursePowerMAX), Reiatsu (Bleach Reborn : energie 0..1 x
//   cap), Ki (DragonMine Z : ressources / max), Chakra (Ninshu : Chakra / MaxChakra), Mana (Solo Leveling : MP / Mana),
//   Alter (Quirks Unchained : pas d'energie dans le mod, seulement la charge d'un Alter pendant qu'on la tient).
// Les valeurs sont lues sur le joueur local : chaque mod les synchronise deja pour son propre affichage.
// Barres d'origine cachees : Bleach (calque bleachreborn:soul, bord droit) et DragonMine Z (ki du style compact,
// L2_KI). Restent : le chakra dans le panneau de Ninshu (avec l'endurance et les ryo), le mana dans le panneau Systeme
// de Solo Leveling (qui porte aussi la vie) ; le panneau de JJK est deja cache par Shonen Core.
// Les univers du joueur : global.shonenUnivers (shonen_univers.js, envoye par le serveur).
// Rhino : var et while, pas de fonction flechee.
var $EnMF = Java.loadClass('net.minecraftforge.common.MinecraftForge')
var $EnPrio = Java.loadClass('net.minecraftforge.eventbus.api.EventPriority')
var $EnOvPre = Java.loadClass('net.minecraftforge.client.event.RenderGuiOverlayEvent$Pre')
var $EnGuiPost = Java.loadClass('net.minecraftforge.client.event.RenderGuiEvent$Post')
var $EnMc = Java.loadClass('net.minecraft.client.Minecraft')

var shonenEn = { errors: 0, jjk: null, bleach: null, dmzStats: null, dmzCap: null, ninshu: null, solo: null, mha: null,
  dmzLayout: null, dmzStyle: null, dmzElement: null, dmzKiCache: false }
function shonenEnClasse(nom) { try { return Java.loadClass(nom) } catch (e) { return null } }
shonenEn.jjk = shonenEnClasse('net.mcreator.jujutsucraft.network.JujutsucraftModVariables')
shonenEn.bleach = shonenEnClasse('littlebreadloaf.bleachreborn.bleach.ExtendedPlayerProvider')
shonenEn.dmzStats = shonenEnClasse('com.dragonminez.common.stats.StatsProvider')
shonenEn.dmzCap = shonenEnClasse('com.dragonminez.common.stats.StatsCapability')
shonenEn.ninshu = shonenEnClasse('net.saberart.ninshuorigins.common.utils.CapabilityUtils')
shonenEn.solo = shonenEnClasse('net.solocraft.network.SololevelingModVariables')
shonenEn.mha = shonenEnClasse('net.mcreator.quirksunchained.network.QuirksunchainedModVariables')
shonenEn.dmzLayout = shonenEnClasse('com.dragonminez.client.gui.hud.layout.HudLayout')
shonenEn.dmzStyle = shonenEnClasse('com.dragonminez.client.gui.hud.HudStyle')
shonenEn.dmzElement = shonenEnClasse('com.dragonminez.client.gui.hud.layout.HudElement')

// univers (noms de shonen_univers.js) -> nom de l'energie, couleur (0xRRGGBB)
var SHONEN_EN_DEFS = {
  jjk: ['Énergie occulte', 0x9B59B6], bleach: ['Reiatsu', 0x5DADE2], dbz: ['Ki', 0xF39C12], naruto: ['Chakra', 0x3498DB],
  sololeveling: ['Mana', 0x2E86C1], mha: ['Alter', 0x27AE60]
}

function shonenEnLog(msg) { if (shonenEn.errors < 3) console.error('shonen_energies: ' + msg); shonenEn.errors++ }

function shonenEnCap(p, classe) {
  var o = p.getCapability(classe.PLAYER_VARIABLES_CAPABILITY, null).resolve()
  return o.isPresent() ? o.get() : null
}

/** [actuel, max] de l'energie de l'univers u pour le joueur local, ou null (rien a montrer). */
function shonenEnValeur(p, u) {
  if (u === 'jjk' && shonenEn.jjk != null) {
    var v = shonenEnCap(p, shonenEn.jjk)
    return v == null ? null : [Number(v.PlayerCursePower), Number(v.PlayerCursePowerMAX)]
  }
  if (u === 'bleach' && shonenEn.bleach != null) {
    var o = p.getCapability(shonenEn.bleach.BLEACH_PLAYER).resolve()
    if (!o.isPresent()) return null
    var b = o.get()
    var cap = Number(b.getCurrentCap())
    return [Number(b.getCurrentEnergy()) * cap, cap]
  }
  if (u === 'dbz' && shonenEn.dmzStats != null) {
    var od = shonenEn.dmzStats.get(shonenEn.dmzCap.INSTANCE, p).resolve()
    if (!od.isPresent()) return null
    var s = od.get()
    if (!s.getStatus().isHasCreatedCharacter()) return null
    return [Number(s.getResources().getCurrentEnergy()), Number(s.getMaxEnergy())]
  }
  if (u === 'naruto' && shonenEn.ninshu != null) {
    var nv = shonenEn.ninshu.getPlayerVariables(p)
    if (nv == null) return null
    return [Number(nv.getData('Chakra', 'java.lang.Integer')), Number(nv.getData('MaxChakra', 'java.lang.Integer'))]
  }
  if (u === 'sololeveling' && shonenEn.solo != null) {
    var sv = shonenEnCap(p, shonenEn.solo)
    return sv == null ? null : [Number(sv.MP), Number(sv.Mana)]
  }
  if (u === 'mha' && shonenEn.mha != null) {
    var mv = shonenEnCap(p, shonenEn.mha)
    if (mv == null || !mv.ChargeActive) return null       // pas d'energie dans le mod : la charge d'un Alter seulement
    return [Number(mv.ChargeAmount), Number(mv.ChargeMax)]
  }
  return null
}

// cache le ki du style compact de DragonMine Z (une fois, en memoire, comme shonen_hud.js pour la vie)
function shonenEnCacherKiDmz() {
  if (shonenEn.dmzKiCache || shonenEn.dmzLayout == null || shonenEn.dmzElement == null) return
  if (!shonenEn.dmzStyle.COMPACT.equals(shonenEn.dmzStyle.current())) return
  var pl = shonenEn.dmzLayout.placement(shonenEn.dmzStyle.COMPACT, shonenEn.dmzElement.L2_KI).copy()
  pl.setVisible(false)
  shonenEn.dmzLayout.setPlacement(shonenEn.dmzStyle.COMPACT, shonenEn.dmzElement.L2_KI, pl)
  shonenEn.dmzKiCache = true
}

$EnMF.EVENT_BUS.addListener($EnPrio.HIGH, false, $EnOvPre, function (event) {
  try {
    if (String(event.getOverlay().id()) === 'bleachreborn:soul' && global.shonenUnivers !== undefined && global.shonenUnivers.recu) event.setCanceled(true)
  } catch (e) { shonenEnLog(e) }
})

$EnMF.EVENT_BUS.addListener($EnPrio.NORMAL, false, $EnGuiPost, function (event) {
  try {
    var mc = $EnMc.getInstance()
    var p = mc.player
    if (p == null || mc.options.hideGui || p.isSpectator() || global.shonenUnivers === undefined || !global.shonenUnivers.recu) return
    shonenEnCacherKiDmz()
    var liste = global.shonenUnivers.liste
    var g = event.getGuiGraphics()
    var w = g.guiWidth(), h = g.guiHeight()
    var largeur = Math.max(40, Math.min(90, Math.floor(w / 2) - 91 - 12))
    var x = 6
    var y = h - 8
    var n = 0
    var i = 0
    while (i < liste.length && n < 2) {
      var u = String(liste[i])
      var def = SHONEN_EN_DEFS[u]
      var val = def === undefined ? null : shonenEnValeur(p, u)
      if (val !== null && val[1] > 0) {
        var f = Math.max(0, Math.min(1, val[0] / val[1]))
        var top = y - 6
        g.fill(x - 1, top - 1, x + largeur + 1, top + 5, (0xC0000000 | 0))                    // cadre fin
        g.fill(x, top, x + Math.round(largeur * f), top + 4, 0xFF000000 | def[1])          // la barre, couleur de l'univers
        var texte = def[0] + ' ' + Math.floor(val[0]) + ' / ' + Math.floor(val[1])
        g.drawString(mc.font, texte, x, top - 10, 0xFFFFFF, true)
        y = top - 14
        n = n + 1
      }
      i = i + 1
    }
  } catch (e) { shonenEnLog(e) }
})
console.info('shonen_energies: barres des energies enregistrees')
