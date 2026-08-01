# Contexte
Jeu Roblox : "Village Maudit".
Type : Nouveau script serveur (chemin : src/server/NightMechanics.server.luau).

# Objectif
Implémenter 3 mécaniques de survie qui s'activent la nuit (18:00 à 06:00) en surveillant `Lighting:GetPropertyChangedSignal("ClockTime")`.

# Contraintes Techniques Strictes
1. Variable d'état : Utilise un booléen `isNight` pour ne déclencher les modifications d'environnement (Brouillard et Portes) qu'au moment précis des transitions (jour vers nuit, et inversement).
2. Le Brouillard : La nuit, règle `Lighting.FogEnd` sur 40 et `Lighting.FogColor` sur Color3.new(0, 0, 0). Le jour, remets `Lighting.FogEnd` sur 10000.
3. Les Refuges : Parcourt le `workspace` pour trouver tous les objets nommés "RefugeDoor". La nuit, ils s'ouvrent (Transparency = 1, CanCollide = false). Le jour, ils se verrouillent (Transparency = 0, CanCollide = true).
4. L'Ombre Mortelle : Utilise un `task.spawn` avec une boucle `while task.wait(2) do`. Si `isNight` est vrai, vérifie tous les joueurs. Si un joueur n'est pas à moins de 25 studs d'un objet nommé "SafeZone" dans le `workspace`, inflige 10 points de dégâts à son `Humanoid`.
5. Le code doit être robuste, optimisé et gérer l'absence éventuelle des dossiers ou pièces requises.

# Format de Sortie
Renvoie UNIQUEMENT le code Luau en texte brut. N'inclus aucune explication, et n'utilise AUCUNE balise markdown.
