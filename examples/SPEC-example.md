---
spec: SPEC-healthcheck-endpoint
version: Rev.2
date: 2026-03-15
status: VALIDATED
author: Spec Architect
---

# SPEC — Endpoint de healthcheck API REST

## 1. Contexte

L'API REST du service `payment-gateway` ne dispose pas de mecanisme de healthcheck. Les orchestrateurs (Kubernetes, load balancers) ne peuvent pas determiner si le service est operationnel, ce qui provoque :
- Du trafic route vers des instances defaillantes (erreurs 502 en cascade)
- Des redemarrages retardes : le liveness probe Kubernetes utilise un TCP check qui ne detecte pas les pannes applicatives (connexion BDD perdue, queue pleine)
- Pas de visibilite operationnelle sur l'etat des dependances en production

Incident declencheur : le 2026-03-01, une panne de 47 minutes due a un pool de connexions PostgreSQL sature, non detecte par le TCP probe.

## 2. Objectifs

- O1 : Fournir un endpoint `/health` qui retourne l'etat agrege du service et de ses dependances
- O2 : Supporter les deux modes Kubernetes : liveness (le process tourne) et readiness (le service peut traiter du trafic)
- O3 : Permettre aux ops de diagnostiquer rapidement quelle dependance est en panne
- O4 : Ne pas degrader les performances du service (overhead < 5ms p99 sur le healthcheck)

## 3. Perimetre

### In-scope

- Endpoint `GET /health` avec reponse JSON structuree
- Endpoint `GET /health/live` (liveness, sans check dependances)
- Endpoint `GET /health/ready` (readiness, avec check dependances)
- Checks de dependances : PostgreSQL, Redis, RabbitMQ
- Configuration des timeouts et seuils par dependance
- Metriques Prometheus sur les checks (duree, statut)

### Out-of-scope

- Dashboard de monitoring (existe deja via Grafana)
- Alerting (gere par AlertManager, consomme les metriques)
- Healthcheck des services downstream (API tierces) — a traiter dans une spec dediee
- Authentication sur les endpoints de healthcheck (acces libre, derriere ingress interne)

## 4. Design

### Architecture

```
GET /health/live   -> LivenessHandler   -> { status: "UP" }
GET /health/ready  -> ReadinessHandler  -> DependencyChecker -> [PostgresCheck, RedisCheck, RabbitCheck]
GET /health        -> HealthHandler     -> ReadinessHandler + metadata (version, uptime)
```

### Interface de reponse

```json
{
  "status": "UP",
  "version": "2.4.1",
  "uptime_seconds": 84200,
  "checks": {
    "postgresql": {
      "status": "UP",
      "response_time_ms": 2.3,
      "details": { "pool_active": 5, "pool_max": 20 }
    },
    "redis": {
      "status": "UP",
      "response_time_ms": 0.8,
      "details": { "connected_clients": 12 }
    },
    "rabbitmq": {
      "status": "DOWN",
      "response_time_ms": null,
      "error": "Connection refused",
      "details": {}
    }
  }
}
```

### Codes HTTP

| Endpoint | Tous UP | Au moins un DOWN |
|----------|---------|------------------|
| `/health/live` | 200 | 200 (toujours, sauf process mort) |
| `/health/ready` | 200 | 503 |
| `/health` | 200 | 503 |

### Classes principales

```python
class DependencyCheck(Protocol):
    """Interface pour un check de dependance."""
    name: str
    async def check(self) -> CheckResult: ...

class CheckResult:
    status: Literal["UP", "DOWN"]
    response_time_ms: float | None
    error: str | None
    details: dict[str, Any]

class DependencyChecker:
    """Execute tous les checks en parallele avec timeout individuel."""
    def __init__(self, checks: list[DependencyCheck], timeout_ms: int = 3000): ...
    async def run_all(self) -> dict[str, CheckResult]: ...

class HealthHandler:
    """Handler principal, compose liveness + readiness + metadata."""
    def __init__(self, checker: DependencyChecker, app_version: str): ...
    async def handle(self, request: Request) -> Response: ...
```

### Configuration

```yaml
health:
  timeout_ms: 3000        # Timeout global par check
  cache_ttl_ms: 5000      # Cache des resultats (evite de surcharger les dependances)
  checks:
    postgresql:
      enabled: true
      timeout_ms: 2000     # Override du timeout global
    redis:
      enabled: true
    rabbitmq:
      enabled: true
```

## 5. V-criteres

| ID | Description | Niveau |
|----|-------------|--------|
| V1 | `GET /health/live` retourne 200 avec `{"status": "UP"}` quand le service tourne | unit |
| V2 | `GET /health/ready` retourne 200 quand toutes les dependances sont UP | integration |
| V3 | `GET /health/ready` retourne 503 quand au moins une dependance est DOWN | integration |
| V4 | Le check PostgreSQL detecte un pool de connexions sature (pool_active >= pool_max) | unit |
| V5 | Le check Redis detecte une connexion refusee et retourne status DOWN | unit |
| V6 | Le check RabbitMQ detecte un timeout de connexion et retourne status DOWN | unit |
| V7 | Les checks s'executent en parallele (duree totale < max des durees individuelles + 100ms) | unit |
| V8 | Un check qui depasse son timeout retourne DOWN avec error "Timeout after {timeout_ms}ms" | unit |
| V9 | Les resultats sont caches pendant `cache_ttl_ms` (deux appels rapides = un seul check reel) | unit |
| V10 | `GET /health` inclut version et uptime_seconds dans la reponse | unit |
| V11 | Les metriques Prometheus `health_check_duration_seconds` et `health_check_status` sont emises | integration |
| V12 | Un check desactive par config (`enabled: false`) n'apparait pas dans la reponse | unit |
| V13 | Le endpoint `/health` repond en moins de 5ms p99 quand les resultats sont en cache | E2E |
| V14 | Kubernetes peut utiliser `/health/live` comme liveness probe et `/health/ready` comme readiness probe | manual |

## 6. Coverage matrix

| Dimension | Couverture |
|-----------|-----------|
| **Fonctionnel** | V1, V2, V3, V10 — parcours nominal UP/DOWN, metadata reponse |
| **Erreurs** | V4, V5, V6, V8 — chaque dependance en echec, timeout depasse |
| **Edge cases** | V7, V9, V12 — parallelisme, cache, check desactive |
| **Securite** | Endpoint sans auth (perimetre : ingress interne uniquement). Pas de donnees sensibles dans la reponse (pas de credentials, pas de hostnames internes dans la version publique) |
| **Performance** | V13 — latence p99 < 5ms en cache. V9 — cache TTL evite la surcharge des dependances |
| **Integration** | V2, V3, V11, V14 — interaction avec vraies dependances, metriques Prometheus, probes Kubernetes |

## 7. Risques

| Risque | Probabilite | Impact | Mitigation |
|--------|-------------|--------|-----------|
| Le healthcheck surcharge les dependances (appels trop frequents) | Moyenne | Moyen | Cache TTL configurable (defaut 5s). Metriques pour monitorer la frequence |
| Un check bloquant gele tout le endpoint | Basse | Haut | Timeout individuel par check + execution en parallele avec `asyncio.gather` |
| Faux positif : dependance OK mais check echoue (reseau intermittent) | Moyenne | Moyen | Retry configurable (0 par defaut, 1 recommande en prod) |
| Information disclosure via les details des checks | Basse | Moyen | Les details (pool_active, connected_clients) sont utiles aux ops mais pas critiques. Le endpoint est derriere l'ingress interne |

## 8. Dependances

| Dependance | Type | Version | Usage |
|-----------|------|---------|-------|
| FastAPI | Framework | >=0.104 | Routing, Request/Response |
| asyncpg | Librairie | >=0.29 | Check PostgreSQL (pool stats) |
| redis.asyncio | Librairie | >=5.0 | Check Redis (PING) |
| aio-pika | Librairie | >=9.0 | Check RabbitMQ (connexion) |
| prometheus-client | Librairie | >=0.20 | Metriques healthcheck |
| pydantic-settings | Librairie | >=2.0 | Configuration YAML/env |

## 9. Plan

| Tache | Effort | Priorite |
|-------|--------|----------|
| T1 : Interfaces (`DependencyCheck`, `CheckResult`) + `DependencyChecker` | 2h | P0 |
| T2 : Checks PostgreSQL, Redis, RabbitMQ | 3h | P0 |
| T3 : Handlers HTTP (`/health`, `/health/live`, `/health/ready`) | 2h | P0 |
| T4 : Cache des resultats avec TTL configurable | 1h | P0 |
| T5 : Configuration YAML/env avec pydantic-settings | 1h | P1 |
| T6 : Metriques Prometheus | 1h | P1 |
| T7 : Tests d'integration avec containers (testcontainers) | 2h | P1 |
| **Total** | **12h** | |
