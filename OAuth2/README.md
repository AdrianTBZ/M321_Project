# Remote Tic-Tac-Toe / OAuth2 — Hands-On Lab

Dieses Projekt erweitert das OAuth2-Labor um ein kleines verteiltes System.
Die Spieloberfläche ist unter [http://localhost:3000](http://localhost:3000)
erreichbar.

## Verteilte Architektur

```text
Browser  -- REST commands -->  Game Service  -- JWKS -->  IAM / OAuth2
   \---- WebSocket events ---/       |
                                  in-memory state
```

- **IAM:** `mock-oauth2-server` stellt OIDC Discovery, JWTs und JWKS bereit.
- **Game Service:** FastAPI validiert Bearer-Tokens, verarbeitet Spielzüge und
  veröffentlicht Zustandsänderungen über WebSockets.
- **Client:** Browser-UI mit REST für Commands und WebSocket für Live-Events.

Die Demo erlaubt Requests ohne Token für den lokalen Einstieg. Sobald ein
`Authorization: Bearer <token>` Header vorhanden ist, validiert der Service den
JWT gegen den öffentlichen Schlüssel des IAM. Damit lässt sich der OAuth2-Flow
aus dem bestehenden `client/flow.sh` weiterhin nachvollziehen.

## Remote-Spiel starten

```bash
cd OAuth2
docker compose up --build
```

Danach zwei Browserfenster öffnen. Für echte getrennte Spieler verwendet man
zwei unterschiedliche OAuth2-Identitäten; ohne Token ist der Browser eine
lokale Demo-Identität.

Wichtige Endpunkte:

| Methode | Endpoint | Zweck |
|---|---|---|
| `GET` | `/health` | Health Check |
| `GET` | `/api/game` | aktuellen versionierten Zustand lesen |
| `POST` | `/api/game/join?player_name=Ada` | Spieler registrieren |
| `POST` | `/api/game/move` | `{ "position": 0 }` senden |
| `POST` | `/api/game/reset` | Spiel zurücksetzen |
| `WS` | `/ws/game` | `game.updated` Events empfangen |

Die Datenhaltung ist absichtlich im Speicher. Als nächste Ausbaustufe kann sie
gegen Redis oder PostgreSQL ersetzt werden; die REST- und Event-Grenzen bleiben
dabei erhalten.

---

## Ursprüngliches OAuth2-Labor

A hands-on lab where you manually step through a complete **OAuth2 Authorization Code flow with PKCE** using Docker and `curl`. No SDKs, no frameworks, no browser needed — just HTTP requests.

**Works on macOS, Linux, and Windows** (anything that runs Docker).

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│  Docker Network                                                  │
│                                                                  │
│  ┌───────────────┐   ┌───────────────────┐   ┌───────────────┐   │
│  │  CLIENT       │   │   IAM             │   │  BACKEND      │   │
│  │  (curl)       │   │   (mock-oauth2)   │   │  (Python)     │   │
│  │               │   │                   │   │               │   │
│  │ 1. GET       ────►│ /authorize        │   │               │   │
│  │    login page │   │   → HTML form     │   │               │   │
│  │               │   │                   │   │               │   │
│  │ 2. POST      ────►│ /authorize        │   │               │   │
│  │    username   │   │   → 302 ?code=... │   │               │   │
│  │               │   │                   │   │               │   │
│  │ 3. POST      ────►│ /token            │   │               │   │
│  │    code+PKCE  │   │   → JWT tokens    │   │               │   │
│  │               │   │                   │   │               │   │
│  │ 4. GET       ────────────────────────────►│ /api/me       │   │
│  │    + Bearer   │   │                   │   │  → validate   │   │
│  │               │   │                   │ ◄─┤    JWT (JWKS) │   │
│  │ 5. Response  ◄────────────────────────────┤  → 200 / 401  │   │
│  └───────────────┘   └───────────────────┘   └───────────────┘   │
│                         ▲ port 8080                              │
│                         │ (also accessible from host browser)    │
└─────────────────────────┼────────────────────────────────────────┘
                          │
                    http://localhost:8080
                    (explore the IAM UI)
```

## Prerequisites

- **Docker** (with Docker Compose)

That's it! Everything else runs inside containers.

## Quick Start

### Step 1 — Start the IAM + Backend

```bash
docker compose up --build
```

Wait until you see:
- `Resource server listening on http://localhost:3000`
- The IAM logs showing it's ready

### Step 2 — Run the OAuth2 Flow (in a second terminal)

```bash
docker compose run --rm client
```

Follow the step-by-step prompts. The script walks you through:

| Step | What happens                                   | OAuth2 concept        |
|------|------------------------------------------------|-----------------------|
| 1    | Fetch `/.well-known/openid-configuration`      | OIDC Discovery        |
| 2    | Generate `code_verifier` + `code_challenge`    | PKCE                  |
| 3    | Build the authorization URL                    | Authorization Request |
| 4    | Login via `curl POST` → get `?code=`           | Authorization Code    |
| 5    | Exchange `code` + `verifier` for tokens        | Token Exchange        |
| 6    | Decode the ID token (and peek at access token) | JWT / Token Types     |
| 7    | Call `GET /api/me` with Bearer token           | Protected Resource    |
| 8    | Try tampered/missing tokens → 401              | Token Validation      |
| 9    | Use refresh token to get a new access token    | Token Refresh         |

### Optional — Explore the IAM

Open [http://localhost:8080](http://localhost:8080) in your browser to see the mock server.
OIDC discovery: [http://localhost:8080/default/.well-known/openid-configuration](http://localhost:8080/default/.well-known/openid-configuration)

## What is each component doing?

### IAM (Identity & Access Management)

The **mock-oauth2-server** acts as the Authorization Server / Identity Provider. In production, this would be **Keycloak**, **Auth0**, **Okta**, **Microsoft Entra ID**, or **AWS Cognito**. It:

- Authenticates the user (login page)
- Issues signed JWT tokens (access token, ID token, refresh token)
- Publishes its public keys at the JWKS endpoint so backends can verify tokens
- Publishes an OIDC discovery document so clients know where to find everything

### Backend (Resource Server)

A ~50-line Python script ([`backend/server.py`](backend/server.py)) that protects the `GET /api/me` endpoint:

1. Extracts the `Bearer` token from the `Authorization` header
2. Fetches the IAM's public keys (JWKS) to verify the JWT signature
3. Checks that the token hasn't expired and was issued by the expected IAM
4. Returns the token's claims if valid, or `401 Unauthorized` if not

### Client

A shell script ([`client/flow.sh`](client/flow.sh)) that acts as the OAuth2 client using only `curl` + `openssl` + `jq`. It demonstrates that **no SDK is needed** — OAuth2 is just HTTP requests.

## Key Concepts

### ID Token vs Access Token

|                       | **ID Token**           | **Access Token**            |
|-----------------------|------------------------|-----------------------------|
| **For**               | The client             | The backend                 |
| **Format**            | Always JWT (OIDC spec) | Opaque (could be anything)  |
| **Contains**          | Identity claims (who)  | Authorization claims (what) |
| **Client parses it?** | ✅ Yes                  | ❌ No — just pass it along   |

The script highlights this distinction in Step 6.

## File Structure

```
OAuth2/
├── docker-compose.yml          # All three services
├── backend/
│   ├── Dockerfile              # Python 3.12 slim
│   ├── server.py               # ~50-line resource server
│   └── requirements.txt        # PyJWT, cryptography
├── client/
│   ├── Dockerfile              # curl + jq + openssl + python3
│   └── flow.sh                 # Interactive 9-step walkthrough
└── README.md                   # This file
```

## Troubleshooting

| Problem              | Solution                                                                       |
|----------------------|--------------------------------------------------------------------------------|
| `IAM not reachable`  | Wait a few seconds — the IAM starts slower than the client                     |
| Port 8080 in use     | Another service is on 8080. Stop it or change the port in `docker-compose.yml` |
| Port 3000 in use     | Same — change the port mapping in `docker-compose.yml`                         |
| Windows line endings | If you edited `flow.sh` on Windows, run `dos2unix client/flow.sh`              |

## Going Further

- **Read the code**: [`backend/server.py`](backend/server.py) is ~50 lines — read every line
- **Try Client Credentials**: A simpler flow for machine-to-machine (no user login):
  ```bash
  curl -s -X POST http://localhost:8080/default/token \
      -u 'my-service:secret' \
      -d 'grant_type=client_credentials' \
      -d 'scope=openid' | jq .
  ```
- **Explore the IAM**: Visit [http://localhost:8080](http://localhost:8080) in your browser
- **Compare with production**: Set up a free Keycloak or Auth0 tenant and try the same flow
