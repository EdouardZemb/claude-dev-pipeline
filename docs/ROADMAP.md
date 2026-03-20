# Roadmap — Claude Dev Pipeline

## Statut projet

| Metrique | Valeur |
|----------|--------|
| Fichiers | 27 |
| Lignes | ~3300 |
| Agents | 11 |
| Skills | 7 |
| Exemples | 4 |
| Derniere mise a jour | 2026-03-20 |

## Historique des corrections

### Audit initial (2026-03-20) — 19 findings

| # | Categorie | Severite | Description | Statut |
|---|-----------|----------|-------------|--------|
| F1 | gap | BLOQUANT | Pas de detection automatique du `--from` (scan artefacts existants) | [x] Corrige |
| F2 | coherence | BLOQUANT | Phase 1b skip non documente lors de reprise `--from challenge` | [x] Corrige |
| F3 | completude | BLOQUANT | Test Architect sans guidance sur les fixtures pytest | [x] Corrige |
| F4 | completude | BLOQUANT | Spec Architect sans budget exploration (codebase volumineux) | [x] Corrige |
| F5 | coherence | MAJEUR | Duplication regles interview entre spec-architect.md et dev-spec/SKILL.md | [x] Corrige |
| F6 | completude | MAJEUR | Mecanique Spec Rev.2 non documentee (qui genere le diff ?) | [x] Corrige |
| F7 | gap | MAJEUR | Pas de workflows alternatifs (bugfix, refactoring, doc-only) | [x] Corrige |
| F8 | coherence | MAJEUR | Markers `@pytest.mark.spec` : classe vs methode (contradictoire) | [x] Corrige |
| F9 | completude | MAJEUR | Impact Analyst : transitifs non clarifies dans matrice risque | [x] Corrige |
| F10 | doc | MAJEUR | Exemples manquants (adversarial, pipeline) — 2/7 skills couverts | [x] Corrige |
| F11 | coherence | MAJEUR | Specs documentaires : 3 reponses differentes dans 3 fichiers | [x] Corrige |
| F12 | style | MINEUR | Nommage agents : harmoniser kebab-case partout | [ ] |
| F13 | completude | MINEUR | Conformance check : pas d'adaptation multi-langages (JS/Go) | [ ] |
| F14 | completude | MINEUR | Security Checker : pas d'audit scripts/hooks | [ ] |
| F15 | completude | MINEUR | Phase 5b : gestion erreurs lint non documentee | [ ] |
| F16 | qualite | MINEUR | Front-matter YAML standardise pour les specs | [x] Corrige |
| F17 | doc | MINEUR | Agents adversariaux : verifier `model: sonnet` en en-tete | [x] Deja present |
| F18 | completude | MINEUR | Pas d'exemple implement-SPEC ni review-SPEC | [ ] |
| F19 | completude | MINEUR | Pas d'exemple impact-SPEC | [ ] |

**Bilan** : 13/19 corriges, 6 restants (tous MINEURS).

## Backlog

### Completude

| # | Module | Description | Severite | Statut |
|---|--------|-------------|----------|--------|
| BL.1 | conformance | Adapter Phase 3d pour multi-langages (JS: JSDoc `@spec V1`, Go: suffix `TestV1_*`) | Basse | [ ] |
| BL.2 | security-checker | Ajouter checklist A11 — audit scripts shell, hooks, configs | Basse | [ ] |
| BL.3 | dev-pipeline | Documenter gestion erreurs lint Phase 5b (lint --fix qui casse les tests) | Basse | [ ] |
| BL.4 | examples | Ajouter exemples : impact-SPEC-example.md, implement-SPEC-example.md, review-SPEC-example.md | Basse | [ ] |
| BL.5 | style | Harmoniser typographie agent names (kebab-case dans README, skills, agents) | Basse | [ ] |

### Patterns manquants

| # | Module | Description | Severite | Statut |
|---|--------|-------------|----------|--------|
| BL.6 | sys-retro | Ajouter skill `/sys-retro` (retrospective structuree fin de session) | Moyenne | [ ] |
| BL.7 | findings | Ajouter mecanisme capture de findings (findings-log.jsonl + hook log-finding.sh) | Moyenne | [ ] |
| BL.8 | hooks | Ajouter hook `log-failures.sh` (capture erreurs outils dans error-log.jsonl) | Moyenne | [ ] |
| BL.9 | hooks | Ajouter hook `session-metrics.sh` (compteurs fin de session) | Basse | [ ] |
| BL.10 | memory | Ajouter structure MEMORY.md + session-journal.md pour persistance inter-sessions | Moyenne | [ ] |
| BL.11 | rules | Ajouter regles contextuelles par paths (testing.md, scripts.md) | Basse | [ ] |
| BL.12 | dev-pipeline | Ajouter mode `--dry-run` pour simuler le pipeline sans executer | Basse | [ ] |
| BL.13 | dev-pipeline | Ajouter metriques cumulees cross-pipelines (historique qualite) | Basse | [ ] |

### Evolution

| # | Module | Description | Severite | Statut |
|---|--------|-------------|----------|--------|
| BL.14 | agents | Ajouter agent `doc-writer` dedie (separation review doc / ecriture doc) | Basse | [ ] |
| BL.15 | dev-pipeline | Support rollback automatique apres echec Phase 3 (git stash / git reset) | Basse | [ ] |
| BL.16 | dev-pipeline | Support pipeline parallele (2 features en meme temps via worktrees) | Basse | [ ] |
| BL.17 | conformance | Implementer conformance checker generique en Python (pas lie a pytest) | Moyenne | [ ] |
| BL.18 | dev-challenge | Ajouter 4e agent adversarial optionnel : Performance Analyst | Basse | [ ] |
| BL.19 | dev-spec | Support specs multi-langues (sections traduisibles) | Basse | [ ] |
| BL.20 | hooks | Hook pre-commit : bloquer commit si findings BLOQUANTS non resolus | Basse | [ ] |
