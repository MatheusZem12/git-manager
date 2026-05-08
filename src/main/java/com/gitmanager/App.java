package com.gitmanager;

import com.gitmanager.ui.dashboard.DashboardScreen;
import javafx.application.Application;
import javafx.stage.Stage;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class App extends Application {

    private static final Logger log = LoggerFactory.getLogger(App.class);

    @Override
    public void start(Stage primaryStage) {
        log.info("Iniciando Git Manager...");
        DashboardScreen dashboard = new DashboardScreen(primaryStage);
        dashboard.show();
        primaryStage.show();
    }

    @Override
    public void stop() {
        log.info("Encerrando aplicação...");
    }

    public static void main(String[] args) {
        launch(args);
    }
}
