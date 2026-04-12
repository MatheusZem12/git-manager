package com.gitmanager;

import com.gitmanager.ui.login.LoginScreen;
import com.gitmanager.util.DatabaseConfig;
import com.gitmanager.util.SchemaInitializer;
import javafx.application.Application;
import javafx.application.Platform;
import javafx.scene.control.Alert;
import javafx.stage.Stage;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class App extends Application {

    private static final Logger log = LoggerFactory.getLogger(App.class);

    @Override
    public void start(Stage primaryStage) {
        try {
            SchemaInitializer.initialize();
        } catch (Exception e) {
            log.error("Falha ao inicializar banco de dados.", e);
            Alert alert = new Alert(Alert.AlertType.ERROR);
            alert.setTitle("Erro de conexão");
            alert.setHeaderText("Não foi possível conectar ao banco de dados.");
            alert.setContentText("Verifique se o PostgreSQL está rodando e as configurações em " +
                    "application.properties.\n\nErro: " + e.getCause().getMessage());
            alert.showAndWait();
            Platform.exit();
            return;
        }

        LoginScreen loginScreen = new LoginScreen(primaryStage);
        loginScreen.show();
    }

    @Override
    public void stop() {
        log.info("Encerrando aplicação...");
        DatabaseConfig.close();
    }

    public static void main(String[] args) {
        launch(args);
    }
}
