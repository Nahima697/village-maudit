# Contexte
Jeu Roblox : "Village Maudit". Script serveur (src/server/WorldBuilder.server.luau).

# Objectif
Créer les éléments 3D du jeu dès le lancement via un script.

# Contraintes Strictes
1. Crée une Part nommée "RefugeDoor" (Taille: 5, 8, 1 | Position: 0, 4, -15 | Anchored: true | Couleur: Marron).
2. Crée une Part nommée "SafeZone" (Taille: 15, 1, 15 | Position: 0, 0.5, 15 | Anchored: true | CanCollide: false | Transparence: 0.5 | Couleur: Vert).
3. Assigne obligatoirement la propriété Parent à `workspace` pour chaque Part afin qu'elles apparaissent en jeu.
4. Le code doit être propre et ne pas utiliser de boucles bloquantes.

# Format de sortie
Code Luau pur uniquement, sans aucune balise markdown ni explication.
