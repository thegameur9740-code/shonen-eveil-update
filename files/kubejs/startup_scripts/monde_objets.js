// monde_objets.js - les objets des événements du monde (lot I3 section 2, kubejs/server_scripts/evenements.js ; session
// « monde », 07/11) : fragment de météore (Pluie de météores, Dragon Ball), cristal de reiatsu (Tempête de reiatsu,
// Bleach), rouleau de chakra (Tempête de chakra, Naruto). L'ermite de la montagne (quête secrète, section 5) en demandera
// 10 de chaque. Ils ne se fabriquent pas.
// Textures : client/overrides/kubejs/assets/shonen/textures/item (tools/monde/make_textures.py).
// Côté serveur ET client (le registre doit être le même). Rhino : var seulement.

StartupEvents.registry('item', function (event) {
  event.create('shonen:fragment_meteore').maxStackSize(64).rarity('uncommon').displayName('Fragment de météore')
  event.create('shonen:cristal_reiatsu').maxStackSize(64).rarity('uncommon').displayName('Cristal de reiatsu')
  event.create('shonen:rouleau_chakra').maxStackSize(64).rarity('uncommon').displayName('Rouleau de chakra')
  // Colporteur et quêtes secrètes (lot I3 sections 4 et 5 : colporteur.js, secrets_monde.js)
  event.create('shonen:carte_tresor').maxStackSize(1).rarity('rare').displayName('Carte au trésor')
  event.create('shonen:parchemin_lieu').maxStackSize(16).rarity('rare').displayName('Parchemin de lieu')
  event.create('shonen:fragment_ciel').maxStackSize(1).rarity('epic').displayName('Fragment du ciel')
  event.create('shonen:page_convergence').maxStackSize(1).rarity('epic').displayName('Page de « La Convergence »')
  // Familiers et montures (lot I3 sections 7 et 8 : familiers.js)
  event.create('shonen:sifflet_cheval').maxStackSize(1).rarity('rare').displayName('Sifflet du cheval de l\'école')
  event.create('shonen:oeuf_ombre').maxStackSize(16).rarity('uncommon').displayName('Œuf d\'ombre')
})
