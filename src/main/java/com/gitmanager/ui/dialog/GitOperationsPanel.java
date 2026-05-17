package com.gitmanager.ui.dialog;

import com.gitmanager.model.GitProject;
import com.gitmanager.service.GitService;
import com.gitmanager.service.ProjectService;
import com.gitmanager.ui.components.UiComponents;
import com.gitmanager.ui.theme.ThemeManager;
import com.gitmanager.ui.timeline.GitTimelinePanel;
import javafx.animation.FadeTransition;
import javafx.application.Platform;
import javafx.geometry.Insets;
import javafx.geometry.Pos;
import javafx.scene.Node;
import javafx.scene.control.*;
import javafx.scene.layout.*;
import javafx.scene.paint.Color;
import javafx.scene.text.Font;
import javafx.scene.text.FontWeight;
import javafx.util.Duration;

import java.util.List;
import java.util.function.Consumer;

/**
 * Painel de operações Git para um projeto selecionado.
 * Layout premium com cards, tabs modernas e botões refinados.
 */
public class GitOperationsPanel {

    private final GitProject project;
    private final ProjectService projectService;
    private final GitService gitService;
    private final Runnable onRefresh;
    private final Runnable onProjectRefresh;
    private final Consumer<GitProject> onEdit;

    private TextArea outputArea;
    private ComboBox<String> branchCombo;
    private StagingPanel stagingPanel;

    public GitOperationsPanel(GitProject project, ProjectService projectService,
                              Runnable onRefresh, Runnable onProjectRefresh,
                              Consumer<GitProject> onEdit) {
        this.project = project;
        this.projectService = projectService;
        this.gitService = projectService.getGitService();
        this.onRefresh = onRefresh;
        this.onProjectRefresh = onProjectRefresh;
        this.onEdit = onEdit;
    }

    public Node build() {
        VBox header = buildHeader();

        if (!project.isAvailable()) {
            return buildUnavailableView(header);
        }

        TabPane mainTabs = new TabPane();
        mainTabs.setTabClosingPolicy(TabPane.TabClosingPolicy.UNAVAILABLE);
        mainTabs.getStyleClass().add("gm-tab-modern");
        mainTabs.setStyle("-fx-background-color: transparent;");

        Tab overviewTab = new Tab(UiComponents.ICON_GIT + "  Visão Geral", buildOverviewTab());
        Tab historyTab = new Tab(UiComponents.ICON_COMMIT + "  Histórico", buildHistoryTab());
        Tab tagsTab = new Tab(UiComponents.ICON_TAG + "  Tags", buildTagsTab());
        Tab stashTab = new Tab(UiComponents.ICON_STASH + "  Stash", buildStashTab());

        mainTabs.getTabs().addAll(overviewTab, historyTab, tagsTab, stashTab);

        BorderPane root = new BorderPane();
        root.setTop(header);
        root.setCenter(mainTabs);
        root.setPadding(new Insets(0));
        root.setMinWidth(500);
        root.setMinHeight(400);
        return root;
    }

    private VBox buildHeader() {
        Label nameLabel = new Label(project.getName());
        nameLabel.setFont(Font.font("Inter", FontWeight.BOLD, 24));
        nameLabel.getStyleClass().add("gm-project-title");

        Label pathLabel = new Label(project.getPath());
        pathLabel.getStyleClass().add("gm-path-label");
        pathLabel.setWrapText(true);

        Label statusBadge = buildStatusBadge();

        Button editBtn = UiComponents.iconButton(
                UiComponents.ICON_EDIT, "Editar projeto", "gm-btn-icon",
                () -> onEdit.accept(project));

        HBox titleRow = new HBox(14, nameLabel, statusBadge, UiComponents.spacer(), editBtn);
        titleRow.setAlignment(Pos.CENTER_LEFT);

        VBox header = new VBox(6, titleRow, pathLabel);
        header.setPadding(new Insets(22, 28, 18, 28));
        header.getStyleClass().add("gm-surface-header");
        return header;
    }

    private Label buildStatusBadge() {
        String text;
        String styleClass;
        if (!project.isExistsOnDisk()) {
            text = "Não encontrado";
            styleClass = "gm-badge-error";
        } else if (!project.isHasGit()) {
            text = "Sem git";
            styleClass = "gm-badge-warn";
        } else {
            text = "OK";
            styleClass = "gm-badge-ok";
        }
        return UiComponents.badge(text, styleClass);
    }

    private Node buildUnavailableView(VBox header) {
        String reason = !project.isExistsOnDisk()
                ? "O diretório não existe neste computador."
                : "O diretório existe mas não contém um repositório Git válido.";

        VBox center = UiComponents.emptyState(
                UiComponents.ICON_WARN,
                "Repositório indisponível",
                reason + "\n\nVocê pode editar o caminho ou remover da lista."
        );

        Button editBtn = UiComponents.neutralButton("Editar projeto", () -> onEdit.accept(project));
        Button removeBtn = UiComponents.dangerButton("Remover da lista", () -> {
            projectService.deleteProject(project.getPath());
            onRefresh.run();
        });

        HBox actions = new HBox(12, editBtn, removeBtn);
        actions.setAlignment(Pos.CENTER);

        VBox wrapper = new VBox(24, center, actions);
        wrapper.setAlignment(Pos.CENTER);
        wrapper.setPadding(new Insets(48));

        BorderPane root = new BorderPane();
        root.setTop(header);
        root.setCenter(wrapper);
        return root;
    }

    // ========== Visão Geral ==========

    private Node buildOverviewTab() {
        // Branch section
        VBox branchCard = UiComponents.card();
        branchCard.getChildren().add(UiComponents.sectionHeader(UiComponents.ICON_BRANCH, "Branch"));

        branchCombo = new ComboBox<>();
        branchCombo.setPrefWidth(240);
        branchCombo.getStyleClass().add("combo-box");
        refreshBranches();

        Button checkoutBtn = UiComponents.neutralButton("Checkout", this::doCheckout);
        Button newBranchBtn = UiComponents.primaryButton("+ Nova", this::doNewBranch);

        HBox branchRow = new HBox(12, new Label("Branch atual:"), branchCombo, checkoutBtn, newBranchBtn);
        branchRow.setAlignment(Pos.CENTER_LEFT);
        branchCard.getChildren().add(branchRow);

        // Sync section
        VBox syncCard = UiComponents.card();
        syncCard.getChildren().add(UiComponents.sectionHeader(UiComponents.ICON_FETCH, "Sincronização"));

        Button pushBtn = buildOpBtn(UiComponents.ICON_PUSH + "  Push", "gm-btn-primary", e -> doGitOp("push"));
        Button pullBtn = buildOpBtn(UiComponents.ICON_PULL + "  Pull", "gm-btn-success", e -> doGitOp("pull"));
        Button fetchBtn = buildOpBtn(UiComponents.ICON_REFRESH + "  Fetch", "gm-btn-neutral", e -> doGitOp("fetch"));

        HBox syncRow = new HBox(14, pushBtn, pullBtn, fetchBtn);
        syncRow.setAlignment(Pos.CENTER_LEFT);
        syncCard.getChildren().add(syncRow);

        // Commit section
        VBox commitCard = buildCommitCard();

        // Output section
        VBox outputCard = UiComponents.card();
        outputCard.getChildren().add(UiComponents.sectionHeader(UiComponents.ICON_INFO, "Saída"));

        outputArea = new TextArea();
        outputArea.setEditable(false);
        outputArea.setPrefHeight(180);
        outputArea.getStyleClass().add("gm-output");
        outputArea.setWrapText(true);

        Button clearBtn = UiComponents.ghostButton("Limpar", () -> outputArea.clear());
        HBox outputHeader = new HBox(UiComponents.spacer(), clearBtn);
        outputHeader.setAlignment(Pos.CENTER_RIGHT);

        outputCard.getChildren().addAll(outputHeader, outputArea);
        VBox.setVgrow(outputArea, Priority.ALWAYS);

        VBox content = new VBox(18,
                branchCard,
                syncCard,
                commitCard,
                outputCard);
        content.setPadding(new Insets(18, 24, 24, 24));
        content.setSpacing(18);

        ScrollPane scroll = new ScrollPane(content);
        scroll.setFitToWidth(true);
        scroll.setStyle("-fx-background-color: transparent;");
        scroll.setMinHeight(300);
        return scroll;
    }

    private VBox buildCommitCard() {
        VBox card = UiComponents.card();
        card.getChildren().add(UiComponents.sectionHeader(UiComponents.ICON_CHANGES, "Commit"));

        stagingPanel = new StagingPanel(project.getPath(), gitService);
        Node stagingNode = stagingPanel.build();

        TextArea commitMsg = new TextArea();
        commitMsg.setPromptText("Mensagem do commit...");
        commitMsg.setPrefRowCount(3);
        commitMsg.setStyle("-fx-font-size: 13.5px;");

        Button commitBtn = buildOpBtn(UiComponents.ICON_CHECK + "  Fazer Commit", "gm-btn-warn", e -> {
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

        VBox box = new VBox(12, stagingNode, commitMsg, commitBtn);
        card.getChildren().add(box);
        return card;
    }

    // ========== Histórico ==========

    private Node buildHistoryTab() {
        ListView<String> logList = new ListView<>();
        logList.setPrefHeight(240);
        logList.getStyleClass().add("gm-log-list");
        logList.setStyle("-fx-font-family: monospace; -fx-font-size: 12.5px;");

        List<String> recentCommits = gitService.getRecentCommits(project.getPath(), 20);
        logList.getItems().setAll(recentCommits);

        VBox listBox = new VBox(10, logList);
        listBox.setPadding(new Insets(14));

        Tab listTab = new Tab("Lista", listBox);
        listTab.setClosable(false);

        GitTimelinePanel timeline = new GitTimelinePanel(project.getPath(), gitService);
        Tab graphTab = new Tab("Gráfico", timeline);
        graphTab.setClosable(false);

        TabPane historyTabs = new TabPane(listTab, graphTab);
        historyTabs.setPrefHeight(480);
        historyTabs.setStyle("-fx-background-color: transparent;");
        VBox wrapper = new VBox(historyTabs);
        VBox.setVgrow(historyTabs, Priority.ALWAYS);
        wrapper.setPadding(new Insets(10));
        wrapper.setMinHeight(300);
        return wrapper;
    }

    // ========== Tags ==========

    private Node buildTagsTab() {
        ListView<String> tagList = new ListView<>();
        tagList.setPrefHeight(280);
        tagList.setStyle("-fx-background-color: transparent;");

        Button createBtn = UiComponents.primaryButton(UiComponents.ICON_ADD + "  Nova Tag", () -> {
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

        HBox topBar = new HBox(12, createBtn);
        topBar.setAlignment(Pos.CENTER_LEFT);
        topBar.setPadding(new Insets(10, 0, 8, 0));

        VBox box = new VBox(12, topBar, tagList);
        box.setPadding(new Insets(18, 24, 24, 24));
        box.setMinHeight(200);

        loadTags(tagList);
        return box;
    }

    private void loadTags(ListView<String> list) {
        new Thread(() -> {
            List<String> tags = gitService.getTags(project.getPath());
            Platform.runLater(() -> list.getItems().setAll(tags));
        }).start();
    }

    // ========== Stash ==========

    private Node buildStashTab() {
        ListView<String> stashList = new ListView<>();
        stashList.setPrefHeight(240);
        stashList.setStyle("-fx-background-color: transparent;");

        Button saveBtn = UiComponents.primaryButton(UiComponents.ICON_ADD + "  Salvar Stash", () -> {
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

        Button applyBtn = UiComponents.neutralButton("Aplicar", () -> {
            int idx = stashList.getSelectionModel().getSelectedIndex();
            if (idx < 0) return;
            runAsync(() -> {
                String result = gitService.stashApply(project.getPath(), idx);
                Platform.runLater(() -> showOutput(result));
                return result;
            });
        });

        Button popBtn = UiComponents.successButton("Pop", () -> {
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

        HBox topBar = new HBox(12, saveBtn, UiComponents.spacer(), applyBtn, popBtn);
        topBar.setAlignment(Pos.CENTER_LEFT);
        topBar.setPadding(new Insets(10, 0, 8, 0));

        VBox box = new VBox(12, topBar, stashList);
        box.setPadding(new Insets(18, 24, 24, 24));
        box.setMinHeight(200);

        loadStashes(stashList);
        return box;
    }

    private void loadStashes(ListView<String> list) {
        new Thread(() -> {
            List<String> stashes = gitService.getStashes(project.getPath());
            Platform.runLater(() -> list.getItems().setAll(stashes));
        }).start();
    }

    // ========== Actions ==========

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
        grid.setHgap(12);
        grid.setVgap(12);
        grid.setPadding(new Insets(8));
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
        btn.setPrefWidth(140);
        btn.setOnAction(handler);
        return btn;
    }

    private void runAsync(java.util.concurrent.Callable<String> task) {
        showOutput("⏳ Executando...");
        new Thread(() -> {
            try {
                String result = task.call();
                Platform.runLater(() -> showOutput(result));
            } catch (Exception e) {
                Platform.runLater(() -> showOutput("❌ Erro: " + e.getMessage()));
            }
        }).start();
    }

    private void showOutput(String text) {
        if (outputArea != null) {
            outputArea.appendText(text + "\n");
        }
    }
}
