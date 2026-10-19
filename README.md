# Remote Tic-Tac-Toe

Ein kleines verteiltes Tic-Tac-Toe-System mit OAuth2, REST und WebSockets.

## Architektur

```text
Browser (Angular/TypeScript)
        │ REST + WebSocket
        ▼
Frontend (Nginx) ──► Backend (Spring Boot / Java) ──► IAM
                         REST, WebSockets              JWKS / JWT
```

- **IAM:** `mock-oauth2-server` stellt OIDC Discovery, JWTs und JWKS bereit.
- **Backend:** Spring Boot validiert Bearer-Tokens, verarbeitet Spielzüge und
  veröffentlicht Spielstatus über WebSockets.
- **Frontend:** Angular mit TypeScript stellt das Spielfeld dar und kommuniziert
  über REST und WebSockets mit dem Backend.
- **Speicher:** Der Spielstatus liegt für die Demo im Speicher.

## Starten

Voraussetzung ist Docker mit Docker Compose.

```bash
cd OAuth2
docker compose up --build
```

Die Anwendung ist anschließend unter [http://localhost:3000](http://localhost:3000)
erreichbar. Für zwei Spieler können zwei Browserfenster geöffnet werden.

Der IAM ist unter [http://localhost:8080](http://localhost:8080) erreichbar.
OIDC Discovery befindet sich unter
[http://localhost:8080/default/.well-known/openid-configuration](http://localhost:8080/default/.well-known/openid-configuration).

## Services

| Service | Technologie | Zweck |
|---|---|---|
| `iam` | mock-oauth2-server | OAuth2/OIDC, JWT und JWKS |
| `backend` | Java 17, Spring Boot | REST-API, JWT-Prüfung und WebSockets |
| `frontend` | Angular, TypeScript, Nginx | Browser-Oberfläche und Proxy |

## API

| Methode | Endpoint | Zweck |
|---|---|---|
| `GET` | `/api/health` | Health Check |
| `GET` | `/api/me` | Aktuellen Benutzer ermitteln |
| `GET` | `/api/game` | Spielstatus lesen |
| `POST` | `/api/game/join?player_name=Ada` | Spieler registrieren |
| `POST` | `/api/game/move` | `{ "position": 0 }` senden |
| `POST` | `/api/game/reset` | Spiel zurücksetzen |
| `WS` | `/ws/game` | `game.updated` Events empfangen |

## Projektstruktur

```text
OAuth2/
├── docker-compose.yml
├── backend/
│   ├── Dockerfile
│   ├── pom.xml
│   └── src/main/
│       ├── java/com/example/gameservice/
│       │   ├── GameServiceApplication.java
│       │   ├── GameController.java
│       │   ├── GameState.java
│       │   ├── IdentityService.java
│       │   ├── GameWebSocketHandler.java
│       │   └── WebSocketConfig.java
│       └── resources/application.properties
├── frontend/
│   ├── Dockerfile
│   ├── nginx.conf
│   ├── package.json
│   └── src/app/
│       ├── app.component.ts
│       ├── app.component.html
│       ├── app.component.css
│       ├── game.models.ts
│       └── game.service.ts
└── README.md
```

## Entwicklung

Das Frontend wird im Docker-Build mit Node 22 gebaut. Für lokale Builds wird
Node.js 18.19 oder neuer benötigt:

```bash
cd frontend
npm install
npm run build
```

Das Java-Backend kann mit Maven gebaut werden:

```bash
cd backend
mvn package
```

## Weiterführende Schritte

- Spielstatus in Redis oder PostgreSQL speichern
- OAuth2-Login direkt im Angular-Frontend integrieren
- Mehrere parallele Spiele über eine Game-ID unterstützen
- Tests für Spielregeln, REST und WebSockets ergänzen
