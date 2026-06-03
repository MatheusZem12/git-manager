package com.gitmanager.ui.components;

import javafx.geometry.Insets;
import javafx.geometry.Pos;
import javafx.scene.control.Button;
import javafx.scene.control.Label;
import javafx.scene.control.TextField;
import javafx.scene.control.Tooltip;
import javafx.scene.layout.HBox;
import javafx.scene.layout.Priority;
import javafx.scene.layout.Region;
import javafx.scene.layout.VBox;
import javafx.scene.paint.Color;
import javafx.scene.shape.Circle;

/**
 * Biblioteca centralizada de componentes UI reutilizáveis.
 * Factory methods para botões, badges, cards, ícones e layouts comuns.
 */
public final class UiComponents {

    private UiComponents() {}

    // ========== SPACER ==========

    public static Region spacer() {
        Region r = new Region();
        HBox.setHgrow(r, Priority.ALWAYS);
        return r;
    }

    public static Region vSpacer() {
        Region r = new Region();
        VBox.setVgrow(r, Priority.ALWAYS);
        return r;
    }

    // ========== ICONES ==========

    public static Label icon(String unicode, String styleClass) {
        Label lbl = new Label(unicode);
        if (styleClass != null) {
            lbl.getStyleClass().add(styleClass);
        }
        return lbl;
    }

    public static Label largeIcon(String unicode) {
        return icon(unicode, "gm-empty-state-icon");
    }

    // ========== BOTOES ==========

    public static Button iconButton(String icon, String tooltipText, String styleClass, Runnable action) {
        Button btn = new Button(icon);
        btn.getStyleClass().add(styleClass != null ? styleClass : "gm-btn-icon");
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

    public static Button dangerButton(String text, Runnable action) {
        Button btn = new Button(text);
        btn.getStyleClass().add("gm-btn-danger");
        if (action != null) {
            btn.setOnAction(e -> action.run());
        }
        return btn;
    }

    public static Button warnButton(String text, Runnable action) {
        Button btn = new Button(text);
        btn.getStyleClass().add("gm-btn-warn");
        if (action != null) {
            btn.setOnAction(e -> action.run());
        }
        return btn;
    }

    public static Button neutralButton(String text, Runnable action) {
        Button btn = new Button(text);
        btn.getStyleClass().add("gm-btn-neutral");
        if (action != null) {
            btn.setOnAction(e -> action.run());
        }
        return btn;
    }

    public static Button ghostButton(String text, Runnable action) {
        Button btn = new Button(text);
        btn.getStyleClass().add("gm-btn-ghost");
        if (action != null) {
            btn.setOnAction(e -> action.run());
        }
        return btn;
    }

    public static Button modernButton(String icon, String text, String styleClass, Runnable action) {
        Button btn = new Button(icon + "  " + text);
        btn.getStyleClass().add(styleClass);
        if (action != null) {
            btn.setOnAction(e -> action.run());
        }
        return btn;
    }

    // ========== BADGES ==========

    public static Label badge(String text, String styleClass) {
        Label lbl = new Label(text);
        lbl.getStyleClass().add(styleClass);
        return lbl;
    }

    public static Label badgeOk(String text) {
        return badge(text, "gm-badge-ok");
    }

    public static Label badgeWarn(String text) {
        return badge(text, "gm-badge-warn");
    }

    public static Label badgeError(String text) {
        return badge(text, "gm-badge-error");
    }

    public static Label badgeInfo(String text) {
        return badge(text, "gm-badge-info");
    }

    public static Label badgeNeutral(String text) {
        return badge(text, "gm-badge-neutral");
    }

    // ========== STATUS DOTS ==========

    public static Circle statusDot(double radius, String styleClass) {
        Circle dot = new Circle(radius);
        dot.getStyleClass().add(styleClass);
        return dot;
    }

    public static Circle dotSuccess(double radius) {
        return statusDot(radius, "gm-dot-success");
    }

    public static Circle dotWarning(double radius) {
        return statusDot(radius, "gm-dot-warning");
    }

    public static Circle dotDanger(double radius) {
        return statusDot(radius, "gm-dot-danger");
    }

    public static Circle dotNeutral(double radius) {
        return statusDot(radius, "gm-dot");
    }

    // ========== CARDS ==========

    public static VBox card() {
        VBox card = new VBox();
        card.getStyleClass().add("gm-card");
        card.setSpacing(10);
        return card;
    }

    public static VBox elevatedCard() {
        VBox card = new VBox();
        card.getStyleClass().add("gm-card-elevated");
        card.setSpacing(10);
        return card;
    }

    // ========== EMPTY STATES ==========

    public static VBox emptyState(String iconUnicode, String title, String subtitle) {
        Label iconLabel = largeIcon(iconUnicode);
        
        Label titleLabel = new Label(title);
        titleLabel.getStyleClass().add("gm-empty-state-title");
        
        Label subtitleLabel = new Label(subtitle);
        subtitleLabel.getStyleClass().add("gm-empty-state-subtitle");
        subtitleLabel.setWrapText(true);
        subtitleLabel.setAlignment(Pos.CENTER);
        subtitleLabel.setMaxWidth(300);
        subtitleLabel.setTextAlignment(javafx.scene.text.TextAlignment.CENTER);

        VBox box = new VBox(16, iconLabel, titleLabel, subtitleLabel);
        box.setAlignment(Pos.CENTER);
        box.setPadding(new Insets(48));
        return box;
    }

    // ========== SECTION HEADERS ==========

    public static HBox sectionHeader(String iconUnicode, String title) {
        Label iconLabel = icon(iconUnicode, "gm-section-icon");
        Label titleLabel = new Label(title);
        titleLabel.getStyleClass().add("gm-section-header");
        HBox hbox = new HBox(10, iconLabel, titleLabel);
        hbox.setAlignment(Pos.CENTER_LEFT);
        return hbox;
    }

    // ========== SEARCH FIELD ==========

    public static TextField searchField(String prompt) {
        TextField field = new TextField();
        field.setPromptText(prompt);
        field.getStyleClass().add("gm-search-field");
        field.setPrefWidth(240);
        return field;
    }

    // ========== STATS ==========

    public static VBox stat(String value, String label, String styleClass) {
        Label valueLabel = new Label(value);
        valueLabel.getStyleClass().add(styleClass);
        Label labelLbl = new Label(label);
        labelLbl.getStyleClass().add("gm-stat-label");
        VBox box = new VBox(6, valueLabel, labelLbl);
        box.setAlignment(Pos.CENTER);
        return box;
    }

    // ========== LABELS UTILITARIOS ==========

    public static Label subtitle(String text) {
        Label lbl = new Label(text);
        lbl.getStyleClass().add("gm-subtitle-label");
        return lbl;
    }

    public static Label hint(String text) {
        Label lbl = new Label(text);
        lbl.getStyleClass().add("gm-hint-label");
        lbl.setWrapText(true);
        return lbl;
    }

    public static Label error(String text) {
        Label lbl = new Label(text);
        lbl.getStyleClass().add("gm-error-label");
        lbl.setWrapText(true);
        return lbl;
    }

    // ========== ICONES UNICODE COMUNS ==========
    public static final String ICON_GIT = "\uE0A0";
    public static final String ICON_FOLDER = "\uD83D\uDCC1";
    public static final String ICON_SEARCH = "\uD83D\uDD0D";
    public static final String ICON_ADD = "+";
    public static final String ICON_REFRESH = "\u21BB";

    public static final String ICON_BRANCH = "\uD83D\uDD18";
    public static final String ICON_COMMIT = "\u25CF";
    public static final String ICON_PUSH = "\u2191";
    public static final String ICON_PULL = "\u2193";
    public static final String ICON_FETCH = "\uD83D\uDD04";
    public static final String ICON_TAG = "\uD83C\uDFF7";
    public static final String ICON_STASH = "\uD83D\uDCBC";
    public static final String ICON_CHECK = "\u2713";
    public static final String ICON_WARN = "\u26A0";
    public static final String ICON_ERROR = "\u2715";
    public static final String ICON_INFO = "\u2139";
    public static final String ICON_EDIT = "\u270E";
    public static final String ICON_DELETE = "\uD83D\uDDD1";
    public static final String ICON_SETTINGS = "\u2699";
    public static final String ICON_BACK = "\u2190";
    public static final String ICON_FILE = "\uD83D\uDCC4";
    public static final String ICON_FOLDER_OPEN = "\uD83D\uDCC2";
    public static final String ICON_CHANGES = "\uD83D\uDCDD";
    public static final String ICON_EMPTY = "\uD83D\uDED1";
    public static final String ICON_REPO = "\uD83D\uDCC3";
}
