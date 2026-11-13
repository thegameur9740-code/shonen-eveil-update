// Shonen Eveil - ecran titre (client uniquement : ce fichier n'est copie que dans l'instance joueur).
// DragonMine Z ajoute sans option de config (mixin TitleScreen, injection a la fin de init) un bouton
// Discord a la place du bouton Realms et une petite icone Patreon. FancyMenu ne peut pas les masquer
// de facon fiable (leur identifiant depend de la taille de la fenetre), donc on les retire ici, juste
// apres l'init de l'ecran titre (ScreenEvent.Init.Post), avant que FancyMenu n'applique le layout.
var $TitleScreen = Java.loadClass('net.minecraft.client.gui.screens.TitleScreen')
var $DmzDiscord = Java.loadClass('com.dragonminez.client.gui.buttons.DiscordTitleButton')
var $DmzIcon = Java.loadClass('com.dragonminez.client.gui.buttons.IconButton')

ForgeEvents.onEvent('net.minecraftforge.client.event.ScreenEvent$Init$Post', event => {
  if (!(event.getScreen() instanceof $TitleScreen)) return
  var toRemove = []
  event.getListenersList().forEach(w => {
    if (w instanceof $DmzDiscord || w instanceof $DmzIcon) toRemove.push(w)
  })
  toRemove.forEach(w => event.removeListener(w))
})
