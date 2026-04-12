package com.gitmanager.util;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.sql.Connection;
import java.sql.SQLException;
import java.sql.Statement;

public class SchemaInitializer {

    private static final Logger log = LoggerFactory.getLogger(SchemaInitializer.class);

    private SchemaInitializer() {}

    public static void initialize() {
        try (InputStream is = SchemaInitializer.class.getClassLoader().getResourceAsStream("schema.sql")) {
            if (is == null) {
                log.error("schema.sql não encontrado no classpath.");
                return;
            }
            String sql = new String(is.readAllBytes(), StandardCharsets.UTF_8);
            try (Connection conn = DatabaseConfig.getConnection();
                 Statement stmt = conn.createStatement()) {
                stmt.execute(sql);
                log.info("Schema do banco de dados inicializado com sucesso.");
            }
        } catch (Exception e) {
            log.error("Falha ao inicializar schema do banco.", e);
            throw new RuntimeException("Não foi possível inicializar o banco de dados.", e);
        }
    }
}
