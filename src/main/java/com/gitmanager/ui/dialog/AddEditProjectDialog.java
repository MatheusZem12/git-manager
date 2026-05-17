package com.gitmanager.ui.dialog;

import com.gitmanager.model.GitProject;
import com.gitmanager.service.ProjectService;
import com.gitmanager.ui.components.UiComponents;
import com.gitmanager.ui.theme.ThemeManager;
import javafx.geometry.Insets;
import javafx.geometry.Pos;
import javafx.scene.Scene;
import javafx.scene.control.*;
import javafx.scene.layout.GridPane;
import javafx.scene.layout.HBox;
import javafx.scene.layout.VBox;
import javafx.scene.text.Font;
import javafx.scene.text.FontWeight;
import javafx.stage.DirectoryChooser;
import javafx.stage.Modality;
import javafx.stage.Stage;
import javafx.stage.StageStyle;

import java.io.File;

/**
 * Janela modal premium para adicionar ou editar um repositório Git.
 * Usa Stage customizado para controle total do visual.
 */
public class AddEditProjectDialog {

    private final GitProject existing;
    private final ProjectService projectService;
    private final Stage ownerStage;

    private TextField nameField;
    private TextField pathField;
    private Label errorLabel;
    private GitProject result;

    public AddEditProjectDialog(Stage owner, GitProject existing, ProjectService projectService) {
        this.ownerStage = owner;
        this.existing = existing;
        this.projectService = projectService;
    }

    public GitProject showAndWait() {
        boolean isEdit = existing != null;

        Stage stage = new Stage();
        stage.initOwner(ownerStage);
        stage.initModality(Modality.APPLICATION_MODAL);
        stage.initStyle(StageStyle.DECORATED);
        stage.setTitle(isEdit ? "Editar Repositório" : "Adicionar Repositório");
        stage.setResizable(false);

        // ---- Título ----
        Label iconLabel = new Label(isEdit ? UiComponents.ICON_EDIT : UiComponents.ICON_ADD);
        iconLabel.getStyleClass().add("gm-dialog-icon");
        
        Label title = new Label(isEdit ? "Editar Repositório" : "Adicionar Repositório");
        title.setFont(Font.font("Inter", FontWeight.BOLD, 22));
        title.getStyleClass().add("gm-dialog-title");
        
        HBox titleBox = new HBox(12, iconLabel, title);
        titleBox.setAlignment(Pos.CENTER_LEFT);

        // ---- Campos ----
        Label nameLabel = new Label("Nome do projeto");
        nameLabel.getStyleClass().add("gm-field-label");
        
        nameField = new TextField(isEdit ? existing.getName() : "");
        nameField.setPromptText("Ex: Meu Backend");
        nameField.setPrefWidth(440);
        nameField.setStyle("-fx-font-size: 14px;");

        Label pathLabelText = new Label("Diretório do repositório");
        pathLabelText.getStyleClass().add("gm-field-label");

        pathField = new TextField(isEdit ? existing.getPath() : "");
        pathField.setPromptText("Caminho absoluto do diretório");
        pathField.setPrefWidth(360);
        pathField.setStyle("-fx-font-size: 14px;");
        if (isEdit) {
            pathField.setDisable(true);
            pathField.setStyle(pathField.getStyle() + "-fx-opacity: 0.6;");
        }

        Button browseBtn = UiComponents.neutralButton("\uD83D\uDCC1  Procurar...", () -> {
            DirectoryChooser chooser = new DirectoryChooser();
            chooser.setTitle("Selecionar diretório do repositório Git");
            if (!pathField.getText().isBlank()) {
                File current = new File(pathField.getText());
                if (current.exists()) chooser.setInitialDirectory(current);
            }
            File selected = chooser.showDialog(stage);
            if (selected != null) {
                pathField.setText(selected.getAbsolutePath());
            }
        });
        if (isEdit) {
            browseBtn.setDisable(true);
        }

        errorLabel = new Label("");
        errorLabel.setStyle("-fx-text-fill: #ef4444; -fx-font-size: 12.5px; -fx-font-weight: bold;");
        errorLabel.setMaxWidth(460);
        errorLabel.setWrapText(true);

        // Grid
        GridPane grid = new GridPane();
        grid.setHgap(14);
        grid.setVgap(10);
        grid.add(nameLabel, 0, 0, 3, 1);
        grid.add(nameField, 0, 1, 3, 1);
        grid.add(pathLabelText, 0, 2, 3, 1);
        grid.add(pathField, 0, 3);
        grid.add(browseBtn, 1, 3);

        Label hint = UiComponents.hint("O diretório será validado: deve existir e conter um .git válido.");
        hint.setWrapText(true);

        // Botões de ação
        Button cancelBtn = new Button("Cancelar");
        cancelBtn.getStyleClass().add("gm-btn-neutral");
        cancelBtn.setOnAction(e -> {
            result = null;
            stage.close();
        });

        Button saveBtn = new Button(isEdit ? "Salvar" : "Adicionar");
        saveBtn.getStyleClass().add("gm-btn-primary");
        saveBtn.setOnAction(e -> {
            if (validate()) {
                result = handleResult();
                if (result != null) {
                    stage.close();
                }
            }
        });

        HBox buttonBox = new HBox(12, cancelBtn, saveBtn);
        buttonBox.setAlignment(Pos.CENTER_RIGHT);
        buttonBox.setPadding(new Insets(8, 0, 0, 0));

        VBox content = new VBox(18, titleBox, grid, hint, errorLabel, buttonBox);
        content.setPadding(new Insets(32));
        content.setPrefWidth(580);
        content.setAlignment(Pos.TOP_LEFT);
        content.getStyleClass().add("gm-dialog-content");

        Scene scene = new Scene(content);
        ThemeManager.registerScene(scene);
        stage.setScene(scene);
        stage.sizeToScene();

        stage.showAndWait();
        return result;
    }

    private boolean validate() {
        errorLabel.setText("");
        if (nameField.getText().isBlank()) {
            errorLabel.setText("⚠  O nome do projeto é obrigatório.");
            return false;
        }
        if (pathField.getText().isBlank()) {
            errorLabel.setText("⚠  Selecione o diretório do repositório.");
            return false;
        }
        if (!projectService.getGitService().isValidGitRepo(pathField.getText().trim())) {
            errorLabel.setText("⚠  O diretório selecionado não é um repositório Git válido (não contém .git).");
            return false;
        }
        return true;
    }

    private GitProject handleResult() {
        try {
            if (existing == null) {
                return projectService.addProject(
                        nameField.getText().trim(),
                        pathField.getText().trim(),
                        "");
            } else {
                existing.setName(nameField.getText().trim());
                existing.setNotes("");
                return projectService.updateProject(existing);
            }
        } catch (IllegalArgumentException e) {
            errorLabel.setText("⚠  " + e.getMessage());
            return null;
        } catch (Exception e) {
            errorLabel.setText("❌  Erro ao salvar: " + e.getMessage());
            return null;
        }
    }
}
