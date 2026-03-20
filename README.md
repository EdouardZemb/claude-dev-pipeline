# Claude Dev Pipeline

Kit de maturation pour projets Claude Code : de l'idee au code livre, avec artefacts durables a chaque etape.

## Philosophie

Quatre principes fondateurs :

1. **Contexte frais** : chaque etape peut etre declenchee dans une nouvelle session en pointant vers les artefacts des etapes precedentes
2. **Artefacts durables** : toute analyse, revue ou decision est sauvegardee dans un fichier — jamais uniquement dans la conversation
3. **Chainement explicite** : chaque commande indique l'etape suivante et les artefacts attendus en entree/sortie
4. **Autonomie des etapes** : on peut sauter une etape ou reprendre le workflow a n'importe quel point

## Le pipeline

```
Idee/Demande
    |
    v
. . . . . . . . . . . . . .
. 0. /dev-explore            .   docs/explorations/EXPLORE-{name}.md
.    (optionnel)             .
. . . . . . . . . . . . . .
    |
    | GO -> Phase 1 | PIVOT -> re-explore | DROP -> stop
    v
+-------------+   docs/specs/SPEC-{name}.md
| 1. /dev-spec |
+-------------+
    |
    v
+------------------------+
| 1b. quality gate        |   resume + gate GO/REVISE/STOP
| validation utilisateur  |   REVISE -> re-spec (max 2 cycles)
+------------------------+
    |
    v (GO)
+-------------------+   docs/reviews/adversarial-SPEC-{name}.md
| 2a. /dev-challenge |---+
+-------------------+   |  (en parallele)
+-------------------+   |  docs/reviews/impact-SPEC-{name}.md
| 2b. Impact Analyst |---+
+-------------------+
    |
    v (mise a jour spec si GO WITH CHANGES)
+------------------+   squelettes TDD
| 3a. Test Architect|
+------------------+
    |
    v
+------------------+   code source (fait passer les tests)
| 3b. Implementer   |
+------------------+
    |
    v
+------------------+   tests completes (edge cases, erreurs)
| 3c. Tester        |
+------------------+
    |
    v
+------------------------+
| 3d. conformance check   |   V-criteres N/M couverts
+------------------------+
    |
    v
+------------------+   docs/reviews/review-{name}.md
| 4. Review         |---+
+------------------+   |  (conditionnel, en parallele)
+---------------------+|
| Security Checker     |
+---------------------+
    |
    v
+------------+   documentation mise a jour + commit
| 5. /dev-doc |
+------------+
    |
    v
+-------------+   docs/reviews/pipeline-{name}.md
| 6. Rapport   |
+-------------+
```

## Contenu du kit

```
.claude/
  agents/           11 agents specialises (roles read-only ou implementation)
  skills/           7 skills (orchestration des phases)
  hooks/            1 hook (auto-lint post-ecriture)
docs/
  WORKFLOW.md        Vue d'ensemble des pipelines
  WORKFLOW-DEV.md    Reference detaillee par etape
examples/
  SPEC-example.md    Exemple de specification complete
  EXPLORE-example.md Exemple de rapport d'exploration
CLAUDE.md            Exemple de CLAUDE.md projet integrant le pipeline
```

### Agents (11)

| Agent | Role | Model | Mode |
|-------|------|-------|------|
| `explorer` | Exploration structuree pre-spec (3 axes, matrice, verdict) | sonnet | lecture seule |
| `spec-architect` | Specification d'implementation (9 sections, V-criteres) | sonnet | ecriture spec |
| `impact-analyst` | Analyse d'impact cross-packages (blast radius, risque) | haiku | lecture seule |
| `devils-advocate` | Adversarial : contradictions, hypotheses, decisions arbitraires | sonnet | lecture seule |
| `edge-case-hunter` | Adversarial : cas limites, erreurs, scenarios manquants | sonnet | lecture seule |
| `simplicity-skeptic` | Adversarial : sur-complexite, sur-ingenierie, ecart codebase | sonnet | lecture seule |
| `test-architect` | Conception strategie test + squelettes TDD | haiku | ecriture tests |
| `implementer` | Implementation TDD (fait passer les tests) | sonnet | ecriture code |
| `tester` | Completion tests (edge cases, erreurs, robustesse) | haiku | ecriture tests |
| `reviewer` | Revue de code (conventions, patterns, architecture) | sonnet | lecture seule |
| `security-checker` | Audit securite OWASP adapte (credentials, injection, transport) | sonnet | lecture seule |

### Skills (7)

| Skill | Phase | Description |
|-------|-------|-------------|
| `/dev-explore` | 0 | Exploration structuree avant spec |
| `/dev-spec` | 1 | Generation specification 9 sections |
| `/dev-challenge` | 2 | Stress-test adversarial (3 agents paralleles) |
| `/dev-implement` | 3 | Implementation TDD multi-agents |
| `/dev-review` | 4 | Revue de code rapide |
| `/dev-doc` | 5 | Mise a jour documentation |
| `/dev-pipeline` | * | Meta-orchestrateur (toutes les phases) |

## Installation

1. Copier `.claude/` dans votre projet
2. Copier `docs/WORKFLOW.md` et `docs/WORKFLOW-DEV.md`
3. Creer les dossiers d'artefacts : `mkdir -p docs/{specs,reviews,explorations}`
4. Adapter le `CLAUDE.md` de votre projet (voir `CLAUDE.md` fourni comme exemple)

## Personnalisation

### Ce qu'il faut adapter (obligatoire)

1. **Agents `spec-architect` et `reviewer`** : remplacer les patterns SDK/API generiques par les patterns de votre projet
2. **Agent `security-checker`** : adapter la checklist OWASP a votre stack (frameworks, auth, transport)
3. **Skill `dev-review`** : remplacer les conventions lint/test par les votres
4. **Skill `dev-doc`** : lister vos fichiers de documentation
5. **Hook `post-write.sh`** : adapter la commande lint a votre linter

### Ce qu'il faut garder tel quel

- La structure du pipeline (phases, quality gates, retry cycles)
- Les 3 agents adversariaux (leur valeur vient de leur independance)
- Les patterns TDD (Test Architect -> Implementer -> Tester)
- Les conventions d'artefacts (nommage, dossiers)
- Les limites de retry (max 2 adversariaux, max 2 correctifs, max 1 review)

### Variables a remplacer

| Placeholder | Description | Exemple |
|-------------|-------------|---------|
| `{your_lint_command}` | Commande lint de votre projet | `ruff check .`, `eslint .` |
| `{your_format_command}` | Commande format | `ruff format .`, `prettier --write .` |
| `{your_test_command}` | Commande test | `pytest`, `jest`, `cargo test` |
| `{your_ci_command}` | Commande CI (lint + test) | `just ci`, `make check`, `npm run ci` |
| `{your_package_manager}` | Gestionnaire de paquets | `uv`, `npm`, `cargo` |

## Commandes de reprise

Le pipeline supporte `--from {phase}` pour reprendre a n'importe quelle etape :

```bash
# Reprendre apres /dev-spec
/dev-pipeline --from challenge docs/specs/SPEC-{name}.md

# Reprendre apres /dev-challenge
/dev-pipeline --from implement docs/specs/SPEC-{name}.md

# Reprendre apres /dev-implement (review + doc + commit)
/dev-pipeline --from review docs/specs/SPEC-{name}.md

# Reprendre seulement doc + commit
/dev-pipeline --from doc docs/specs/SPEC-{name}.md
```

## Patterns cles

### Artefact-driven workflow

Chaque phase produit un fichier sur disque. Si la conversation est perdue, le pipeline peut reprendre car l'etat est dans les fichiers, pas dans la memoire de session.

### Challenge adversarial (3 perspectives independantes)

Les 3 agents ne communiquent pas entre eux — pas de groupthink. Un finding identifie par 2+ agents est un signal fort de priorite.

### TDD multi-agents

La separation Test Architect / Implementer / Tester empeche le biais "je code ce que je veux tester" : les tests sont ecrits AVANT le code, completes APRES.

### Quality gates

Chaque transition entre phases est gardee par un verdict (GO/NO-GO/REVISE) avec des seuils adaptatifs et des cycles de correction bornes.

### Conformance check (V-criteres)

Les criteres de validation (V-criteres) de la spec sont traces jusqu'aux tests via des markers (`@pytest.mark.spec("V1")`). Le conformance checker verifie que chaque V-critere est couvert par au moins un test.
