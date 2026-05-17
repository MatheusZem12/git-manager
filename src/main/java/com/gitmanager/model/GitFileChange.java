package com.gitmanager.model;

public class GitFileChange {

    public enum Type {
        ADDED("Novo", "#2ea043"),
        MODIFIED("Modificado", "#d7ba7d"),
        DELETED("Deletado", "#f85149"),
        RENOMEADO("Renomeado", "#79c0ff"),
        CONFLICTING("Conflito", "#f85149"),
        UNTRACKED("Não rastreado", "#a0a0a0");

        private final String label;
        private final String color;

        Type(String label, String color) {
            this.label = label;
            this.color = color;
        }

        public String getLabel() { return label; }
        public String getColor() { return color; }
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
