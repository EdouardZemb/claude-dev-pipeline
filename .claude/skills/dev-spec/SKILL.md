---
name: dev-spec
description: "Specification d'implementation structuree. TRIGGER when: nouvelle feature ou modification non triviale. DO NOT TRIGGER for: bugfix simple ou typo."
argument-hint: "[description feature]"
---

Input : $ARGUMENTS (description de la feature/modification souhaitee + artefacts fournis)
Prerequis : aucun

## Objectif

Transformer une demande floue + artefacts (mail, document, screenshot, spec) en un document de specification complet et non-ambigu, pret a alimenter `/dev-implement` ou une implementation directe.

Le probleme resolu : l'utilisateur fournit des exemples et du contexte, mais les **regles metier implicites** ne sont pas explicitees. Ce skill les extrait, les formalise, et demande confirmation avant de produire le spec final.

## Workflow (3 phases)

### Phase 1 -- Collecte et analyse (automatique)

1. Lire les artefacts fournis par l'utilisateur :
   - Si fichier local (document, image) : lire avec Read ou extraction de texte
   - Si reference externe : recuperer via les outils disponibles
   - Si description textuelle : analyser le contenu
2. Explorer le codebase pour identifier :
   - Les fichiers/modules qui seront impactes (Glob + Grep)
   - Les patterns existants similaires (comment le codebase fait des choses proches)
   - Les dependances et contraintes techniques
3. Produire un **DRAFT de regles** : pour chaque element de sortie (tableau, champ, calcul, format), formuler la regle candidate deduite des artefacts.

### Phase 2 -- Discovery Interview (interactive)

Explorer systematiquement 4 dimensions obligatoires dans l'ordre : **Probleme -> Perimetre -> Validation -> Technique**. Budget global : **max 4 rounds** (questions de base + follow-ups).

#### Grille des dimensions (2 sous-questions de base chacune)

| Dimension | Sous-questions de base | Follow-up si insuffisant (max 2) |
|-----------|----------------------|----------------------------------|
| **Probleme** | Quel probleme concret et qui est impacte ? Impact de NE PAS le faire ? | Bon niveau d'abstraction ? Problemes connexes ? |
| **Perimetre** | IN scope vs OUT scope ? MVP ou version complete ? | Criteres d'acceptation precis ? Phases V1/V2 ? |
| **Validation** | Comment savoir que ca marche ? Edge cases a couvrir ? | Tests automatises necessaires ? Metriques de perf ? |
| **Technique** | Modules impactes et patterns a reutiliser ? Contraintes perf/securite ? | Impact architecture ? Dependances nouvelles ? |

#### Considerations ponctuelles (integrer dans les rounds si pertinentes)

- **UX** (si feature a interaction utilisateur) : parcours utilisateur, format I/O, messages d'erreur
- **Alternatives** (si plusieurs approches possibles) : alternatives evaluees, trade-offs, justification

#### Regles pour l'interview

- Maximum 4 questions par round. Un round couvre 2 dimensions (2x2=4 questions)
- Chaque question doit avoir 2-4 options concretes (pas de "autre" vague)
- Si une regle semble evidente depuis les artefacts, la proposer comme option "(Recommande)"
- Si une reponse est insuffisante sur une dimension, poser max 2 questions de suivi dans un round dedie
- Si l'utilisateur repond "je ne sais pas" a une dimension, la marquer "Non couverte" avec justification
- **Condition d'abandon** : si toutes les dimensions obligatoires sont "Non couvert", afficher un warning et proposer d'abandonner ou de produire un spec exploratoire marque "[EXPLORATOIRE]"
- Evaluer UX et Alternatives par auto-evaluation argumentee (1 phrase). Si l'utilisateur conteste un statut "Non applicable", explorer dans le round suivant (max 2 questions)

### Phase 3 -- Production du spec

Generer un document Markdown structure avec les sections suivantes :

```markdown
# Spec : [Titre court]

> Genere le [date]. Source : [artefacts utilises].

## 1. Objectif
[1-3 phrases : quoi et pourquoi]

## 2. Regles metier
Pour chaque domaine/sortie, lister les regles sous forme de table :

| # | Regle | Source | Exemple |
|---|-------|--------|---------|
| R1 | [regle explicite] | [artefact/reponse user] | [cas concret] |

## 3. Donnees d'entree
| Source | Type | Acces | Champs utilises |
|--------|------|-------|-----------------|

## 4. Donnees de sortie
Pour chaque element de sortie (tableau, fichier, email...) :
- Structure (colonnes, format)
- Regles de remplissage (reference aux regles metier)
- Exemple attendu

## 5. Fichiers concernes
| Fichier | Action | Raison |
|---------|--------|--------|
| [chemin] | creer/modifier | [description] |

## 6. Patterns existants
[Comment le codebase fait deja des choses similaires -- code a reutiliser]

## 7. Contraintes
- [Ce qu'il ne faut PAS casser]
- [Limites techniques]
- [Dependances]

## 8. Criteres de validation
| # | Critere | Verification | Niveau |
|---|---------|-------------|--------|
| V1 | [comportement attendu] | [comment verifier] | [unit/integration/E2E/manual] |

## 9. Coverage et zones d'ombre
| Dimension | Statut | Justification |
|-----------|--------|---------------|
| Probleme | Couvert / Non couvert | [raison] |
| Perimetre | Couvert / Non couvert | [raison] |
| Validation | Couvert / Non couvert | [raison] |
| Technique | Couvert / Non couvert | [raison] |
| UX | Pertinent / Non applicable | [justification 1 phrase] |
| Alternatives | Pertinent / Non applicable | [justification 1 phrase] |

**Zones d'ombre residuelles** : [questions non resolues, a trancher pendant l'implementation]
```

Presenter le spec complet a l'utilisateur.

## Regles

- Ne pas inventer de regles : toute regle doit etre tracee vers un artefact ou une reponse utilisateur
- Privilegier la precision a l'exhaustivite : mieux vaut 5 regles claires que 20 vagues
- Si un artefact est un exemple (mail, document), le traiter comme UN CAS -- pas comme LA regle. Demander si c'est representatif
- Le spec est un document vivant : il peut etre mis a jour apres un premier round d'implementation
- Ne pas commencer l'implementation dans ce skill -- le spec est le livrable

## Sortie (artefact obligatoire)

1. Afficher le spec complet dans la conversation
2. **Sauvegarder** dans `docs/specs/SPEC-{name}.md` (obligatoire -- le nom est derive du titre en kebab-case)
3. Confirmer le chemin du fichier sauvegarde

## Etape suivante (workflow)

Apres la sauvegarde, indiquer a l'utilisateur :
- **Recommande** : `/dev-challenge docs/specs/SPEC-{name}.md` pour stress-tester la spec avant implementation
- **Si simple** : `/dev-implement` directement avec reference au spec
