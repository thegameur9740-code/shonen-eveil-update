# Crédits musicaux — Shonen Éveil

La musique dynamique du pack (mod **Ambience Mini**, voir « Fonctionnement » plus bas) utilise uniquement des
morceaux **libres de droits** dont la licence autorise la redistribution dans un modpack. Aucune bande originale
d'anime n'est utilisée. Les fichiers ne sont pas dans le dépôt : `scripts/build-music.ps1` les télécharge depuis la
source officielle, vérifie leur empreinte sha1 (`music/tracks.json`), adoucit leurs aigus, règle leur volume
(EBU R128, -22 LUFS depuis le 11/11/2026, -27 pour la taverne, voir `docs/interface.md`, « Musique »), ajoute 50 s
de silence à la fin des morceaux d'exploration et les convertit en .ogg. Cette conversion, ce filtre d'aigus, ce
réglage de volume et ce silence final sont les seules modifications apportées (CC BY : modifications signalées ici).

Licences vérifiées le 1er novembre 2026 sur la page de chaque morceau, puis revérifiées le même jour sur les pages en
ligne pour Kawarayu (CC BY 4.0, auteur Yubatake) et Fall of Nightmares (CC0, auteur nene ; notice d'attribution
« Voices by Helena Kesti and Matias Lindgren », reproduite ci-dessous même si CC0 ne l'exige pas).
Retiré du pack le 11/11/2026 : le morceau de combat de TAD (CC BY 4.0, https://opengameart.org/content/samurai), resté
trop aigu après le réglage ; il n'est plus téléchargé ni distribué.
Ajoutés le 11/11/2026 : les trois morceaux de taverne de RandomMind (CC0, champ « License(s) » lu sur la page
OpenGameArt de chacun ce jour-là ; l'auteur écrit « Credits are appreciated but not required »).

- **CC0 1.0** (domaine public) : aucune attribution exigée ; les auteurs sont tout de même cités ci-dessous.
- **CC BY 4.0** / **CC BY 3.0** : attribution **obligatoire** (titre, auteur, licence, lien) — c'est l'objet de ce
  fichier, qui doit accompagner toute diffusion du pack. Licence : https://creativecommons.org/licenses/by/4.0/
  (et https://creativecommons.org/licenses/by/3.0/).

## Morceaux par ambiance

| Ambiance | Titre | Auteur | Licence | Source |
|---|---|---|---|---|
| Menu | Senbazuru | Kevin MacLeod (incompetech.com) | CC BY 4.0 | https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1100821 |
| Menu | Asianoriental2 | Tozan (OpenGameArt.org) | CC0 1.0 | https://opengameart.org/content/asianoriental2 |
| Jour | Finding Movement | Kevin MacLeod (incompetech.com) | CC BY 4.0 | https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1100693 |
| Jour | Eastern Thought | Kevin MacLeod (incompetech.com) | CC BY 4.0 | https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1100682 |
| Jour | Kawarayu (shamisen) | Yubatake (OpenGameArt.org) | CC BY 4.0 | https://opengameart.org/node/15058 |
| Nuit | Eastminster | Kevin MacLeod (incompetech.com) | CC BY 4.0 | https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1100719 |
| Nuit | Ripples | Kevin MacLeod (incompetech.com) | CC BY 4.0 | https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1100691 |
| Nuit | That Zen Moment | Kevin MacLeod (incompetech.com) | CC BY 4.0 | https://incompetech.com/music/royalty-free/index.html?isrc=USUAN2400001 |
| Village | Hot Springs Town | Kistol (OpenGameArt.org) | CC0 1.0 | https://opengameart.org/content/hot-springs-town |
| Village | Ishikari Lore | Kevin MacLeod (incompetech.com) | CC BY 4.0 | https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1100192 |
| Mer | Pirate's Orchestra | Dizzy Crow (OpenGameArt.org) | CC0 1.0 | https://opengameart.org/content/pirates-orchestra-208 |
| Mer | Treasure Hunter | TAD (OpenGameArt.org) | CC0 1.0 | https://opengameart.org/content/treasure-hunter |
| Donjon | Asian Drums | Kevin MacLeod (incompetech.com) | CC BY 4.0 | https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1100396 |
| Donjon | Dark Shrine Loop | qubodup (OpenGameArt.org) | CC0 1.0 | https://opengameart.org/content/dark-shrine-loop |
| Combat | Mountain Emperor (taiko) | Kevin MacLeod (incompetech.com) | CC BY 4.0 | https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1700012 |
| Combat | Big Mojo | Kevin MacLeod (incompetech.com) | CC BY 4.0 | https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1100306 |
| Boss | Fall of Nightmares (chœurs) | nene, voix Helena Kesti et Matias Lindgren (OpenGameArt.org) | CC0 1.0 | https://opengameart.org/content/fall-of-nightmares-epic-orchestral |
| Boss | Clash Defiant (chœurs) | Kevin MacLeod (incompetech.com) | CC BY 4.0 | https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1600003 |
| Boss | Final Battle of the Dark Wizards (chœurs) | Kevin MacLeod (incompetech.com) | CC BY 4.0 | https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1500085 |
| Taverne | Medieval: The Old Tower Inn | RandomMind (OpenGameArt.org) | CC0 1.0 | https://opengameart.org/content/medieval-the-old-tower-inn |
| Taverne | Medieval: The Bard's Tale | RandomMind (OpenGameArt.org) | CC0 1.0 | https://opengameart.org/content/medieval-the-bards-tale |
| Taverne | Medieval: King's Feast | RandomMind (OpenGameArt.org) | CC0 1.0 | https://opengameart.org/content/medieval-kings-feast |

## Attributions exigées (texte à reproduire tel quel)

Kevin MacLeod (format demandé par l'auteur, une ligne de titres par morceau) :

```
"Senbazuru", "Finding Movement", "Eastern Thought", "Eastminster", "Ripples", "That Zen Moment",
"Ishikari Lore", "Asian Drums", "Mountain Emperor", "Big Mojo", "Clash Defiant",
"Final Battle of the Dark Wizards"
Kevin MacLeod (incompetech.com)
Licensed under Creative Commons: By Attribution 4.0 License
http://creativecommons.org/licenses/by/4.0/
```

```
"Kawarayu" by Yubatake — OpenGameArt.org (https://opengameart.org/node/15058)
Licensed under Creative Commons: By Attribution 4.0 — https://creativecommons.org/licenses/by/4.0/

"Fall of Nightmares [Epic, Orchestral]" by nene — OpenGameArt.org (https://opengameart.org/content/fall-of-nightmares-epic-orchestral)
Voices by Helena Kesti and Matias Lindgren — CC0 1.0 (attribution not required, given as requested)
```

(Notice d'attribution de Yubatake : « Please just mention my username and this site. » — fait ci-dessus.)

## Tes propres musiques (« Mes musiques »)

Les fichiers que tu places dans `<instance>\mes-musiques\<ambiance>\` restent les tiens : ils ne sont jamais
envoyés ni versionnés, seulement copiés (convertis en .ogg, volume réglé) dans `ambience_music\music\mes-musiques\`
de ton instance. Ils ne doivent pas être redistribués avec le pack s'ils sont protégés.

Une musique par Grand Ennemi : `<instance>\mes-musiques\boss-<clé>\` (igris, toji, akainu, roi_fourmis, aizen,
freezer, cell, kaido, sukuna, mahoraga, yhwach, broly). Exemple : mets ici ta musique pour Sukuna
(`mes-musiques\boss-sukuna\`), elle ne sera jouée que chez toi. Elle passe avant la musique « boss » générale tant que
la barre de vie de ce boss est affichée (ou qu'il te combat) ; un dossier vide = la musique « boss » habituelle. Le
pack ne télécharge ni ne fournit jamais de musique pour ces dossiers.

## Fonctionnement (rappel)

Mod : Ambience Mini 2.7.12 par Molybdenum042 (molybdenum042 sur Modrinth, dépôt GitHub sdfg610/Ambience-Mini-Mod),
LGPL-3.0, https://modrinth.com/mod/ambience-mini, côté client.
Configuration générée : `ambience_music\music_config.txt` (règles et priorités : voir `docs/interface.md`,
section « Musique »).

## Sons de l'Éveil ultime (calculés par nous)

Les 4 sons de la forme ultime (`transformation`, `tir`, `impact`, `extinction`, dans
`shonen-core/src/main/resources/assets/shonencore/sounds/ultime/`) sont **calculés par un programme à nous**,
`tools/eveil/ult_sons.py` (numpy : sinusoïdes, balayages de fréquence, bruit filtré ; puis ffmpeg pour le .ogg). Aucun
enregistrement, aucune banque de sons, aucun son d'un jeu, d'un anime ou d'un autre mod n'est utilisé : rien à créditer,
aucune licence tierce. Le programme est déterministe (mêmes octets à chaque exécution) ; `scripts/tests/eveil-spectacle.test.js`
vérifie les fichiers (Ogg Vorbis mono 44,1 kHz, courts, petits) et leur déclaration dans `sounds.json` avec sous-titres FR et EN.
