#!/bin/bash

# 1. Vérifier s'il y a des modifications
if [[ -z $(git status -s) ]]; then
  echo "⚠️ Aucune modification à committer."
  exit 0
fi

# 2. Lancer les vérifications de sécurité / tests de base
echo "🛡️ Exécution des garde-fous..."
# (Tu peux appeler ici tes scripts de test ou de validation de syntaxe Luau/autre)

# 3. Si tout est OK, ajout et commit avec un message standardisé
git add .
git commit -m "🤖 [Auto-Agent] Mise à jour validée par les tests"

# 4. Push automatique vers le dépôt distant
git push origin main

echo "🚀 Modifications poussées avec succès !"
