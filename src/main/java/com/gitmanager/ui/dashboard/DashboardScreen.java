package com.gitmanager.ui.dashboard;

import com.gitmanager.model.GitProject;
import com.gitmanager.model.User;
import com.gitmanager.service.ProjectService;
import com.gitmanager.ui.dialog.AddEditProjectDialog;
import com.gitmanager.ui.dialog.GitOperationsPanel;
import com.gitmanager.ui.login.LoginScreen;
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
import java.util.Optional;

public class DashboardScreen {

    private final Stage stage;
    private final User currentUser;
    private final ProjectService projectService;

    private ObservableList<GitProject> projectList;
    private ListView<GitProject> listView;
    private Label statusLabel;
    private SplitPane splitPane;
    private BorderPane detailArea;

    public DashboardScreen(Stage stage, User currentUser) {
        this.stage = stage;
        this.currentUser = currentUser;
        this.projectService = new ProjectService();
        this.projectList = FXCollections.observableArrayList();
    }

    public void show() {
        stage.setTitle("Git Manager — " + currentUser.getUsername());
        stage.setScene(buildScene());
        stage.setResizable(true);
        stage.setMinWidth(900);
        stage.setMinHeight(600);
        loadProjects();
    }

    private Scene buildScene() {
        // ---- Cabeçalho ----
        Label appTitle = new Label("Git Manager");
        appTitle.setFont(Font.font("System", FontWeight.BOLD, 18));
        appTitle.setStyle("-fx-text-fill: white;");

        Label userLabel = new Label("Olá, " + currentUser.getUsername());
        userLabel.setStyle("-fx-text-fill: #bdc3c7; -fx-font-size: 13px;");

        Button logoutBtn = new Button("Sair");
        logoutBtn.setStyle("-fx-background-color: transparent; -fx-text-fill: #bdc3c7; " +
                           "-fx-border-color: #bdc3c7; -fx-cursor: hand;");
        logoutBtn.setOnAction(e -> logout());

        HBox header = new HBox(10, appTitle, new Spacer(), userLabel, logoutBtn);
        header.setAlignment(Pos.CENTER_LEFT);
        header.setPadding(new Insets(12, 20, 12, 20));
        header.setStyle("-fx-background-color: #2c3e50;");

        // ---- Painel esquerdo: lista de projetos ----
        Label projectsTitle = new Label("Meus Repositórios");
        projectsTitle.setFont(Font.font("System", FontWeight.BOLD, 14));

        Button addBtn = new Button("+ Adicionar");
        addBtn.setStyle("-fx-background-color: #27ae60; -fx-text-fill: white; -fx-cursor: hand;");
        addBtn.setOnAction(e -> openAddDialog());

        Button refreshBtn = new Button("↻");
        refreshBtn.setTooltip(new Tooltip("Revalidar projetos"));
        refreshBtn.setStyle("-fx-cursor: hand;");
        refreshBtn.setOnAction(e -> loadProjects());

        HBox listHeader = new HBox(8, projectsTitle, new Spacer(), refreshBtn, addBtn);
        listHeader.setAlignment(Pos.CENTER_LEFT);
        listHeader.setPadding(new Insets(10));

        listView = new ListView<>(projectList);
        listView.setCellFactory(lv -> new ProjectListCell());
        listView.setPlaceholder(new Label("Nenhum repositório cadastrado.\nClique em '+ Adicionar' para começar."));
        listView.getSelectionModel().selectedItemProperty().addListener(
                (obs, old, selected) -> onProjectSelected(selected));

        VBox leftPane = new VBox(0, listHeader, listView);
        VBox.setVgrow(listView, Priority.ALWAYS);
        leftPane.setMinWidth(280);
        leftPane.setMaxWidth(360);

        // ---- Painel direito: detalhe/operações ----
        detailArea = new BorderPane();
        Label placeholder = new Label("Selecione um repositório\nna lista à esquerda.");
        placeholder.setStyle("-fx-text-fill: #95a5a6; -fx-font-size: 15px;");
        placeholder.setAlignment(Pos.CENTER);
        detailArea.setCenter(placeholder);

        // ---- SplitPane ----
        splitPane = new SplitPane(leftPane, detailArea);
        splitPane.setDividerPositions(0.3);

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

        return new Scene(root, 1100, 680);
    }

    private void loadProjects() {
        statusLabel.setText("Validando repositórios no disco...");
        listView.setDisable(true);

        new Thread(() -> {
            List<GitProject> projects = projectService.loadProjectsForCurrentMachine(currentUser);
            Platform.runLater(() -> {
                projectList.setAll(projects);
                listView.setDisable(false);
                long available = projects.stream().filter(GitProject::isAvailable).count();
                statusLabel.setText(projects.size() + " projeto(s) cadastrado(s) — " +
                        available + " disponível(is) neste PC.");
            });
        }).start();
    }

    private void onProjectSelected(GitProject project) {
        if (project == null) return;
        GitOperationsPanel panel = new GitOperationsPanel(project, projectService, this::loadProjects, this::openEditDialog);
        detailArea.setCenter(panel.build());
    }

    private void openAddDialog() {
        AddEditProjectDialog dialog = new AddEditProjectDialog(stage, currentUser, null, projectService);
        Optional<GitProject> result = dialog.showAndWait();
        result.ifPresent(p -> {
            loadProjects();
            // Selecionar o novo projeto
            Platform.runLater(() ->
                projectList.stream()
                    .filter(pr -> pr.getId().equals(p.getId()))
                    .findFirst()
                    .ifPresent(pr -> listView.getSelectionModel().select(pr)));
        });
    }

    private void openEditDialog(GitProject project) {
        AddEditProjectDialog dialog = new AddEditProjectDialog(stage, currentUser, project, projectService);
        dialog.showAndWait().ifPresent(updated -> loadProjects());
    }

    private void logout() {
        LoginScreen loginScreen = new LoginScreen(stage);
        loginScreen.show();
    }

    // Spacer utilitário
    private static class Spacer extends Region {
        Spacer() { HBox.setHgrow(this, Priority.ALWAYS); }
    }
}
