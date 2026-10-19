package com.example.gameservice;

import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

public class GameState {
    public enum Status { WAITING, PLAYING, FINISHED }

    public record Event(String id, String type, String player, String symbol,
                        Integer position, long version, long at) {}

    private final String[] board = new String[9];
    private final Map<String, String> players = new LinkedHashMap<>();
    private final Map<String, String> playerNames = new LinkedHashMap<>();
    private final List<Event> events = new ArrayList<>();
    private String turn = "X";
    private Status status = Status.WAITING;
    private String winner;
    private long version;

    public synchronized Map<String, Object> snapshot() {
        Map<String, String> names = new LinkedHashMap<>();
        players.forEach((symbol, player) -> names.put(symbol, playerNames.getOrDefault(player, player)));
        return Map.of(
                "board", board.clone(),
                "players", names,
                "turn", turn,
                "status", status.name().toLowerCase(),
                "winner", winner == null ? "" : winner,
                "version", version,
                "events", events.subList(Math.max(0, events.size() - 12), events.size())
        );
    }

    public synchronized String join(String player, String name) {
        String existing = players.entrySet().stream()
                .filter(entry -> entry.getValue().equals(player))
                .map(Map.Entry::getKey)
                .findFirst().orElse(null);
        if (existing != null) return existing;
        if (players.size() >= 2) return null;
        String symbol = players.isEmpty() ? "X" : "O";
        players.put(symbol, player);
        playerNames.put(player, name);
        if (players.size() == 2) status = Status.PLAYING;
        version++;
        addEvent("player.joined", player, symbol, null);
        return symbol;
    }

    public synchronized void move(String player, int position) {
        String symbol = symbolFor(player);
        if (symbol == null) throw new GameException(403, "Join the game first");
        if (status != Status.PLAYING) throw new GameException(409, "The game is not ready");
        if (!symbol.equals(turn)) throw new GameException(409, "It is the other player's turn");
        if (board[position] != null) throw new GameException(409, "That field is already occupied");
        board[position] = symbol;
        version++;
        String outcome = result();
        if (outcome != null) {
            status = Status.FINISHED;
            winner = outcome;
        } else {
            turn = symbol.equals("X") ? "O" : "X";
        }
        addEvent("move.played", player, symbol, position);
    }

    public synchronized void reset(String player) {
        java.util.Arrays.fill(board, null);
        turn = "X";
        status = players.size() == 2 ? Status.PLAYING : Status.WAITING;
        winner = null;
        version++;
        addEvent("game.reset", player, null, null);
    }

    public synchronized String symbolFor(String player) {
        return players.entrySet().stream()
                .filter(entry -> entry.getValue().equals(player))
                .map(Map.Entry::getKey).findFirst().orElse(null);
    }

    private String result() {
        int[][] lines = {{0,1,2},{3,4,5},{6,7,8},{0,3,6},{1,4,7},{2,5,8},{0,4,8},{2,4,6}};
        for (int[] line : lines) {
            if (board[line[0]] != null && board[line[0]].equals(board[line[1]])
                    && board[line[0]].equals(board[line[2]])) return board[line[0]];
        }
        return java.util.Arrays.stream(board).allMatch(java.util.Objects::nonNull) ? "draw" : null;
    }

    private void addEvent(String type, String player, String symbol, Integer position) {
        events.add(new Event(UUID.randomUUID().toString(), type, player, symbol, position, version,
                Instant.now().getEpochSecond()));
    }

    public static class GameException extends RuntimeException {
        private final int status;
        public GameException(int status, String message) { super(message); this.status = status; }
        public int status() { return status; }
    }
}
