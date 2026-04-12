package com.gitmanager.ui.login;

import com.gitmanager.model.User;
import com.gitmanager.service.AuthService;
import javafx.geometry.Insets;
import javafx.geometry.Pos;
import javafx.scene.control.*;
import javafx.scene.layout.GridPane;
import javafx.scene.layout.VBox;
import javafx.scene.text.Font;
import javafx.scene.text.FontWeight;
import javafx.stage.Stage;
import javafx.stage.Window;

import java.util.Optional;

public class RegisterDialog extends Dialog<User> {

    private final AuthService authService;

    private TextField usernameField;
    private TextField emailField;
    private PasswordField passwordField;
    private PasswordField confirmPasswordField;
    private Label errorLabel;

    public RegisterDialog(Window owner, AuthService authService) {
        this.authService = authService;
        initOwner(owner);
        setTitle("Criar Conta");
        setHeaderText(null);
        buildContent();
        setResultConverter(this::handleResult);
    }

    private void buildContent() {
        Label title = new Label("Criar nova conta");
        title.setFont(Font.font("System", FontWeight.BOLD, 18));

        usernameField = new TextField();
        usernameField.setPromptText("Nome de usuário");

        emailField = new TextField();
        emailField.setPromptText("E-mail");

        passwordField = new PasswordField();
        passwordField.setPromptText("Senha (mín. 6 caracteres)");

        confirmPasswordField = new PasswordField();
        confirmPasswordField.setPromptText("Confirmar senha");

        errorLabel = new Label();
        errorLabel.setStyle("-fx-text-fill: #e74c3c; -fx-font-size: 12px;");
        errorLabel.setWrapText(true);
        errorLabel.setMaxWidth(320);

        GridPane grid = new GridPane();
        grid.setHgap(10);
        grid.setVgap(10);
        grid.add(new Label("Usuário:"), 0, 0);
        grid.add(usernameField, 1, 0);
        grid.add(new Label("E-mail:"), 0, 1);
        grid.add(emailField, 1, 1);
        grid.add(new Label("Senha:"), 0, 2);
        grid.add(passwordField, 1, 2);
        grid.add(new Label("Confirmar:"), 0, 3);
        grid.add(confirmPasswordField, 1, 3);

        VBox content = new VBox(14, title, grid, errorLabel);
        content.setAlignment(Pos.CENTER_LEFT);
        content.setPadding(new Insets(20));
        content.setPrefWidth(380);

        getDialogPane().setContent(content);
        getDialogPane().getButtonTypes().addAll(ButtonType.OK, ButtonType.CANCEL);

        Button okButton = (Button) getDialogPane().lookupButton(ButtonType.OK);
        okButton.setText("Criar conta");
        okButton.addEventFilter(javafx.event.ActionEvent.ACTION, e -> {
            if (!validate()) e.consume();
        });
    }

    private boolean validate() {
        errorLabel.setText("");
        String username = usernameField.getText().trim();
        String email = emailField.getText().trim();
        String pass = passwordField.getText();
        String confirm = confirmPasswordField.getText();

        if (username.isBlank() || email.isBlank() || pass.isBlank()) {
            errorLabel.setText("Todos os campos são obrigatórios.");
            return false;
        }
        if (!email.matches("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$")) {
            errorLabel.setText("E-mail inválido.");
            return false;
        }
        if (pass.length() < 6) {
            errorLabel.setText("A senha deve ter pelo menos 6 caracteres.");
            return false;
        }
        if (!pass.equals(confirm)) {
            errorLabel.setText("As senhas não coincidem.");
            return false;
        }
        return true;
    }

    private User handleResult(ButtonType type) {
        if (type != ButtonType.OK) return null;
        try {
            Optional<User> created = authService.register(
                    usernameField.getText().trim(),
                    emailField.getText().trim(),
                    passwordField.getText());
            return created.orElse(null);
        } catch (IllegalArgumentException e) {
            errorLabel.setText(e.getMessage());
            return null;
        }
    }
}
