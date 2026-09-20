package com.smartfoodai.backend.common.security;

import com.smartfoodai.backend.auth.repository.UserRepository;
import com.smartfoodai.backend.auth.service.JwtService;
import io.jsonwebtoken.JwtException;
import jakarta.servlet.*;
import jakarta.servlet.http.*;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.filter.OncePerRequestFilter;
import java.io.IOException;
import java.util.List;
import java.util.Set;

public class JwtAuthenticationFilter extends OncePerRequestFilter {
    private static final Set<String> PUBLIC_POSTS = Set.of(
            "/api/auth/register", "/api/auth/login", "/api/auth/refresh", "/api/auth/logout");
    private final JwtService jwt;
    private final UserRepository users;

    public JwtAuthenticationFilter(JwtService jwt, UserRepository users) {
        this.jwt = jwt;
        this.users = users;
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        return "POST".equals(request.getMethod()) && PUBLIC_POSTS.contains(request.getServletPath());
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                    FilterChain chain) throws ServletException, IOException {
        String authorization = request.getHeader("Authorization");
        if (authorization != null && authorization.startsWith("Bearer ")) {
            Long userId = null;
            try {
                userId = jwt.readUserId(authorization.substring(7));
            } catch (JwtException | IllegalArgumentException exception) {
                SecurityContextHolder.clearContext();
            }
            if (userId != null) {
                boolean exists;
                try {
                    exists = users.existsById(userId);
                } catch (org.springframework.dao.DataAccessException exception) {
                    response.setStatus(503);
                    response.setContentType("application/json;charset=UTF-8");
                    response.getWriter().write("{\"message\":\"Servicio temporalmente no disponible\",\"errors\":{}}");
                    return;
                }
                if (exists) {
                    var context = SecurityContextHolder.createEmptyContext();
                    context.setAuthentication(new UsernamePasswordAuthenticationToken(userId, null, List.of()));
                    SecurityContextHolder.setContext(context);
                }
            }
        }
        chain.doFilter(request, response);
    }
}
