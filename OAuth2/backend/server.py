"""Remote Tic-Tac-Toe resource server."""

import asyncio
import os
import time
import uuid
from pathlib import Path
from typing import Any

import jwt
from fastapi import Depends, FastAPI, Header, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

ISSUER = os.environ.get("ISSUER", "http://localhost:8080/default")
JWKS_URL = f"{ISSUER}/jwks"
STATIC_DIR = Path(__file__).parent / "static"

app = FastAPI(title="Remote Tic-Tac-Toe", version="1.0.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")


class Move(BaseModel):
    position: int = Field(ge=0, le=8)


class Game:
    def __init__(self) -> None:
        self.board: list[str | None] = [None] * 9
        self.players: dict[str, str] = {}
        self.player_names: dict[str, str] = {}
        self.turn = "X"
        self.status = "waiting"
        self.winner: str | None = None
        self.version = 0
        self.events: list[dict[str, Any]] = []
        self.connections: set[WebSocket] = set()
        self.lock = asyncio.Lock()

    def snapshot(self) -> dict[str, Any]:
        return {"board": self.board, "players": {symbol: self.player_names.get(player, player)
                               for symbol, player in self.players.items()}, "turn": self.turn,
                "status": self.status, "winner": self.winner, "version": self.version,
                "events": self.events[-12:]}

    def result(self) -> str | None:
        for a, b, c in ((0, 1, 2), (3, 4, 5), (6, 7, 8), (0, 3, 6),
                        (1, 4, 7), (2, 5, 8), (0, 4, 8), (2, 4, 6)):
            if self.board[a] and self.board[a] == self.board[b] == self.board[c]:
                return self.board[a]
        return "draw" if all(self.board) else None

    async def broadcast(self) -> None:
        message = {"type": "game.updated", "data": self.snapshot()}
        stale: set[WebSocket] = set()
        for connection in self.connections:
            try:
                await connection.send_json(message)
            except Exception:
                stale.add(connection)
        self.connections.difference_update(stale)


game = Game()
jwk_client = jwt.PyJWKClient(JWKS_URL)


def identity(authorization: str | None = Header(default=None),
             x_player: str | None = Header(default=None)) -> str:
    if x_player and not authorization:
        return x_player.strip()[:48] or "demo-player"
    if not authorization:
        return "demo-player"
    if not authorization.startswith("Bearer "):
        raise HTTPException(401, "Expected a Bearer token")
    try:
        token = authorization[7:]
        key = jwk_client.get_signing_key_from_jwt(token)
        claims = jwt.decode(token, key.key, algorithms=["RS256"], issuer=ISSUER,
                            options={"verify_aud": False})
        return str(claims.get("sub") or claims.get("preferred_username") or "player")
    except jwt.InvalidTokenError as error:
        raise HTTPException(401, f"Token validation failed: {error}") from error
    except Exception as error:
        raise HTTPException(503, "Identity provider is unavailable") from error


@app.get("/")
async def index() -> FileResponse:
    return FileResponse(STATIC_DIR / "index.html")


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok", "service": "game-service"}


@app.get("/api/me")
async def me(player: str = Depends(identity)) -> dict[str, str]:
    return {"player": player}


@app.get("/api/game")
async def get_game() -> dict[str, Any]:
    return game.snapshot()


@app.post("/api/game/join")
async def join_game(player_name: str, player: str = Depends(identity)) -> dict[str, Any]:
    name = player_name.strip()[:24] or player
    async with game.lock:
        if player not in game.players.values() and len(game.players) < 2:
            symbol = "X" if not game.players else "O"
            game.players[symbol] = player
            game.player_names[player] = name
            if len(game.players) == 2:
                game.status = "playing"
            game.version += 1
            game.events.append({"id": str(uuid.uuid4()), "type": "player.joined",
                                "player": name, "symbol": symbol, "at": int(time.time())})
            await game.broadcast()
        symbol = next((symbol for symbol, owner in game.players.items() if owner == player), None)
        return {"player": player, "symbol": symbol, "game": game.snapshot()}


@app.post("/api/game/move")
async def make_move(move: Move, player: str = Depends(identity)) -> dict[str, Any]:
    async with game.lock:
        symbol = next((symbol for symbol, owner in game.players.items() if owner == player), None)
        if symbol is None:
            raise HTTPException(403, "Join the game first")
        if game.status != "playing":
            raise HTTPException(409, "The game is not ready")
        if symbol != game.turn:
            raise HTTPException(409, "It is the other player's turn")
        if game.board[move.position] is not None:
            raise HTTPException(409, "That field is already occupied")
        game.board[move.position] = symbol
        game.version += 1
        outcome = game.result()
        if outcome:
            game.status, game.winner = "finished", outcome
        else:
            game.turn = "O" if symbol == "X" else "X"
        game.events.append({"id": str(uuid.uuid4()), "type": "move.played", "player": player,
                            "symbol": symbol, "position": move.position,
                            "version": game.version, "at": int(time.time())})
        await game.broadcast()
        return game.snapshot()


@app.post("/api/game/reset")
async def reset_game(player: str = Depends(identity)) -> dict[str, Any]:
    async with game.lock:
        game.board = [None] * 9
        game.turn = "X"
        game.status = "playing" if len(game.players) == 2 else "waiting"
        game.winner = None
        game.version += 1
        game.events.append({"id": str(uuid.uuid4()), "type": "game.reset",
                            "player": player, "version": game.version, "at": int(time.time())})
        await game.broadcast()
        return game.snapshot()


@app.websocket("/ws/game")
async def game_socket(websocket: WebSocket) -> None:
    await websocket.accept()
    game.connections.add(websocket)
    await websocket.send_json({"type": "game.updated", "data": game.snapshot()})
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        game.connections.discard(websocket)
