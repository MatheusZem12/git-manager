package com.gitmanager.model;

public class GitFileChange {

    public enum Type {
        ADDED("Novo", "#27ae60", "#2ea043"),
        MODIFIED("Modificado", "#e67e22", "#d7ba7d"),
        DELETED("Deletado", "#e74c3c", "#f85149"),
        RENAMED("Renomeado", "#2980b9", "#79c0ff"),
        CONFLICTING("Conflito", "#c0392b", "#f85149"),
        UNTRACKED("Não rastreado", "#7f8c8d", "#a0a0a0");

        private final String label;
        private final String colorLight;
        private final String colorDark;

        Type(String label, String colorLight, String colorDark) {
            this.label = label;
            this.colorLight = colorLight;
            this.colorDark = colorDark;
        }

        public String getLabel() { return label; }
        public String getColor(boolean dark) { return dark ? colorDark : colorLight; }
    }

    private final String path;
    private final String oldPath;
    private final Type type;
    private boolean staged;

    public GitFileChange(String path, Type type, boolean staged) {
        this(path, null, type, staged);
    }

    public GitFileChange(String path, String oldPath, Type type, boolean staged) {
        this.path = path;
        this.oldPath = oldPath;
        this.type = type;
        this.staged = staged;
    }

    public String getPath() { return path; }
    public String getOldPath() { return oldPath; }
    public Type getType() { return type; }
    public boolean isStaged() { return staged; }
    public void setStaged(boolean staged) { this.staged = staged; }

    @Override
    public String toString() {
        return path + " [" + type.getLabel() + "]";
    }
}
