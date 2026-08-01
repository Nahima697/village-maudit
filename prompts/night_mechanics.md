Jeu Roblox : "Village Maudit" (Jeu de déduction sociale et de survie horrifique).
Type : Script serveur (chemin : src/server/NightMechanics.server.luau).

# Objectif
Gérer la phase nocturne (18:00 à 06:00) en veillant sur le service `Lighting`. 

# Contraintes Techniques Strictes
1. Cycle et État : Utilise un booléen `isNight`. Quand la nuit tombe, l'éclairage s'assombrit lourdement.
2. Apparition des Monstres : La nuit, fais spawner des entités hostiles (les monstres) aux abords du village qui se dirigent vers les joueurs ou les bâtiments.
3. Le Rôle des Traîtres (Base) : Prépare une structure de données ou un attribut sur les joueurs (`isTraitor`) assigné au début de la partie. La nuit, les traîtres disposent d'une interaction spéciale ( sabotage de portes ou silence radio) pour aider les monstres de l'intérieur, sans se faire repérer par les villageois loyaux.
4. Le code doit être propre, modulaire et en Luau pur, sans balise markdown.
