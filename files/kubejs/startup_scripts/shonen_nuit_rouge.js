// Shonen Eveil - la nuit rouge (client uniquement : ce fichier n'est copie que dans l'instance joueur).
// Lot I3 section 1 (kubejs/server_scripts/nuit.js) : la nuit de pleine lune (phase 0, une nuit sur 8) est une nuit
// rouge. Le client connait deja l'heure et la phase de la lune du monde (envoyees par le serveur), donc aucun
// message reseau : le brouillard et l'horizon de l'Overworld virent au rouge sang, en douceur au crepuscule et a l'aube.
// Meme calcul que nuit.js : nuit = temps du jour 13000 a 23000, phase = (jour / 24000) % 8.
// (Pas de variable locale dans l'ecouteur : le Rhino de KubeJS signale des redeclarations a chaque appel.)
var $NuitMinecraft = Java.loadClass('net.minecraft.client.Minecraft')

var shonenNuit = { errors: 0, mc: null, t: 0, h: 0, f: 0 }

ForgeEvents.onEvent('net.minecraftforge.client.event.ViewportEvent$ComputeFogColor', event => {
  try {
    shonenNuit.mc = $NuitMinecraft.getInstance()
    if (shonenNuit.mc.level == null) return
    if (String(shonenNuit.mc.level.dimension) !== 'minecraft:overworld') return   // propriété KubeJS (dimension() n'est pas appelable)
    shonenNuit.t = shonenNuit.mc.level.getDayTime()
    if (((Math.floor(shonenNuit.t / 24000) % 8) + 8) % 8 !== 0) return
    shonenNuit.h = ((shonenNuit.t % 24000) + 24000) % 24000
    if (shonenNuit.h < 13000 || shonenNuit.h >= 23000) return
    // force 0 -> 1 pendant la premiere et la derniere demi-heure de jeu de la nuit (600 ticks)
    shonenNuit.f = Math.min(1, (shonenNuit.h - 13000) / 600, (23000 - shonenNuit.h) / 600)
    event.setRed(event.getRed() + (0.45 - event.getRed()) * shonenNuit.f)
    event.setGreen(event.getGreen() * (1 - 0.75 * shonenNuit.f))
    event.setBlue(event.getBlue() * (1 - 0.75 * shonenNuit.f))
  } catch (e) {
    if (shonenNuit.errors < 3) console.error('shonen_nuit_rouge: ' + e)
    shonenNuit.errors++
  }
})
