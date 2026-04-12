package com.gitmanager.service;

import at.favre.lib.crypto.bcrypt.BCrypt;
import com.gitmanager.dao.UserDao;
import com.gitmanager.model.User;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.Optional;

public class AuthService {

    private static final Logger log = LoggerFactory.getLogger(AuthService.class);
    private static final int BCRYPT_COST = 12;

    private final UserDao userDao;

    public AuthService() {
        this.userDao = new UserDao();
    }

    /**
     * Autentica um usuário pelo username/email e senha.
     * @return Optional com o usuário autenticado ou empty se credenciais inválidas.
     */
    public Optional<User> login(String usernameOrEmail, String rawPassword) {
        if (usernameOrEmail == null || usernameOrEmail.isBlank() || rawPassword == null) {
            return Optional.empty();
        }
        Optional<User> userOpt = usernameOrEmail.contains("@")
                ? userDao.findByEmail(usernameOrEmail.trim())
                : userDao.findByUsername(usernameOrEmail.trim());

        if (userOpt.isEmpty()) {
            log.debug("Login falhou: usuário não encontrado '{}'", usernameOrEmail);
            return Optional.empty();
        }
        User user = userOpt.get();
        BCrypt.Result result = BCrypt.verifyer().verify(rawPassword.toCharArray(), user.getPassword());
        if (!result.verified) {
            log.debug("Login falhou: senha incorreta para '{}'", usernameOrEmail);
            return Optional.empty();
        }
        log.info("Login bem-sucedido: {}", user.getUsername());
        return Optional.of(user);
    }

    /**
     * Registra um novo usuário.
     * @return Optional com o usuário criado ou empty se houve conflito/erro.
     */
    public Optional<User> register(String username, String email, String rawPassword) {
        if (username == null || username.isBlank()) throw new IllegalArgumentException("Username obrigatório.");
        if (email == null || email.isBlank()) throw new IllegalArgumentException("Email obrigatório.");
        if (rawPassword == null || rawPassword.length() < 6) throw new IllegalArgumentException("Senha deve ter pelo menos 6 caracteres.");

        if (userDao.existsByUsername(username.trim())) {
            throw new IllegalArgumentException("Username '" + username + "' já está em uso.");
        }
        if (userDao.existsByEmail(email.trim())) {
            throw new IllegalArgumentException("Email '" + email + "' já está cadastrado.");
        }

        String hash = BCrypt.withDefaults().hashToString(BCRYPT_COST, rawPassword.toCharArray());
        User user = new User(username.trim(), email.trim().toLowerCase(), hash);
        return userDao.save(user);
    }
}
