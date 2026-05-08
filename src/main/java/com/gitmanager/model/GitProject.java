package com.gitmanager.model;

public class GitProject {

    private String name;
    private String path;
    private String notes;

    // Transientes - calculados em tempo de execução
    private transient boolean existsOnDisk;
    private transient boolean hasGit;
    private transient String currentBranch;
    private transient String statusSummary;

    public GitProject() {}

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getPath() { return path; }
    public void setPath(String path) { this.path = path; }

    public String getNotes() { return notes; }
    public void setNotes(String notes) { this.notes = notes; }

    public boolean isExistsOnDisk() { return existsOnDisk; }
    public void setExistsOnDisk(boolean existsOnDisk) { this.existsOnDisk = existsOnDisk; }

    public boolean isHasGit() { return hasGit; }
    public void setHasGit(boolean hasGit) { this.hasGit = hasGit; }

    public String getCurrentBranch() { return currentBranch; }
    public void setCurrentBranch(String currentBranch) { this.currentBranch = currentBranch; }

    public String getStatusSummary() { return statusSummary; }
    public void setStatusSummary(String statusSummary) { this.statusSummary = statusSummary; }

    /** Retorna true se o projeto é utilizável neste PC */
    public boolean isAvailable() {
        return existsOnDisk && hasGit;
    }

    @Override
    public String toString() {
        return "GitProject{name='" + name + "', path='" + path + "'}";
    }
}
