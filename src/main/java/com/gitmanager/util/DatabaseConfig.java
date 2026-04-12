package com.gitmanager.util;

import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.io.InputStream;
import java.sql.Connection;
import java.sql.SQLException;
import java.util.Properties;

public class DatabaseConfig {

    private static final Logger log = LoggerFactory.getLogger(DatabaseConfig.class);
    private static HikariDataSource dataSource;

    static {
        initDataSource();
    }

    private DatabaseConfig() {}

    private static void initDataSource() {
        Properties props = loadProperties();
        HikariConfig config = new HikariConfig();
        config.setJdbcUrl(props.getProperty("db.url", "jdbc:postgresql://localhost:5432/gitmanager"));
        config.setUsername(props.getProperty("db.username", "postgres"));
        config.setPassword(props.getProperty("db.password", "postgres"));
        config.setMaximumPoolSize(Integer.parseInt(props.getProperty("db.pool.maximumPoolSize", "10")));
        config.setMinimumIdle(Integer.parseInt(props.getProperty("db.pool.minimumIdle", "2")));
        config.setConnectionTimeout(Long.parseLong(props.getProperty("db.pool.connectionTimeout", "30000")));
        config.setIdleTimeout(Long.parseLong(props.getProperty("db.pool.idleTimeout", "600000")));
        config.setMaxLifetime(Long.parseLong(props.getProperty("db.pool.maxLifetime", "1800000")));
        config.setPoolName("GitManagerPool");
        config.addDataSourceProperty("cachePrepStmts", "true");
        config.addDataSourceProperty("prepStmtCacheSize", "250");
        config.addDataSourceProperty("prepStmtCacheSqlLimit", "2048");

        dataSource = new HikariDataSource(config);
        log.info("Pool de conexões iniciado: {}", config.getJdbcUrl());
    }

    private static Properties loadProperties() {
        Properties props = new Properties();
        try (InputStream in = DatabaseConfig.class.getClassLoader()
                .getResourceAsStream("application.properties")) {
            if (in != null) {
                props.load(in);
            }
        } catch (IOException e) {
            log.warn("Não foi possível carregar application.properties, usando valores padrão.", e);
        }
        return props;
    }

    public static Connection getConnection() throws SQLException {
        return dataSource.getConnection();
    }

    public static void close() {
        if (dataSource != null && !dataSource.isClosed()) {
            dataSource.close();
            log.info("Pool de conexões encerrado.");
        }
    }
}
