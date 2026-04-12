package com.gitmanager.model;

import java.time.LocalDateTime;

public class GitProject {

    private Long id;
    private Long userId;
    private String name;        // Nome/alias do usuário para o projeto
    private String path;        // Caminho absoluto no filesystem
    private String remoteUrl;   // URL do repositório remoto (pode ser nulo)
    private String notes;       // Observações livres do usuário
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    // Campos transientes (não persistidos) - calculados em tempo de execução
    private transient boolean existsOnDisk;         // O diretório existe neste PC?
    private transient boolean hasGit;               // Tem .git válido?
    private transient boolean remoteUrlMatches;     // URL remota bate com o BD?
    private transient String currentBranch;         // Branch atual
    private transient String statusSummary;         // Resumo de status (atrás/na frente/sujo)

    public GitProject() {}

    public GitProject(Long userId, String name, String path) {
        this.userId = userId;
        this.name = name;
        this.path = path;
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public Long getUserId() { return userId; }
    public void setUserId(Long userId) { this.userId = userId; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getPath() { return path; }
    public void setPath(String path) { this.path = path; }

    public String getRemoteUrl() { return remoteUrl; }
    public void setRemoteUrl(String remoteUrl) { this.remoteUrl = remoteUrl; }

    public String getNotes() { return notes; }
    public void setNotes(String notes) { this.notes = notes; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }

    public LocalDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(LocalDateTime updatedAt) { this.updatedAt = updatedAt; }

    public boolean isExistsOnDisk() { return existsOnDisk; }
    public void setExistsOnDisk(boolean existsOnDisk) { this.existsOnDisk = existsOnDisk; }

    public boolean isHasGit() { return hasGit; }
    public void setHasGit(boolean hasGit) { this.hasGit = hasGit; }

    public boolean isRemoteUrlMatches() { return remoteUrlMatches; }
    public void setRemoteUrlMatches(boolean remoteUrlMatches) { this.remoteUrlMatches = remoteUrlMatches; }

    public String getCurrentBranch() { return currentBranch; }
    public void setCurrentBranch(String currentBranch) { this.currentBranch = currentBranch; }

    public String getStatusSummary() { return statusSummary; }
    public void setStatusSummary(String statusSummary) { this.statusSummary = statusSummary; }

    /** Retorna true se o projeto é utilizável neste PC (existe, tem git e remote coerente) */
    public boolean isAvailable() {
        return existsOnDisk && hasGit;
    }

    @Override
    public String toString() {
        return "GitProject{id=" + id + ", name='" + name + "', path='" + path + "'}";
    }
}
