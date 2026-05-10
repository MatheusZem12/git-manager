package com.gitmanager.ui.dialog;

import com.gitmanager.model.GitProject;
import com.gitmanager.service.GitService;
import com.gitmanager.service.ProjectService;
import com.gitmanager.ui.theme.ThemeManager;
import com.gitmanager.ui.timeline.GitTimelinePanel;
import javafx.application.Platform;
import javafx.geometry.Insets;
import javafx.geometry.Pos;
import javafx.scene.Node;
import javafx.scene.control.*;
import javafx.scene.layout.*;
import javafx.scene.text.Font;
import javafx.scene.text.FontWeight;

import java.util.List;
import java.util.function.Consumer;

public class GitOperationsPanel {

    private final GitProject project;
    private final ProjectService projectService;
    private final GitService gitService;
    private final Runnable onRefresh;
    private final Consumer<GitProject> onEdit;

    private TextArea outputArea;
    private ComboBox<String> branchCombo;
    private StagingPanel stagingPanel;

    public GitOperationsPanel(GitProject project, ProjectService projectService,
                              Runnable onRefresh, Consumer<GitProject> onEdit) {
        this.project = project;
        this.projectService = projectService;
        this.gitService = projectService.getGitService();
        this.onRefresh = onRefresh;
        this.onEdit = onEdit;
    }

    public Node build() {
        Label nameLabel = new Label(project.getName());
        nameLabel.setFont(Font.font("System", FontWeight.BOLD, 20));

        Label pathLabel = new Label(project.getPath());
        pathLabel.getStyleClass().add("gm-path-label");
        pathLabel.setWrapText(true);

        Label statusBadge = buildStatusBadge();

        Button editBtn = new Button("Editar");
        editBtn.setOnAction(e -> onEdit.accept(project));

        HBox titleRow = new HBox(10, nameLabel, statusBadge, new Spacer(), editBtn);
        titleRow.setAlignment(Pos.CENTER_LEFT);

        VBox header = new VBox(4, titleRow, pathLabel);
        header.setPadding(new Insets(14, 16, 10, 16));
        header.getStyleClass().add("gm-surface-header");

        if (!project.isAvailable()) {
            return buildUnavailableView(header);
        }

        TabPane mainTabs = new TabPane();
        mainTabs.setTabClosingPolicy(TabPane.TabClosingPolicy.UNAVAILABLE);

        Tab overviewTab = new Tab("Visão Geral", buildOverviewTab());
        Tab historyTab = new Tab("Histórico", buildHistoryTab());
        Tab tagsTab = new Tab("Tags", buildTagsTab());
        Tab stashTab = new Tab("Stash", buildStashTab());

        mainTabs.getTabs().addAll(overviewTab, historyTab, tagsTab, stashTab);

        BorderPane root = new BorderPane();
        root.setTop(header);
        root.setCenter(mainTabs);
        return root;
    }

    private Label buildStatusBadge() {
        String text;
        String styleClass;
        if (!project.isExistsOnDisk()) {
            text = "Não encontrado"; styleClass = "gm-badge-error";
        } else if (!project.isHasGit()) {
            text = "Sem git"; styleClass = "gm-badge-warn";
        } else {
            text = "OK"; styleClass = "gm-badge-ok";
        }
        Label badge = new Label(text);
        badge.getStyleClass().add(styleClass);
        return badge;
    }

    private Node buildUnavailableView(VBox header) {
        String reason = !project.isExistsOnDisk()
                ? "O diretório '" + project.getPath() + "' não existe neste computador."
                : "O diretório existe mas não contém um repositório Git válido.";
        Label msg = new Label("Repositório indisponível neste PC\n\n" + reason);
        msg.setWrapText(true);
        msg.getStyleClass().add("gm-unavailable-msg");
        msg.setAlignment(Pos.CENTER);
        Button editBtn = new Button("Editar projeto");
        editBtn.setOnAction(e -> onEdit.accept(project));
        Button removeBtn = new Button("Remover da lista");
        removeBtn.getStyleClass().add("gm-btn-danger");
        removeBtn.setOnAction(e -> {
            projectService.deleteProject(project.getPath());
            onRefresh.run();
        });
        VBox center = new VBox(16, msg, editBtn, removeBtn);
        center.setAlignment(Pos.CENTER);
        center.setPadding(new Insets(40));
        BorderPane root = new BorderPane();
        root.setTop(header);
        root.setCenter(center);
        return root;
    }

    // ---------- Visão Geral ----------

    private Node buildOverviewTab() {
        // Branch selector
        branchCombo = new ComboBox<>();
        refreshBranches();
        branchCombo.setPrefWidth(200);

        Button checkoutBtn = new Button("Checkout");
        checkoutBtn.getStyleClass().add("gm-btn-neutral");
        checkoutBtn.setOnAction(e -> doCheckout());

        Button newBranchBtn = new Button("Nova Branch");
        newBranchBtn.setOnAction(e -> doNewBranch());

        HBox branchRow = new HBox(8, new Label("Branch:"), branchCombo, checkoutBtn, newBranchBtn);
        branchRow.setAlignment(Pos.CENTER_LEFT);

        // Sync buttons
        Button pushBtn = buildOpBtn("Push ↑", "gm-btn-primary", e -> doGitOp("push"));
        Button pullBtn = buildOpBtn("Pull ↓", "gm-btn-success", e -> doGitOp("pull"));
        Button fetchBtn = buildOpBtn("Fetch", "gm-btn-neutral", e -> doGitOp("fetch"));

        HBox syncRow = new HBox(10, pushBtn, pullBtn, fetchBtn);
        syncRow.setAlignment(Pos.CENTER_LEFT);

        // Commit section
        TitledPane commitPane = buildCommitPane();

        // Output area
        outputArea = new TextArea();
        outputArea.setEditable(false);
        outputArea.setPrefHeight(140);
        outputArea.getStyleClass().add("gm-output");

        Button clearBtn = new Button("Limpar saída");
        clearBtn.setOnAction(e -> { if (outputArea != null) outputArea.clear(); });

        HBox outputHeader = new HBox(10, new Label("Saída das operações:"), new Spacer(), clearBtn);
        outputHeader.setAlignment(Pos.CENTER_LEFT);

        VBox content = new VBox(12,
                branchRow,
                new Separator(),
                syncRow,
                new Separator(),
                commitPane,
                outputHeader,
                outputArea);
        content.setPadding(new Insets(14, 16, 16, 16));

        ScrollPane scroll = new ScrollPane(content);
        scroll.setFitToWidth(true);
        scroll.setStyle("-fx-background-color: transparent;");
        return scroll;
    }

    private TitledPane buildCommitPane() {
        stagingPanel = new StagingPanel(project.getPath(), gitService);
        Node stagingNode = stagingPanel.build();

        TextArea commitMsg = new TextArea();
        commitMsg.setPromptText("Mensagem do commit...");
        commitMsg.setPrefRowCount(3);

        Button commitBtn = buildOpBtn("Fazer Commit", "gm-btn-warn", e -> {
            String msg = commitMsg.getText().trim();
            if (msg.isBlank()) {
                showOutput("⚠ Mensagem do commit não pode ser vazia.");
                return;
            }
            List<String> selected = stagingPanel.getSelectedPaths();
            if (selected.isEmpty()) {
                showOutput("⚠ Nenhum arquivo selecionado para commit.");
                return;
            }
            runAsync(() -> {
                String result = gitService.commitSelected(project.getPath(), msg, selected, null, null);
                Platform.runLater(() -> {
                    showOutput(result);
                    commitMsg.clear();
                    onRefresh.run();
                });
                return result;
            });
        });

        VBox box = new VBox(8, stagingNode, commitMsg, commitBtn);
        box.setPadding(new Insets(8));
        TitledPane pane = new TitledPane("Commit", box);
        pane.setExpanded(true);
        return pane;
    }

    // ---------- Histórico ----------

    private Node buildHistoryTab() {
        // Text list tab
        ListView<String> logList = new ListView<>();
        logList.setPrefHeight(220);
        logList.getStyleClass().add("gm-output");
        logList.setStyle("-fx-font-family: monospace; -fx-font-size: 11px;");

        Button refreshLog = new Button("Atualizar");
        refreshLog.setOnAction(e -> {
            List<String> commits = gitService.getRecentCommits(project.getPath(), 20);
            logList.getItems().setAll(commits);
        });
        VBox listBox = new VBox(6, refreshLog, logList);
        listBox.setPadding(new Insets(8));
        Tab listTab = new Tab("Lista textual", listBox);
        listTab.setClosable(false);

        // Graph timeline tab
        GitTimelinePanel timeline = new GitTimelinePanel(project.getPath(), gitService);
        Tab graphTab = new Tab("Gráfico (timeline)", timeline);
        graphTab.setClosable(false);

        TabPane historyTabs = new TabPane(listTab, graphTab);
        return historyTabs;
    }

    // ---------- Tags ----------

    private Node buildTagsTab() {
        ListView<String> tagList = new ListView<>();
        tagList.setPrefHeight(260);

        Button refreshBtn = new Button("↻ Atualizar");
        refreshBtn.setOnAction(e -> loadTags(tagList));

        Button createBtn = new Button("+ Nova Tag");
        createBtn.getStyleClass().add("gm-btn-primary");
        createBtn.setOnAction(e -> {
            TextInputDialog nameDialog = new TextInputDialog();
            ThemeManager.applyToDialog(nameDialog);
            nameDialog.setTitle("Nova Tag");
            nameDialog.setHeaderText("Criar nova tag");
            nameDialog.setContentText("Nome da tag:");
            nameDialog.showAndWait().ifPresent(name -> {
                if (name.isBlank()) return;
                TextInputDialog msgDialog = new TextInputDialog();
                ThemeManager.applyToDialog(msgDialog);
                msgDialog.setTitle("Mensagem da Tag");
                msgDialog.setHeaderText("Mensagem (opcional)");
                msgDialog.setContentText("Mensagem:");
                msgDialog.showAndWait().ifPresent(msg -> {
                    runAsync(() -> {
                        String result = gitService.createTag(project.getPath(), name.trim(), msg.trim());
                        Platform.runLater(() -> {
                            showOutput(result);
                            loadTags(tagList);
                        });
                        return result;
                    });
                });
            });
        });

        HBox topBar = new HBox(10, refreshBtn, createBtn);
        topBar.setAlignment(Pos.CENTER_LEFT);
        topBar.setPadding(new Insets(8, 0, 6, 0));

        VBox box = new VBox(8, topBar, tagList);
        box.setPadding(new Insets(14, 16, 16, 16));

        loadTags(tagList);
        return box;
    }

    private void loadTags(ListView<String> list) {
        new Thread(() -> {
            List<String> tags = gitService.getTags(project.getPath());
            Platform.runLater(() -> list.getItems().setAll(tags));
        }).start();
    }

    // ---------- Stash ----------

    private Node buildStashTab() {
        ListView<String> stashList = new ListView<>();
        stashList.setPrefHeight(220);

        Button refreshBtn = new Button("↻ Atualizar");
        refreshBtn.setOnAction(e -> loadStashes(stashList));

        Button saveBtn = new Button("+ Salvar Stash");
        saveBtn.getStyleClass().add("gm-btn-primary");
        saveBtn.setOnAction(e -> {
            TextInputDialog dialog = new TextInputDialog();
            ThemeManager.applyToDialog(dialog);
            dialog.setTitle("Salvar Stash");
            dialog.setHeaderText("Salvar alterações atuais em stash");
            dialog.setContentText("Mensagem (opcional):");
            dialog.showAndWait().ifPresent(msg -> {
                runAsync(() -> {
                    String result = gitService.stashSave(project.getPath(), msg.trim());
                    Platform.runLater(() -> {
                        showOutput(result);
                        loadStashes(stashList);
                    });
                    return result;
                });
            });
        });

        Button applyBtn = new Button("Aplicar selecionado");
        applyBtn.setOnAction(e -> {
            int idx = stashList.getSelectionModel().getSelectedIndex();
            if (idx < 0) return;
            runAsync(() -> {
                String result = gitService.stashApply(project.getPath(), idx);
                Platform.runLater(() -> showOutput(result));
                return result;
            });
        });

        Button popBtn = new Button("Pop selecionado");
        popBtn.getStyleClass().add("gm-btn-success");
        popBtn.setOnAction(e -> {
            int idx = stashList.getSelectionModel().getSelectedIndex();
            if (idx < 0) return;
            runAsync(() -> {
                String result = gitService.stashPop(project.getPath(), idx);
                Platform.runLater(() -> {
                    showOutput(result);
                    loadStashes(stashList);
                });
                return result;
            });
        });

        HBox topBar = new HBox(10, refreshBtn, saveBtn, new Spacer(), applyBtn, popBtn);
        topBar.setAlignment(Pos.CENTER_LEFT);
        topBar.setPadding(new Insets(8, 0, 6, 0));

        VBox box = new VBox(8, topBar, stashList);
        box.setPadding(new Insets(14, 16, 16, 16));

        loadStashes(stashList);
        return box;
    }

    private void loadStashes(ListView<String> list) {
        new Thread(() -> {
            List<String> stashes = gitService.getStashes(project.getPath());
            Platform.runLater(() -> list.getItems().setAll(stashes));
        }).start();
    }

    // ---------- Actions ----------

    private void refreshBranches() {
        new Thread(() -> {
            List<String> branches = gitService.listLocalBranches(project.getPath());
            String current = gitService.getCurrentBranch(project.getPath());
            Platform.runLater(() -> {
                branchCombo.getItems().setAll(branches);
                branchCombo.setValue(current);
            });
        }).start();
    }

    private void doCheckout() {
        String branch = branchCombo.getValue();
        if (branch == null || branch.isBlank()) return;
        runAsync(() -> {
            String result = gitService.checkout(project.getPath(), branch);
            project.setCurrentBranch(gitService.getCurrentBranch(project.getPath()));
            onRefresh.run();
            return result;
        });
    }

    private void doNewBranch() {
        TextInputDialog dialog = new TextInputDialog();
        ThemeManager.applyToDialog(dialog);
        dialog.setTitle("Nova Branch");
        dialog.setHeaderText("Criar nova branch");
        dialog.setContentText("Nome da branch:");
        dialog.showAndWait().ifPresent(name -> {
            if (!name.isBlank()) {
                runAsync(() -> {
                    String result = gitService.createBranch(project.getPath(), name);
                    refreshBranches();
                    onRefresh.run();
                    return result;
                });
            }
        });
    }

    private void doGitOp(String op) {
        Alert alert = new Alert(Alert.AlertType.CONFIRMATION);
        ThemeManager.applyToDialog(alert);
        alert.setTitle("Credenciais (opcional)");
        alert.setHeaderText("Usar credenciais HTTP?");
        alert.setContentText("Deixe em branco para usar SSH ou o gerenciador de credenciais do sistema.");

        ButtonType withCreds = new ButtonType("Informar credenciais");
        ButtonType withoutCreds = new ButtonType("Usar SSH / padrão", ButtonBar.ButtonData.OK_DONE);
        ButtonType cancel = ButtonType.CANCEL;
        alert.getButtonTypes().setAll(withoutCreds, withCreds, cancel);

        alert.showAndWait().ifPresent(bt -> {
            if (bt == cancel) return;
            if (bt == withCreds) {
                buildCredentialDialog().showAndWait().ifPresent(creds ->
                    runAsync(() -> execOp(op, creds[0], creds[1])));
            } else {
                runAsync(() -> execOp(op, null, null));
            }
        });
    }

    private String execOp(String op, String user, String pass) {
        return switch (op) {
            case "push"  -> gitService.push(project.getPath(), user, pass);
            case "pull"  -> gitService.pull(project.getPath(), user, pass);
            case "fetch" -> gitService.fetch(project.getPath(), user, pass);
            default -> "Operação desconhecida.";
        };
    }

    private Dialog<String[]> buildCredentialDialog() {
        Dialog<String[]> dialog = new Dialog<>();
        ThemeManager.applyToDialog(dialog);
        dialog.setTitle("Credenciais Git");
        dialog.setHeaderText("Informe suas credenciais (deixe vazio para usar SSH/token configurado)");

        TextField userField = new TextField();
        userField.setPromptText("Usuário Git");
        PasswordField passField = new PasswordField();
        passField.setPromptText("Senha / Token de acesso");

        GridPane grid = new GridPane();
        grid.setHgap(10);
        grid.setVgap(10);
        grid.add(new Label("Usuário:"), 0, 0);
        grid.add(userField, 1, 0);
        grid.add(new Label("Senha/Token:"), 0, 1);
        grid.add(passField, 1, 1);
        dialog.getDialogPane().setContent(grid);
        dialog.getDialogPane().getButtonTypes().addAll(ButtonType.OK, ButtonType.CANCEL);
        dialog.setResultConverter(bt -> bt == ButtonType.OK
                ? new String[]{userField.getText(), passField.getText()}
                : null);
        return dialog;
    }

    private Button buildOpBtn(String text, String styleClass, javafx.event.EventHandler<javafx.event.ActionEvent> handler) {
        Button btn = new Button(text);
        btn.getStyleClass().add(styleClass);
        btn.setPrefWidth(110);
        btn.setOnAction(handler);
        return btn;
    }

    private void runAsync(java.util.concurrent.Callable<String> task) {
        showOutput("Executando...");
        new Thread(() -> {
            try {
                String result = task.call();
                Platform.runLater(() -> showOutput(result));
            } catch (Exception e) {
                Platform.runLater(() -> showOutput("Erro: " + e.getMessage()));
            }
        }).start();
    }

    private void showOutput(String text) {
        if (outputArea != null) {
            outputArea.appendText(text + "\n");
        }
    }

    private static class Spacer extends Region {
        Spacer() { HBox.setHgrow(this, Priority.ALWAYS); }
    }
}
