#!/usr/bin/env bash
# =============================================================================
# Hook post-write : auto-lint des fichiers Python apres ecriture
# =============================================================================
#
# Ce hook est execute apres chaque appel a l'outil Write de Claude Code.
# Il recoit sur stdin un JSON avec les parametres de l'outil, dont `file_path`.
#
# Installation :
#   1. Rendre executable : chmod +x .claude/hooks/post-write.sh
#   2. Configurer dans .claude/settings.json :
#      {
#        "hooks": {
#          "PostToolUse": [
#            {
#              "matcher": "Write",
#              "hooks": [{ "type": "command", "command": ".claude/hooks/post-write.sh" }]
#            }
#          ]
#        }
#      }
#
# Adaptation :
#   - Remplacer LINT_CMD et FORMAT_CMD par vos outils (pylint, black, isort, etc.)
#   - Ajouter des extensions supplementaires dans le case (*.ts, *.js, etc.)
#   - Pour un hook bloquant (qui empeche le Write si lint echoue), retirer le
#     "exit 0" final et laisser propager le code de retour
# =============================================================================

set -euo pipefail

# --- Configuration -----------------------------------------------------------
# Adapter ces commandes a votre projet.
# Exemples courants :
#   ruff check --fix    / ruff format
#   flake8              / black
#   pylint              / autopep8
#   eslint --fix        (pour JS/TS)
LINT_CMD="ruff check --fix"
FORMAT_CMD="ruff format"
# -----------------------------------------------------------------------------

# Lire le JSON d'entree sur stdin et extraire le chemin du fichier ecrit.
# Le JSON contient { "tool_input": { "file_path": "/absolute/path/to/file.py", ... } }
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))" 2>/dev/null || true)

# Si on n'a pas pu extraire le chemin, sortir silencieusement
if [ -z "$FILE_PATH" ]; then
    exit 0
fi

# Verifier que le fichier existe
if [ ! -f "$FILE_PATH" ]; then
    exit 0
fi

# Appliquer le lint/format uniquement sur les fichiers Python
case "$FILE_PATH" in
    *.py)
        # Lint avec correction automatique (non-bloquant)
        $LINT_CMD "$FILE_PATH" 2>/dev/null || true

        # Formatage (non-bloquant)
        $FORMAT_CMD "$FILE_PATH" 2>/dev/null || true
        ;;

    # --- Exemples pour d'autres langages (decommenter si necessaire) ---
    #
    # *.ts|*.tsx|*.js|*.jsx)
    #     npx eslint --fix "$FILE_PATH" 2>/dev/null || true
    #     npx prettier --write "$FILE_PATH" 2>/dev/null || true
    #     ;;
    #
    # *.rs)
    #     rustfmt "$FILE_PATH" 2>/dev/null || true
    #     ;;
    #
    # *.go)
    #     gofmt -w "$FILE_PATH" 2>/dev/null || true
    #     ;;

    *)
        # Pas un fichier Python, rien a faire
        ;;
esac

# Toujours sortir avec succes pour ne pas bloquer l'outil Write.
# Pour un hook bloquant, supprimer cette ligne et laisser le code de retour
# de la derniere commande se propager.
exit 0
