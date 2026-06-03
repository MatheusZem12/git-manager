package com.gitmanager.ui.dashboard;

import com.gitmanager.model.GitProject;
import com.gitmanager.service.ProjectService;
import com.gitmanager.ui.components.UiComponents;
import com.gitmanager.ui.dialog.AddEditProjectDialog;
import com.gitmanager.ui.dialog.GitOperationsPanel;
import com.gitmanager.ui.theme.ThemeManager;
import javafx.animation.FadeTransition;
import javafx.application.Platform;
import javafx.collections.FXCollections;
import javafx.collections.ObservableList;
import javafx.geometry.Insets;
import javafx.geometry.Pos;
import javafx.scene.Node;
import javafx.scene.Scene;
import javafx.scene.control.*;
import javafx.scene.layout.*;
import javafx.scene.paint.Color;
import javafx.stage.Stage;
import javafx.util.Duration;

import java.util.List;
import java.util.stream.Collectors;

/**
 * Tela principal do Git Manager.
 * Layout premium com header glassmorphism, lista de projetos em cards, painel de detalhes e status bar.
 */
public class DashboardScreen {

    private final Stage stage;
    private final ProjectService projectService;
    private final ObservableList<GitProject> projectList = FXCollections.observableArrayList();

    private ListView<GitProject> listView;
    private Label statusLabel;
    private BorderPane detailArea;
    private Scene scene;
    private HBox statsBar;
    private TextField searchField;
    private Button removeBtn;

    public DashboardScreen(Stage stage) {
        this.stage = stage;
        this.projectService = new ProjectService();
    }

    public void show() {
        stage.setTitle("Git Manager");
        scene = buildScene();
        ThemeManager.registerScene(scene);
        stage.setScene(scene);
        stage.setResizable(true);
        stage.setMinWidth(1150);
        stage.setMinHeight(760);
        stage.setWidth(1350);
        stage.setHeight(850);
        loadProjects();
    }

    private Scene buildScene() {
        // ---- Header premium ----
        HBox header = buildHeader();

        // ---- Painel esquerdo (lista de projetos) ----
        VBox leftPane = buildLeftPane();
        leftPane.setMinWidth(340);
        leftPane.setMaxWidth(440);
        leftPane.setStyle("-fx-background-color: transparent;");
        VBox.setVgrow(leftPane, Priority.ALWAYS);

        // ---- Painel direito (detalhes) ----
        detailArea = new BorderPane();
        detailArea.setMinWidth(500);
        showDetailPlaceholder();

        SplitPane splitPane = new SplitPane(leftPane, detailArea);
        splitPane.setDividerPositions(0.30);
        splitPane.setStyle("-fx-background-color: transparent; -fx-padding: 12;");
        VBox.setVgrow(splitPane, Priority.ALWAYS);

        // ---- Status bar ----
        HBox statusBar = buildStatusBar();

        VBox root = new VBox(0, header, splitPane, statusBar);
        VBox.setVgrow(splitPane, Priority.ALWAYS);

        return new Scene(root);
    }

    private HBox buildHeader() {
        // Logo / title with gradient accent
        Label appIcon = new Label(UiComponents.ICON_REPO);
        appIcon.getStyleClass().add("gm-dashboard-icon");
        
        Label appTitle = new Label("Git Manager");
        appTitle.getStyleClass().add("gm-header-label");
        appTitle.setStyle("-fx-font-size: 22px;");

        HBox titleBox = new HBox(10, appIcon, appTitle);
        titleBox.setAlignment(Pos.CENTER_LEFT);

        Button refreshBtn = UiComponents.modernButton(
                UiComponents.ICON_REFRESH, "Atualizar", "gm-header-btn",
                this::loadProjects);

        removeBtn = UiComponents.modernButton(
                UiComponents.ICON_DELETE, "Remover", "gm-header-btn-danger",
                this::removeSelectedProject);
        removeBtn.setDisable(true);

        Button addBtn = UiComponents.modernButton(
                UiComponents.ICON_ADD, "Adicionar", "gm-btn-primary",
                this::openAddDialog);

        HBox header = new HBox(12, titleBox, UiComponents.spacer(), refreshBtn, removeBtn, addBtn);
        header.setAlignment(Pos.CENTER_LEFT);
        header.setPadding(new Insets(16, 28, 16, 28));
        header.getStyleClass().add("gm-header");

        return header;
    }

    private VBox buildLeftPane() {
        // Título da lista
        Label listTitle = new Label("REPOSITÓRIOS");
        listTitle.getStyleClass().add("gm-list-title");

        // Barra de busca
        searchField = UiComponents.searchField("Buscar repositório...");
        searchField.setPrefWidth(260);
        searchField.textProperty().addListener((obs, old, val) -> filterProjects(val));

        // Lista de projetos
        listView = new ListView<>(projectList);
        listView.setCellFactory(lv -> new ProjectListCell());
        listView.setPlaceholder(buildEmptyPlaceholder());
        listView.setStyle("-fx-background-color: transparent; -fx-border-color: transparent;");
        VBox.setVgrow(listView, Priority.ALWAYS);

        listView.getSelectionModel().selectedItemProperty().addListener(
                (obs, old, selected) -> {
                    removeBtn.setDisable(selected == null);
                    if (selected != null) {
                        onProjectSelected(selected);
                    }
                });

        // Context menu
        ContextMenu ctx = new ContextMenu();
        MenuItem removeItem = new MenuItem(UiComponents.ICON_DELETE + "  Remover da lista");
        removeItem.setOnAction(e -> {
            GitProject selected = listView.getSelectionModel().getSelectedItem();
            if (selected != null) {
                Alert confirm = new Alert(Alert.AlertType.CONFIRMATION);
                ThemeManager.applyToDialog(confirm);
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

        // Stats bar
        statsBar = new HBox(24);
        statsBar.setAlignment(Pos.CENTER_LEFT);
        statsBar.setPadding(new Insets(10, 16, 4, 16));

        VBox leftPane = new VBox(8, listTitle, searchField, listView, statsBar);
        leftPane.setPadding(new Insets(12));
        VBox.setVgrow(listView, Priority.ALWAYS);
        return leftPane;
    }

    private VBox buildEmptyPlaceholder() {
        return UiComponents.emptyState(
                UiComponents.ICON_EMPTY,
                "Nenhum repositório",
                "Clique em 'Adicionar' para cadastrar\num diretório git."
        );
    }

    private void showDetailPlaceholder() {
        VBox placeholder = UiComponents.emptyState(
                UiComponents.ICON_GIT,
                "Selecione um repositório",
                "Clique em um item da lista à esquerda\npara ver detalhes e operações."
        );
        VBox wrapper = new VBox(placeholder);
        wrapper.getStyleClass().add("gm-card");
        wrapper.setAlignment(Pos.CENTER);
        VBox.setVgrow(placeholder, Priority.ALWAYS);
        detailArea.setCenter(wrapper);
    }

    private HBox buildStatusBar() {
        statusLabel = new Label("Carregando...");
        statusLabel.getStyleClass().add("gm-status-label");

        HBox bar = new HBox(statusLabel);
        bar.setAlignment(Pos.CENTER_LEFT);
        bar.setPadding(new Insets(10, 28, 10, 28));
        bar.getStyleClass().add("gm-status-bar");
        return bar;
    }

    /** Carrega e valida projetos. */
    private void loadProjects() {
        statusLabel.setText(UiComponents.ICON_REFRESH + "  Validando repositórios...");
        listView.setDisable(true);

        new Thread(() -> {
            List<GitProject> all = projectService.loadAllProjects();
            Platform.runLater(() -> {
                projectList.setAll(all);
                listView.setDisable(false);
                updateStats(all);
                long available = all.stream().filter(GitProject::isAvailable).count();
                long withChanges = all.stream()
                        .filter(GitProject::isAvailable)
                        .filter(p -> p.getStatusSummary() != null && !p.getStatusSummary().equals("Limpo"))
                        .count();
                statusLabel.setText(String.format(
                        "%s  %d disponíveis  ·  %d com alterações  ·  %d total",
                        UiComponents.ICON_CHECK, available, withChanges, all.size()));
            });
        }).start();
    }

    private void filterProjects(String query) {
        if (query == null || query.isBlank()) {
            listView.setItems(projectList);
            return;
        }
        String lower = query.toLowerCase();
        ObservableList<GitProject> filtered = projectList.stream()
                .filter(p -> p.getName().toLowerCase().contains(lower)
                        || p.getPath().toLowerCase().contains(lower))
                .collect(Collectors.toCollection(FXCollections::observableArrayList));
        listView.setItems(filtered);
    }

    private void updateStats(List<GitProject> all) {
        statsBar.getChildren().clear();
        long available = all.stream().filter(GitProject::isAvailable).count();
        long withChanges = all.stream()
                .filter(GitProject::isAvailable)
                .filter(p -> p.getStatusSummary() != null && !p.getStatusSummary().equals("Limpo"))
                .count();
        long unavailable = all.size() - available;

        statsBar.getChildren().addAll(
                UiComponents.stat(String.valueOf(all.size()), "TOTAL", "gm-stat-total"),
                UiComponents.stat(String.valueOf(available), "OK", "gm-stat-ok"),
                UiComponents.stat(String.valueOf(withChanges), "ALTERAÇÕES", "gm-stat-warn"),
                UiComponents.stat(String.valueOf(unavailable), "INDISP.", unavailable > 0 ? "gm-stat-danger" : "gm-stat-muted")
        );
    }

    private void onProjectSelected(GitProject project) {
        if (project == null) return;
        try {
            GitOperationsPanel panel = new GitOperationsPanel(
                    project, projectService, this::loadProjects,
                    () -> Platform.runLater(() -> onProjectSelected(project)),
                    this::openEditDialog);
            Node node = panel.build();
            detailArea.setCenter(node);
            detailArea.layout();
        } catch (Exception e) {
            statusLabel.setText("❌ Erro ao abrir projeto: " + e.getMessage());
            e.printStackTrace();
        }
    }

    private void openAddDialog() {
        AddEditProjectDialog dialog = new AddEditProjectDialog(stage, null, projectService);
        GitProject p = dialog.showAndWait();
        if (p != null) {
            loadProjects();
            Platform.runLater(() ->
                projectList.stream()
                    .filter(pr -> pr.getPath().equals(p.getPath()))
                    .findFirst()
                    .ifPresent(pr -> listView.getSelectionModel().select(pr)));
        }
    }

    private void openEditDialog(GitProject project) {
        AddEditProjectDialog dialog = new AddEditProjectDialog(stage, project, projectService);
        GitProject updated = dialog.showAndWait();
        if (updated != null) {
            loadProjects();
        }
    }

    private void removeSelectedProject() {
        GitProject selected = listView.getSelectionModel().getSelectedItem();
        if (selected == null) return;

        Alert confirm = new Alert(Alert.AlertType.CONFIRMATION);
        ThemeManager.applyToDialog(confirm);
        confirm.setTitle("Remover");
        confirm.setHeaderText("Remover '" + selected.getName() + "'?");
        confirm.setContentText("Isso apenas remove a entrada da lista local. O diretório no disco não será alterado.");
        confirm.showAndWait().ifPresent(bt -> {
            if (bt == ButtonType.OK) {
                projectService.deleteProject(selected.getPath());
                loadProjects();
                detailArea.setCenter(null);
                showDetailPlaceholder();
                removeBtn.setDisable(true);
            }
        });
    }
}
