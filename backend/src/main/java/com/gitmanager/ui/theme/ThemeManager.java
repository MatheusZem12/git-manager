package com.gitmanager.ui.theme;

import javafx.scene.Scene;
import javafx.scene.control.Dialog;
import javafx.scene.layout.Region;

import java.util.ArrayList;
import java.util.List;

/**
 * Gerenciador de temas da aplicação.
 * Tema escuro fixo.
 */
public class ThemeManager {

    private static final List<Scene> trackedScenes = new ArrayList<>();

    private ThemeManager() {}

    public static boolean isDark() {
        return true;
    }

    public static void registerScene(Scene scene) {
        if (!trackedScenes.contains(scene)) {
            trackedScenes.add(scene);
        }
        apply(scene);
    }

    public static void apply(Scene scene) {
        if (scene == null) return;
        scene.getStylesheets().clear();
        String css = ThemeManager.class.getResource("/styles/dark.css").toExternalForm();
        scene.getStylesheets().add(css + "?t=" + System.currentTimeMillis());
        Region root = (Region) scene.getRoot();
        if (root != null) {
            root.getStyleClass().removeAll("theme-light", "theme-dark");
            root.getStyleClass().add("theme-dark");
            root.applyCss();
            root.layout();
        }
    }

    public static void applyToDialog(Dialog<?> dialog) {
        if (dialog == null) return;
        dialog.getDialogPane().getScene().getStylesheets().clear();
        String css = ThemeManager.class.getResource("/styles/dark.css").toExternalForm();
        dialog.getDialogPane().getScene().getStylesheets().add(css + "?t=" + System.currentTimeMillis());
        dialog.getDialogPane().getStyleClass().removeAll("theme-light", "theme-dark");
        dialog.getDialogPane().getStyleClass().add("theme-dark");
        dialog.getDialogPane().applyCss();
        dialog.getDialogPane().layout();
    }
}
