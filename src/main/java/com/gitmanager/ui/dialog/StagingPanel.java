package com.gitmanager.ui.dialog;

import com.gitmanager.model.GitFileChange;
import com.gitmanager.service.GitService;
import com.gitmanager.ui.components.DiffView;
import com.gitmanager.ui.components.UiComponents;
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

import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

/**
 * Painel de staging com lista de arquivos alterados e preview de diff.
 * Layout premium com cards, filtros e syntax highlighting refinado.
 */
public class StagingPanel {

    private final String repoPath;
    private final GitService gitService;
    private final ObservableList<GitFileChange> allChanges = FXCollections.observableArrayList();
    private final SimpleBooleanProperty loading = new SimpleBooleanProperty(false);

    private ListView<GitFileChange> listView;
    private TextArea currentView;
    private DiffView diffView;
    private Label fileInfoLabel;
    private TabPane tabPane;

    public StagingPanel(String repoPath, GitService gitService) {
        this.repoPath = repoPath;
        this.gitService = gitService;
    }

    public Node build() {
        // Header
        HBox topBar = new HBox(12);
        topBar.setAlignment(Pos.CENTER_LEFT);
        topBar.setPadding(new Insets(0, 0, 12, 0));

        Label title = new Label(UiComponents.ICON_CHANGES + "  Arquivos Alterados");
        title.getStyleClass().add("gm-section-header");

        TextField filterField = UiComponents.searchField("Filtrar por nome...");
        filterField.setPrefWidth(200);

        Button selectAllBtn = UiComponents.ghostButton("Todos", () -> setAllSelected(true));
        Button selectNoneBtn = UiComponents.ghostButton("Nenhum", () -> setAllSelected(false));

        topBar.getChildren().addAll(title, UiComponents.spacer(), filterField, selectAllBtn, selectNoneBtn);

        // Lista filtrada e ordenada
        SortedList<GitFileChange> sortedChanges = new SortedList<>(allChanges,
                java.util.Comparator.comparing(GitFileChange::getPath));
        FilteredList<GitFileChange> filteredChanges = new FilteredList<>(sortedChanges, p -> true);

        filterField.textProperty().addListener((obs, oldVal, newVal) -> {
            if (newVal == null || newVal.isEmpty()) {
                filteredChanges.setPredicate(p -> true);
            } else {
                String lower = newVal.toLowerCase();
                filteredChanges.setPredicate(p -> p.getPath().toLowerCase().contains(lower));
            }
        });

        // ListView
        listView = new ListView<>(filteredChanges);
        listView.setCellFactory(lv -> new ChangeCell());
        listView.setPrefHeight(240);
        listView.setStyle("-fx-background-color: transparent;");
        listView.getSelectionModel().selectedItemProperty().addListener((obs, old, selected) -> {
            if (selected != null) {
                showFile(selected);
            } else {
                clearViews();
            }
        });

        // Preview
        fileInfoLabel = new Label("Selecione um arquivo para visualizar");
        fileInfoLabel.getStyleClass().add("gm-file-info");

        currentView = new TextArea();
        currentView.setEditable(false);
        currentView.setWrapText(true);
        currentView.getStyleClass().add("gm-output");
        currentView.setPrefHeight(220);

        diffView = new DiffView();
        diffView.setPrefHeight(220);

        Tab currentTab = new Tab(UiComponents.ICON_FILE + "  Atual", currentView);
        currentTab.setClosable(false);
        Tab diffTab = new Tab("Diff", diffView);
        diffTab.setClosable(false);

        tabPane = new TabPane(currentTab, diffTab);
        tabPane.setPrefHeight(280);
        tabPane.setStyle("-fx-background-color: transparent;");

        VBox previewBox = new VBox(fileInfoLabel, tabPane);
        previewBox.getStyleClass().add("gm-card");
        previewBox.setPadding(new Insets(14));
        VBox.setVgrow(tabPane, Priority.ALWAYS);

        // Split
        SplitPane split = new SplitPane(listView, previewBox);
        split.setDividerPositions(0.42);
        split.setOrientation(javafx.geometry.Orientation.VERTICAL);
        split.setStyle("-fx-background-color: transparent;");

        VBox root = new VBox(10, topBar, split);
        VBox.setVgrow(split, Priority.ALWAYS);
        root.setPadding(new Insets(6));

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
                    fileInfoLabel.setTextFill(Color.web("#5e6a7a"));
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
        String icon = getTypeIcon(change.getType());
        fileInfoLabel.setText(icon + "  " + change.getPath() + "  —  " + change.getType().getLabel());
        String color = change.getType().getColor();
        fileInfoLabel.setTextFill(Color.web(color));

        String content = gitService.getFileContent(repoPath, change.getPath());
        currentView.setText(content);

        if (change.getType() == GitFileChange.Type.ADDED) {
            diffView.setDiffText("(arquivo novo)\n\n" + content);
        } else if (change.getType() == GitFileChange.Type.DELETED) {
            diffView.setDiffText("(arquivo removido)");
        } else if (change.getType() == GitFileChange.Type.UNTRACKED) {
            diffView.setDiffText("(não rastreado)\n\n" + content);
        } else {
            String diff = gitService.getFileDiff(repoPath, change.getPath(), change.isStaged());
            diffView.setDiffText(diff);
        }
    }

    private void clearViews() {
        currentView.clear();
        diffView.clear();
        fileInfoLabel.setText("Selecione um arquivo para visualizar");
        fileInfoLabel.setTextFill(Color.web("#5e6a7a"));
    }

    private String getTypeIcon(GitFileChange.Type type) {
        return switch (type) {
            case ADDED -> "+";
            case MODIFIED -> "~";
            case DELETED -> "-";
            case RENAMED -> "→";
            case CONFLICTING -> "!";
            case UNTRACKED -> "?";
        };
    }

    private static class ChangeCell extends ListCell<GitFileChange> {
        private final CheckBox checkBox = new CheckBox();
        private final Label nameLabel = new Label();
        private final Label badge = new Label();
        private final HBox graphic;

        ChangeCell() {
            nameLabel.setStyle("-fx-font-family: 'JetBrains Mono', monospace; -fx-font-size: 12.5px;");
            badge.setStyle("-fx-padding: 3 10; -fx-background-radius: 10; -fx-font-size: 10.5px; -fx-font-weight: bold;");
            HBox right = new HBox(10, badge, checkBox);
            right.setAlignment(Pos.CENTER_RIGHT);
            graphic = new HBox(12, nameLabel, UiComponents.spacer(), right);
            graphic.setAlignment(Pos.CENTER_LEFT);
            graphic.setPadding(new Insets(8, 12, 8, 12));
            graphic.getStyleClass().add("gm-project-card");

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

            String color = item.getType().getColor();
            badge.setText(item.getType().getLabel());
            badge.setStyle("-fx-background-color: " + color + "20; -fx-text-fill: " + color + "; " +
                           "-fx-padding: 3 10; -fx-background-radius: 10; -fx-font-size: 10.5px; -fx-font-weight: bold;");

            if (item.getType() == GitFileChange.Type.DELETED || item.getType() == GitFileChange.Type.CONFLICTING) {
                nameLabel.setStyle("-fx-font-family: 'JetBrains Mono', monospace; -fx-font-size: 12.5px; -fx-text-fill: " + color + ";");
            } else {
                nameLabel.setStyle("-fx-font-family: 'JetBrains Mono', monospace; -fx-font-size: 12.5px;");
            }

            // Selected state
            if (isSelected()) {
                graphic.getStyleClass().remove("gm-project-card");
                graphic.getStyleClass().add("gm-project-card-selected");
            } else {
                graphic.getStyleClass().remove("gm-project-card-selected");
                graphic.getStyleClass().add("gm-project-card");
            }

            setGraphic(graphic);
        }
    }
}
