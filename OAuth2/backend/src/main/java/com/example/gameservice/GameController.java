package com.example.gameservice;

import java.util.Map;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api")
public class GameController {
    public record MoveRequest(int position) {}
    private final GameState game = new GameState();
    private final IdentityService identity;
    private final GameWebSocketHandler socket;

    public GameController(IdentityService identity, GameWebSocketHandler socket) {
        this.identity = identity;
        this.socket = socket;
    }

    @GetMapping("/game")
    public Map<String, Object> game() { return game.snapshot(); }

    @GetMapping("/me")
    public Map<String, String> me(@RequestHeader(value = "Authorization", required = false) String auth,
                                  @RequestHeader(value = "X-Player", required = false) String player) {
        return Map.of("player", identity.resolve(auth, player));
    }

    @PostMapping("/game/join")
    public Map<String, Object> join(@RequestParam String player_name,
                                     @RequestHeader(value = "Authorization", required = false) String auth,
                                     @RequestHeader(value = "X-Player", required = false) String player) {
        String current = identity.resolve(auth, player);
        String name = player_name.trim().substring(0, Math.min(24, player_name.trim().length()));
        String symbol = game.join(current, name);
        socket.broadcast(game.snapshot());
        return Map.of("player", current, "symbol", symbol == null ? "" : symbol, "game", game.snapshot());
    }

    @PostMapping("/game/move")
    public Map<String, Object> move(@RequestBody MoveRequest request,
                                    @RequestHeader(value = "Authorization", required = false) String auth,
                                    @RequestHeader(value = "X-Player", required = false) String player) {
        if (request.position() < 0 || request.position() > 8) {
            throw new ResponseStatusException(org.springframework.http.HttpStatus.BAD_REQUEST, "Position must be between 0 and 8");
        }
        game.move(identity.resolve(auth, player), request.position());
        socket.broadcast(game.snapshot());
        return game.snapshot();
    }

    @PostMapping("/game/reset")
    public Map<String, Object> reset(@RequestHeader(value = "Authorization", required = false) String auth,
                                     @RequestHeader(value = "X-Player", required = false) String player) {
        game.reset(identity.resolve(auth, player));
        socket.broadcast(game.snapshot());
        return game.snapshot();
    }

    @GetMapping("/health")
    public Map<String, String> health() { return Map.of("status", "ok", "service", "game-service"); }

    @ExceptionHandler(GameState.GameException.class)
    public ResponseEntity<Map<String, String>> gameError(GameState.GameException error) {
        return ResponseEntity.status(error.status()).body(Map.of("detail", error.getMessage()));
    }
}
