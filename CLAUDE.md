# Mon Projet — CLAUDE.md

Fichier d'instructions projet pour Claude Code. Adapte ce template a ton projet.

## Pipeline de maturation

Ce projet utilise le pipeline de maturation Dev pour toute feature non triviale.

### Workflow complet (une ligne)

`/dev-spec` -> quality gate -> `/dev-challenge` + Impact -> `/dev-implement` (TDD) -> conformance check -> review -> `/dev-doc` -> commit

### Commandes pipeline

| Commande | Role |
|----------|------|
| `/dev-explore` | Exploration prealable (optionnel, verdict GO/PIVOT/DROP) |
| `/dev-spec` | Rediger une specification formelle (9 sections, V-criteres) |
| `/dev-challenge` | Challenge adversarial + analyse d'impact sur la spec |
| `/dev-implement` | Implementation TDD (Test Architect -> Implementer -> Tester) |
| `/dev-pipeline` | Orchestre tout le pipeline de bout en bout |
| `/dev-pipeline --from {phase}` | Reprendre a une etape (spec, challenge, implement, review, doc) |
| `/dev-review` | Revue de code sur les fichiers modifies |
| `/dev-test` | Generer les tests pour le nouveau code |
| `/dev-doc` | Mettre a jour la documentation |

### Conventions artefacts

| Dossier | Contenu |
|---------|---------|
| `docs/specs/` | Specifications formelles (`SPEC-{name}.md`) |
| `docs/reviews/` | Reviews adversariales et d'impact (`adversarial-SPEC-{name}.md`, `impact-SPEC-{name}.md`) |
| `docs/explorations/` | Rapports d'exploration (`EXPLORE-{name}.md`) |

### Reprise en contexte frais

Le pipeline produit des artefacts durables sur disque. Pour reprendre apres interruption :

```bash
# Reprendre a l'implementation (spec + challenge deja faits)
/dev-pipeline --from implement

# Reprendre a la review (implementation deja faite)
/dev-pipeline --from review
```

Chaque artefact est auto-suffisant : un agent en contexte frais peut lire `docs/specs/SPEC-foo.md` et reprendre sans historique de conversation.

## Structure projet

```
src/              # Code source principal
tests/            # Tests (pytest)
docs/             # Documentation
  specs/          # Specifications formelles
  reviews/        # Reviews adversariales et d'impact
  explorations/   # Rapports d'exploration
examples/         # Exemples de reference
.claude/          # Configuration Claude Code
  skills/         # Skills (commandes slash)
  agents/         # Agents specialises
  hooks/          # Hooks pre/post execution
```

## Commandes

```bash
# TODO: adapter a ton projet
uv sync                    # Installer les dependances
uv run pytest              # Lancer les tests
uv run ruff check .        # Lint
uv run ruff format .       # Format
just ci                    # Lint + tests (pre-commit)
```

## Regles critiques

<!-- Regles dont la violation cause des bugs. Exemples : -->

1. **Dry-run par defaut** : toute operation d'ecriture API doit etre en dry-run par defaut
2. **Pas de secrets dans le code** : utiliser `.env` ou variables d'environnement
3. <!-- Ajouter tes regles specifiques -->

## Conventions

- Python >=3.11, ruff pour lint/format
- Tests : pytest, `@pytest.mark.integration` pour tests reseau
- `@pytest.mark.spec(id)` pour lier un test a un V-critere de spec
- Commits en francais, conventionnels (`type: description`), atomiques
- `just ci` obligatoire avant commit

## Challenge systematique

Avant toute implementation d'une nouvelle feature :

1. **Questionner le besoin** : quel probleme concret ca resout ?
2. **Explorer les alternatives** : existe-t-il deja dans le codebase ?
3. **Evaluer les trade-offs** : complexite ajoutee vs valeur
4. **Proposer la recommandation** : presenter le resultat du challenge

## Post-implementation

Apres toute implementation significative :

1. `/dev-test` : generer les tests
2. `/dev-review` : revue de code
3. `/dev-doc` : mettre a jour la documentation
4. `just ci` puis commit automatique
