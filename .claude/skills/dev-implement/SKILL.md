---
name: dev-implement
description: "[team] Implementation multi-agents TDD (Test Architect, Implementer, Tester). TRIGGER when: une spec est approuvee et prete pour implementation. DO NOT TRIGGER for: changement simple (1-2 fichiers)."
argument-hint: "[spec-path ou description]"
context: fork
---

Input : $ARGUMENTS (description de la feature/bug/refactoring + fichiers optionnels)
Prerequis : aucun

## Description

Ce workflow coordonne 3 agents pour implementer une feature complete en TDD :
1. **Test Architect** (haiku) : Genere les squelettes de tests TDD depuis la spec (V-criteres + markers)
2. **Implementer** (sonnet) : Code en TDD pour faire passer les tests generes
3. **Tester** (haiku) : Complete les squelettes avec edge cases, scenarios d'erreur et robustesse

## Instructions

1. Analyser la demande : decomposer en sous-taches
2. Phase 1 -- Spawner le Test Architect :
   - Agent "test-architect" (subagent_type: general-purpose, model: haiku)
     avec instructions de `.claude/agents/test-architect.md`
   - Input : la spec (chemin vers `docs/specs/SPEC-{name}.md`)
   - Attendre la completion : squelettes generes dans `tests/` + plan de test
3. Phase 2 -- Spawner l'Implementer :
   - Agent "implementer" (subagent_type: general-purpose, model: sonnet)
     avec instructions de `.claude/agents/implementer.md`
   - Input : spec + squelettes generes en Phase 1 + review adversariale (si fournie)
   - L'Implementer DOIT faire passer les tests des squelettes (TDD)
   - Attendre la completion du code
4. Phase 3 -- Spawner le Tester :
   - Agent "tester" (subagent_type: general-purpose, model: haiku)
     avec instructions de `.claude/agents/tester.md`
   - Input : squelettes + code source implemente
   - Le Tester complete les squelettes avec edge cases, erreurs, robustesse
   - Attendre la completion des tests
5. Phase 4 -- Consolidation :
   - Run `{your_ci_command}` pour validation finale
   - Si bloquants CI : renvoyer a l'Implementer (max 2 iterations)
6. Produire le rapport consolide

## Input attendu

L'utilisateur specifie :
- La description de la feature, bug fix, ou refactoring a implementer
- Les fichiers ou packages concernes (optionnel)
- **Reference aux artefacts du workflow** (recommande) :
  - Spec : `docs/specs/SPEC-{name}.md` -- le Test Architect et l'Implementer DOIVENT lire ce fichier si fourni
  - Review adversariale : `docs/reviews/adversarial-SPEC-{name}.md` -- l'Implementer DOIT tenir compte des findings si fourni

## Output (artefact obligatoire)

1. Afficher le rapport consolide dans la conversation
2. **Sauvegarder** dans `docs/reviews/implement-{name}.md` (obligatoire -- {name} derive de la spec ou de la description)
3. Le rapport inclut :
   - Squelettes generes par le Test Architect (fichiers, V-criteres couverts)
   - Fichiers modifies par l'Implementer et lignes changees
   - Tests completes par le Tester et resultats
   - Resultat `{your_ci_command}`
   - Statut final (DONE ou NEEDS_FIXES)

## Etape suivante (workflow)

Apres la sauvegarde, indiquer a l'utilisateur :
- **DONE** : le conformance check puis la review sont geres par `/dev-pipeline`
- **NEEDS_FIXES** : corriger les problemes restants, puis relancer la validation
