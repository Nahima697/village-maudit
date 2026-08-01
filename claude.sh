#!/bin/bash

PROMPT_FILE="$1"
TARGET_FILE="$2"

if [ -z "$PROMPT_FILE" ] || [ -z "$TARGET_FILE" ]; then
    echo "Usage: ./claude.sh <chemin_prompt.md> <chemin_fichier_cible.luau>"
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

# Création d'un fichier temporaire pour le super prompt si l'agent attend un chemin de fichier
TEMP_PROMPT="/tmp/agent_prompt.md"
echo "$SUPER_PROMPT" > "$TEMP_PROMPT"

# Appel de l'agent avec les arguments positionnels (change l'ordre si ton agent attend le fichier cible en premier)
python3 /root/hermes/agent.py "$TEMP_PROMPT" "$TARGET_FILE"

echo "✅ Mise à jour terminée pour $TARGET_FILE"
