#!/bin/bash

# 1. Vérifier s'il y a des modifications
if [[ -z $(git status -s) ]]; then
  echo "⚠️  Aucune modification à committer."
  exit 0
fi

# 2. Lancer les vérifications statiques (bloquant)
echo "🛡️  Exécution des garde-fous..."
python3 static_checks.py
if [ $? -ne 0 ]; then
  echo "❌ Vérifications échouées. Commit annulé."
  exit 1
fi

# 3. Message de commit (passé en argument, ou générique par défaut)
COMMIT_MSG="${1:-[Auto-Agent] Mise à jour validée par les tests}"

# 4. Commit
git add .
git commit -m "$COMMIT_MSG"

# 5. Push automatique
git push origin master
if [ $? -ne 0 ]; then
  echo "⚠️  Commit local OK, mais le push a échoué (identifiants ? réseau ?)."
  exit 1
fi

echo "🚀 Modifications commitées et poussées avec succès !"
