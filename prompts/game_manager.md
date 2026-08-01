Jeu Roblox : "Village Maudit".
Type : Script serveur (chemin : src/ServerScriptService/Server/GameManager.lua).

# Objectif
Créer le module `GameManager.lua` qui sert d'orchestrateur principal de la partie en reliant RoleAssignment, DayNightCycle et VotingSystem.

# Contraintes Techniques Strictes
- Charger et utiliser les modules : `RoleAssignment`, `DayNightCycle`, et `VotingSystem` (situés dans le même dossier ou via ReplicatedStorage/ServerScriptService selon l'architecture).
- Gérer la liste des joueurs vivants (`alivePlayers`), avec un minimum de 4 joueurs pour lancer la partie (`GameManager.StartGame()`).
- Écouter les changements d'état du cycle jour/nuit via `DayNightCycle.OnStateChange`.
- Pendant la phase `VOTE_PHASE`, appeler `VotingSystem.OpenVote(alivePlayers, callback)` pour gérer le vote et éliminer le joueur désigné si besoin.
- Surveiller les conditions de victoire en temps réel via une fonction `checkWinConditions()` (victoire des Villageois si 0 traître, victoire des Traîtres si traîtres >= villageois) et appeler `DayNightCycle.Stop()` le cas échéant.
- Fournir une fonction `GameManager.RemovePlayer(player)` pour retirer un joueur mort de la liste des vivants.
- Le code doit être robuste, optimisé et en Luau pur, sans balise markdown ni texte superflu.

# Format de Sortie
Renvoie UNIQUEMENT le code Luau en texte brut. N'inclus aucune explication, et n'utilise AUCUNE balise markdown.
