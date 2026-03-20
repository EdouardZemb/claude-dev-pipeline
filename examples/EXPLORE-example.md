---
explore: EXPLORE-cache-migration-valkey
date: 2026-03-10
status: DONE
verdict: GO
option_retenue: "Option B — Migration incrementale vers Valkey 8"
---

# EXPLORE — Migration du systeme de cache de Redis vers Valkey

## 1. Probleme

Depuis le fork Redis/Valkey (mars 2024), Redis Ltd a change la licence de Redis 7.4+ en SSPL (Server Side Public License). Notre stack utilise Redis 7.2 en production pour :
- Cache applicatif (sessions, tokens, reponses API mises en cache)
- Pub/Sub inter-services (notifications temps reel)
- Rate limiting (sliding window counters)

**Contraintes identifiees** :
- La licence SSPL est incompatible avec notre politique open-source interne (validee par le service juridique le 2026-02-15)
- Redis 7.2 est en fin de support communautaire (septembre 2026)
- Nous devons migrer avant le renouvellement infra Q4 2026
- Zero downtime exige : le cache sert 12K req/s en pointe

**Question** : quelle strategie de migration adopter pour remplacer Redis tout en maintenant la continuite de service ?

## 2. Etat de l'art

| Source | Type | Pertinence | Resume |
|--------|------|-----------|--------|
| [Valkey.io — Documentation officielle](https://valkey.io/docs/) | Documentation | Haute | Fork communautaire de Redis 7.2, API compatible a 100%. Maintenu par Linux Foundation. Valkey 8 ajoute les modules RDMA et multi-threaded I/O |
| [AWS ElastiCache — Migration guide](https://docs.aws.amazon.com/elasticache/) | Guide cloud | Moyenne | AWS a migre ElastiCache de Redis vers Valkey. Blue-green deployment natif. Non applicable a notre infra on-premise |
| [KeyDB vs Valkey vs Dragonfly — Benchmark 2026](https://benchmarks.example.com/kv-stores-2026) | Benchmark | Haute | Valkey 8 : +15% throughput vs Redis 7.2 sur workload mixte. KeyDB : multi-threaded natif mais communaute reduite. Dragonfly : 25x Redis en memoire mais incompatible modules |
| [Blog Shopify — Our Valkey migration](https://shopify.engineering/valkey-migration) | Retour experience | Haute | Migration transparente de 200+ instances. Aucun changement code applicatif. Seuls les clients Sentinel ont necessite une reconfig |
| [Dragonfly DB — Documentation](https://dragonflydb.io/docs/) | Documentation | Moyenne | Drop-in replacement Redis, multi-threaded, jusqu'a 25x les performances. Licence BSL (Business Source License), pas de Pub/Sub cluster |
| [Redis Ltd — Licence SSPL FAQ](https://redis.io/legal/licenses/) | Juridique | Haute | SSPL interdit l'usage en SaaS sans open-sourcer toute la stack. Notre usage interne est techniquement couvert mais la politique interne l'interdit par precaution |

## 3. Archeologie codebase

Audit des fichiers et modules qui dependent de Redis dans le codebase actuel.

| Fichier / Module | Dependance Redis | Impact migration |
|------------------|-----------------|-----------------|
| `src/cache/redis_client.py` | Client principal (`redis.asyncio.Redis`) | Faible : Valkey utilise le meme protocole RESP3, le client `redis-py` fonctionne sans modification |
| `src/cache/session_store.py` | Sessions utilisateur (GET/SET avec TTL) | Nul : operations basiques, aucun module specifique Redis |
| `src/pubsub/event_bus.py` | Pub/Sub pour notifications inter-services | Faible : Pub/Sub standard, pas de Redis Streams |
| `src/ratelimit/sliding_window.py` | Lua scripts pour sliding window rate limiting | Moyen : 2 scripts Lua custom, a valider sur Valkey (theoriquement compatible) |
| `docker-compose.yml` | Image `redis:7.2-alpine` | Faible : remplacer par `valkey/valkey:8-alpine` |
| `helm/values.yaml` | Chart Bitnami Redis | Moyen : migrer vers chart Bitnami Valkey (existe depuis v19.0) |
| `tests/conftest.py` | Fixture `redis_client` avec `fakeredis` | Faible : `fakeredis` supporte Valkey protocol (meme RESP3) |
| `src/config/settings.py` | `REDIS_URL` env var | Faible : renommer en `CACHE_URL` (backward-compat avec alias) |
| `monitoring/grafana/dashboards/redis.json` | Dashboard Redis metriques | Moyen : adapter les metriques specifiques (INFO command output differe legerement) |

**Bilan** : 9 fichiers concernes, aucun bloquant. Les 2 scripts Lua et le dashboard Grafana necessitent une validation manuelle.

## 4. Matrice d'alternatives

### Option A — Rester sur Redis 7.2 (statu quo)

| Critere | Evaluation |
|---------|-----------|
| Effort | Nul |
| Risque | Haut — fin de support sept. 2026, pas de patches securite apres |
| Compatibilite | 100% (pas de changement) |
| Performance | Baseline |
| Licence | Non conforme a la politique interne |
| Communaute | Reduite (fork communautaire = Valkey) |

**Verdict** : Non viable a moyen terme. La contrainte licence et la fin de support rendent cette option intenable.

### Option B — Migration incrementale vers Valkey 8

| Critere | Evaluation |
|---------|-----------|
| Effort | Moyen (2-3 jours) — changement image + validation scripts Lua + dashboard |
| Risque | Bas — API 100% compatible, retours d'experience nombreux (Shopify, AWS) |
| Compatibilite | 100% protocole RESP3, client `redis-py` inchange |
| Performance | +15% throughput (benchmark independant) |
| Licence | BSD-3-Clause, conforme |
| Communaute | Linux Foundation, 400+ contributeurs, releases mensuelles |

**Strategie de migration** :
1. Deployer Valkey 8 en replica read-only a cote de Redis 7.2
2. Basculer les lectures vers Valkey (feature flag)
3. Promouvoir Valkey en primary, basculer les ecritures
4. Decommissionner Redis
5. Rollback possible a chaque etape

### Option C — Migration vers Dragonfly DB

| Critere | Evaluation |
|---------|-----------|
| Effort | Eleve (1-2 semaines) — pas de Pub/Sub cluster, refactoring event_bus |
| Risque | Moyen — communaute plus petite, moins de retours en production |
| Compatibilite | 95% — la plupart des commandes Redis, mais pas les modules ni Pub/Sub cluster |
| Performance | Tres haute (25x Redis en single-node) |
| Licence | BSL 1.1, conforme pour usage interne |
| Communaute | Startup (Dragonfly Inc.), ~50 contributeurs |

**Blocage** : le module Pub/Sub cluster n'est pas supporte. Notre `event_bus.py` devrait etre refactorise pour utiliser des polling ou un broker externe (NATS, RabbitMQ). Disproportionne par rapport au gain.

## 5. Verdict

**GO — Option B : Migration incrementale vers Valkey 8**

**Justification** :
- **Compatibilite prouvee** : API 100% compatible, client Python inchange, retour d'experience Shopify sur 200+ instances
- **Risque minimal** : strategie blue-green avec rollback a chaque etape, zero downtime
- **Effort calibre** : 2-3 jours d'implementation + 1 jour de validation en staging
- **Gains mesurables** : +15% throughput, licence conforme, communaute perenne (Linux Foundation)
- **Pas d'alternative credible** : Option A non viable (licence + fin de support), Option C disproportionnee (refactoring Pub/Sub)

**Risques residuels a surveiller** :
- Valider les 2 scripts Lua de rate limiting sur Valkey (V-critere a ajouter en spec)
- Adapter le dashboard Grafana aux metriques Valkey INFO
- Tester la compatibilite `fakeredis` en CI

## 6. Input pour dev-spec

Si le verdict est GO, voici les elements a transmettre a `/dev-spec` :

**Feature** : Migration du systeme de cache de Redis 7.2 vers Valkey 8

**Objectifs** :
- Remplacer Redis 7.2 par Valkey 8 sans interruption de service
- Valider la compatibilite des scripts Lua custom
- Adapter la configuration (Docker, Helm, env vars)
- Adapter le monitoring (dashboard Grafana)

**Contraintes** :
- Zero downtime obligatoire
- Rollback possible a chaque etape
- Client Python `redis-py` inchange (meme protocole RESP3)

**Fichiers a modifier** (identifies en Phase 3 Archeologie) :
- `docker-compose.yml` : image `valkey/valkey:8-alpine`
- `helm/values.yaml` : chart Bitnami Valkey
- `src/config/settings.py` : alias `REDIS_URL` -> `CACHE_URL`
- `monitoring/grafana/dashboards/redis.json` : metriques adaptees

**Fichiers a valider sans modification** :
- `src/cache/redis_client.py` : client inchange
- `src/ratelimit/sliding_window.py` : scripts Lua a tester
- `tests/conftest.py` : fixture `fakeredis` a valider

**V-criteres suggeres** :
- Les 2 scripts Lua de rate limiting produisent les memes resultats sur Valkey et Redis
- Le basculement read replica -> primary se fait sans perte de donnees
- Le rollback Valkey -> Redis restaure l'etat en < 2 minutes
- Le dashboard Grafana affiche les metriques correctes apres migration
