package com.gitmanager.ui.dashboard;

import com.gitmanager.model.GitProject;
import com.gitmanager.ui.components.UiComponents;
import com.gitmanager.ui.theme.ThemeManager;
import javafx.geometry.Insets;
import javafx.geometry.Pos;
import javafx.scene.control.Label;
import javafx.scene.control.ListCell;
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
    private Label subtitleLabel;
    private Label statusBadge;

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
            subtitleLabel = new Label();
            subtitleLabel.getStyleClass().add("gm-project-subtitle");

            VBox textBox = new VBox(4, nameLabel, subtitleLabel);
            VBox.setVgrow(textBox, Priority.ALWAYS);

            statusBadge = new Label();

            content = new HBox(12, statusDot, textBox, UiComponents.spacer(), statusBadge);
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
        subtitleLabel.setText(buildSubtitle(project));

        Label newBadge = buildStatusBadge(project);
        statusBadge.setText(newBadge.getText());
        statusBadge.getStyleClass().setAll(newBadge.getStyleClass());

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

    private String buildSubtitle(GitProject p) {
        if (!p.isExistsOnDisk()) return "Diretório não encontrado";
        if (!p.isHasGit()) return "Sem repositório git";
        String branch = p.getCurrentBranch() != null ? p.getCurrentBranch() : "?";
        String status = p.getStatusSummary() != null ? p.getStatusSummary() : "";
        return UiComponents.ICON_BRANCH + " " + branch + "   ·   " + status;
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
