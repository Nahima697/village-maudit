#!/bin/bash

PROMPT_FILE="$1"
TARGET_FILE="$2"

if [ -z "$PROMPT_FILE" ] || [ -z "$TARGET_FILE" ]; then
    echo "Usage: ./claude.sh <chemin_prompt.md> <chemin_fichier_cible.luau>"
    exit 1
fi

if [ ! -f "$PROMPT_FILE" ]; then
    echo "❌ Erreur : le fichier prompt '$PROMPT_FILE' n'existe pas."
    exit 1
fi

PROJECT_STRUCTURE=$(find src/ -type f | sed 's/^/ - /')
CONTRACT_CONTENT=$(cat AI_CONTRACT.md 2>/dev/null || echo "Pas de contrat trouvé.")
USER_PROMPT=$(cat "$PROMPT_FILE")
CURRENT_TARGET_CONTENT=$(cat "$TARGET_FILE" 2>/dev/null || echo "Fichier vide ou nouveau.")

SUPER_PROMPT="
[CONTEXTE SYSTÈME & RÈGLES ABSOLUES]
Tu es un agent expert en Luau pour Roblox. Respecte le contrat.

--- CONTRAT (AI_CONTRACT.md) ---
$CONTRACT_CONTENT

--- ARBORESCENCE ACTUELLE DU PROJET ---
$PROJECT_STRUCTURE

--- FICHIER CIBLE ACTUEL ($TARGET_FILE) ---
$CURRENT_TARGET_CONTENT

--- TÂCHE ---
$USER_PROMPT
"

# Fichier temporaire pour le super-prompt fusionné
TEMP_PROMPT="/tmp/agent_super_prompt.md"
echo "$SUPER_PROMPT" > "$TEMP_PROMPT"

# Utilise TOUJOURS le Python du venv Hermes, peu importe si le venv
# est activé ou non dans le shell courant. Ça évite le bug silencieux
# où l'agent plantait avec "ModuleNotFoundError: No module named 'openai'"
# tout en affichant quand même un message de succès.
HERMES_PYTHON="$HOME/hermes/venv/bin/python3"

if [ ! -x "$HERMES_PYTHON" ]; then
    echo "❌ Erreur : Python du venv Hermes introuvable à $HERMES_PYTHON"
    echo "   Vérifie que le venv existe : ls ~/hermes/venv/bin/"
    exit 1
fi

"$HERMES_PYTHON" ~/hermes/agent.py "$TEMP_PROMPT" "$TARGET_FILE"
AGENT_EXIT_CODE=$?

if [ $AGENT_EXIT_CODE -ne 0 ]; then
    echo "❌ Erreur : l'agent a échoué (code de sortie $AGENT_EXIT_CODE). Fichier NON mis à jour correctement."
    echo "   Vérifie les logs ci-dessus pour la cause exacte."
    exit 1
fi

echo "✅ Mise à jour terminée pour $TARGET_FILE"

# Commit + push automatique si tout s'est bien passé
./agent_commit.sh "[Auto-Agent] Mise à jour de $TARGET_FILE via $PROMPT_FILE"
