---
name: dev-challenge
description: "[team] Stress-test spec via 3 agents adversariaux independants (Devil's Advocate, Edge Case Hunter, Simplicity Skeptic). TRIGGER when: une spec existe et doit etre validee avant implementation."
argument-hint: "[spec-path]"
context: fork
---

Input : $ARGUMENTS (chemin vers un fichier spec Markdown)
Prerequis : aucun

## Description

Ce workflow coordonne 3 agents adversariaux pour identifier les failles, contradictions, angles morts et sur-complexite d'une specification avant implementation :
1. **Devil's Advocate** : Contradictions, hypotheses non fondees, decisions arbitraires
2. **Edge Case Hunter** : Cas limites, scenarios non couverts, conditions d'erreur oubliees
3. **Simplicity Skeptic** : Sur-complexite, sur-ingenierie, ecarts avec le codebase existant

Chaque agent adopte une perspective adversariale independante. Les agents ne communiquent pas entre eux (pas de groupthink).

## Instructions

1. Determiner le fichier spec cible :
   - Si `$ARGUMENTS` contient un chemin : utiliser ce fichier
   - Sinon : prendre le dernier fichier modifie dans `docs/specs/SPEC-*.md`
2. Lire la spec cible et `CLAUDE.md` racine pour le contexte
3. Spawner les 3 agents **en parallele** :
   - Agent "devils-advocate" (subagent_type: general-purpose, model: sonnet)
     avec instructions de `.claude/agents/devils-advocate.md`
   - Agent "edge-case-hunter" (subagent_type: general-purpose, model: sonnet)
     avec instructions de `.claude/agents/edge-case-hunter.md`
   - Agent "simplicity-skeptic" (subagent_type: general-purpose, model: sonnet)
     avec instructions de `.claude/agents/simplicity-skeptic.md`
4. Attendre les rapports de chaque agent
5. Consolider les findings :
   - Dedupliquer (si 2+ agents trouvent le meme probleme, crediter les deux)
   - Classer par severite : BLOQUANT > MAJEUR > MINEUR
   - Determiner le verdict :
     - **NO-GO** : >= 1 BLOQUANT non resolvable
     - **GO WITH CHANGES** : >= 1 BLOQUANT resolvable ou >= 3 MAJEURS
     - **GO** : sinon
   - Un BLOQUANT "resolvable" = corrigeable en modifiant la spec sans remettre en cause l'architecture
6. Produire le rapport final (format ci-dessous)

## Input attendu

L'utilisateur specifie :
- Un chemin vers un fichier spec Markdown (ex: `docs/specs/SPEC-my-feature.md`)
- Ou rien (fallback sur le dernier `docs/specs/SPEC-*.md` modifie)

## Output (artefact obligatoire)

1. Afficher le rapport consolide dans la conversation
2. **Sauvegarder** dans `docs/reviews/adversarial-SPEC-{name}.md` (obligatoire -- {name} correspond au nom de la spec source)
3. Le rapport inclut :
   - Tableau de synthese (findings par agent et severite)
   - Verdict : GO / GO WITH CHANGES / NO-GO (avec justification)
   - Findings detailles par agent (avec sources precises)
   - Recommandations (actions concretes pour passer a GO)
   - Points forts identifies (equilibre du feedback)

## Etape suivante (workflow)

Apres la sauvegarde, indiquer a l'utilisateur selon le verdict :
- **GO** : `/dev-implement "Implementer SPEC-{name}. Spec: docs/specs/SPEC-{name}.md"`
- **GO WITH CHANGES** : mettre a jour `docs/specs/SPEC-{name}.md` selon les findings, puis `/dev-implement`
- **NO-GO** : retravailler la spec avec `/dev-spec`
