package com.gitmanager.ui.dialog;

import com.gitmanager.model.GitProject;
import com.gitmanager.model.User;
import com.gitmanager.service.ProjectService;
import javafx.geometry.Insets;
import javafx.scene.control.*;
import javafx.scene.layout.GridPane;
import javafx.scene.layout.VBox;
import javafx.scene.text.Font;
import javafx.scene.text.FontWeight;
import javafx.stage.DirectoryChooser;
import javafx.stage.Stage;
import javafx.stage.Window;

import java.io.File;

public class AddEditProjectDialog extends Dialog<GitProject> {

    private final User currentUser;
    private final GitProject existing; // null = modo adição
    private final ProjectService projectService;
    private final Stage ownerStage;

    private TextField nameField;
    private TextField pathField;
    private TextArea notesArea;
    private Label errorLabel;

    public AddEditProjectDialog(Stage owner, User currentUser,
                                GitProject existing, ProjectService projectService) {
        this.ownerStage = owner;
        this.currentUser = currentUser;
        this.existing = existing;
        this.projectService = projectService;

        initOwner(owner);
        setTitle(existing == null ? "Adicionar Repositório" : "Editar Repositório");
        setHeaderText(null);
        buildContent();
        setResultConverter(this::handleResult);
    }

    private void buildContent() {
        boolean isEdit = existing != null;

        Label title = new Label(isEdit ? "Editar repositório" : "Adicionar repositório Git");
        title.setFont(Font.font("System", FontWeight.BOLD, 17));

        nameField = new TextField(isEdit ? existing.getName() : "");
        nameField.setPromptText("Nome/alias do projeto (ex: Meu Backend)");
        nameField.setPrefWidth(380);

        pathField = new TextField(isEdit ? existing.getPath() : "");
        pathField.setPromptText("Caminho absoluto do diretório");
        pathField.setPrefWidth(310);

        Button browseBtn = new Button("Procurar...");
        browseBtn.setStyle("-fx-cursor: hand;");
        browseBtn.setOnAction(e -> {
            DirectoryChooser chooser = new DirectoryChooser();
            chooser.setTitle("Selecionar diretório do repositório Git");
            if (!pathField.getText().isBlank()) {
                File current = new File(pathField.getText());
                if (current.exists()) chooser.setInitialDirectory(current);
            }
            File selected = chooser.showDialog(ownerStage);
            if (selected != null) {
                pathField.setText(selected.getAbsolutePath());
            }
        });

        notesArea = new TextArea(isEdit && existing.getNotes() != null ? existing.getNotes() : "");
        notesArea.setPromptText("Observações opcionais sobre este projeto...");
        notesArea.setPrefRowCount(4);

        errorLabel = new Label();
        errorLabel.setStyle("-fx-text-fill: #e74c3c; -fx-font-size: 12px;");
        errorLabel.setWrapText(true);
        errorLabel.setMaxWidth(400);

        GridPane grid = new GridPane();
        grid.setHgap(10);
        grid.setVgap(10);
        grid.add(new Label("Nome:"), 0, 0);
        grid.add(nameField, 1, 0, 2, 1);
        grid.add(new Label("Diretório:"), 0, 1);
        grid.add(pathField, 1, 1);
        grid.add(browseBtn, 2, 1);
        grid.add(new Label("Notas:"), 0, 2);
        grid.add(notesArea, 1, 2, 2, 1);

        // Aviso sobre validação
        Label hint = new Label("O diretório será validado: deve existir e conter um .git válido.");
        hint.setStyle("-fx-text-fill: #7f8c8d; -fx-font-size: 11px;");

        VBox content = new VBox(14, title, grid, hint, errorLabel);
        content.setPadding(new Insets(20));
        content.setPrefWidth(480);

        getDialogPane().setContent(content);

        ButtonType saveType = new ButtonType(isEdit ? "Salvar" : "Adicionar", ButtonBar.ButtonData.OK_DONE);
        getDialogPane().getButtonTypes().addAll(saveType, ButtonType.CANCEL);

        Button saveBtn = (Button) getDialogPane().lookupButton(saveType);
        saveBtn.addEventFilter(javafx.event.ActionEvent.ACTION, e -> {
            if (!validate()) e.consume();
        });
    }

    private boolean validate() {
        errorLabel.setText("");
        if (nameField.getText().isBlank()) {
            errorLabel.setText("O nome do projeto é obrigatório.");
            return false;
        }
        if (pathField.getText().isBlank()) {
            errorLabel.setText("Selecione o diretório do repositório.");
            return false;
        }
        // Valida se existe .git
        if (!projectService.getGitService().isValidGitRepo(pathField.getText().trim())) {
            errorLabel.setText("O diretório selecionado não é um repositório Git válido (não contém .git).");
            return false;
        }
        return true;
    }

    private GitProject handleResult(ButtonType type) {
        if (type.getButtonData() != ButtonBar.ButtonData.OK_DONE) return null;
        try {
            if (existing == null) {
                // Adição
                return projectService.addProject(
                        currentUser,
                        nameField.getText().trim(),
                        pathField.getText().trim(),
                        notesArea.getText().trim());
            } else {
                // Edição
                existing.setName(nameField.getText().trim());
                existing.setPath(pathField.getText().trim());
                existing.setNotes(notesArea.getText().trim());
                // Atualiza remote URL ao alterar path
                String newRemote = projectService.getGitService().getRemoteOriginUrl(existing.getPath());
                existing.setRemoteUrl(newRemote);
                return projectService.updateProject(existing);
            }
        } catch (IllegalArgumentException e) {
            errorLabel.setText(e.getMessage());
            return null;
        } catch (Exception e) {
            errorLabel.setText("Erro ao salvar: " + e.getMessage());
            return null;
        }
    }
}
