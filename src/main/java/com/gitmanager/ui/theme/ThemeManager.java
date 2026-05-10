package com.gitmanager.ui.theme;

import javafx.scene.Scene;
import javafx.scene.control.Dialog;
import javafx.scene.layout.Region;

import java.util.ArrayList;
import java.util.List;
import java.util.prefs.Preferences;

public class ThemeManager {

    public enum Theme { LIGHT, DARK }

    private static final Preferences PREFS = Preferences.userNodeForPackage(ThemeManager.class);
    private static final String KEY_THEME = "theme";

    private static Theme current = Theme.LIGHT;
    private static final List<Scene> trackedScenes = new ArrayList<>();

    static {
        String saved = PREFS.get(KEY_THEME, Theme.LIGHT.name());
        try {
            current = Theme.valueOf(saved);
        } catch (Exception e) {
            current = Theme.LIGHT;
        }
    }

    public static Theme getCurrent() {
        return current;
    }

    public static boolean isDark() {
        return current == Theme.DARK;
    }

    public static void toggle() {
        setTheme(current == Theme.LIGHT ? Theme.DARK : Theme.LIGHT);
    }

    public static void setTheme(Theme theme) {
        if (theme == current) return;
        current = theme;
        PREFS.put(KEY_THEME, current.name());
        applyToAll();
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
        String css = ThemeManager.class.getResource("/styles/" + current.name().toLowerCase() + ".css").toExternalForm();
        scene.getStylesheets().add(css);
        Region root = (Region) scene.getRoot();
        if (root != null) {
            root.getStyleClass().removeAll("theme-light", "theme-dark");
            root.getStyleClass().add(current == Theme.DARK ? "theme-dark" : "theme-light");
        }
    }

    public static void applyToDialog(Dialog<?> dialog) {
        if (dialog == null) return;
        dialog.getDialogPane().getScene().getStylesheets().clear();
        String css = ThemeManager.class.getResource("/styles/" + current.name().toLowerCase() + ".css").toExternalForm();
        dialog.getDialogPane().getScene().getStylesheets().add(css);
        dialog.getDialogPane().getStyleClass().removeAll("theme-light", "theme-dark");
        dialog.getDialogPane().getStyleClass().add(current == Theme.DARK ? "theme-dark" : "theme-light");
    }

    private static void applyToAll() {
        trackedScenes.removeIf(s -> s.getRoot() == null);
        for (Scene scene : trackedScenes) {
            apply(scene);
        }
    }
}
