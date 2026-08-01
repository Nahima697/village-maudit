# CONTRAT D'ARCHITECTURE ET RÈGLES STRICTES - "VILLAGE MAUDIT"

⚠️ **À L'ATTENTION DE L'AGENT IA : Tu DOIS lire et respecter ces règles avant de proposer, modifier ou générer du code pour ce projet.** ⚠️

## 1. Règle anti-crash ("Infinite Yield")
Le projet utilise plusieurs scripts autonomes (`.server.luau`) qui démarrent en même temps. 
* **Interdiction absolue** de faire un `WaitForChild()` sur un `RemoteEvent` ou un `BindableEvent` sans s'assurer qu'il a été créé.
* **Le `GameManager.server.luau` est le garant des ressources globales.** C'est lui qui DOIT créer le dossier `ReplicatedStorage.RemoteEvents` et instancier TOUS les événements globaux (comme `AssignRole`, `TraitorSabotage`, etc.) tout en haut de son code, avant même de définir ses fonctions.

## 2. Architecture des fichiers
* Les systèmes indépendants (`WorldBuilder`, `MonsterSpawner`, `RoleManager`, `VotingSystem`, `PlayerManager`) ont l'extension `.server.luau` pour s'exécuter de façon autonome au démarrage. Ne les transforme PAS en `ModuleScript` (pas de `.luau` simple pour eux).
* Les configurations partagées (comme `GameConfig.luau`) vont dans `ReplicatedStorage/Modules`.

## 3. Unicité des instructions
* Il ne doit y avoir qu'un seul fichier markdown par système dans le dossier `prompts/`. 
* Si tu dois unifier un système, supprime l'ancien fichier de prompt pour éviter la duplication de contexte (ex: on garde `game_manager_unified.md`, pas `game_manager.md`).

## 4. Communication entre scripts
* Les variables globales d'état (comme la phase actuelle ou le compteur de nuits) doivent être stockées sous forme d'attributs dans `ReplicatedStorage.SharedData`.
* Les scripts autonomes doivent utiliser `SharedData:GetAttributeChangedSignal("CurrentPhase")` pour réagir aux changements de phase du jeu, plutôt que de faire des boucles `while` indépendantes.

## 5. Syntaxe et Formatage du Code (Zéro Markdown)
* **Zéro Markdown dans les fichiers source :** N'insère JAMAIS de balises Markdown (comme ` ```luau ` ou ` ``` `) à l'intérieur des fichiers `.luau`. Le code doit être brut et prêt à être compilé.
* **Commentaires Luau stricts :** Les commentaires s'écrivent exclusivement avec `--` ou `--[[ ]]`. N'utilise JAMAIS le symbole `#` pour faire un commentaire ou un titre dans un fichier de code, cela provoque des erreurs fatales de parsing.
