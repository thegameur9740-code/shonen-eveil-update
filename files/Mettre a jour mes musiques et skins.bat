@echo off
REM Shonen Eveil : met a jour la musique (dossier mes-musiques), les skins de boss (dossier mes-skins) et telecharge
REM les mods qui ne peuvent pas etre dans le zip. Jeu ferme. Aucun droit administrateur necessaire.
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0shonen-outils\mettre-a-jour.ps1"
echo.
pause
