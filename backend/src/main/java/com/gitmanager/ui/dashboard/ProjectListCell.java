package com.gitmanager.ui.dashboard;

import com.gitmanager.model.GitProject;
import com.gitmanager.ui.components.UiComponents;
import com.gitmanager.ui.theme.ThemeManager;
import javafx.geometry.Insets;
import javafx.geometry.Pos;
import javafx.scene.control.Label;
import javafx.scene.control.ListCell;
import javafx.scene.control.Tooltip;
import javafx.scene.layout.HBox;
import javafx.scene.layout.Priority;
import javafx.scene.layout.VBox;
import javafx.scene.paint.Color;
import javafx.scene.shape.Circle;

/**
 * Cell renderer premium para itens de projeto na lista.
 * Exibe card com indicador de status, nome, branch e resumo de status.
 */
public class ProjectListCell extends ListCell<GitProject> {

    private HBox content;
    private Circle statusDot;
    private Label nameLabel;
    private Label branchLabel;
    private Label pathLabel;
    private Label statusBadge;
    private HBox syncBox;

    public ProjectListCell() {
        setOnMouseClicked(e -> {
            if (!isEmpty() && getItem() != null && getListView() != null) {
                getListView().getSelectionModel().select(getItem());
                getListView().requestFocus();
            }
        });
    }

    @Override
    protected void updateItem(GitProject project, boolean empty) {
        super.updateItem(project, empty);
        if (empty || project == null) {
            setGraphic(null);
            setText(null);
            setStyle("-fx-background-color: transparent;");
            return;
        }

        if (content == null) {
            statusDot = new Circle(6);
            nameLabel = new Label();
            nameLabel.getStyleClass().add("gm-project-name");

            branchLabel = new Label();
            branchLabel.getStyleClass().add("gm-project-branch");

            pathLabel = new Label();
            pathLabel.getStyleClass().add("gm-project-path");
            pathLabel.setWrapText(false);

            statusBadge = new Label();

            syncBox = new HBox(4);
            syncBox.setAlignment(Pos.CENTER_LEFT);

            HBox topRow = new HBox(8, nameLabel, syncBox, UiComponents.spacer(), statusBadge);
            topRow.setAlignment(Pos.CENTER_LEFT);

            VBox textBox = new VBox(3, topRow, branchLabel, pathLabel);
            textBox.setAlignment(Pos.CENTER_LEFT);
            VBox.setVgrow(textBox, Priority.ALWAYS);

            content = new HBox(12, statusDot, textBox);
            content.setAlignment(Pos.CENTER_LEFT);
            content.setPadding(new Insets(12, 14, 12, 14));
            content.getStyleClass().add("gm-project-card");
        }

        // Atualiza dados
        if (!project.isExistsOnDisk()) {
            statusDot.setRadius(6);
            statusDot.getStyleClass().setAll("gm-dot-danger");
        } else if (!project.isHasGit()) {
            statusDot.setRadius(6);
            statusDot.getStyleClass().setAll("gm-dot-warning");
        } else {
            statusDot.setRadius(6);
            statusDot.getStyleClass().setAll("gm-dot-success");
        }

        nameLabel.setText(project.getName());
        branchLabel.setText(buildBranchLine(project));
        pathLabel.setText(shortenPath(project.getPath()));
        pathLabel.setTooltip(new Tooltip(project.getPath()));

        Label newBadge = buildStatusBadge(project);
        statusBadge.setText(newBadge.getText());
        statusBadge.getStyleClass().setAll(newBadge.getStyleClass());

        syncBox.getChildren().clear();
        if (project.getAhead() > 0 || project.getBehind() > 0) {
            syncBox.getChildren().add(buildSyncBadge(project));
        }

        applySelectionStyle();

        setGraphic(content);
        setText(null);
        setStyle("-fx-background-color: transparent; -fx-padding: 3 4;");
    }

    @Override
    public void updateSelected(boolean selected) {
        super.updateSelected(selected);
        applySelectionStyle();
    }

    private void applySelectionStyle() {
        if (content == null) return;
        if (isSelected()) {
            if (!content.getStyleClass().contains("gm-project-card-selected")) {
                content.getStyleClass().remove("gm-project-card");
                content.getStyleClass().add("gm-project-card-selected");
            }
        } else {
            if (!content.getStyleClass().contains("gm-project-card")) {
                content.getStyleClass().remove("gm-project-card-selected");
                content.getStyleClass().add("gm-project-card");
            }
        }
    }

    private String buildBranchLine(GitProject p) {
        if (!p.isExistsOnDisk()) return "Diretório não encontrado";
        if (!p.isHasGit()) return "Sem repositório git";
        String branch = p.getCurrentBranch() != null ? p.getCurrentBranch() : "?";
        String status = p.getStatusSummary() != null ? p.getStatusSummary() : "";
        if (status.isEmpty() || status.equals("Limpo")) {
            return UiComponents.ICON_BRANCH + "  " + branch;
        }
        return UiComponents.ICON_BRANCH + "  " + branch + "    ·    " + status;
    }

    private String shortenPath(String raw) {
        if (raw == null || raw.isEmpty()) return raw;
        String[] parts = raw.split("/");
        java.util.List<String> filtered = new java.util.ArrayList<>();
        for (String p : parts) {
            if (p != null && !p.isEmpty()) filtered.add(p);
        }
        if (filtered.size() <= 2) {
            return raw.startsWith("/") ? "/" + String.join("/", filtered) : String.join("/", filtered);
        }
        return "../" + String.join("/", filtered.subList(filtered.size() - 2, filtered.size()));
    }

    private Label buildSyncBadge(GitProject p) {
        StringBuilder sb = new StringBuilder();
        if (p.getAhead() > 0) sb.append("↑").append(p.getAhead());
        if (p.getBehind() > 0) {
            if (sb.length() > 0) sb.append("  ");
            sb.append("↓").append(p.getBehind());
        }
        Label lbl = new Label(sb.toString());
        lbl.getStyleClass().add("gm-project-sync");
        return lbl;
    }

    private Label buildStatusBadge(GitProject p) {
        if (!p.isAvailable()) {
            return UiComponents.badgeError("OFF");
        }
        String status = p.getStatusSummary();
        if (status == null || status.equals("Limpo")) {
            return UiComponents.badgeOk("OK");
        }
        if (status.contains("alteração")) {
            return UiComponents.badgeWarn(status);
        }
        return UiComponents.badgeNeutral(status);
    }
}
