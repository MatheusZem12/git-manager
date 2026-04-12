package com.gitmanager.service;

import com.gitmanager.model.GitProject;
import org.eclipse.jgit.api.*;
import org.eclipse.jgit.api.errors.GitAPIException;
import org.eclipse.jgit.lib.*;
import org.eclipse.jgit.revwalk.RevCommit;
import org.eclipse.jgit.storage.file.FileRepositoryBuilder;
import org.eclipse.jgit.transport.FetchResult;
import org.eclipse.jgit.transport.PushResult;
import org.eclipse.jgit.transport.UsernamePasswordCredentialsProvider;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.File;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

public class GitService {

    private static final Logger log = LoggerFactory.getLogger(GitService.class);

    /**
     * Verifica se o diretório é um repositório git válido.
     */
    public boolean isValidGitRepo(String path) {
        if (path == null || path.isBlank()) return false;
        Path dir = Path.of(path);
        if (!Files.isDirectory(dir)) return false;
        File gitDir = dir.resolve(".git").toFile();
        if (!gitDir.exists()) return false;
        try {
            Repository repo = new FileRepositoryBuilder()
                    .setGitDir(gitDir)
                    .readEnvironment()
                    .build();
            return repo.getObjectDatabase().exists();
        } catch (Exception e) {
            log.debug("Diretório '{}' não é um git válido: {}", path, e.getMessage());
            return false;
        }
    }

    /**
     * Obtém a URL do remote 'origin' do repositório.
     * @return URL ou null se não existir remote.
     */
    public String getRemoteOriginUrl(String path) {
        try (Repository repo = openRepo(path)) {
            if (repo == null) return null;
            StoredConfig config = repo.getConfig();
            return config.getString("remote", "origin", "url");
        } catch (Exception e) {
            log.debug("Erro ao obter remote do repo '{}': {}", path, e.getMessage());
            return null;
        }
    }

    /**
     * Obtém a branch atual do repositório.
     */
    public String getCurrentBranch(String path) {
        try (Repository repo = openRepo(path)) {
            if (repo == null) return "N/A";
            String branch = repo.getBranch();
            return branch != null ? branch : "HEAD detachada";
        } catch (Exception e) {
            log.debug("Erro ao obter branch do repo '{}': {}", path, e.getMessage());
            return "Erro";
        }
    }

    /**
     * Retorna um resumo do status do repositório (arquivos modificados/staged/untracked).
     */
    public String getStatusSummary(String path) {
        try (Git git = openGit(path)) {
            if (git == null) return "Inacessível";
            Status status = git.status().call();
            List<String> parts = new ArrayList<>();
            int modified = status.getModified().size() + status.getMissing().size()
                         + status.getUntracked().size() + status.getAdded().size()
                         + status.getChanged().size() + status.getRemoved().size()
                         + status.getConflicting().size();
            if (modified > 0) parts.add(modified + " alteração(ões)");
            if (status.isClean()) parts.add("Limpo");
            return parts.isEmpty() ? "Limpo" : String.join(", ", parts);
        } catch (Exception e) {
            log.debug("Erro ao obter status do repo '{}': {}", path, e.getMessage());
            return "Erro";
        }
    }

    /**
     * Lista os commits recentes do repositório.
     */
    public List<String> getRecentCommits(String path, int limit) {
        List<String> commits = new ArrayList<>();
        try (Git git = openGit(path)) {
            if (git == null) return commits;
            Iterable<RevCommit> logs = git.log().setMaxCount(limit).call();
            for (RevCommit commit : logs) {
                commits.add(commit.abbreviate(7).name() +
                        " - " + commit.getShortMessage() +
                        " [" + commit.getAuthorIdent().getName() + "]");
            }
        } catch (Exception e) {
            log.debug("Erro ao obter commits de '{}': {}", path, e.getMessage());
        }
        return commits;
    }

    /**
     * Lista as branches locais do repositório.
     */
    public List<String> listLocalBranches(String path) {
        List<String> branches = new ArrayList<>();
        try (Git git = openGit(path)) {
            if (git == null) return branches;
            List<Ref> refs = git.branchList().call();
            for (Ref ref : refs) {
                branches.add(Repository.shortenRefName(ref.getName()));
            }
        } catch (Exception e) {
            log.debug("Erro ao listar branches de '{}': {}", path, e.getMessage());
        }
        return branches;
    }

    /**
     * Lista as branches remotas do repositório.
     */
    public List<String> listRemoteBranches(String path) {
        List<String> branches = new ArrayList<>();
        try (Git git = openGit(path)) {
            if (git == null) return branches;
            List<Ref> refs = git.branchList().setListMode(ListBranchCommand.ListMode.REMOTE).call();
            for (Ref ref : refs) {
                branches.add(Repository.shortenRefName(ref.getName()));
            }
        } catch (Exception e) {
            log.debug("Erro ao listar branches remotas de '{}': {}", path, e.getMessage());
        }
        return branches;
    }

    /**
     * Executa git add + commit.
     * @param message Mensagem do commit.
     * @param addAll  Se true, faz 'git add -A' antes.
     */
    public String commit(String path, String message, boolean addAll,
                         String authorName, String authorEmail) {
        try (Git git = openGit(path)) {
            if (git == null) return "Repositório inacessível.";
            if (addAll) {
                git.add().addFilepattern(".").call();
            }
            RevCommit commit = git.commit()
                    .setMessage(message)
                    .setAuthor(authorName, authorEmail)
                    .setAllowEmpty(false)
                    .call();
            return "Commit realizado: " + commit.abbreviate(7).name() + " - " + commit.getShortMessage();
        } catch (GitAPIException e) {
            log.error("Erro no commit de '{}': {}", path, e.getMessage());
            return "Erro no commit: " + e.getMessage();
        }
    }

    /**
     * Executa git push (origin, branch atual).
     */
    public String push(String path, String username, String password) {
        try (Git git = openGit(path)) {
            if (git == null) return "Repositório inacessível.";
            PushCommand push = git.push();
            if (username != null && !username.isBlank()) {
                push.setCredentialsProvider(new UsernamePasswordCredentialsProvider(username, password));
            }
            Iterable<PushResult> results = push.call();
            StringBuilder sb = new StringBuilder();
            for (PushResult result : results) {
                sb.append(result.getMessages());
                result.getRemoteUpdates().forEach(u -> sb.append(u.getStatus()).append(" "));
            }
            String msg = sb.toString().trim();
            return msg.isEmpty() ? "Push realizado com sucesso." : msg;
        } catch (GitAPIException e) {
            log.error("Erro no push de '{}': {}", path, e.getMessage());
            return "Erro no push: " + e.getMessage();
        }
    }

    /**
     * Executa git pull (origin, branch atual).
     */
    public String pull(String path, String username, String password) {
        try (Git git = openGit(path)) {
            if (git == null) return "Repositório inacessível.";
            PullCommand pull = git.pull();
            if (username != null && !username.isBlank()) {
                pull.setCredentialsProvider(new UsernamePasswordCredentialsProvider(username, password));
            }
            PullResult result = pull.call();
            if (result.isSuccessful()) {
                return "Pull realizado com sucesso. " + result.getMergeResult().getMergeStatus();
            } else {
                return "Pull falhou: " + result.getMergeResult().getMergeStatus();
            }
        } catch (GitAPIException e) {
            log.error("Erro no pull de '{}': {}", path, e.getMessage());
            return "Erro no pull: " + e.getMessage();
        }
    }

    /**
     * Executa git fetch.
     */
    public String fetch(String path, String username, String password) {
        try (Git git = openGit(path)) {
            if (git == null) return "Repositório inacessível.";
            FetchCommand fetch = git.fetch();
            if (username != null && !username.isBlank()) {
                fetch.setCredentialsProvider(new UsernamePasswordCredentialsProvider(username, password));
            }
            FetchResult result = fetch.call();
            String updates = result.getTrackingRefUpdates().isEmpty()
                    ? "Nenhuma atualização." : result.getTrackingRefUpdates().size() + " referência(s) atualizada(s).";
            return "Fetch concluído. " + updates;
        } catch (GitAPIException e) {
            log.error("Erro no fetch de '{}': {}", path, e.getMessage());
            return "Erro no fetch: " + e.getMessage();
        }
    }

    /**
     * Executa git checkout para uma branch existente.
     */
    public String checkout(String path, String branchName) {
        try (Git git = openGit(path)) {
            if (git == null) return "Repositório inacessível.";
            git.checkout().setName(branchName).call();
            return "Checkout para '" + branchName + "' realizado.";
        } catch (GitAPIException e) {
            log.error("Erro no checkout de '{}' para '{}': {}", path, branchName, e.getMessage());
            return "Erro no checkout: " + e.getMessage();
        }
    }

    /**
     * Cria e muda para uma nova branch.
     */
    public String createBranch(String path, String branchName) {
        try (Git git = openGit(path)) {
            if (git == null) return "Repositório inacessível.";
            git.checkout().setCreateBranch(true).setName(branchName).call();
            return "Branch '" + branchName + "' criada e ativada.";
        } catch (GitAPIException e) {
            log.error("Erro ao criar branch '{}' em '{}': {}", branchName, path, e.getMessage());
            return "Erro ao criar branch: " + e.getMessage();
        }
    }

    /**
     * Valida se o repositório possui remote e se a URL bate com a cadastrada no BD.
     */
    public void validateProject(GitProject project) {
        boolean existsOnDisk = Files.isDirectory(Path.of(project.getPath()));
        project.setExistsOnDisk(existsOnDisk);

        if (!existsOnDisk) {
            project.setHasGit(false);
            project.setRemoteUrlMatches(false);
            project.setCurrentBranch("N/A");
            project.setStatusSummary("Diretório não encontrado");
            return;
        }

        boolean hasGit = isValidGitRepo(project.getPath());
        project.setHasGit(hasGit);

        if (!hasGit) {
            project.setRemoteUrlMatches(false);
            project.setCurrentBranch("N/A");
            project.setStatusSummary("Sem repositório git");
            return;
        }

        project.setCurrentBranch(getCurrentBranch(project.getPath()));
        project.setStatusSummary(getStatusSummary(project.getPath()));

        String storedRemote = project.getRemoteUrl();
        String actualRemote = getRemoteOriginUrl(project.getPath());

        if (storedRemote == null || storedRemote.isBlank()) {
            // Sem remote cadastrado no BD — não há o que validar
            project.setRemoteUrlMatches(true);
        } else {
            // Ambos existem: compara sem trailing slash e case-insensitive
            String normalized = storedRemote.trim().replaceAll("/$", "");
            String actualNorm = actualRemote != null ? actualRemote.trim().replaceAll("/$", "") : "";
            project.setRemoteUrlMatches(normalized.equalsIgnoreCase(actualNorm));
        }
    }

    // ----- Helpers privados -----

    private Repository openRepo(String path) {
        try {
            return new FileRepositoryBuilder()
                    .setGitDir(new File(path, ".git"))
                    .readEnvironment()
                    .build();
        } catch (Exception e) {
            log.debug("Não foi possível abrir repo em '{}': {}", path, e.getMessage());
            return null;
        }
    }

    private Git openGit(String path) {
        Repository repo = openRepo(path);
        return repo != null ? new Git(repo) : null;
    }
}
