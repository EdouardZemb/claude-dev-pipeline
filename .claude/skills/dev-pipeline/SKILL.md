---
name: dev-pipeline
description: "Meta-orchestrateur du pipeline de maturation (spec -> challenge -> implement -> review -> doc -> commit). TRIGGER when: nouvelle feature complexe a traiter de bout en bout. DO NOT TRIGGER for: changement simple (use dev-implement) ou etape isolee (use dev-spec, dev-challenge, etc.)."
argument-hint: "[description feature] ou [--from {phase} docs/specs/SPEC-{name}.md]"
---

Input : $ARGUMENTS (description de la feature OU `--from {phase} chemin-spec`)
Prerequis : aucun

## Objectif

Derouler automatiquement tout le pipeline de maturation -- de l'idee au commit -- en orchestrant les skills et agents existants. L'utilisateur fournit une description ; le pipeline produit du code livre avec spec, review adversariale, implementation, documentation et commit.

## Initialisation

Avant toute phase, noter le SHA du HEAD courant pour isoler les metriques du pipeline :

```bash
PIPELINE_START_SHA=$(git rev-parse HEAD)
```

Ce SHA sera utilise en Phase 6 pour calculer les diff stats uniquement sur les commits crees par le pipeline.

Capturer egalement le baseline de couverture tests pour le delta :

```bash
COVERAGE_BEFORE=$({your_test_command} --coverage 2>&1 | grep -oP '\d+(?=%)' || echo "")
```

Si la commande echoue ou ne retourne pas de valeur, `COVERAGE_BEFORE` reste vide et le delta ne sera pas affiche en Phase 6.

## Parsing des arguments

1. Si `$ARGUMENTS` contient `--from {phase}` :
   - Extraire la phase de depart parmi : `spec`, `challenge`, `implement`, `review`, `doc`, `commit`
   - Extraire le chemin de spec (argument restant)
   - Verifier que le fichier spec existe (Read). Si absent : STOP avec message d'erreur
   - Deduire `{name}` du nom de fichier (ex: `SPEC-batch-emission.md` -> `batch-emission`)
   - Demarrer a la phase demandee (sauter les phases precedentes)
   - Tableau de skip des phases selon `--from` :

| `--from` | Phase 1 | Phase 1b | Phase 2 | Phase 3 (a-d) | Phase 4 | Phase 5 | Phase 6 |
|----------|---------|----------|---------|---------------|---------|---------|---------|
| `spec` | execute | execute | execute | execute | execute | execute | execute |
| `challenge` | skip | skip | execute | execute | execute | execute | execute |
| `implement` | skip | skip | skip | execute | execute | execute | execute |
| `review` | skip | skip | skip | skip | execute | execute | execute |
| `doc` | skip | skip | skip | skip | skip | execute | execute |
| `commit` | skip | skip | skip | skip | skip | skip | partiel |

2. Sinon :
   - La description complete est l'input de la Phase 1
   - Deduire `{name}` apres la Phase 1 (du titre de la spec produite)

## Phases

### Phase 1 -- SPEC (skip si `--from` >= challenge)

Deleguer a un subagent specialise **Spec Architect** (Agent tool, subagent_type: general-purpose) avec ces instructions :

> Tu es le Spec Architect. Lis ton profil agent dans `.claude/agents/spec-architect.md` et suis ses instructions.
> Lis egalement `.claude/skills/dev-spec/SKILL.md` pour le template exact des 9 sections et le workflow (collecte, interview, production).
> Input : "{description fournie par l'utilisateur}"
> Sauvegarde le resultat dans `docs/specs/SPEC-{name}.md`.

Attendre la completion. Recuperer le chemin du fichier spec produit.

Message de progression : "Phase 1 terminee -- spec produite : docs/specs/SPEC-{name}.md"

---

### Phase 1b -- QUALITY GATE POST-SPEC (skip si `--from` >= challenge)

Checkpoint de validation utilisateur. Objectif : verifier que la spec repond au besoin avant de lancer le stress-test adversarial.

#### 1. Resume synthetique

Lire `docs/specs/SPEC-{name}.md` et extraire un resume structure :

```
--- Resume spec : SPEC-{name} ---

Objectif : {section 1 -- probleme resolu, en 1-2 phrases}
Perimetre : {section 5 -- modules/packages impactes}
V-criteres : {N} criteres de verification (section 8)
Fichiers impactes : {liste des fichiers de la section 5, ou "a determiner" si absente}
Regles metier cles : {2-3 regles principales de la section 2, en bref}

Spec complete : docs/specs/SPEC-{name}.md
```

Afficher ce resume dans la conversation.

#### 2. Gate GO / REVISE / STOP

Demander a l'utilisateur (question directe dans la conversation) :

> "La spec repond-elle au besoin ? **GO** (lancer le challenge adversarial) / **REVISE** (re-executer la spec avec feedback) / **STOP** (abandonner le pipeline)"

Attendre la reponse de l'utilisateur.

**GO** : continuer vers Phase 2.

**REVISE** :
1. L'utilisateur fournit son feedback (ce qui manque, ce qui est mal compris, ce qui doit changer)
2. Re-executer Phase 1 en passant le feedback comme contexte additionnel :
   > Deleguer a un subagent Spec Architect avec instructions :
   > "Tu es le Spec Architect. Lis ton profil agent dans `.claude/agents/spec-architect.md` et suis ses instructions.
   > Lis egalement `.claude/skills/dev-spec/SKILL.md` pour le template exact des 9 sections.
   > Input : '{description originale}. REVISION : la spec precedente (docs/specs/SPEC-{name}.md) doit etre revisee selon ce feedback utilisateur : {feedback}.'
   > Sauvegarde le resultat dans `docs/specs/SPEC-{name}.md` (ecrase la version precedente)."
3. Attendre la completion. Revenir au debut de la Phase 1b (resume + gate).
4. **Max 2 cycles REVISE**. Au 3e REVISE, traiter comme GO (la spec est assez bonne pour le challenge adversarial qui affinera).

**STOP** : arreter le pipeline. Produire un rapport minimal dans `docs/reviews/pipeline-{name}.md` avec statut "STOPPED (utilisateur)" et la raison. Afficher a l'utilisateur la suggestion de reprendre avec `/dev-pipeline` quand pret.

Message de progression : "Phase 1b terminee -- gate {GO/REVISE cycle N/STOP}."

---

### Phase 2 -- CHALLENGE ADVERSARIAL + IMPACT ANALYSIS (skip si `--from` >= implement)

Lancer **en parallele** deux subagents :

#### 2a. Challenge adversarial

Deleguer a un subagent (Agent tool, subagent_type: general-purpose) avec ces instructions :

> Lis le fichier `.claude/skills/dev-challenge/SKILL.md` et execute ses instructions completement.
> Input : "docs/specs/SPEC-{name}.md"
> Sauvegarde le resultat dans `docs/reviews/adversarial-SPEC-{name}.md`.

#### 2b. Impact Analyst (en parallele)

Deleguer a un subagent (Agent tool, subagent_type: general-purpose) avec ces instructions :

> Tu es l'Impact Analyst. Lis ton profil agent dans `.claude/agents/impact-analyst.md` et suis ses instructions.
> Input : "docs/specs/SPEC-{name}.md"
> Sauvegarde le resultat dans `docs/reviews/impact-SPEC-{name}.md`.

Attendre la completion des deux subagents.

#### Evaluation du verdict

Lire `docs/reviews/adversarial-SPEC-{name}.md` et identifier le verdict dans la section "Verdict".

**Seuils adaptatifs** : si un agent adversarial a crash ou timeout, les seuils s'adaptent au nombre d'agents ayant repondu. Formule : `seuil_majeur = nb_agents_repondus`. Avec 3 agents : >= 3 MAJEURS. Avec 2 agents : >= 2 MAJEURS. Le seuil BLOQUANT (>= 1) reste inchange.

**GO** : passer directement a la Phase 3.

**GO WITH CHANGES** :
1. Lire les findings MAJEURS et les recommandations du rapport adversarial
2. Proposer a l'utilisateur un diff de la spec integrant les recommandations. Presenter le diff clairement (sections modifiees, ajouts, suppressions)
3. Demander la validation de l'utilisateur (question directe dans la conversation)
4. Si l'utilisateur valide : appliquer les modifications a `docs/specs/SPEC-{name}.md`
5. Re-challenger la spec mise a jour (relancer un subagent challenge, cycle 2)
6. Si le cycle 2 retourne :
   - **GO** : continuer vers Phase 3
   - **GO WITH CHANGES** : traiter comme GO (max 2 cycles adversariaux) et continuer vers Phase 3
   - **NO-GO** : STOP definitif (voir ci-dessous)

**NO-GO** : STOP. Produire le rapport pipeline avec les raisons et pistes de resolution. Sauvegarder dans `docs/reviews/pipeline-{name}.md`. Afficher a l'utilisateur :
- Les raisons du NO-GO (findings BLOQUANTS)
- Les pistes de resolution proposees par les agents
- La suggestion de retravailler la spec avec `/dev-spec`

Message de progression : "Phase 2 terminee -- verdict {verdict}. Impact: docs/reviews/impact-SPEC-{name}.md"

---

### Phase 3 -- IMPLEMENTATION (skip si `--from` >= review)

#### Detection spec documentaire

Avant de deleguer, lire la section 5 (Fichiers concernes) de la spec et determiner si c'est une **spec documentaire** :
- Lister les fichiers de la section 5 (exclure les fichiers de tests)
- Si **aucun fichier source** (uniquement `.md`, `.yaml`, `.json`, `.toml`, ou fichiers de configuration) : c'est une spec documentaire
- Ajouter dans les instructions du subagent : `"SPEC DOCUMENTAIRE : le Test Architect doit generer des tests structurels (existence, front-matter, sections, references). Voir la section 'Specs documentaires' de test-architect.md."`

Deleguer a un subagent (Agent tool, subagent_type: general-purpose) avec ces instructions :

> Lis le fichier `.claude/skills/dev-implement/SKILL.md` et execute ses instructions completement.
> Input : "Implementer SPEC-{name}. Spec: docs/specs/SPEC-{name}.md. Review adversariale: docs/reviews/adversarial-SPEC-{name}.md"
> L'equipe DOIT lire la spec ET la review adversariale pour tenir compte des findings.
> **Scope guard** : ne modifier que les fichiers listes dans la section 5 de la spec. Si un besoin hors scope est identifie (nouveau fichier, module non liste), le documenter en fin de rapport d'implementation sans l'implementer.
> Sauvegarde le resultat dans `docs/reviews/implement-{name}.md`.

L'equipe `/dev-implement` coordonne en interne 3 sous-phases :
- **Phase 3a** -- Test Architect genere les squelettes TDD depuis la spec
- **Phase 3b** -- Implementer code pour faire passer les tests (TDD)
- **Phase 3c** -- Tester complete les squelettes (edge cases, erreurs, robustesse)

Attendre la completion. Lire le rapport pour verifier le statut (DONE ou NEEDS_FIXES).

Si **NEEDS_FIXES** : le rapport d'implementation detaille les problemes. Le pipeline s'arrete et produit un rapport partiel. L'utilisateur doit corriger puis reprendre avec `--from review`.

Si **DONE** : continuer vers Phase 3d.

Message de progression : "Phase 3 (a-c) terminee -- implementation complete, statut {statut}."

---

### Phase 3d -- CONFORMANCE CHECK (skip si `--from` >= review)

Executer dans le contexte principal (pas de subagent -- c'est une verification, pas une phase complexe).

**Objectif** : verifier que les V-criteres de la spec (section 8) sont couverts par des tests marques `@pytest.mark.spec("Vx")` (ou l'equivalent dans votre framework de test).

**Adaptation requise** : le mecanisme de verification de conformance depend de votre projet. Vous devez adapter cette phase a votre stack :
- Si vous avez un outil de conformance check (ex: API Python, script custom) : l'utiliser ici
- Sinon : verifier manuellement que chaque V-critere de la section 8 de la spec a au moins un test correspondant

#### Cas 1 -- Spec sans V-criteres

WARNING "spec sans V-criteres -- feature purement technique (ok)". GO direct vers Phase 4.

#### Cas 2 -- Orphelins detectes (markers sans V-critere correspondant)

**STOP immediat. Pas de boucle corrective.**

Afficher dans la conversation :

```
Phase 3d BLOQUE -- orphelins detectes.
Raison : N marker(s) orphelin(s) -- markers de test sans V-critere correspondant dans la spec.

Action requise :
- Supprimer les markers orphelins des tests, OU
- Ajouter les V-criteres correspondants dans docs/specs/SPEC-{name}.md
- Puis reprendre avec : /dev-pipeline --from implement docs/specs/SPEC-{name}.md
```

#### Cas 3 -- V-criteres non couverts, pas d'orphelins

Boucle corrective, **max 2 cycles** :

1. Deleguer a un subagent Tester pour ajouter les markers manquants et completer les tests si necessaire :
   > "Les V-criteres suivants sont non couverts : [liste]. Ajouter les markers manquants dans les fichiers de tests existants et completer les tests si necessaire. Ne pas modifier la logique metier."
2. Attendre la completion du subagent
3. Re-executer la verification de conformance
4. Si des orphelins sont introduits par le cycle correctif : STOP immediat (meme comportement que Cas 2)
5. Si encore des gaps apres 2 cycles : STOP avec statut NEEDS_FIXES

#### Cas 4 -- 100% coverage

GO direct vers Phase 4.

Message de progression : "Phase 3d terminee -- conformance: {N}/{M} couverts. GO vers Phase 4." (ou message STOP si bloquant)

---

### Phase 4 -- REVIEW (skip si `--from` >= doc)

Phase de review unique.

#### 4a. Reviewer

**Calcul du scope de review** : avant de deleguer au Reviewer, calculer la liste des fichiers reellement modifies par le pipeline :

```bash
# Si des commits pipeline existent (SHA a change)
CURRENT_SHA=$(git rev-parse HEAD)
if [ "$CURRENT_SHA" != "$PIPELINE_START_SHA" ]; then
  CHANGED_FILES=$(git diff --name-only $PIPELINE_START_SHA..HEAD)
else
  # Fallback : staged + unstaged + fichiers nouveaux (untracked)
  CHANGED_FILES=$(git diff --name-only HEAD; git ls-files --others --exclude-standard)
fi
```

**Si la liste est vide** (aucun fichier modifie) : skip la Phase 4 review. Marquer "SKIPPED (aucun fichier modifie)" dans le rapport Phase 6.

**Si la liste est non-vide** : deleguer a un subagent (Agent tool, subagent_type: general-purpose) avec ces instructions :

> Tu es le Reviewer. Lis ton profil agent dans `.claude/agents/reviewer.md` et suis ses instructions.
> Input : "Fichiers modifies pour SPEC-{name}. Contexte : implementation de docs/specs/SPEC-{name}.md."
> Rapport d'impact disponible : docs/reviews/impact-SPEC-{name}.md -- utiliser comme input supplementaire pour prioriser les points de review.
>
> **Scope de la review** -- fichiers modifies par ce pipeline :
> {liste des fichiers, un par ligne, prefixe "- "}
>
> UNIQUEMENT ces fichiers -- ne pas signaler de problemes dans des fichiers non modifies. Exception : les findings de type "backward compatibility" (cassure d'API publique impactant des dependants) sont autorises hors scope, clairement marques comme tels.
>
> Sauvegarde le resultat dans `docs/reviews/review-{name}.md`.

#### 4b. Security Checker (conditionnel)

Si les fichiers modifies touchent auth, credentials, reseau, subprocess ou transport HTTP, lancer **en parallele** du Reviewer :

Deleguer a un subagent (Agent tool, subagent_type: general-purpose) avec ces instructions :

> Tu es le Security Checker. Lis ton profil agent dans `.claude/agents/security-checker.md` et suis ses instructions.
> Input : "Fichiers modifies pour SPEC-{name}."

Attendre la completion de tous les subagents. Lire le rapport de review pour extraire le verdict.

#### Evaluation du verdict

Lire `docs/reviews/review-{name}.md` et identifier la decision (APPROVE ou REQUEST CHANGES).

**APPROVE** : continuer vers Phase 5.

**REQUEST CHANGES** :
1. Lire les findings bloquants du rapport de review
2. Deleguer a un subagent Implementer pour corriger les bloquants :
   > "Les findings bloquants suivants ont ete identifies par la review : [liste]. Corriger uniquement ces points. Spec: docs/specs/SPEC-{name}.md. Review: docs/reviews/review-{name}.md."
3. Attendre la completion du subagent
4. Re-executer `{your_ci_command}` pour verifier que les corrections passent
5. Si CI verte : continuer vers Phase 5 (pas de 2e cycle review -- max 1 boucle corrective)
6. Si CI rouge : STOP avec statut NEEDS_FIXES

Message de progression : "Phase 4 terminee -- review {verdict}. GO vers Phase 5." (ou message STOP si REQUEST CHANGES non resolu)

---

### Phase 5 -- FINALISATION (doc + CI + commit)

#### 5a. Documentation

Deleguer a un subagent (Agent tool, subagent_type: general-purpose) avec ces instructions :

> Lis le fichier `.claude/skills/dev-doc/SKILL.md` et execute ses instructions completement.
> Contexte : implementation de SPEC-{name}. Verifier la coherence de la documentation avec les changements effectues.

Attendre la completion.

#### 5b. CI + Commit

Executer dans le contexte principal (pas de subagent) :

0. **Lint auto-fix** : les subagents generent souvent du code non conforme au linter. Executer avant CI pour eviter un echec trivial :
   ```bash
   {your_lint_command} --fix . 2>/dev/null; {your_format_command} . 2>/dev/null
   ```
   (Adapter les commandes a votre stack : ruff, eslint, prettier, black, etc.)

1. **Verifier l'etat git** : les subagents peuvent avoir auto-committe pendant la Phase 3. Verifier quels fichiers sont deja commites avant de stager :
   ```bash
   git status
   ```
   Ne stager que les artefacts pipeline restants (spec Rev.2, adversarial review, rapport, doc) et les fichiers non encore commites.

2. `{your_ci_command}` (lint + tests)
   - Si echec : inclure l'erreur dans le rapport. Statut pipeline = NEEDS_FIXES. Ne pas committer.
   - Si succes : continuer

3. Preparer le commit :
   - `git add` des fichiers identifies a l'etape 1 (pas de `git add .` aveugle)
   - Message de commit conventionnel, avec `Co-Authored-By`
   - Creer le commit

4. Ne jamais `git push` -- le deploy est manuel

Message de progression : "Phase 5 terminee -- CI green, commit {hash}. Pour deployer : git push"

---

### Phase 6 -- RAPPORT

Generer le rapport consolide et sauvegarder dans `docs/reviews/pipeline-{name}.md`.

Le rapport s'adapte au nombre de phases executees (pas de lignes vides pour les phases skippees via `--from`).

#### 6a. Collecte des metriques quantitatives

Avant de generer le rapport, collecter les metriques suivantes dans le contexte principal :

1. **Diff stats** : executer `git diff --stat $PIPELINE_START_SHA..HEAD` pour ne compter que les commits crees par le pipeline (isole des commits concurrents). Si le pipeline n'a pas encore committe (NEEDS_FIXES/NO-GO), utiliser `git diff --stat` (staged + unstaged). Extraire :
   - Nombre de fichiers modifies
   - Nombre d'insertions (+) et de deletions (-)
   - Total lignes changees (insertions + deletions)

2. **Delta couverture tests** : capturer le pourcentage apres CI et comparer avec le baseline (capture en Initialisation) :
   - Si `COVERAGE_BEFORE` et `COVERAGE_AFTER` sont definis : calculer `DELTA = COVERAGE_AFTER - COVERAGE_BEFORE` et afficher `+X%` ou `-X%`
   - Si l'un des deux est absent : afficher "N/A" pour le delta

3. **Compteurs pipeline** : extraire des artefacts des phases precedentes :
   - **V-criteres** : total et couverts de Phase 3d (0/0 si Phase 3d skippee ou spec sans V-criteres)
   - **Taux conformance** : couverts / total * 100 (ou "N/A" si total == 0)
   - **Findings adversarial** : compter les findings BLOQUANT, MAJEUR, MINEUR dans `docs/reviews/adversarial-SPEC-{name}.md` (0 si Phase 2 skippee)
   - **Findings review** : compter les findings bloquants et non-bloquants dans `docs/reviews/review-{name}.md` (0 si Phase 4 skippee)
   - **Impact** : niveau de risque (LOW/MEDIUM/HIGH) dans `docs/reviews/impact-SPEC-{name}.md` (N/A si Phase 2 skippee)

4. **Checklist d'acceptance (validation utilisateur)** : construire a partir des V-criteres de la Phase 3d. Pour chaque critere :
   - Si couvert par CI (unit/integration) : marquer `[x]` avec mention "auto-verifie (CI)"
   - Si hors CI (E2E/manual) : marquer `[ ]` avec mention "A verifier manuellement"
   - Si Phase 3d skippee ou spec sans V-criteres : indiquer "N/A -- pas de V-criteres disponibles"

#### 6b. Generation du rapport

```markdown
# Pipeline Report : {Titre}

> Genere le {date}.

## Phases

| Phase | Statut | Artefact |
|-------|--------|----------|
| 1. Spec | {statut} | docs/specs/SPEC-{name}.md |
| 1b. Quality Gate | {GO / REVISE x N / STOP} | -- (inline) |
| 2. Challenge + Impact | {statut + verdict} | docs/reviews/adversarial-SPEC-{name}.md, docs/reviews/impact-SPEC-{name}.md |
| 3a. Test Architect | {statut} | squelettes TDD generes |
| 3b. Implementer (TDD) | {statut} | code source |
| 3c. Tester | {statut} | tests completes |
| 3d. Conformance Check | {statut + N/M criteres} | -- (inline dans ce rapport si STOP) |
| 4. Review | {statut + verdict} | docs/reviews/review-{name}.md |
| 5. Documentation | {statut} | documentation mise a jour |
| 5b. CI + Commit | {statut} | {commit hash} |

## Metriques

### Ampleur du changement

| Metrique | Valeur |
|----------|--------|
| Fichiers modifies | {N} |
| Insertions (+) | {N} |
| Deletions (-) | {N} |
| Total lignes changees | {N} |

### Couverture

| Metrique | Valeur |
|----------|--------|
| V-criteres spec | {covered}/{total} ({taux}%) |
| Couverture tests | {COVERAGE_AFTER}% -- delta: {DELTA}% |

### Findings

| Source | Bloquant | Majeur | Mineur | Total |
|--------|----------|--------|--------|-------|
| Challenge adversarial | {N} | {N} | {N} | {N} |
| Review | {N} | {N} | {N} | {N} |
| Impact Analyst | -- | -- | -- | Risque: {LOW/MEDIUM/HIGH} |

## Validation utilisateur

> Checklist d'acceptance generee a partir des V-criteres de la spec (section 8).
> Les criteres CI sont auto-verifies par les tests. Les criteres E2E/manuels
> necessitent une verification humaine pour confirmer que le code repond au besoin.
> Cette section ne bloque PAS le pipeline -- c'est un rappel structure.

| # | Critere | Niveau | Statut |
|---|---------|--------|--------|
{Pour chaque V-critere, une ligne :}
| V1 | {description} | unit | [x] auto-verifie (CI) |
| V2 | {description} | E2E | [ ] A verifier manuellement |
| V3 | {description} | manual | [ ] A verifier manuellement |

{Si aucun V-critere disponible :}
N/A -- pas de V-criteres disponibles (spec sans section 8 ou Phase 3d skippee).

### Criteres a verifier manuellement

{Liste des V-criteres avec level E2E ou manual, avec description complete et suggestion de verification :}

- [ ] **V2** (E2E) : {description complete du critere} -- *Verification : {methode de verification du critere}*
- [ ] **V3** (manual) : {description complete du critere} -- *Verification : {methode de verification du critere}*

{Si aucun critere hors-CI : "Aucun critere hors-CI -- tous les V-criteres sont couverts par la CI."}

## Artefacts produits
- docs/specs/SPEC-{name}.md
- docs/reviews/adversarial-SPEC-{name}.md
- docs/reviews/impact-SPEC-{name}.md
- docs/reviews/implement-{name}.md
- docs/reviews/review-{name}.md
- docs/reviews/pipeline-{name}.md (ce fichier)

## Statut final
{statut} -- {justification}
```

**Logique de calcul du statut final** :

| Condition | Statut |
|-----------|--------|
| Pipeline reussi + V-criteres E2E/manual restants | `DONE (PENDING E2E)` |
| Pipeline reussi + aucun V-critere hors-CI | `DONE` |
| Pipeline reussi + Phase 3d skippee (`--from` >= review) | `DONE` |
| Pipeline reussi + spec sans V-criteres | `DONE` |
| Pipeline echoue (CI rouge, conformance KO, etc.) | `NEEDS_FIXES` |
| Challenge adversarial NO-GO definitif | `NO-GO` |

Afficher le rapport dans la conversation et confirmer le chemin du fichier sauvegarde.

Message final : "Pipeline termine -- rapport : docs/reviews/pipeline-{name}.md. Pour deployer : git push"

## Regles

- **Pas de skills imbriques** : ne pas invoquer `/dev-spec`, `/dev-challenge`, etc. via Skill tool. Deleguer a des subagents qui lisent les SKILL.md correspondants
- **Max 2 cycles adversariaux** : si le 2e challenge retourne NO-GO, stop definitif. 2e GO WITH CHANGES = GO
- **Max 2 boucles correctives** : inherite de `/dev-implement`
- **Pas de push** : le pipeline commit mais ne pousse jamais
- **Seuils adaptatifs** : si un agent adversarial crash, adapter les seuils au nombre d'agents ayant repondu
- **Context lean** : les phases paralleles (challenge + impact, implement) sont deleguees a des subagents pour garder le contexte principal leger
- **Phase 3d inline** : le conformance check s'execute dans le contexte principal (pas de subagent pour le check lui-meme). Le cycle correctif delegue au Tester
- **Orphelins = STOP immediat** : pas de tentative de correction automatique (indique souvent un probleme de spec, pas juste de test)
- **Skip Phase 3/3d si `--from` >= review** : si l'utilisateur reprend a `--from review`, `--from doc` ou `--from commit`, il prend la responsabilite de l'implementation et de la conformance
- **Phase 4 max 1 boucle corrective** : si REQUEST CHANGES, un seul cycle correctif (pas de re-review). Si CI rouge apres correction : STOP NEEDS_FIXES
- **Quality gate post-spec (Phase 1b)** : l'utilisateur valide que la spec repond au besoin avant le challenge adversarial. Resume synthetique + gate GO/REVISE/STOP. Evite de challenger une spec qui ne correspond pas au besoin
- **Max 2 cycles REVISE** : si l'utilisateur demande REVISE 3 fois en Phase 1b, traiter comme GO. La spec est assez mature pour le challenge adversarial
- **Skip Phase 1b si `--from` >= challenge** : la validation post-spec n'est pertinente qu'apres generation de la spec en Phase 1
- **`--from commit`** : execute uniquement Phase 5b (CI + commit) sans documentation. Utile quand l'implementation et la doc sont deja faites mais le commit manque (ex: CI avait echoue). Le rapport Phase 6 est genere avec les phases precedentes marquees "skip"
- **Impact Analyst en parallele** : l'Impact Analyst s'execute en meme temps que le challenge adversarial en Phase 2 -- pas de latence ajoutee. Son rapport est transmis au Reviewer en Phase 4
- **Pas de Reviewer en Phase 3** : le Reviewer n'intervient qu'en Phase 4 (review unique). L'equipe Phase 3 est Test Architect + Implementer + Tester (pas de review interne)

## Placeholders a adapter

Les commandes suivantes doivent etre adaptees a votre projet :

| Placeholder | Description | Exemples |
|-------------|-------------|----------|
| `{your_ci_command}` | Commande CI complete (lint + tests) | `just ci`, `make check`, `npm run ci` |
| `{your_lint_command}` | Commande lint seule | `ruff check`, `eslint`, `flake8` |
| `{your_format_command}` | Commande de formatage | `ruff format`, `prettier --write`, `black` |
| `{your_test_command}` | Commande tests seule | `pytest`, `jest`, `go test ./...` |
| `{your_package_manager}` | Gestionnaire de paquets | `uv`, `npm`, `pip`, `cargo` |

## Sortie (artefact obligatoire)

1. Afficher le rapport consolide dans la conversation
2. **Sauvegarder** dans `docs/reviews/pipeline-{name}.md` (obligatoire)
