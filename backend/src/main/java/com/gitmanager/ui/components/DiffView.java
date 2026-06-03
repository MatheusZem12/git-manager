package com.gitmanager.ui.components;

import javafx.collections.FXCollections;
import javafx.collections.ObservableList;
import javafx.scene.control.ListCell;
import javafx.scene.control.ListView;
import javafx.scene.control.MultipleSelectionModel;
import javafx.scene.layout.HBox;
import javafx.scene.layout.Priority;
import javafx.scene.layout.VBox;
import javafx.scene.paint.Color;
import javafx.scene.text.Font;
import javafx.scene.text.FontWeight;
import javafx.scene.text.Text;

/**
 * Visualizador de diff com numeração de linha e syntax highlighting básico.
 * Layout premium com fonte monospace e cores refinadas.
 */
public class DiffView extends VBox {

    private final ListView<DiffLine> listView;

    public DiffView() {
        listView = new ListView<>();
        listView.setCellFactory(lv -> new DiffListCell());
        listView.getStyleClass().add("diff-view");
        listView.setStyle("-fx-font-family: 'JetBrains Mono', monospace; -fx-font-size: 12.5px;");
        listView.setSelectionModel(new NoSelectionModel<>());
        VBox.setVgrow(listView, Priority.ALWAYS);
        getChildren().add(listView);
    }

    public void setDiffText(String diff) {
        if (diff == null) {
            listView.getItems().clear();
            return;
        }
        String[] lines = diff.split("\n", -1);
        ObservableList<DiffLine> diffLines = FXCollections.observableArrayList();
        int lineNum = 1;
        for (String line : lines) {
            diffLines.add(new DiffLine(lineNum++, line));
        }
        listView.getItems().setAll(diffLines);
    }

    public void clear() {
        listView.getItems().clear();
    }

    private static class DiffLine {
        final int number;
        final String text;
        DiffLine(int number, String text) {
            this.number = number;
            this.text = text;
        }
    }

    private static class DiffListCell extends ListCell<DiffLine> {
        @Override
        protected void updateItem(DiffLine line, boolean empty) {
            super.updateItem(line, empty);
            if (empty || line == null) {
                setText(null);
                setGraphic(null);
                getStyleClass().removeAll("gm-diff-added", "gm-diff-removed", "gm-diff-header");
                return;
            }
            
            getStyleClass().removeAll("gm-diff-added", "gm-diff-removed", "gm-diff-header");
            
            String text = line.text;
            if (text.startsWith("+")) {
                getStyleClass().add("gm-diff-added");
            } else if (text.startsWith("-")) {
                getStyleClass().add("gm-diff-removed");
            } else if (text.startsWith("@@")) {
                getStyleClass().add("gm-diff-header");
            }
            
            // Número de linha
            Text numText = new Text(String.format("%4d  ", line.number));
            numText.setFont(Font.font("JetBrains Mono", FontWeight.NORMAL, 11.5));
            numText.setFill(Color.web("#5e6a7a", 0.6));
            
            // Conteúdo da linha
            Text contentText = new Text(text);
            contentText.setFont(Font.font("JetBrains Mono", FontWeight.NORMAL, 12.5));
            contentText.setFill(Color.web("#eceff4"));
            
            HBox row = new HBox(numText, contentText);
            row.setAlignment(javafx.geometry.Pos.CENTER_LEFT);
            setGraphic(row);
            setText(null);
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
