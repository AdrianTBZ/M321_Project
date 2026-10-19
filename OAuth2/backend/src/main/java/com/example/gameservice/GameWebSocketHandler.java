package com.example.gameservice;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.*;
import org.springframework.web.socket.handler.TextWebSocketHandler;

@Component
public class GameWebSocketHandler extends TextWebSocketHandler {
    private final Set<WebSocketSession> sessions = ConcurrentHashMap.newKeySet();
    private final ObjectMapper mapper = new ObjectMapper();
    private volatile Map<String, Object> current = Map.of();

    @Override
    public void afterConnectionEstablished(WebSocketSession session) throws Exception {
        sessions.add(session);
        if (!current.isEmpty()) session.sendMessage(new TextMessage(mapper.writeValueAsString(Map.of("type", "game.updated", "data", current))));
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) { sessions.remove(session); }

    public void broadcast(Map<String, Object> snapshot) {
        current = snapshot;
        String message;
        try { message = mapper.writeValueAsString(Map.of("type", "game.updated", "data", snapshot)); }
        catch (Exception exception) { return; }
        sessions.removeIf(session -> !session.isOpen() || !send(session, message));
    }

    private boolean send(WebSocketSession session, String message) {
        try { session.sendMessage(new TextMessage(message)); return true; }
        catch (Exception exception) { return false; }
    }
}
