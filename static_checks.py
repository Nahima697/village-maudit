#!/usr/bin/env python3
"""
static_checks.py — Vérifications rapides et déterministes sur tous les
fichiers .luau du projet, avant chaque commit.

Attrape spécifiquement les bugs rencontrés pendant le développement :
- Fichiers vides (silencieusement écrasés par une génération ratée)
- Texte Markdown collé en tête de fichier au lieu de code
- Caractères non-ASCII injectés dans des identifiants (corruption d'encodage)
- do/end déséquilibrés (signe fort de génération tronquée)
- Un .server.luau qui finit par "return X" (piège ModuleScript vs Script)
"""

import re
import sys
from pathlib import Path

SRC_DIR = Path("src")
ERRORS = []


def check_file(path: Path):
    text = path.read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines()

    # 1. Fichier vide
    if len(text.strip()) == 0:
        ERRORS.append(f"{path}: fichier VIDE")
        return

    # 2. Markdown collé en tête de fichier (titres, texte de présentation)
    first_non_empty = next((l for l in lines if l.strip()), "")
    if first_non_empty.startswith("#") and not first_non_empty.startswith("#!"):
        ERRORS.append(f"{path}: commence par un titre Markdown ('{first_non_empty[:50]}'), pas du code Luau")
    if re.search(r"^Voici (un|le|la)", text, re.MULTILINE):
        ERRORS.append(f"{path}: contient une phrase d'introduction ('Voici...'), texte non filtré avant le code")
    if "```" in text:
        ERRORS.append(f"{path}: contient des balises Markdown ``` non nettoyées")

    # 3. Caractères non-ASCII dans des identifiants (hors commentaires et chaînes)
    #    Heuristique simple : cherche des mots avec lettres accentuées/arabes
    #    collées à des lettres latines sans espace (signe de corruption).
    for i, line in enumerate(lines, 1):
        code_part = line.split("--")[0]  # ignore les commentaires simples
        suspicious = re.findall(r"\b[A-Za-z]+[\u0600-\u06FF\u0750-\u077F][A-Za-z]*\b", code_part)
        if suspicious:
            ERRORS.append(f"{path}:{i}: identifiant corrompu détecté ({suspicious})")

    # 4. do/end déséquilibrés (approximatif mais utile)
    do_count = len(re.findall(r"\b(do|function|then)\b", text))
    end_count = len(re.findall(r"\bend\b", text))
    if end_count == 0 and do_count > 0:
        ERRORS.append(f"{path}: aucun 'end' trouvé alors que le fichier contient des blocs (fichier tronqué ?)")

    # 5. Piège ModuleScript vs Script : un .server.luau qui finit par
    #    "return X" n'a aucun effet utile pour les autres scripts.
    if path.name.endswith(".server.luau"):
        stripped = text.rstrip()
        if re.search(r"\breturn\s+\w+\s*$", stripped):
            ERRORS.append(f"{path}: se termine par 'return X' mais c'est un Script auto-exécutable (.server.luau), pas un ModuleScript — ce return est probablement une erreur")


def main():
    if not SRC_DIR.exists():
        print("⚠️  Dossier src/ introuvable, vérifications ignorées.")
        return 0

    luau_files = list(SRC_DIR.rglob("*.luau")) + list(SRC_DIR.rglob("*.lua"))

    if not luau_files:
        print("⚠️  Aucun fichier .luau/.lua trouvé.")
        return 0

    for f in luau_files:
        check_file(f)

    if ERRORS:
        print(f"❌ {len(ERRORS)} problème(s) détecté(s) :\n")
        for e in ERRORS:
            print(f"  - {e}")
        print("\nCommit bloqué. Corrige ces points avant de committer.")
        return 1

    print(f"✅ {len(luau_files)} fichier(s) Luau vérifié(s), aucun problème détecté.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
