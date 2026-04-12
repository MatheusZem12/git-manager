package com.gitmanager.ui.dialog;

import com.gitmanager.model.GitProject;
import com.gitmanager.service.GitService;
import com.gitmanager.service.ProjectService;
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

    public GitOperationsPanel(GitProject project, ProjectService projectService,
                              Runnable onRefresh, Consumer<GitProject> onEdit) {
        this.project = project;
        this.projectService = projectService;
        this.gitService = projectService.getGitService();
        this.onRefresh = onRefresh;
        this.onEdit = onEdit;
    }

    public Node build() {
        // ---- Cabeçalho do projeto ----
        Label nameLabel = new Label(project.getName());
        nameLabel.setFont(Font.font("System", FontWeight.BOLD, 20));

        Label pathLabel = new Label(project.getPath());
        pathLabel.setStyle("-fx-text-fill: #7f8c8d; -fx-font-size: 12px;");
        pathLabel.setWrapText(true);

        // Status badge
        Label statusBadge = buildStatusBadge();

        Button editBtn = new Button("Editar");
        editBtn.setStyle("-fx-cursor: hand;");
        editBtn.setOnAction(e -> onEdit.accept(project));

        HBox titleRow = new HBox(10, nameLabel, statusBadge, new Spacer(), editBtn);
        titleRow.setAlignment(Pos.CENTER_LEFT);

        VBox header = new VBox(4, titleRow, pathLabel);
        header.setPadding(new Insets(14, 16, 10, 16));
        header.setStyle("-fx-background-color: #f8f9fa; -fx-border-color: #dee2e6; -fx-border-width: 0 0 1 0;");

        if (!project.isAvailable()) {
            return buildUnavailableView(header);
        }

        // ---- Área de operações (só se disponível) ----

        // Remote warning
        VBox remoteWarning = buildRemoteWarning();

        // Branch selector
        branchCombo = new ComboBox<>();
        refreshBranches();
        branchCombo.setPrefWidth(200);

        Button checkoutBtn = new Button("Checkout");
        checkoutBtn.setStyle("-fx-cursor: hand; -fx-background-color: #8e44ad; -fx-text-fill: white;");
        checkoutBtn.setOnAction(e -> doCheckout());

        Button newBranchBtn = new Button("Nova Branch");
        newBranchBtn.setStyle("-fx-cursor: hand;");
        newBranchBtn.setOnAction(e -> doNewBranch());

        HBox branchRow = new HBox(8, new Label("Branch:"), branchCombo, checkoutBtn, newBranchBtn);
        branchRow.setAlignment(Pos.CENTER_LEFT);

        // Commit section
        TitledPane commitPane = buildCommitPane();

        // Push / Pull / Fetch buttons
        Button pushBtn = buildOpBtn("Push ↑", "#2980b9", e -> doGitOp("push"));
        Button pullBtn = buildOpBtn("Pull ↓", "#27ae60", e -> doGitOp("pull"));
        Button fetchBtn = buildOpBtn("Fetch", "#7f8c8d", e -> doGitOp("fetch"));

        HBox syncRow = new HBox(10, pushBtn, pullBtn, fetchBtn);
        syncRow.setAlignment(Pos.CENTER_LEFT);

        // Commits recentes
        TitledPane logPane = buildLogPane();

        // Output area
        outputArea = new TextArea();
        outputArea.setEditable(false);
        outputArea.setPrefHeight(120);
        outputArea.setStyle("-fx-font-family: monospace; -fx-font-size: 12px; -fx-background-color: #1e1e1e; -fx-text-fill: #d4d4d4;");

        // Notas
        TitledPane notesPane = buildNotesPane();

        VBox content = new VBox(12,
                remoteWarning,
                branchRow,
                new Separator(),
                syncRow,
                new Separator(),
                commitPane,
                logPane,
                new Label("Saída das operações:"),
                outputArea,
                notesPane);
        content.setPadding(new Insets(14, 16, 16, 16));

        ScrollPane scroll = new ScrollPane(content);
        scroll.setFitToWidth(true);
        scroll.setStyle("-fx-background-color: transparent;");

        BorderPane root = new BorderPane();
        root.setTop(header);
        root.setCenter(scroll);
        return root;
    }

    private Label buildStatusBadge() {
        String text;
        String color;
        if (!project.isExistsOnDisk()) {
            text = "Não encontrado"; color = "#e74c3c";
        } else if (!project.isHasGit()) {
            text = "Sem git"; color = "#e67e22";
        } else if (!project.isRemoteUrlMatches()) {
            text = "Remote divergente"; color = "#f39c12";
        } else {
            text = "OK"; color = "#27ae60";
        }
        Label badge = new Label(text);
        badge.setStyle("-fx-background-color: " + color + "; -fx-text-fill: white; " +
                       "-fx-padding: 2 8 2 8; -fx-background-radius: 10; -fx-font-size: 11px;");
        return badge;
    }

    private VBox buildRemoteWarning() {
        VBox box = new VBox();
        if (project.getRemoteUrl() != null && !project.isRemoteUrlMatches()) {
            String actual = gitService.getRemoteOriginUrl(project.getPath());
            Label warn = new Label("⚠ O remote 'origin' neste PC é diferente do cadastrado.\n" +
                    "Cadastrado: " + project.getRemoteUrl() + "\n" +
                    "Atual:      " + (actual != null ? actual : "nenhum"));
            warn.setWrapText(true);
            warn.setStyle("-fx-background-color: #fef9e7; -fx-border-color: #f39c12; " +
                          "-fx-border-width: 1; -fx-padding: 8; -fx-font-size: 12px;");
            box.getChildren().add(warn);
        }
        return box;
    }

    private Node buildUnavailableView(VBox header) {
        String reason = !project.isExistsOnDisk()
                ? "O diretório '" + project.getPath() + "' não existe neste computador."
                : "O diretório existe mas não contém um repositório Git válido.";
        Label msg = new Label("Repositório indisponível neste PC\n\n" + reason);
        msg.setWrapText(true);
        msg.setStyle("-fx-text-fill: #7f8c8d; -fx-font-size: 14px;");
        msg.setAlignment(Pos.CENTER);
        Button editBtn = new Button("Editar projeto");
        editBtn.setOnAction(e -> onEdit.accept(project));
        VBox center = new VBox(16, msg, editBtn);
        center.setAlignment(Pos.CENTER);
        center.setPadding(new Insets(40));
        BorderPane root = new BorderPane();
        root.setTop(header);
        root.setCenter(center);
        return root;
    }

    private TitledPane buildCommitPane() {
        CheckBox addAllCheck = new CheckBox("Adicionar todos os arquivos antes (git add -A)");
        addAllCheck.setSelected(true);

        TextArea commitMsg = new TextArea();
        commitMsg.setPromptText("Mensagem do commit...");
        commitMsg.setPrefRowCount(3);

        TextField authorName = new TextField();
        authorName.setPromptText("Nome do autor (opcional)");

        TextField authorEmail = new TextField();
        authorEmail.setPromptText("Email do autor (opcional)");

        HBox authorRow = new HBox(8, authorName, authorEmail);
        HBox.setHgrow(authorName, Priority.ALWAYS);
        HBox.setHgrow(authorEmail, Priority.ALWAYS);

        Button commitBtn = buildOpBtn("Fazer Commit", "#e67e22", e -> {
            String msg = commitMsg.getText().trim();
            if (msg.isBlank()) {
                showOutput("⚠ Mensagem do commit não pode ser vazia.");
                return;
            }
            runAsync(() -> gitService.commit(project.getPath(), msg, addAllCheck.isSelected(),
                    authorName.getText().trim(), authorEmail.getText().trim()));
            commitMsg.clear();
        });

        VBox box = new VBox(8, addAllCheck, commitMsg, authorRow, commitBtn);
        box.setPadding(new Insets(8));
        TitledPane pane = new TitledPane("Commit", box);
        pane.setExpanded(false);
        return pane;
    }

    private TitledPane buildLogPane() {
        ListView<String> logList = new ListView<>();
        logList.setPrefHeight(180);
        logList.setStyle("-fx-font-family: monospace; -fx-font-size: 11px;");

        Button refreshLog = new Button("Atualizar");
        refreshLog.setStyle("-fx-cursor: hand;");
        refreshLog.setOnAction(e -> {
            List<String> commits = gitService.getRecentCommits(project.getPath(), 20);
            logList.getItems().setAll(commits);
        });
        // Carrega automaticamente
        new Thread(() -> {
            List<String> commits = gitService.getRecentCommits(project.getPath(), 20);
            Platform.runLater(() -> logList.getItems().setAll(commits));
        }).start();

        VBox box = new VBox(6, refreshLog, logList);
        box.setPadding(new Insets(8));
        TitledPane pane = new TitledPane("Histórico de commits (últimos 20)", box);
        pane.setExpanded(false);
        return pane;
    }

    private TitledPane buildNotesPane() {
        TextArea notesArea = new TextArea(project.getNotes() != null ? project.getNotes() : "");
        notesArea.setPromptText("Escreva observações sobre este projeto...");
        notesArea.setPrefRowCount(4);

        Button saveNotes = new Button("Salvar notas");
        saveNotes.setStyle("-fx-cursor: hand; -fx-background-color: #2980b9; -fx-text-fill: white;");
        saveNotes.setOnAction(e -> {
            project.setNotes(notesArea.getText());
            try {
                projectService.updateProject(project);
                showOutput("✓ Notas salvas.");
            } catch (Exception ex) {
                showOutput("Erro ao salvar notas: " + ex.getMessage());
            }
        });

        VBox box = new VBox(8, notesArea, saveNotes);
        box.setPadding(new Insets(8));
        TitledPane pane = new TitledPane("Observações / Notas", box);
        pane.setExpanded(true);
        return pane;
    }

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
        // Para push/pull/fetch que podem precisar de credenciais
        Dialog<String[]> credDialog = buildCredentialDialog();
        credDialog.showAndWait().ifPresent(creds -> {
            String user = creds[0];
            String pass = creds[1];
            runAsync(() -> switch (op) {
                case "push" -> gitService.push(project.getPath(), user, pass);
                case "pull" -> gitService.pull(project.getPath(), user, pass);
                case "fetch" -> gitService.fetch(project.getPath(), user, pass);
                default -> "Operação desconhecida.";
            });
        });
    }

    private Dialog<String[]> buildCredentialDialog() {
        Dialog<String[]> dialog = new Dialog<>();
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

    private Button buildOpBtn(String text, String color, javafx.event.EventHandler<javafx.event.ActionEvent> handler) {
        Button btn = new Button(text);
        btn.setStyle("-fx-background-color: " + color + "; -fx-text-fill: white; " +
                     "-fx-font-size: 13px; -fx-cursor: hand; -fx-pref-width: 110;");
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
