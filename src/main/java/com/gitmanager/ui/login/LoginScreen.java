package com.gitmanager.ui.login;

import com.gitmanager.model.User;
import com.gitmanager.service.AuthService;
import com.gitmanager.ui.dashboard.DashboardScreen;
import javafx.application.Platform;
import javafx.geometry.Insets;
import javafx.geometry.Pos;
import javafx.scene.Scene;
import javafx.scene.control.*;
import javafx.scene.layout.*;
import javafx.scene.text.Font;
import javafx.scene.text.FontWeight;
import javafx.stage.Stage;

import java.util.Optional;

public class LoginScreen {

    private final Stage stage;
    private final AuthService authService;

    private TextField usernameField;
    private PasswordField passwordField;
    private Label messageLabel;
    private Button loginBtn;
    private Button registerBtn;

    public LoginScreen(Stage stage) {
        this.stage = stage;
        this.authService = new AuthService();
    }

    public void show() {
        stage.setTitle("Git Manager — Login");
        stage.setScene(buildScene());
        stage.setResizable(false);
        stage.show();
    }

    private Scene buildScene() {
        // Título
        Label titleLabel = new Label("Git Manager");
        titleLabel.setFont(Font.font("System", FontWeight.BOLD, 28));
        titleLabel.setStyle("-fx-text-fill: #2c3e50;");

        Label subtitleLabel = new Label("Gerencie todos os seus repositórios em um só lugar");
        subtitleLabel.setStyle("-fx-text-fill: #7f8c8d; -fx-font-size: 13px;");

        // Campos
        usernameField = new TextField();
        usernameField.setPromptText("Usuário ou e-mail");
        usernameField.setPrefWidth(300);
        usernameField.setPrefHeight(38);
        usernameField.setStyle("-fx-font-size: 13px;");

        passwordField = new PasswordField();
        passwordField.setPromptText("Senha");
        passwordField.setPrefHeight(38);
        passwordField.setStyle("-fx-font-size: 13px;");
        passwordField.setOnAction(e -> doLogin());

        // Mensagem de feedback
        messageLabel = new Label();
        messageLabel.setWrapText(true);
        messageLabel.setMaxWidth(300);
        messageLabel.setStyle("-fx-text-fill: #e74c3c; -fx-font-size: 12px;");

        // Botões
        loginBtn = new Button("Entrar");
        loginBtn.setPrefWidth(300);
        loginBtn.setPrefHeight(40);
        loginBtn.setDefaultButton(true);
        loginBtn.setStyle("-fx-background-color: #2980b9; -fx-text-fill: white; " +
                          "-fx-font-size: 14px; -fx-font-weight: bold; -fx-cursor: hand;");
        loginBtn.setOnAction(e -> doLogin());
        loginBtn.setOnMouseEntered(e -> loginBtn.setStyle("-fx-background-color: #1f6fa0; -fx-text-fill: white; " +
                "-fx-font-size: 14px; -fx-font-weight: bold; -fx-cursor: hand;"));
        loginBtn.setOnMouseExited(e -> loginBtn.setStyle("-fx-background-color: #2980b9; -fx-text-fill: white; " +
                "-fx-font-size: 14px; -fx-font-weight: bold; -fx-cursor: hand;"));

        registerBtn = new Button("Criar conta");
        registerBtn.setPrefWidth(300);
        registerBtn.setPrefHeight(38);
        registerBtn.setStyle("-fx-background-color: transparent; -fx-text-fill: #2980b9; " +
                             "-fx-font-size: 13px; -fx-cursor: hand; -fx-border-color: #2980b9; -fx-border-radius: 3;");
        registerBtn.setOnAction(e -> showRegisterDialog());

        // Layout
        VBox form = new VBox(12,
                new Label("Usuário ou e-mail"), usernameField,
                new Label("Senha"), passwordField,
                messageLabel,
                loginBtn,
                new Separator(),
                registerBtn);
        form.setAlignment(Pos.CENTER_LEFT);
        form.setPadding(new Insets(20));
        form.setStyle("-fx-background-color: white; -fx-border-radius: 8; -fx-background-radius: 8;");
        form.setMaxWidth(340);

        VBox header = new VBox(6, titleLabel, subtitleLabel);
        header.setAlignment(Pos.CENTER);

        VBox root = new VBox(24, header, form);
        root.setAlignment(Pos.CENTER);
        root.setPadding(new Insets(40));
        root.setStyle("-fx-background-color: #ecf0f1;");

        return new Scene(root, 420, 520);
    }

    private void doLogin() {
        String usernameOrEmail = usernameField.getText().trim();
        String rawPassword = passwordField.getText();

        if (usernameOrEmail.isBlank() || rawPassword.isBlank()) {
            showError("Preencha todos os campos.");
            return;
        }

        loginBtn.setDisable(true);
        loginBtn.setText("Entrando...");
        messageLabel.setText("");

        new Thread(() -> {
            Optional<User> userOpt = authService.login(usernameOrEmail, rawPassword);
            Platform.runLater(() -> {
                loginBtn.setDisable(false);
                loginBtn.setText("Entrar");
                if (userOpt.isPresent()) {
                    openDashboard(userOpt.get());
                } else {
                    showError("Usuário ou senha inválidos.");
                    passwordField.clear();
                }
            });
        }).start();
    }

    private void showRegisterDialog() {
        RegisterDialog dialog = new RegisterDialog(stage, authService);
        dialog.showAndWait().ifPresent(user -> {
            messageLabel.setStyle("-fx-text-fill: #27ae60; -fx-font-size: 12px;");
            messageLabel.setText("Conta criada com sucesso! Faça login.");
            usernameField.setText(user.getUsername());
            passwordField.clear();
            passwordField.requestFocus();
        });
    }

    private void openDashboard(User user) {
        DashboardScreen dashboard = new DashboardScreen(stage, user);
        dashboard.show();
    }

    private void showError(String message) {
        messageLabel.setStyle("-fx-text-fill: #e74c3c; -fx-font-size: 12px;");
        messageLabel.setText(message);
    }
}
