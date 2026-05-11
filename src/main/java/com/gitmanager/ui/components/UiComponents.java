package com.gitmanager.ui.components;

import javafx.scene.control.Button;
import javafx.scene.control.Tooltip;

public final class UiComponents {

    private UiComponents() {}

    public static Button iconButton(String icon, String tooltipText, String styleClass, Runnable action) {
        Button btn = new Button(icon);
        btn.getStyleClass().add(styleClass);
        btn.setStyle("-fx-font-size: 14px;");
        if (tooltipText != null && !tooltipText.isEmpty()) {
            btn.setTooltip(new Tooltip(tooltipText));
        }
        if (action != null) {
            btn.setOnAction(e -> action.run());
        }
        return btn;
    }

    public static Button primaryButton(String text, Runnable action) {
        Button btn = new Button(text);
        btn.getStyleClass().add("gm-btn-primary");
        if (action != null) {
            btn.setOnAction(e -> action.run());
        }
        return btn;
    }

    public static Button successButton(String text, Runnable action) {
        Button btn = new Button(text);
        btn.getStyleClass().add("gm-btn-success");
        if (action != null) {
            btn.setOnAction(e -> action.run());
        }
        return btn;
    }
}
