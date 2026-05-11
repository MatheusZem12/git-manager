package com.gitmanager.ui.components;

import javafx.collections.FXCollections;
import javafx.collections.ObservableList;
import javafx.scene.control.ListCell;
import javafx.scene.control.ListView;
import javafx.scene.control.MultipleSelectionModel;
import javafx.scene.layout.Priority;
import javafx.scene.layout.VBox;

public class DiffView extends VBox {

    private final ListView<String> listView;

    public DiffView() {
        listView = new ListView<>();
        listView.setCellFactory(lv -> new DiffListCell());
        listView.getStyleClass().add("diff-view");
        listView.setStyle("-fx-font-family: monospace; -fx-font-size: 12px;");
        listView.setSelectionModel(new NoSelectionModel<>());
        VBox.setVgrow(listView, Priority.ALWAYS);
        getChildren().add(listView);
    }

    public void setDiffText(String diff) {
        if (diff == null) {
            listView.getItems().clear();
            return;
        }
        listView.getItems().setAll(diff.split("\n", -1));
    }

    public void clear() {
        listView.getItems().clear();
    }

    private static class DiffListCell extends ListCell<String> {
        @Override
        protected void updateItem(String line, boolean empty) {
            super.updateItem(line, empty);
            if (empty || line == null) {
                setText(null);
                setGraphic(null);
                getStyleClass().removeAll("gm-diff-added", "gm-diff-removed", "gm-diff-header");
                return;
            }
            setText(line);
            setGraphic(null);
            getStyleClass().removeAll("gm-diff-added", "gm-diff-removed", "gm-diff-header");
            if (line.startsWith("+")) {
                getStyleClass().add("gm-diff-added");
            } else if (line.startsWith("-")) {
                getStyleClass().add("gm-diff-removed");
            } else if (line.startsWith("@@")) {
                getStyleClass().add("gm-diff-header");
            }
        }
    }

    private static class NoSelectionModel<T> extends MultipleSelectionModel<T> {
        @Override public ObservableList<Integer> getSelectedIndices() { return FXCollections.emptyObservableList(); }
        @Override public ObservableList<T> getSelectedItems() { return FXCollections.emptyObservableList(); }
        @Override public void selectIndices(int index, int... indices) {}
        @Override public void selectAll() {}
        @Override public void selectFirst() {}
        @Override public void selectLast() {}
        @Override public void clearAndSelect(int index) {}
        @Override public void select(int index) {}
        @Override public void select(T obj) {}
        @Override public void clearSelection(int index) {}
        @Override public void clearSelection() {}
        @Override public boolean isSelected(int index) { return false; }
        @Override public boolean isEmpty() { return true; }
        @Override public void selectPrevious() {}
        @Override public void selectNext() {}
    }
}
