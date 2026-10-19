#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════
#  OAuth2 Authorization Code Flow with PKCE — Step by Step
# ══════════════════════════════════════════════════════════════════
#  This script walks you through a complete OAuth2 flow using ONLY
#  curl, openssl, and jq. No browser needed — everything is HTTP.
#
#  Run with:  docker compose run --rm client
# ══════════════════════════════════════════════════════════════════

set -euo pipefail

# ── Configuration ──────────────────────────────────────────────
IAM_BASE="http://iam:8080/default"
BACKEND_BASE="http://backend:3000"
CLIENT_ID="demo-client"
REDIRECT_URI="http://client/callback"

# ── Helper: decode a JWT part (base64url → JSON) ──────────────
decode_jwt() {
    python3 -c "
import base64, json, sys
s = sys.argv[1]
s += '=' * (4 - len(s) % 4)
raw = base64.urlsafe_b64decode(s)
print(json.dumps(json.loads(raw), indent=2))
" "$1"
}

# ── Startup ────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  OAuth2 Authorization Code Flow with PKCE                    ║"
echo "║  Step-by-step with curl — no browser needed                  ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

for cmd in curl jq openssl python3; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "ERROR: '$cmd' is required but not installed."
        exit 1
    fi
done

echo "Waiting for IAM to be ready..."
for i in $(seq 1 30); do
    if curl -sf "$IAM_BASE/.well-known/openid-configuration" > /dev/null 2>&1; then
        break
    fi
    [ "$i" -eq 30 ] && echo "ERROR: IAM not reachable at $IAM_BASE" && exit 1
    sleep 1
done
echo "✓ IAM is ready"

echo "Waiting for backend to be ready..."
for i in $(seq 1 30); do
    if curl -s "$BACKEND_BASE/api/me" > /dev/null 2>&1; then
        break
    fi
    [ "$i" -eq 30 ] && echo "ERROR: Backend not reachable at $BACKEND_BASE" && exit 1
    sleep 1
done
echo "✓ Backend is ready"
echo ""


# ══════════════════════════════════════════════════════════════════
#  STEP 1: Try to Access the Protected API
# ══════════════════════════════════════════════════════════════════
echo "━━━ STEP 1: Try to Access the Protected API ━━━━━━━━━━━━━━━"
echo ""
echo "We want to access user data from the backend's API."
echo "Let's just try calling it and see what happens..."
echo ""
read -r -p "Press Enter to call GET /api/me... "
echo ""

echo "$ curl -s -i $BACKEND_BASE/api/me"
echo ""
REJECTED_RESPONSE=$(curl -s -D - "$BACKEND_BASE/api/me")
echo "$REJECTED_RESPONSE"
echo ""

# Extract the WWW-Authenticate header
WWW_AUTH=$(echo "$REJECTED_RESPONSE" | grep -i "^www-authenticate:" | sed 's/^[Ww][Ww][Ww]-[Aa]uthenticate: //' | tr -d '\r\n')

echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│ ✗ HTTP 401 Unauthorized!                                    │"
echo "│                                                             │"
echo "│ The backend rejected our request because we didn't send     │"
echo "│ an access token. But it gave us a helpful hint:             │"
echo "│                                                             │"
echo "│ WWW-Authenticate: $WWW_AUTH"
echo "│                                                             │"
echo "│ This header (RFC 6750) tells us:                            │"
echo "│   • Auth scheme: Bearer (we need a Bearer token)            │"
echo "│   • Realm: the IAM's URL where we can get one               │"
echo "└─────────────────────────────────────────────────────────────┘"
echo ""
echo "So we need to authenticate with the IAM first, get a token,"
echo "and then retry this request. Let's go!"
echo ""
read -r -p "Press Enter to continue... "
echo ""


# ══════════════════════════════════════════════════════════════════
#  STEP 2: OIDC Discovery
# ══════════════════════════════════════════════════════════════════
echo "━━━ STEP 2: OIDC Discovery ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "The WWW-Authenticate header pointed us to the IAM."
echo "Every OpenID Connect provider publishes a JSON document at a"
echo "well-known URL. This tells clients where to find the"
echo "authorization, token, and JWKS endpoints."
echo ""
read -r -p "Press Enter to fetch the discovery document... "
echo ""
echo "$ curl -s $IAM_BASE/.well-known/openid-configuration | jq ."
echo ""
DISCOVERY=$(curl -s "$IAM_BASE/.well-known/openid-configuration")
echo "$DISCOVERY" | jq .
echo ""

# Extract endpoints from discovery (this is what a real client would do)
AUTHORIZATION_ENDPOINT=$(echo "$DISCOVERY" | jq -r '.authorization_endpoint')
TOKEN_ENDPOINT=$(echo "$DISCOVERY" | jq -r '.token_endpoint')
JWKS_URI=$(echo "$DISCOVERY" | jq -r '.jwks_uri')

echo "Key endpoints discovered:"
echo "  authorization_endpoint: $AUTHORIZATION_ENDPOINT"
echo "  token_endpoint:         $TOKEN_ENDPOINT"
echo "  jwks_uri:               $JWKS_URI"
echo ""
read -r -p "Press Enter to continue... "
echo ""


# ══════════════════════════════════════════════════════════════════
#  STEP 3: Generate PKCE Parameters
# ══════════════════════════════════════════════════════════════════
echo "━━━ STEP 3: Generate PKCE Parameters ━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "PKCE (Proof Key for Code Exchange) prevents authorization code"
echo "interception attacks."
echo ""
echo "How it works:"
echo "  1. Client generates a random secret: the 'code_verifier'"
echo "  2. Client computes SHA-256 hash of verifier: the 'code_challenge'"
echo "  3. Client sends the CHALLENGE with the authorize request"
echo "  4. Client sends the VERIFIER with the token request"
echo "  5. Server checks: SHA-256(verifier) == challenge"
echo ""
echo "An attacker who intercepts the authorization code can't use it"
echo "because they don't have the original code_verifier."
echo ""
read -r -p "Press Enter to generate PKCE parameters... "
echo ""

# Generate a random code_verifier (43-128 URL-safe characters)
CODE_VERIFIER=$(openssl rand -base64 96 | tr -d '=/+\n' | cut -c1-64)
# Compute code_challenge = BASE64URL(SHA256(code_verifier))
CODE_CHALLENGE=$(printf '%s' "$CODE_VERIFIER" | openssl dgst -sha256 -binary | openssl base64 -e | tr '+/' '-_' | tr -d '=')

echo "$ openssl rand -base64 96 | tr -d '=/+' | cut -c1-64"
echo "  code_verifier:  $CODE_VERIFIER (length: ${#CODE_VERIFIER})"
echo ""
echo "$ echo -n \"\$CODE_VERIFIER\" | openssl dgst -sha256 -binary | base64url"
echo "  code_challenge: $CODE_CHALLENGE"
echo ""
read -r -p "Press Enter to continue... "
echo ""


# ══════════════════════════════════════════════════════════════════
#  STEP 4: Build the Authorization URL
# ══════════════════════════════════════════════════════════════════
echo "━━━ STEP 4: Build the Authorization URL ━━━━━━━━━━━━━━━━━━━"
echo ""
echo "This URL sends the user to the IAM's login page. Parameters:"
echo ""
echo "  response_type=code     → We want an authorization code"
echo "  client_id              → Identifies this application"
echo "  redirect_uri           → Where to send the user after login"
echo "  scope=openid profile   → What access we're requesting"
echo "  code_challenge         → PKCE challenge (hash of verifier)"
echo "  code_challenge_method  → S256 means SHA-256 was used"
echo "  state                  → Random value to prevent CSRF attacks"
echo ""

STATE=$(openssl rand -hex 16)
REDIRECT_URI_ENC=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$REDIRECT_URI', safe=''))")
AUTHORIZE_URL="${AUTHORIZATION_ENDPOINT}?response_type=code&client_id=${CLIENT_ID}&redirect_uri=${REDIRECT_URI_ENC}&scope=openid%20profile&code_challenge=${CODE_CHALLENGE}&code_challenge_method=S256&state=${STATE}"

echo "Parameters:"
echo "  response_type       = code"
echo "  client_id           = $CLIENT_ID"
echo "  redirect_uri        = $REDIRECT_URI"
echo "  scope               = openid profile"
echo "  code_challenge      = $CODE_CHALLENGE"
echo "  code_challenge_method = S256"
echo "  state               = $STATE"
echo ""
echo "Constructed Authorization URL:"
echo "  $AUTHORIZE_URL"
echo ""
echo "In a real app, the client would redirect the user's browser to"
echo "this URL. The IAM shows a login page, the user logs in, and"
echo "the IAM redirects back with the authorization code."
echo ""
echo "Since we're doing everything with curl, we'll simulate this"
echo "in the next step."
echo ""
read -r -p "Press Enter to continue... "
echo ""


# ══════════════════════════════════════════════════════════════════
#  STEP 5: Login & Get the Authorization Code
# ══════════════════════════════════════════════════════════════════
echo "━━━ STEP 5: Login & Get the Authorization Code ━━━━━━━━━━━━"
echo ""
echo "In a real app with a browser, this is what happens:"
echo ""
echo "  1. Browser → GET /authorize?...  → IAM shows login form"
echo "  2. User fills in username/password"
echo "  3. Browser → POST /authorize?... → IAM authenticates user"
echo "  4. IAM → 302 redirect to redirect_uri?code=XXXX&state=YYYY"
echo "  5. Browser follows the redirect → client receives the code"
echo ""
echo "We'll do the same with curl. First, let's see the login page:"
echo ""
read -r -p "Press Enter to fetch the login page... "
echo ""

echo "$ curl -s '$AUTHORIZE_URL' | head"
echo ""

LOGIN_HTML=$(curl -s "$AUTHORIZE_URL")

echo "The IAM returned an HTML login page ($(echo "$LOGIN_HTML" | wc -c | tr -d ' ') bytes)."
echo "The HTML contains a <form method=\"post\"> that posts back to this URL."
echo ""
echo "Now we simulate the user submitting the login form."
echo "The browser POSTs to the authorize URL with the user's credentials."
echo ""
read -r -p "Enter a username (default: student): " USERNAME
USERNAME=${USERNAME:-student}
echo ""

echo "$ curl -s -D - -o /dev/null -X POST '$AUTHORIZE_URL' \\"
echo "    -d 'username=${USERNAME}'"
echo ""
read -r -p "Press Enter to submit the login... "
echo ""

# POST the login form to the authorize URL — capturing the 302 redirect headers
RESPONSE_HEADERS=$(curl -s -D - -o /dev/null \
    -X POST "$AUTHORIZE_URL" \
    -d "username=${USERNAME}")

echo "─── Response Headers ───"
echo "$RESPONSE_HEADERS" | head -10
echo ""

# Extract the Location header (contains the redirect with the code)
LOCATION=$(echo "$RESPONSE_HEADERS" | grep -i "^location:" | sed 's/^[Ll]ocation: //' | tr -d '\r\n')

if [ -z "$LOCATION" ]; then
    echo "ERROR: No redirect received from the IAM."
    echo "Full response headers:"
    echo "$RESPONSE_HEADERS"
    exit 1
fi

echo "The IAM responded with HTTP 302 (redirect) to:"
echo ""
echo "  $LOCATION"
echo ""
echo "In a browser, the browser would follow this redirect automatically."
echo "We extract the 'code' and 'state' parameters from the URL:"
echo ""

# Extract code and state from the redirect URL
AUTH_CODE=$(python3 -c "import urllib.parse, sys; print(urllib.parse.parse_qs(urllib.parse.urlparse(sys.argv[1]).query).get('code', [''])[0])" "$LOCATION")
RETURNED_STATE=$(python3 -c "import urllib.parse, sys; print(urllib.parse.parse_qs(urllib.parse.urlparse(sys.argv[1]).query).get('state', [''])[0])" "$LOCATION")

if [ -z "$AUTH_CODE" ]; then
    echo "ERROR: No authorization code in the redirect URL."
    exit 1
fi

echo "  code:  ${AUTH_CODE:0:30}..."
echo "  state: $RETURNED_STATE"
echo ""

if [ "$STATE" = "$RETURNED_STATE" ]; then
    echo "✓ State matches — no CSRF attack detected"
else
    echo "✗ WARNING: State mismatch! In production this would abort the flow."
fi
echo ""
read -r -p "Press Enter to continue... "
echo ""


# ══════════════════════════════════════════════════════════════════
#  STEP 6: Exchange the Code for Tokens
# ══════════════════════════════════════════════════════════════════
echo "━━━ STEP 6: Exchange Code for Tokens ━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Now we POST to the token endpoint with:"
echo "  grant_type=authorization_code  → This is a code exchange"
echo "  code=<the authorization code>  → From the redirect"
echo "  client_id                      → Same client as before"
echo "  redirect_uri                   → Must match the original"
echo "  code_verifier                  → PKCE proof (original secret)"
echo ""
echo "The server checks:"
echo "  SHA-256(code_verifier) == code_challenge from Step 3? ✓"
echo "  Authorization code valid and not expired? ✓"
echo "  redirect_uri matches? ✓"
echo ""
read -r -p "Press Enter to exchange the code for tokens... "
echo ""

echo "$ curl -s -X POST $TOKEN_ENDPOINT \\"
echo "    -d 'grant_type=authorization_code' \\"
echo "    -d 'client_id=$CLIENT_ID' \\"
echo "    -d 'code=<authorization_code>' \\"
echo "    -d 'redirect_uri=$REDIRECT_URI' \\"
echo "    -d 'code_verifier=<code_verifier>'"
echo ""

TOKEN_RESPONSE=$(curl -s -X POST "$TOKEN_ENDPOINT" \
    -d "grant_type=authorization_code" \
    -d "client_id=${CLIENT_ID}" \
    -d "code=${AUTH_CODE}" \
    -d "redirect_uri=${REDIRECT_URI}" \
    -d "code_verifier=${CODE_VERIFIER}")

echo "$TOKEN_RESPONSE" | jq .
echo ""

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token // empty')
REFRESH_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.refresh_token // empty')
ID_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.id_token // empty')

if [ -z "$ACCESS_TOKEN" ]; then
    echo "ERROR: No access_token in response."
    echo "$TOKEN_RESPONSE" | jq .
    exit 1
fi

echo "✓ Tokens received!"
echo "  access_token:  ${ACCESS_TOKEN:0:30}..."
[ -n "$ID_TOKEN" ]      && echo "  id_token:      ${ID_TOKEN:0:30}..."
[ -n "$REFRESH_TOKEN" ] && echo "  refresh_token: ${REFRESH_TOKEN:0:30}..."
echo ""
read -r -p "Press Enter to continue... "
echo ""


# ══════════════════════════════════════════════════════════════════
#  STEP 7: Inspect the Tokens
# ══════════════════════════════════════════════════════════════════
echo "━━━ STEP 7: Inspect the Tokens ━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "You got back three tokens. An important distinction:"
echo ""
echo "  ┌─────────────────────────────────────────────────────────┐"
echo "  │ ID Token       → FOR THE CLIENT (you!)                  │"
echo "  │                  Always a JWT. Contains identity claims │"
echo "  │                  (who the user is). You SHOULD parse it.│"
echo "  │                                                         │"
echo "  │ Access Token   → FOR THE BACKEND (resource server)      │"
echo "  │                  Opaque to the client! The OAuth2 spec  │"
echo "  │                  says NOTHING about its format. It could│"
echo "  │                  be a random string, a DB reference, or │"
echo "  │                  a JWT. You just pass it along.         │"
echo "  │                                                         │"
echo "  │ Refresh Token  → FOR THE CLIENT                         │"
echo "  │                  Also opaque. Used to get new tokens    │"
echo "  │                  without re-login.                      │"
echo "  └─────────────────────────────────────────────────────────┘"
echo ""
echo "A JWT has three BASE64URL-encoded parts separated by dots:"
echo ""
echo "  HEADER.PAYLOAD.SIGNATURE"
echo "  ^^^^^^ ^^^^^^^ ^^^^^^^^^"
echo "  alg,   claims  cryptographic"
echo "  kid    (data)  signature"
echo ""

# ── ID Token (the one the client is supposed to read) ──────────
echo "Let's start with the ID Token — this is the one YOU read:"
echo ""
read -r -p "Press Enter to decode the ID token... "
echo ""

if [ -n "$ID_TOKEN" ]; then
    echo "─── ID Token HEADER ───"
    ID_HEADER=$(echo "$ID_TOKEN" | cut -d. -f1)
    decode_jwt "$ID_HEADER"
    echo ""
    echo "─── ID Token PAYLOAD (identity claims) ───"
    echo "This tells your client WHO the user is:"
    ID_PAYLOAD=$(echo "$ID_TOKEN" | cut -d. -f2)
    decode_jwt "$ID_PAYLOAD"
    echo ""
    echo "Key claims:  sub = subject (user ID)"
    echo "             iss = who issued this token"
    echo "             iat = when it was issued"
    echo "             exp = when it expires"
    echo ""
else
    echo "(No ID token received — the server may not have returned one)"
    echo ""
fi

# ── Access Token (peeking behind the curtain) ─────────────────
echo ""
echo "Now let's peek inside the Access Token..."
echo ""
echo "⚠  IMPORTANT: Per the OAuth2 spec, the access token is OPAQUE"
echo "   to the client. Your client code should NEVER parse or depend"
echo "   on its format. You just pass it to the backend as-is."
echo ""
echo "   Many implementations (like this one) happen to use JWTs for"
echo "   access tokens too — but that's an implementation detail."
echo "   The BACKEND reads and validates it, not the client."
echo ""
read -r -p "Press Enter to peek inside (for educational purposes only!)... "
echo ""

HEADER=$(echo "$ACCESS_TOKEN" | cut -d. -f1)
PAYLOAD=$(echo "$ACCESS_TOKEN" | cut -d. -f2)

echo "─── Access Token HEADER ───"
decode_jwt "$HEADER"
echo ""
echo "─── Access Token PAYLOAD ───"
echo "(The backend uses these claims for authorization decisions)"
decode_jwt "$PAYLOAD"
echo ""
read -r -p "Press Enter to continue... "
echo ""


# ══════════════════════════════════════════════════════════════════
#  STEP 8: Retry the API Call — This Time With a Token!
# ══════════════════════════════════════════════════════════════════
echo "━━━ STEP 8: Retry the API Call — With a Token! ━━━━━━━━━━━━"
echo ""
echo "Remember Step 1? We tried to call GET /api/me and got 401."
echo "Now we have an access token. Let's retry the same request,"
echo "this time with the token in the Authorization header."
echo ""
echo "The backend will:"
echo "  1. Extract the token from the Authorization header"
echo "  2. Fetch the IAM's public keys (JWKS)"
echo "  3. Verify the JWT signature (is this token authentic?)"
echo "  4. Check expiration (is the token still valid?)"
echo "  5. Return the claims if everything checks out"
echo ""
read -r -p "Press Enter to call GET /api/me... "
echo ""

echo "$ curl -s -H 'Authorization: Bearer <token>' $BACKEND_BASE/api/me | jq ."
echo ""
curl -s -H "Authorization: Bearer ${ACCESS_TOKEN}" "${BACKEND_BASE}/api/me" | jq .
echo ""
read -r -p "Press Enter to continue... "
echo ""


# ══════════════════════════════════════════════════════════════════
#  STEP 9: Try with Invalid Tokens
# ══════════════════════════════════════════════════════════════════
echo "━━━ STEP 9: Try with Invalid Tokens ━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "What happens if we send a tampered or missing token?"
echo ""
read -r -p "Press Enter to try a tampered token... "
echo ""

echo "─── Tampered token (modified payload) ───"
echo "$ curl -s -H 'Authorization: Bearer <token>TAMPERED' $BACKEND_BASE/api/me"
echo ""
curl -s -H "Authorization: Bearer ${ACCESS_TOKEN}TAMPERED" "${BACKEND_BASE}/api/me" | jq .
echo ""

echo "─── No token at all ───"
echo "$ curl -s $BACKEND_BASE/api/me"
echo ""
curl -s "${BACKEND_BASE}/api/me" | jq .
echo ""

echo "─── Completely fake token ───"
echo "$ curl -s -H 'Authorization: Bearer this.is.fake' $BACKEND_BASE/api/me"
echo ""
curl -s -H "Authorization: Bearer this.is.fake" "${BACKEND_BASE}/api/me" | jq .
echo ""
read -r -p "Press Enter to continue... "
echo ""


# ══════════════════════════════════════════════════════════════════
#  STEP 10: Refresh the Token
# ══════════════════════════════════════════════════════════════════
if [ -n "$REFRESH_TOKEN" ]; then
    echo "━━━ STEP 10: Refresh the Token ━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Access tokens are short-lived (minutes). When they expire,"
    echo "the client uses the refresh_token to get a NEW access_token"
    echo "without making the user log in again."
    echo ""
    echo "The refresh_token is longer-lived and is exchanged for a"
    echo "fresh access_token + a new refresh_token (rotation)."
    echo ""
    read -r -p "Press Enter to refresh the token... "
    echo ""

    echo "$ curl -s -X POST $TOKEN_ENDPOINT \\"
    echo "    -d 'grant_type=refresh_token' \\"
    echo "    -d 'client_id=$CLIENT_ID' \\"
    echo "    -d 'refresh_token=<refresh_token>'"
    echo ""

    REFRESH_RESPONSE=$(curl -s -X POST "$TOKEN_ENDPOINT" \
        -d "grant_type=refresh_token" \
        -d "client_id=${CLIENT_ID}" \
        -d "refresh_token=${REFRESH_TOKEN}")

    echo "$REFRESH_RESPONSE" | jq .
    echo ""

    NEW_ACCESS_TOKEN=$(echo "$REFRESH_RESPONSE" | jq -r '.access_token // empty')
    if [ -n "$NEW_ACCESS_TOKEN" ]; then
        echo "✓ New access token received!"
        echo ""
        echo "─── Calling API with the NEW access token ───"
        curl -s -H "Authorization: Bearer ${NEW_ACCESS_TOKEN}" "${BACKEND_BASE}/api/me" | jq .
        echo ""
    fi
fi


# ══════════════════════════════════════════════════════════════════
#  Done!
# ══════════════════════════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ✓ Flow Complete!                                            ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "You just completed the full OAuth2 Authorization Code + PKCE flow."
echo ""
echo "What happened:"
echo "  Step 1  → Access Denied       (tried the API without a token → 401)"
echo "  Step 2  → OIDC Discovery      (found the IAM's endpoints)"
echo "  Step 3  → PKCE                 (generated verifier + challenge)"
echo "  Step 4  → Authorize URL        (built the login redirect)"
echo "  Step 5  → Login via curl       (submitted credentials, got code)"
echo "  Step 6  → Token Exchange       (code + verifier → tokens)"
echo "  Step 7  → Token Inspection     (ID token vs access token)"
echo "  Step 8  → Retry API Call       (same request, now with token → 200!)"
echo "  Step 9  → Invalid Tokens       (saw the backend reject fakes)"
echo "  Step 10 → Token Refresh        (got a fresh token)"
echo ""
echo "In production, you'd use a real IAM like:"
echo "  • Keycloak (open source)"
echo "  • Auth0 / Okta (SaaS)"
echo "  • Microsoft Entra ID (Azure AD)"
echo "  • AWS Cognito"
echo ""
