package com.gitmanager.service;

import com.gitmanager.dao.GitProjectDao;
import com.gitmanager.model.GitProject;
import com.gitmanager.model.User;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

public class ProjectService {

    private static final Logger log = LoggerFactory.getLogger(ProjectService.class);

    private final GitProjectDao projectDao;
    private final GitService gitService;

    public ProjectService() {
        this.projectDao = new GitProjectDao();
        this.gitService = new GitService();
    }

    /**
     * Retorna todos os projetos do usuário, filtrando e validando para o PC atual.
     * Apenas projetos cujo diretório existe E possui .git são retornados como disponíveis.
     */
    public List<GitProject> loadProjectsForCurrentMachine(User user) {
        List<GitProject> all = projectDao.findAllByUserId(user.getId());
        all.forEach(p -> gitService.validateProject(p));
        log.info("Usuário '{}' — {} projeto(s) cadastrado(s), {} disponível(is) neste PC.",
                user.getUsername(), all.size(),
                all.stream().filter(GitProject::isAvailable).count());
        return all;
    }

    /**
     * Adiciona um novo projeto ao usuário, realizando validações antes.
     */
    public GitProject addProject(User user, String name, String path, String notes) {
        if (name == null || name.isBlank()) throw new IllegalArgumentException("Nome do projeto é obrigatório.");
        if (path == null || path.isBlank()) throw new IllegalArgumentException("Caminho do diretório é obrigatório.");

        if (!gitService.isValidGitRepo(path)) {
            throw new IllegalArgumentException("O diretório selecionado não contém um repositório Git válido (.git).");
        }
        if (projectDao.existsByUserIdAndPath(user.getId(), path)) {
            throw new IllegalArgumentException("Este diretório já está cadastrado para sua conta.");
        }

        String remoteUrl = gitService.getRemoteOriginUrl(path);

        GitProject project = new GitProject(user.getId(), name.trim(), path);
        project.setRemoteUrl(remoteUrl);
        project.setNotes(notes);

        Optional<GitProject> saved = projectDao.save(project);
        if (saved.isEmpty()) throw new RuntimeException("Falha ao salvar o projeto no banco de dados.");

        GitProject result = saved.get();
        gitService.validateProject(result);
        return result;
    }

    /**
     * Atualiza nome, path, notas de um projeto.
     */
    public GitProject updateProject(GitProject project) {
        if (!projectDao.update(project)) {
            throw new RuntimeException("Falha ao atualizar o projeto no banco de dados.");
        }
        gitService.validateProject(project);
        return project;
    }

    /**
     * Remove um projeto do usuário.
     */
    public void deleteProject(Long projectId) {
        if (!projectDao.delete(projectId)) {
            throw new RuntimeException("Falha ao remover o projeto.");
        }
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
