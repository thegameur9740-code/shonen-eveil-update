// Shonen Eveil - une seule barre de vie (client uniquement : ce fichier n'est copie que dans l'instance joueur).
// Ce qui s'affichait (verifie en jeu) :
//  - Solo Leveling Reborn montre a TOUS les joueurs en survie son panneau "Systeme" (PV, PM, DEF, FAIM,
//    FATIGUE) quand sa variable joueur CustomHUD est vraie (vraie par defaut) et masque alors les coeurs,
//    l'armure, la faim et l'xp vanilla (DisableHealthbar & co, priorite NORMAL) ;
//  - Bleach Reborn annule TOUJOURS les coeurs et l'armure vanilla pour les redessiner lui-meme (HealthHud,
//    priorite NORMAL, sans regarder si un autre mod les a deja caches) ;
//  - DragonMine Z annule les coeurs quand le personnage DMZ existe et affiche sa propre barre de vie ;
//  - l'ordre entre ces ecouteurs NORMAL n'est pas garanti : on voyait 2 ou 3 barres de vie.
// Regle appliquee ici (priorite HIGH, donc avant les trois) :
//  - panneau Systeme affiche  -> lui seul montre la vie : coeurs + armure annules, barre de vie DMZ masquee ;
//  - panneau coupe + perso DMZ -> la barre de vie DMZ revient (style compact), coeurs annules ;
//  - panneau coupe, pas de DMZ -> coeurs normaux (ceux de Bleach).
// La barre de vie DMZ est basculee en memoire (HudLayout.setPlacement du style compact), seulement quand le
// style DMZ courant est "compact" (le style livre par config/dragonminez/hud_layout.json).
// (Pas de variable locale dans l'ecouteur : le Rhino de KubeJS signale des redeclarations a chaque appel.)
var $MinecraftForge = Java.loadClass('net.minecraftforge.common.MinecraftForge')
var $EventPriority = Java.loadClass('net.minecraftforge.eventbus.api.EventPriority')
var $OverlayPre = Java.loadClass('net.minecraftforge.client.event.RenderGuiOverlayEvent$Pre')
var $VanillaGuiOverlay = Java.loadClass('net.minecraftforge.client.gui.overlay.VanillaGuiOverlay')
var $Minecraft = Java.loadClass('net.minecraft.client.Minecraft')

var shonenHud = { errors: 0, solo: null, dmzStats: null, dmzCap: null, layout: null, style: null, element: null, dmzHealthShown: null }

function shonenHudLog(msg) {
  if (shonenHud.errors < 3) console.error('shonen_hud: ' + msg)
  shonenHud.errors++
}

// Classes des mods chargees prudemment : si un mod change, le script se desactive en partie au lieu de planter.
try { shonenHud.solo = Java.loadClass('net.solocraft.network.SololevelingModVariables') }
catch (e) { console.warn('shonen_hud: Solo Leveling introuvable, panneau Systeme ignore (' + e + ')') }
try {
  shonenHud.dmzStats = Java.loadClass('com.dragonminez.common.stats.StatsProvider')
  shonenHud.dmzCap = Java.loadClass('com.dragonminez.common.stats.StatsCapability')
  shonenHud.layout = Java.loadClass('com.dragonminez.client.gui.hud.layout.HudLayout')
  shonenHud.style = Java.loadClass('com.dragonminez.client.gui.hud.HudStyle')
  shonenHud.element = Java.loadClass('com.dragonminez.client.gui.hud.layout.HudElement')
} catch (e) {
  shonenHud.dmzStats = null
  console.warn('shonen_hud: DragonMine Z introuvable, barre de vie DMZ ignoree (' + e + ')')
}

var SHONEN_HEALTH_ID = $VanillaGuiOverlay.PLAYER_HEALTH.id()
var SHONEN_ARMOR_ID = $VanillaGuiOverlay.ARMOR_LEVEL.id()

// Meme condition que le panneau Systeme de Solo Leveling (IfInSurvivalProcedure) : survie/aventure + CustomHUD.
// 08/11 (retour de test, point 2) : hors de l'univers Solo Leveling, Shonen Core ne dessine plus le panneau (HudSoloMixin) :
// les coeurs reviennent. Univers pas encore recus : comme avant.
function shonenSystemPanelShown(p) {
  if (shonenHud.solo == null || p == null || p.isCreative() || p.isSpectator()) return false
  var t = String(global.shonenUniversTexte === undefined || global.shonenUniversTexte === null ? '' : global.shonenUniversTexte)
  if (t !== '' && (',' + t + ',').indexOf(',sololeveling,') < 0) return false
  return p.getCapability(shonenHud.solo.PLAYER_VARIABLES_CAPABILITY, null).resolve()
    .map(v => v.CustomHUD).orElse(false)
}

function shonenHasDmzCharacter(p) {
  if (shonenHud.dmzStats == null || p == null) return false
  return shonenHud.dmzStats.get(shonenHud.dmzCap.INSTANCE, p).resolve()
    .map(s => s.getStatus().isHasCreatedCharacter()).orElse(false)
}

// Affiche/masque la barre de vie du style compact DMZ (seulement si ce style est actif, et seulement au changement).
function shonenSetDmzHealth(show) {
  if (shonenHud.layout == null || shonenHud.dmzHealthShown === show) return
  if (!shonenHud.style.COMPACT.equals(shonenHud.style.current())) return
  shonenSetDmzHealthPlacement(shonenHud.layout.placement(shonenHud.style.COMPACT, shonenHud.element.L2_HEALTH).copy(), show)
}

function shonenSetDmzHealthPlacement(placement, show) {
  placement.setVisible(show)
  shonenHud.layout.setPlacement(shonenHud.style.COMPACT, shonenHud.element.L2_HEALTH, placement)
  shonenHud.dmzHealthShown = show
}

function shonenHudDecide(event, p) {
  if (shonenSystemPanelShown(p)) {
    shonenSetDmzHealth(false)
    event.setCanceled(true)
  } else if (shonenHasDmzCharacter(p)) {
    shonenSetDmzHealth(true)
    if (SHONEN_HEALTH_ID.equals(event.getOverlay().id())) event.setCanceled(true)
  }
}

$MinecraftForge.EVENT_BUS.addListener($EventPriority.HIGH, false, $OverlayPre, event => {
  try {
    if (SHONEN_HEALTH_ID.equals(event.getOverlay().id()) || SHONEN_ARMOR_ID.equals(event.getOverlay().id())) {
      shonenHudDecide(event, $Minecraft.getInstance().player)
    }
  } catch (e) {
    shonenHudLog(e)
  }
})
console.info('shonen_hud: ecouteur barre de vie unique enregistre')
