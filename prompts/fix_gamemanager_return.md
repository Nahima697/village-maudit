# 1. Retrait du return final
Le fichier `src/server/GameManager.server.luau` est un Script (auto-exécutable) et non un ModuleScript. Il plante à cause du système de vérification car il se termine par un `return`. Supprime le `return` à la toute fin du fichier. Ne modifie strictement rien d'autre, conserve bien l'appel au `WorldBuilder`.
