package com.gitmanager.service;

import com.gitmanager.model.GitProject;
import com.gitmanager.repository.GitProjectFileRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.List;

public class ProjectService {

    private static final Logger log = LoggerFactory.getLogger(ProjectService.class);

    private final GitProjectFileRepository repository;
    private final GitService gitService;

    public ProjectService() {
        this.repository = new GitProjectFileRepository();
        this.gitService = new GitService();
    }

    /**
     * Retorna todos os projetos cadastrados, validando contra o PC atual.
     */
    public List<GitProject> loadAllProjects() {
        List<GitProject> all = repository.loadAll();
        all.forEach(gitService::validateProject);
        log.info("{} projeto(s) carregado(s), {} disponível(is) neste PC.",
                all.size(),
                all.stream().filter(GitProject::isAvailable).count());
        return all;
    }

    /**
     * Adiciona um novo projeto, realizando validações antes.
     */
    public GitProject addProject(String name, String path, String notes) {
        if (name == null || name.isBlank()) throw new IllegalArgumentException("Nome do projeto é obrigatório.");
        if (path == null || path.isBlank()) throw new IllegalArgumentException("Caminho do diretório é obrigatório.");

        if (!gitService.isValidGitRepo(path)) {
            throw new IllegalArgumentException("O diretório selecionado não contém um repositório Git válido (.git).");
        }

        List<GitProject> all = repository.loadAll();
        boolean exists = all.stream().anyMatch(p -> p.getPath().equals(path.trim()));
        if (exists) {
            throw new IllegalArgumentException("Este diretório já está cadastrado.");
        }

        GitProject project = new GitProject();
        project.setName(name.trim());
        project.setPath(path.trim());
        project.setNotes(notes);
        all.add(project);
        repository.saveAll(all);
        gitService.validateProject(project);
        return project;
    }

    /**
     * Atualiza nome, path e notas de um projeto.
     */
    public GitProject updateProject(GitProject project) {
        List<GitProject> all = repository.loadAll();
        boolean found = false;
        for (int i = 0; i < all.size(); i++) {
            // Identifica pelo path original (campo chave)
            if (all.get(i).getPath().equals(project.getPath())) {
                all.set(i, project);
                found = true;
                break;
            }
        }
        if (!found) {
            throw new RuntimeException("Projeto não encontrado.");
        }
        repository.saveAll(all);
        gitService.validateProject(project);
        return project;
    }

    /**
     * Remove um projeto pelo path.
     */
    public void deleteProject(String path) {
        List<GitProject> all = repository.loadAll();
        all.removeIf(p -> p.getPath().equals(path));
        repository.saveAll(all);
    }

    /**
     * Revalida um projeto específico contra o filesystem atual.
     */
    public void revalidate(GitProject project) {
        gitService.validateProject(project);
    }

    public GitService getGitService() {
        return gitService;
    }
}
