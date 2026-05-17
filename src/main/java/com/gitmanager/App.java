package com.gitmanager;

import com.gitmanager.ui.dashboard.DashboardScreen;
import com.gitmanager.ui.theme.ThemeManager;
import javafx.application.Application;
import javafx.stage.Stage;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * Aplicação principal do Git Manager.
 * Inicializa a UI premium e gerencia recursos globais.
 */
public class App extends Application {

    private static final Logger log = LoggerFactory.getLogger(App.class);
    private static ExecutorService executor;

    @Override
    public void start(Stage primaryStage) {
        log.info("Iniciando Git Manager...");
        
        // Thread pool para operações assíncronas
        executor = Executors.newCachedThreadPool(r -> {
            Thread t = new Thread(r, "GitManager-Worker");
            t.setDaemon(true);
            return t;
        });

        DashboardScreen dashboard = new DashboardScreen(primaryStage);
        dashboard.show();
        primaryStage.show();
        
        log.info("Git Manager iniciado com sucesso.");
    }

    @Override
    public void stop() {
        log.info("Encerrando aplicação...");
        if (executor != null && !executor.isShutdown()) {
            executor.shutdown();
        }
    }

    /**
     * Retorna o executor global para operações em background.
     */
    public static ExecutorService getExecutor() {
        return executor;
    }

    public static void main(String[] args) {
        launch(args);
    }
}
