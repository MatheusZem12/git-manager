package com.gitmanager.ui.dashboard;

import com.gitmanager.model.GitProject;
import com.gitmanager.service.ProjectService;
import com.gitmanager.ui.dialog.AddEditProjectDialog;
import com.gitmanager.ui.dialog.GitOperationsPanel;
import javafx.application.Platform;
import javafx.collections.FXCollections;
import javafx.collections.ObservableList;
import javafx.geometry.Insets;
import javafx.geometry.Pos;
import javafx.scene.Scene;
import javafx.scene.control.*;
import javafx.scene.layout.*;
import javafx.scene.text.Font;
import javafx.scene.text.FontWeight;
import javafx.stage.Stage;

import java.util.List;
import java.util.stream.Collectors;

public class DashboardScreen {

    private final Stage stage;
    private final ProjectService projectService;
    private final ObservableList<GitProject> projectList = FXCollections.observableArrayList();

    private ListView<GitProject> listView;
    private Label statusLabel;
    private BorderPane detailArea;

    public DashboardScreen(Stage stage) {
        this.stage = stage;
        this.projectService = new ProjectService();
    }

    public void show() {
        stage.setTitle("Git Manager");
        stage.setScene(buildScene());
        stage.setResizable(true);
        stage.setMinWidth(960);
        stage.setMinHeight(620);
        loadProjects();
    }

    private Scene buildScene() {
        // ---- Cabeçalho ----
        Label appTitle = new Label("Git Manager");
        appTitle.setFont(Font.font("System", FontWeight.BOLD, 18));
        appTitle.setStyle("-fx-text-fill: white;");

        Button addBtn = new Button("+ Adicionar");
        addBtn.setStyle("-fx-background-color: #27ae60; -fx-text-fill: white; -fx-font-size: 12px; -fx-cursor: hand;");
        addBtn.setOnAction(e -> openAddDialog());

        Button refreshBtn = new Button("↻ Atualizar");
        refreshBtn.setStyle("-fx-cursor: hand; -fx-font-size: 12px;");
        refreshBtn.setOnAction(e -> loadProjects());

        HBox header = new HBox(10, appTitle, new Spacer(), refreshBtn, addBtn);
        header.setAlignment(Pos.CENTER_LEFT);
        header.setPadding(new Insets(12, 20, 12, 20));
        header.setStyle("-fx-background-color: #2c3e50;");

        // ---- Painel esquerdo ----
        VBox leftPane = buildLeftPane();
        leftPane.setMinWidth(290);
        leftPane.setMaxWidth(380);

        // ---- Painel direito: detalhe/operações ----
        detailArea = new BorderPane();
        showDetailPlaceholder();

        SplitPane splitPane = new SplitPane(leftPane, detailArea);
        splitPane.setDividerPositions(0.30);

        // ---- Status bar ----
        statusLabel = new Label("Carregando repositórios...");
        statusLabel.setStyle("-fx-text-fill: #7f8c8d; -fx-font-size: 11px;");
        HBox statusBar = new HBox(statusLabel);
        statusBar.setPadding(new Insets(4, 10, 4, 10));
        statusBar.setStyle("-fx-background-color: #ecf0f1; -fx-border-color: #bdc3c7; -fx-border-width: 1 0 0 0;");

        BorderPane root = new BorderPane();
        root.setTop(header);
        root.setCenter(splitPane);
        root.setBottom(statusBar);

        return new Scene(root, 1150, 700);
    }

    private VBox buildLeftPane() {
        Label listTitle = new Label("Repositórios Git");
        listTitle.setFont(Font.font("System", FontWeight.BOLD, 13));
        listTitle.setStyle("-fx-text-fill: #2c3e50;");
        listTitle.setPadding(new Insets(10, 10, 6, 10));

        listView = new ListView<>(projectList);
        listView.setCellFactory(lv -> new ProjectListCell());
        listView.setPlaceholder(buildEmptyPlaceholder());
        VBox.setVgrow(listView, Priority.ALWAYS);
        listView.getSelectionModel().selectedItemProperty().addListener(
                (obs, old, selected) -> {
                    if (selected != null) {
                        onProjectSelected(selected);
                    }
                });

        ContextMenu ctx = new ContextMenu();
        MenuItem removeItem = new MenuItem("Remover da lista");
        removeItem.setOnAction(e -> {
            GitProject selected = listView.getSelectionModel().getSelectedItem();
            if (selected != null) {
                Alert confirm = new Alert(Alert.AlertType.CONFIRMATION);
                confirm.setTitle("Remover");
                confirm.setHeaderText("Remover '" + selected.getName() + "'?");
                confirm.setContentText("Isso apenas remove a entrada da lista local. O diretório no disco não será alterado.");
                confirm.showAndWait().ifPresent(bt -> {
                    if (bt == ButtonType.OK) {
                        projectService.deleteProject(selected.getPath());
                        loadProjects();
                        detailArea.setCenter(null);
                        showDetailPlaceholder();
                    }
                });
            }
        });
        ctx.getItems().add(removeItem);
        listView.setContextMenu(ctx);

        VBox leftPane = new VBox(0, listTitle, listView);
        VBox.setVgrow(listView, Priority.ALWAYS);
        return leftPane;
    }

    private Label buildEmptyPlaceholder() {
        Label lbl = new Label("Nenhum repositório cadastrado.\n\nClique em '+ Adicionar' para\ncadastrar um diretório git.");
        lbl.setStyle("-fx-text-fill: #95a5a6; -fx-font-size: 12px; -fx-text-alignment: center;");
        lbl.setAlignment(Pos.CENTER);
        return lbl;
    }

    private void showDetailPlaceholder() {
        Label placeholder = new Label("Selecione um repositório\nna lista à esquerda.");
        placeholder.setStyle("-fx-text-fill: #95a5a6; -fx-font-size: 15px;");
        placeholder.setAlignment(Pos.CENTER);
        detailArea.setCenter(placeholder);
    }

    /** Carrega e valida projetos. */
    private void loadProjects() {
        statusLabel.setText("Validando repositórios no disco...");
        listView.setDisable(true);

        new Thread(() -> {
            List<GitProject> all = projectService.loadAllProjects();
            Platform.runLater(() -> {
                projectList.setAll(all);
                listView.setDisable(false);
                long available = all.stream().filter(GitProject::isAvailable).count();
                statusLabel.setText(
                    available + " disponível(is) de " + all.size() + " cadastrado(s)");
            });
        }).start();
    }

    private void onProjectSelected(GitProject project) {
        if (project == null) return;
        GitOperationsPanel panel = new GitOperationsPanel(
                project, projectService, this::loadProjects, this::openEditDialog);
        detailArea.setCenter(panel.build());
    }

    private void openAddDialog() {
        AddEditProjectDialog dialog = new AddEditProjectDialog(stage, null, projectService);
        dialog.showAndWait().ifPresent(p -> {
            loadProjects();
            Platform.runLater(() ->
                projectList.stream()
                    .filter(pr -> pr.getPath().equals(p.getPath()))
                    .findFirst()
                    .ifPresent(pr -> listView.getSelectionModel().select(pr)));
        });
    }

    private void openEditDialog(GitProject project) {
        AddEditProjectDialog dialog = new AddEditProjectDialog(stage, project, projectService);
        dialog.showAndWait().ifPresent(updated -> loadProjects());
    }

    private static class Spacer extends Region {
        Spacer() { HBox.setHgrow(this, Priority.ALWAYS); }
    }
}
