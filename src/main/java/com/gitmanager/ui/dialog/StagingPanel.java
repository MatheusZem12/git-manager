package com.gitmanager.ui.dialog;

import com.gitmanager.model.GitFileChange;
import com.gitmanager.service.GitService;
import com.gitmanager.ui.components.DiffView;
import com.gitmanager.ui.theme.ThemeManager;
import javafx.application.Platform;
import javafx.beans.property.SimpleBooleanProperty;
import javafx.collections.FXCollections;
import javafx.collections.ObservableList;
import javafx.collections.transformation.FilteredList;
import javafx.collections.transformation.SortedList;
import javafx.geometry.Insets;
import javafx.geometry.Pos;
import javafx.scene.Node;
import javafx.scene.control.*;
import javafx.scene.layout.*;
import javafx.scene.paint.Color;
import javafx.scene.text.Font;
import javafx.scene.text.FontWeight;

import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

public class StagingPanel {

    private final String repoPath;
    private final GitService gitService;
    private final ObservableList<GitFileChange> allChanges = FXCollections.observableArrayList();
    private final SimpleBooleanProperty loading = new SimpleBooleanProperty(false);

    private ListView<GitFileChange> listView;
    private TextArea currentView;
    private DiffView diffView;
    private Label emptyLabel;
    private Label fileInfoLabel;
    private TabPane tabPane;

    public StagingPanel(String repoPath, GitService gitService) {
        this.repoPath = repoPath;
        this.gitService = gitService;
    }

    public Node build() {
        Label title = new Label("Arquivos alterados");
        title.setFont(Font.font("System", FontWeight.BOLD, 13));

        Button selectAllBtn = new Button("Selecionar todos");
        selectAllBtn.setOnAction(e -> setAllSelected(true));

        Button selectNoneBtn = new Button("Limpar seleção");
        selectNoneBtn.setOnAction(e -> setAllSelected(false));

        TextField filterField = new TextField();
        filterField.setPromptText("Filtrar por path...");
        filterField.setPrefWidth(220);
        filterField.getStyleClass().add("text-field");

        HBox topBar = new HBox(8, title, new Spacer(), filterField, selectAllBtn, selectNoneBtn);
        topBar.setAlignment(Pos.CENTER_LEFT);
        topBar.setPadding(new Insets(0, 0, 6, 0));

        // Ordenar por path e permitir filtro
        SortedList<GitFileChange> sortedChanges = new SortedList<>(allChanges, java.util.Comparator.comparing(GitFileChange::getPath));
        FilteredList<GitFileChange> filteredChanges = new FilteredList<>(sortedChanges, p -> true);

        filterField.textProperty().addListener((obs, oldVal, newVal) -> {
            if (newVal == null || newVal.isEmpty()) {
                filteredChanges.setPredicate(p -> true);
            } else {
                String lower = newVal.toLowerCase();
                filteredChanges.setPredicate(p -> p.getPath().toLowerCase().contains(lower));
            }
        });

        listView = new ListView<>(filteredChanges);
        listView.setCellFactory(lv -> new ChangeCell());
        listView.setPrefHeight(220);
        listView.getSelectionModel().selectedItemProperty().addListener((obs, old, selected) -> {
            if (selected != null) {
                showFile(selected);
            } else {
                clearViews();
            }
        });

        fileInfoLabel = new Label("Selecione um arquivo para visualizar");
        fileInfoLabel.setFont(Font.font("System", FontWeight.BOLD, 12));
        fileInfoLabel.setPadding(new Insets(8, 0, 4, 0));

        currentView = new TextArea();
        currentView.setEditable(false);
        currentView.setWrapText(true);
        currentView.getStyleClass().add("gm-output");

        diffView = new DiffView();

        Tab currentTab = new Tab("Arquivo atual", currentView);
        currentTab.setClosable(false);
        Tab diffTab = new Tab("Diff (antes/depois)", diffView);
        diffTab.setClosable(false);

        tabPane = new TabPane(currentTab, diffTab);
        tabPane.setPrefHeight(280);

        VBox previewBox = new VBox(fileInfoLabel, tabPane);
        VBox.setVgrow(tabPane, Priority.ALWAYS);

        SplitPane split = new SplitPane(listView, previewBox);
        split.setDividerPositions(0.40);
        split.setOrientation(javafx.geometry.Orientation.VERTICAL);

        VBox root = new VBox(6, topBar, split);
        VBox.setVgrow(split, Priority.ALWAYS);
        root.setPadding(new Insets(8));

        Platform.runLater(this::loadChanges);
        return root;
    }

    public List<String> getSelectedPaths() {
        return allChanges.stream()
                .filter(GitFileChange::isStaged)
                .map(GitFileChange::getPath)
                .collect(Collectors.toList());
    }

    public boolean hasChanges() {
        return !allChanges.isEmpty();
    }

    private void loadChanges() {
        loading.set(true);
        new Thread(() -> {
            List<GitFileChange> changes = gitService.getFileChanges(repoPath);
            Platform.runLater(() -> {
                allChanges.setAll(changes);
                loading.set(false);
                if (changes.isEmpty()) {
                    clearViews();
                    fileInfoLabel.setText("Nenhuma alteração pendente");
                }
            });
        }).start();
    }

    private void setAllSelected(boolean selected) {
        for (GitFileChange c : allChanges) {
            c.setStaged(selected);
        }
        listView.refresh();
    }

    private void showFile(GitFileChange change) {
        fileInfoLabel.setText(change.getPath() + "  —  " + change.getType().getLabel());
        boolean dark = ThemeManager.isDark();
        fileInfoLabel.setTextFill(Color.web(change.getType().getColor(dark)));

        String content = gitService.getFileContent(repoPath, change.getPath());
        currentView.setText(content);

        if (change.getType() == GitFileChange.Type.ADDED) {
            diffView.setDiffText("(arquivo novo – diff mostrará o conteúdo completo como adição)\n\n" + content);
        } else if (change.getType() == GitFileChange.Type.DELETED) {
            diffView.setDiffText("(arquivo removido – não há conteúdo atual no disco)");
        } else if (change.getType() == GitFileChange.Type.UNTRACKED) {
            diffView.setDiffText("(arquivo não rastreado – ainda não está no index)\n\n" + content);
        } else {
            String diff = gitService.getFileDiff(repoPath, change.getPath(), change.isStaged());
            diffView.setDiffText(diff);
        }
    }

    private void clearViews() {
        currentView.clear();
        diffView.clear();
        fileInfoLabel.setText("Selecione um arquivo para visualizar");
        fileInfoLabel.setTextFill(Color.web(ThemeManager.isDark() ? "#a0a0a0" : "#6c757d"));
    }

    private static class Spacer extends Region {
        Spacer() { HBox.setHgrow(this, Priority.ALWAYS); }
    }

    private class ChangeCell extends ListCell<GitFileChange> {
        private final CheckBox checkBox = new CheckBox();
        private final Label nameLabel = new Label();
        private final Label badge = new Label();
        private final HBox graphic;

        ChangeCell() {
            nameLabel.setStyle("-fx-font-family: monospace; -fx-font-size: 12px;");
            badge.setStyle("-fx-padding: 1 6 1 6; -fx-background-radius: 8; -fx-font-size: 10px;");
            HBox right = new HBox(6, badge, checkBox);
            right.setAlignment(Pos.CENTER_RIGHT);
            graphic = new HBox(8, nameLabel, new Spacer(), right);
            graphic.setAlignment(Pos.CENTER_LEFT);
            graphic.setPadding(new Insets(4, 6, 4, 6));

            checkBox.setOnAction(e -> {
                GitFileChange item = getItem();
                if (item != null) {
                    item.setStaged(checkBox.isSelected());
                }
            });
        }

        @Override
        protected void updateItem(GitFileChange item, boolean empty) {
            super.updateItem(item, empty);
            if (empty || item == null) {
                setGraphic(null);
                return;
            }
            nameLabel.setText(item.getPath());
            checkBox.setSelected(item.isStaged());

            boolean dark = ThemeManager.isDark();
            String color = item.getType().getColor(dark);
            badge.setText(item.getType().getLabel());
            badge.setStyle("-fx-background-color: " + color + "30; -fx-text-fill: " + color + "; " +
                           "-fx-padding: 1 6 1 6; -fx-background-radius: 8; -fx-font-size: 10px;");

            if (item.getType() == GitFileChange.Type.DELETED || item.getType() == GitFileChange.Type.CONFLICTING) {
                nameLabel.setStyle("-fx-font-family: monospace; -fx-font-size: 12px; -fx-text-fill: " + color + ";");
            } else {
                nameLabel.setStyle("-fx-font-family: monospace; -fx-font-size: 12px;");
            }

            setGraphic(graphic);
        }
    }
}
