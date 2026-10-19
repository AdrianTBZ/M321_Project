package com.example.gameservice;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtException;
import org.springframework.security.oauth2.jwt.JwtValidators;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

@Service
public class IdentityService {
    private final JwtDecoder jwtDecoder;

    public IdentityService(@Value("${issuer}") String issuer) {
        NimbusJwtDecoder decoder = NimbusJwtDecoder.withJwkSetUri(issuer + "/jwks").build();
        decoder.setJwtValidator(JwtValidators.createDefaultWithIssuer(issuer));
        this.jwtDecoder = decoder;
    }

    public String resolve(String authorization, String playerHeader) {
        if ((authorization == null || authorization.isBlank()) && playerHeader != null) {
            return playerHeader.trim().substring(0, Math.min(48, playerHeader.trim().length()));
        }
        if (authorization == null || authorization.isBlank()) return "demo-player";
        if (!authorization.startsWith("Bearer ")) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Expected a Bearer token");
        }
        try {
            Jwt jwt = jwtDecoder.decode(authorization.substring(7));
            String subject = jwt.getClaimAsString("sub");
            String username = jwt.getClaimAsString("preferred_username");
            return subject != null ? subject : (username != null ? username : "player");
        } catch (JwtException exception) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Token validation failed", exception);
        }
    }
}
