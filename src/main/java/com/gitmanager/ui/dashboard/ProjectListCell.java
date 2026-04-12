package com.gitmanager.ui.dashboard;

import com.gitmanager.model.GitProject;
import javafx.geometry.Insets;
import javafx.geometry.Pos;
import javafx.scene.control.Label;
import javafx.scene.control.ListCell;
import javafx.scene.layout.HBox;
import javafx.scene.layout.Priority;
import javafx.scene.layout.VBox;
import javafx.scene.paint.Color;
import javafx.scene.shape.Circle;

public class ProjectListCell extends ListCell<GitProject> {

    @Override
    protected void updateItem(GitProject project, boolean empty) {
        super.updateItem(project, empty);
        if (empty || project == null) {
            setGraphic(null);
            setText(null);
            return;
        }

        // Indicador de status (círculo colorido)
        Circle statusDot = new Circle(6);
        if (!project.isExistsOnDisk()) {
            statusDot.setFill(Color.web("#e74c3c")); // vermelho = não existe
        } else if (!project.isHasGit()) {
            statusDot.setFill(Color.web("#e67e22")); // laranja = sem git
        } else if (!project.isRemoteUrlMatches()) {
            statusDot.setFill(Color.web("#f1c40f")); // amarelo = remote divergente
        } else {
            statusDot.setFill(Color.web("#27ae60")); // verde = OK
        }

        // Nome e branch
        Label nameLabel = new Label(project.getName());
        nameLabel.setStyle("-fx-font-weight: bold; -fx-font-size: 13px;");

        Label branchLabel = new Label(buildSubtitle(project));
        branchLabel.setStyle("-fx-text-fill: #7f8c8d; -fx-font-size: 11px;");

        VBox text = new VBox(2, nameLabel, branchLabel);
        VBox.setVgrow(text, Priority.ALWAYS);

        HBox cell = new HBox(10, statusDot, text);
        cell.setAlignment(Pos.CENTER_LEFT);
        cell.setPadding(new Insets(6, 8, 6, 8));

        setGraphic(cell);
        setText(null);
    }

    private String buildSubtitle(GitProject p) {
        if (!p.isExistsOnDisk()) return "⚠ Diretório não encontrado";
        if (!p.isHasGit()) return "⚠ Sem repositório git";
        String branch = p.getCurrentBranch() != null ? p.getCurrentBranch() : "?";
        String status = p.getStatusSummary() != null ? p.getStatusSummary() : "";
        return "⎇ " + branch + "  ·  " + status;
    }
}
