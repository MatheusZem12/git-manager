package com.gitmanager.service;

import com.gitmanager.model.BranchInfo;
import com.gitmanager.model.GitCommit;
import com.gitmanager.model.GitFileChange;
import com.gitmanager.model.GitProject;
import org.eclipse.jgit.api.*;
import org.eclipse.jgit.api.errors.GitAPIException;
import org.eclipse.jgit.api.CherryPickCommand;
import org.eclipse.jgit.api.CloneCommand;
import org.eclipse.jgit.api.MergeCommand;
import org.eclipse.jgit.api.RebaseCommand;
import org.eclipse.jgit.api.ResetCommand;
import org.eclipse.jgit.diff.DiffEntry;
import org.eclipse.jgit.diff.DiffFormatter;
import org.eclipse.jgit.errors.MissingObjectException;
import org.eclipse.jgit.lib.*;
import org.eclipse.jgit.revwalk.RevCommit;
import org.eclipse.jgit.revwalk.RevWalk;
import org.eclipse.jgit.storage.file.FileRepositoryBuilder;
import org.eclipse.jgit.transport.CredentialItem;
import org.eclipse.jgit.transport.CredentialsProvider;
import org.eclipse.jgit.transport.FetchResult;
import org.eclipse.jgit.transport.PushResult;
import org.eclipse.jgit.transport.RemoteRefUpdate;
import org.eclipse.jgit.transport.SshTransport;
import org.eclipse.jgit.transport.Transport;
import org.eclipse.jgit.transport.TransportConfigCallback;
import org.eclipse.jgit.transport.URIish;
import org.eclipse.jgit.transport.UsernamePasswordCredentialsProvider;
import org.eclipse.jgit.transport.sshd.SshdSessionFactoryBuilder;
import org.eclipse.jgit.util.FS;
import org.eclipse.jgit.errors.UnsupportedCredentialItem;
import org.eclipse.jgit.treewalk.AbstractTreeIterator;
import org.eclipse.jgit.treewalk.CanonicalTreeParser;
import org.eclipse.jgit.treewalk.FileTreeIterator;
import org.eclipse.jgit.treewalk.filter.PathFilter;
import org.eclipse.jgit.util.io.DisabledOutputStream;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.BufferedReader;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.TimeUnit;

public class GitService {

    private static final Logger log = LoggerFactory.getLogger(GitService.class);

    private static final TransportConfigCallback SSH_TRANSPORT_CONFIG = new TransportConfigCallback() {
        @Override
        public void configure(Transport transport) {
            if (transport instanceof SshTransport) {
                ((SshTransport) transport).setSshSessionFactory(
                    new SshdSessionFactoryBuilder()
                        .setPreferredAuthentications("publickey,keyboard-interactive,password")
                        .setHomeDirectory(FS.DETECTED.userHome())
                        .setSshDirectory(new File(FS.DETECTED.userHome(), ".ssh"))
                        .withDefaultConnectorFactory()
                        .build(null)
                );
            }
        }
    };

    /**
     * Obtém a URL do remote "origin" do repositório.
     */
    private String getRemoteUrl(Git git) {
        if (git == null) return null;
        return git.getRepository().getConfig().getString("remote", "origin", "url");
    }

    /**
     * CredentialsProvider que usa o git credential helper do sistema.
     */
    private static class SystemCredentialsProvider extends CredentialsProvider {
        private final String url;
        private String username;
        private String password;

        SystemCredentialsProvider(String url) {
            this.url = url;
        }

        @Override
        public boolean isInteractive() {
            return false;
        }

        @Override
        public boolean supports(CredentialItem... items) {
            return true;
        }

        @Override
        public boolean get(URIish uri, CredentialItem... items) throws UnsupportedCredentialItem {
            if (username == null) {
                loadFromGitCredential();
            }
            if (username == null) return false;
            for (CredentialItem item : items) {
                if (item instanceof CredentialItem.Username) {
                    ((CredentialItem.Username) item).setValue(username);
                } else if (item instanceof CredentialItem.Password) {
                    ((CredentialItem.Password) item).setValue(password != null ? password.toCharArray() : new char[0]);
                } else if (item instanceof CredentialItem.StringType) {
                    ((CredentialItem.StringType) item).setValue(password != null ? password : "");
                }
            }
            return true;
        }

        private void loadFromGitCredential() {
            try {
                ProcessBuilder pb = new ProcessBuilder("git", "credential", "fill");
                pb.redirectErrorStream(true);
                Process p = pb.start();
                try (OutputStream os = p.getOutputStream();
                     BufferedReader reader = new BufferedReader(new InputStreamReader(p.getInputStream(), StandardCharsets.UTF_8))) {
                    os.write(("url=" + url + "\n\n").getBytes(StandardCharsets.UTF_8));
                    os.flush();
                    p.waitFor(5, TimeUnit.SECONDS);
                    String line;
                    while ((line = reader.readLine()) != null) {
                        if (line.startsWith("username=")) {
                            username = line.substring("username=".length());
                        } else if (line.startsWith("password=")) {
                            password = line.substring("password=".length());
                        }
                    }
                }
            } catch (Exception e) {
                log.debug("Falha ao obter credenciais do git credential: {}", e.getMessage());
            }
        }
    }

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
     * Obtém o hash do commit HEAD atual.
     */
    public String getHeadCommitId(String path) {
        try (Repository repo = openRepo(path)) {
            if (repo == null) return null;
            ObjectId head = repo.resolve("HEAD");
            return head != null ? head.name() : null;
        } catch (Exception e) {
            log.debug("Erro ao obter HEAD de '{}': {}", path, e.getMessage());
            return null;
        }
    }

    /**
     * Retorna um resumo do status do repositório.
     */
    public String getStatusSummary(String path) {
        try (Git git = openGit(path)) {
            if (git == null) return "Inacessível";
            Status status = git.status().call();
            int modified = status.getModified().size() + status.getMissing().size()
                         + status.getUntracked().size() + status.getAdded().size()
                         + status.getChanged().size() + status.getRemoved().size()
                         + status.getConflicting().size();
            if (modified > 0) return modified + " alteração(ões)";
            return "Limpo";
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
     * Retorna o grafo de commits com informações de branches para visualização.
     */
    public List<GitCommit> getCommitGraph(String path, int limit) {
        List<GitCommit> result = new ArrayList<>();
        Map<String, GitCommit> commitMap = new LinkedHashMap<>();
        try (Git git = openGit(path)) {
            if (git == null) return result;

            // Build commits
            Iterable<RevCommit> logs = git.log().all().setMaxCount(limit).call();
            for (RevCommit rc : logs) {
                List<String> parents = new ArrayList<>();
                for (RevCommit p : rc.getParents()) {
                    parents.add(p.name());
                }
                GitCommit gc = new GitCommit(
                        rc.name(),
                        rc.abbreviate(7).name(),
                        rc.getShortMessage(),
                        rc.getAuthorIdent().getName(),
                        rc.getAuthorIdent().getEmailAddress(),
                        rc.getAuthorIdent().getWhen().toInstant(),
                        parents
                );
                commitMap.put(gc.getId(), gc);
            }

            // Attach branches
            String headId = getHeadCommitId(path);
            List<BranchInfo> branches = getBranchesInfo(path);
            for (BranchInfo bi : branches) {
                GitCommit target = commitMap.get(bi.getCommitId());
                if (target == null) {
                    // Branch may point to a commit outside the limit; try to resolve it anyway
                    try (RevWalk walk = new RevWalk(git.getRepository())) {
                        ObjectId oid = git.getRepository().resolve(bi.getName());
                        if (oid != null) {
                            RevCommit rc = walk.parseCommit(oid);
                            List<String> parents = new ArrayList<>();
                            for (RevCommit p : rc.getParents()) {
                                parents.add(p.name());
                            }
                            target = new GitCommit(
                                    rc.name(),
                                    rc.abbreviate(7).name(),
                                    rc.getShortMessage(),
                                    rc.getAuthorIdent().getName(),
                                    rc.getAuthorIdent().getEmailAddress(),
                                    rc.getAuthorIdent().getWhen().toInstant(),
                                    parents
                            );
                            commitMap.put(target.getId(), target);
                        }
                    } catch (Exception ex) {
                        log.debug("Não foi possível resolver branch '{}' em '{}'", bi.getName(), path);
                    }
                }
                if (target != null) {
                    target.addBranchName(bi.getName() + (bi.isRemote() ? " (remoto)" : ""));
                    if (headId != null && headId.equals(target.getId())) {
                        target.setHead(true);
                    }
                }
            }

            // Also mark HEAD if not already done
            if (headId != null) {
                GitCommit headCommit = commitMap.get(headId);
                if (headCommit != null) {
                    headCommit.setHead(true);
                }
            }

            result.addAll(commitMap.values());
            // Sort by time descending (newest first)
            result.sort(Comparator.comparing(GitCommit::getCommitTime).reversed());
        } catch (Exception e) {
            log.debug("Erro ao obter grafo de commits de '{}': {}", path, e.getMessage());
        }
        return result;
    }

    /**
     * Lista informações de branches locais e remotas.
     */
    public List<BranchInfo> getBranchesInfo(String path) {
        List<BranchInfo> result = new ArrayList<>();
        try (Git git = openGit(path)) {
            if (git == null) return result;
            Repository repo = git.getRepository();
            String current = getCurrentBranch(path);

            List<Ref> localRefs = git.branchList().call();
            for (Ref ref : localRefs) {
                String name = Repository.shortenRefName(ref.getName());
                String commitId = ref.getObjectId().name();
                result.add(new BranchInfo(name, commitId, false, name.equals(current)));
            }

            List<Ref> remoteRefs = git.branchList().setListMode(ListBranchCommand.ListMode.REMOTE).call();
            for (Ref ref : remoteRefs) {
                String name = Repository.shortenRefName(ref.getName());
                String commitId = ref.getObjectId().name();
                result.add(new BranchInfo(name, commitId, true, false));
            }
        } catch (Exception e) {
            log.debug("Erro ao listar branches info de '{}': {}", path, e.getMessage());
        }
        return result;
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
     * Executa git add + commit (todos os arquivos se addAll=true).
     */
    public String commit(String path, String message, boolean addAll,
                         String authorName, String authorEmail) {
        try (Git git = openGit(path)) {
            if (git == null) return "Repositório inacessível.";
            if (addAll) {
                git.add().addFilepattern(".").call();
            }

            CommitCommand commitCmd = git.commit().setMessage(message).setAllowEmpty(false);
            if (authorName != null && !authorName.isBlank()
                    && authorEmail != null && !authorEmail.isBlank()) {
                commitCmd.setAuthor(authorName, authorEmail);
            }

            RevCommit commit = commitCmd.call();
            return "Commit realizado: " + commit.abbreviate(7).name() + " – " + commit.getShortMessage();
        } catch (GitAPIException e) {
            log.error("Erro no commit de '{}': {}", path, e.getMessage());
            return "Erro no commit: " + e.getMessage();
        }
    }

    /**
     * Executa git add nos arquivos selecionados e depois commit.
     */
    public String commitSelected(String path, String message, List<String> selectedFiles,
                                 String authorName, String authorEmail) {
        try (Git git = openGit(path)) {
            if (git == null) return "Repositório inacessível.";
            if (selectedFiles == null || selectedFiles.isEmpty()) {
                return "Nenhum arquivo selecionado para commit.";
            }

            Status status = git.status().call();
            Set<String> missing = status.getMissing();

            AddCommand addCmd = git.add();
            RmCommand rmCmd = git.rm();
            boolean hasAdd = false;
            boolean hasRm = false;
            for (String file : selectedFiles) {
                if (missing.contains(file)) {
                    rmCmd.addFilepattern(file);
                    hasRm = true;
                } else {
                    addCmd.addFilepattern(file);
                    hasAdd = true;
                }
            }
            if (hasAdd) addCmd.call();
            if (hasRm) rmCmd.call();

            CommitCommand commitCmd = git.commit().setMessage(message).setAllowEmpty(false);
            if (authorName != null && !authorName.isBlank()
                    && authorEmail != null && !authorEmail.isBlank()) {
                commitCmd.setAuthor(authorName, authorEmail);
            }

            RevCommit commit = commitCmd.call();
            return "Commit realizado: " + commit.abbreviate(7).name() + " – " + commit.getShortMessage();
        } catch (GitAPIException e) {
            log.error("Erro no commit de '{}': {}", path, e.getMessage());
            return "Erro no commit: " + e.getMessage();
        }
    }

    /**
     * Executa git add nos arquivos selecionados (stage).
     */
    public String stageFiles(String path, List<String> files) {
        try (Git git = openGit(path)) {
            if (git == null) return "Repositório inacessível.";
            if (files == null || files.isEmpty()) {
                return "Nenhum arquivo selecionado para stage.";
            }
            Status status = git.status().call();
            Set<String> missing = status.getMissing();

            AddCommand addCmd = git.add();
            RmCommand rmCmd = git.rm();
            boolean hasAdd = false;
            boolean hasRm = false;
            for (String file : files) {
                if (missing.contains(file)) {
                    rmCmd.addFilepattern(file);
                    hasRm = true;
                } else {
                    addCmd.addFilepattern(file);
                    hasAdd = true;
                }
            }
            if (hasAdd) addCmd.call();
            if (hasRm) rmCmd.call();
            return files.size() + " arquivo(s) adicionado(s) ao stage.";
        } catch (GitAPIException e) {
            log.error("Erro no stage de '{}': {}", path, e.getMessage());
            return "Erro no stage: " + e.getMessage();
        }
    }

    /**
     * Executa git reset HEAD nos arquivos selecionados (unstage).
     */
    public String unstageFiles(String path, List<String> files) {
        try (Git git = openGit(path)) {
            if (git == null) return "Repositório inacessível.";
            if (files == null || files.isEmpty()) {
                return "Nenhum arquivo selecionado para unstage.";
            }
            ResetCommand reset = git.reset();
            for (String file : files) {
                reset.addPath(file);
            }
            reset.call();
            return files.size() + " arquivo(s) removido(s) do stage.";
        } catch (GitAPIException e) {
            log.error("Erro no unstage de '{}': {}", path, e.getMessage());
            return "Erro no unstage: " + e.getMessage();
        }
    }

    /**
     * Executa commit apenas do que está staged.
     */
    public String commitStaged(String path, String message,
                               String authorName, String authorEmail) {
        try (Git git = openGit(path)) {
            if (git == null) return "Repositório inacessível.";
            CommitCommand commitCmd = git.commit().setMessage(message).setAllowEmpty(false);
            if (authorName != null && !authorName.isBlank()
                    && authorEmail != null && !authorEmail.isBlank()) {
                commitCmd.setAuthor(authorName, authorEmail);
            }
            RevCommit commit = commitCmd.call();
            return "Commit realizado: " + commit.abbreviate(7).name() + " – " + commit.getShortMessage();
        } catch (GitAPIException e) {
            log.error("Erro no commit de '{}': {}", path, e.getMessage());
            return "Erro no commit: " + e.getMessage();
        }
    }

    private boolean isSshRemote(String url) {
        return url != null && (url.startsWith("git@") || url.startsWith("ssh://"));
    }

    private String execGitCommand(String repoPath, String... args) {
        try {
            List<String> cmd = new ArrayList<>();
            cmd.add("git");
            cmd.addAll(Arrays.asList(args));
            ProcessBuilder pb = new ProcessBuilder(cmd);
            pb.directory(new File(repoPath));
            pb.redirectErrorStream(true);
            Process p = pb.start();
            boolean finished = p.waitFor(60, TimeUnit.SECONDS);
            if (!finished) {
                p.destroyForcibly();
                return "Erro: comando excedeu o tempo limite.";
            }
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(p.getInputStream(), StandardCharsets.UTF_8))) {
                StringBuilder sb = new StringBuilder();
                String line;
                while ((line = reader.readLine()) != null) {
                    if (line.contains("Enumerating objects") ||
                        line.contains("Counting objects") ||
                        line.contains("Compressing objects") ||
                        line.contains("Writing objects") ||
                        line.contains("Resolving deltas") ||
                        line.contains("Total")) {
                        continue;
                    }
                    if (sb.length() > 0) sb.append("\n");
                    sb.append(line);
                }
                String output = sb.toString().trim();
                if (p.exitValue() != 0) {
                    return "Erro: " + (output.isEmpty() ? "comando falhou" : output);
                }
                return output.isEmpty() ? "Comando executado com sucesso." : output;
            }
        } catch (Exception e) {
            log.error("Erro ao executar comando git em '{}': {}", repoPath, e.getMessage());
            return "Erro ao executar comando git: " + e.getMessage();
        }
    }

    /**
     * Executa git push (origin, branch atual).
     */
    public String push(String path, String username, String password) {
        try (Git git = openGit(path)) {
            if (git == null) return "Repositório inacessível.";
            String remoteUrl = getRemoteUrl(git);
            if (username == null || username.isBlank()) {
                if (remoteUrl != null && isSshRemote(remoteUrl)) {
                    String output = execGitCommand(path, "push");
                    return output.startsWith("Erro:") ? output : "Push realizado com sucesso." + (output.isEmpty() || output.equals("Comando executado com sucesso.") ? "" : "\n" + output);
                }
            }
            PushCommand push = git.push();
            push.setTransportConfigCallback(SSH_TRANSPORT_CONFIG);
            if (username != null && !username.isBlank()) {
                push.setCredentialsProvider(new UsernamePasswordCredentialsProvider(username, password));
            } else {
                if (remoteUrl != null) {
                    push.setCredentialsProvider(new SystemCredentialsProvider(remoteUrl));
                }
            }
            Iterable<PushResult> results = push.call();
            List<String> updates = new ArrayList<>();
            for (PushResult result : results) {
                String messages = result.getMessages();
                if (messages != null && !messages.isBlank()) {
                    for (String line : messages.split("\\r?\\n")) {
                        String trimmed = line.trim();
                        if (trimmed.isEmpty()) continue;
                        if (trimmed.contains("Enumerating objects") ||
                            trimmed.contains("Counting objects") ||
                            trimmed.contains("Compressing objects") ||
                            trimmed.contains("Writing objects") ||
                            trimmed.contains("Resolving deltas") ||
                            trimmed.contains("Total")) {
                            continue;
                        }
                        updates.add(trimmed);
                    }
                }
                for (RemoteRefUpdate u : result.getRemoteUpdates()) {
                    String ref = u.getRemoteName();
                    String status = u.getStatus().name();
                    updates.add(ref + " → " + status);
                }
            }
            if (updates.isEmpty()) {
                return "Push realizado com sucesso.";
            }
            return "Push realizado com sucesso.\n" + String.join("\n", updates);
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
            String remoteUrl = getRemoteUrl(git);
            if (username == null || username.isBlank()) {
                if (remoteUrl != null && isSshRemote(remoteUrl)) {
                    String output = execGitCommand(path, "pull");
                    return output.startsWith("Erro:") ? output : "Pull realizado com sucesso." + (output.isEmpty() || output.equals("Comando executado com sucesso.") ? "" : "\n" + output);
                }
            }
            PullCommand pull = git.pull();
            pull.setTransportConfigCallback(SSH_TRANSPORT_CONFIG);
            if (username != null && !username.isBlank()) {
                pull.setCredentialsProvider(new UsernamePasswordCredentialsProvider(username, password));
            } else {
                if (remoteUrl != null) {
                    pull.setCredentialsProvider(new SystemCredentialsProvider(remoteUrl));
                }
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
            String remoteUrl = getRemoteUrl(git);
            if (username == null || username.isBlank()) {
                if (remoteUrl != null && isSshRemote(remoteUrl)) {
                    String output = execGitCommand(path, "fetch");
                    return output.startsWith("Erro:") ? output : "Fetch concluído." + (output.isEmpty() || output.equals("Comando executado com sucesso.") ? "" : "\n" + output);
                }
            }
            FetchCommand fetch = git.fetch();
            fetch.setTransportConfigCallback(SSH_TRANSPORT_CONFIG);
            if (username != null && !username.isBlank()) {
                fetch.setCredentialsProvider(new UsernamePasswordCredentialsProvider(username, password));
            } else {
                if (remoteUrl != null) {
                    fetch.setCredentialsProvider(new SystemCredentialsProvider(remoteUrl));
                }
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
     * Retorna o status de sincronização com o remote (ahead/behind).
     */
    public Map<String, Object> getSyncStatus(String path) {
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("ahead", 0);
        result.put("behind", 0);
        result.put("hasRemote", false);
        result.put("remoteUrl", "");
        try (Git git = openGit(path)) {
            if (git == null) return result;
            Repository repo = git.getRepository();
            String currentBranch = repo.getBranch();
            if (currentBranch == null) return result;

            StoredConfig config = repo.getConfig();
            String remoteUrl = config.getString("remote", "origin", "url");
            result.put("hasRemote", remoteUrl != null && !remoteUrl.isBlank());
            result.put("remoteUrl", remoteUrl != null ? remoteUrl : "");

            BranchConfig branchConfig = new BranchConfig(config, currentBranch);
            String trackingBranch = branchConfig.getRemoteTrackingBranch();
            if (trackingBranch == null || trackingBranch.isBlank()) {
                return result;
            }

            ObjectId localId = repo.resolve("HEAD");
            ObjectId remoteId = repo.resolve(trackingBranch);
            if (localId == null || remoteId == null) return result;

            try (RevWalk walk = new RevWalk(repo)) {
                RevCommit localCommit = walk.parseCommit(localId);
                RevCommit remoteCommit = walk.parseCommit(remoteId);

                walk.reset();
                walk.markStart(localCommit);
                walk.markUninteresting(remoteCommit);
                int ahead = 0;
                for (RevCommit c : walk) {
                    ahead++;
                }

                walk.reset();
                walk.markStart(remoteCommit);
                walk.markUninteresting(localCommit);
                int behind = 0;
                for (RevCommit c : walk) {
                    behind++;
                }

                result.put("ahead", ahead);
                result.put("behind", behind);
            }
        } catch (Exception e) {
            log.debug("Erro ao obter sync status de '{}': {}", path, e.getMessage());
        }
        return result;
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

    public String deleteBranch(String path, String branchName) {
        try (Git git = openGit(path)) {
            if (git == null) return "Repositório inacessível.";
            git.branchDelete().setBranchNames(branchName).setForce(true).call();
            return "Branch '" + branchName + "' removida.";
        } catch (GitAPIException e) {
            log.error("Erro ao deletar branch '{}' em '{}': {}", branchName, path, e.getMessage());
            return "Erro ao deletar branch: " + e.getMessage();
        }
    }

    public String amendCommit(String path, String message, String authorName, String authorEmail) {
        try (Git git = openGit(path)) {
            if (git == null) return "Repositório inacessível.";
            CommitCommand cmd = git.commit().setAmend(true).setAllowEmpty(false);
            if (message != null && !message.isBlank()) {
                cmd.setMessage(message);
            }
            if (authorName != null && !authorName.isBlank() && authorEmail != null && !authorEmail.isBlank()) {
                cmd.setAuthor(authorName, authorEmail);
            }
            RevCommit commit = cmd.call();
            return "Commit amendado: " + commit.abbreviate(7).name() + " – " + commit.getShortMessage();
        } catch (GitAPIException e) {
            log.error("Erro no amend de '{}': {}", path, e.getMessage());
            return "Erro no amend: " + e.getMessage();
        }
    }

    public String merge(String path, String branchName) {
        try (Git git = openGit(path)) {
            if (git == null) return "Repositório inacessível.";
            MergeResult result = git.merge().include(git.getRepository().resolve(branchName)).call();
            if (result.getMergeStatus().isSuccessful()) {
                return "Merge realizado com sucesso.";
            } else {
                return "Merge conflitoso. Resolva os conflitos manualmente.";
            }
        } catch (GitAPIException e) {
            log.error("Erro no merge de '{}': {}", path, e.getMessage());
            return "Erro no merge: " + e.getMessage();
        }
    }

    public String cherryPick(String path, String commitId) {
        try (Git git = openGit(path)) {
            if (git == null) return "Repositório inacessível.";
            ObjectId oid = git.getRepository().resolve(commitId);
            if (oid == null) return "Commit não encontrado.";
            CherryPickResult result = git.cherryPick().include(oid).call();
            if (result.getStatus() == CherryPickResult.CherryPickStatus.OK) {
                return "Cherry-pick realizado com sucesso.";
            } else {
                return "Cherry-pick conflitoso. Resolva os conflitos manualmente.";
            }
        } catch (GitAPIException e) {
            log.error("Erro no cherry-pick de '{}': {}", path, e.getMessage());
            return "Erro no cherry-pick: " + e.getMessage();
        }
    }

    public String rebase(String path, String branchName) {
        try (Git git = openGit(path)) {
            if (git == null) return "Repositório inacessível.";
            RebaseResult result = git.rebase().setUpstream(branchName).call();
            if (result.getStatus().isSuccessful()) {
                return "Rebase realizado com sucesso.";
            } else {
                return "Rebase conflitoso. Resolva os conflitos manualmente.";
            }
        } catch (GitAPIException e) {
            log.error("Erro no rebase de '{}': {}", path, e.getMessage());
            return "Erro no rebase: " + e.getMessage();
        }
    }

    public List<Map<String, String>> getRemotes(String path) {
        List<Map<String, String>> remotes = new ArrayList<>();
        try (Git git = openGit(path)) {
            if (git == null) return remotes;
            StoredConfig config = git.getRepository().getConfig();
            for (String name : config.getSubsections("remote")) {
                Map<String, String> r = new LinkedHashMap<>();
                r.put("name", name);
                r.put("url", config.getString("remote", name, "url"));
                remotes.add(r);
            }
        } catch (Exception e) {
            log.debug("Erro ao listar remotes de '{}': {}", path, e.getMessage());
        }
        return remotes;
    }

    public String cloneRepo(String remoteUrl, String localPath, String username, String password) {
        try {
            CloneCommand clone = Git.cloneRepository().setURI(remoteUrl).setDirectory(new File(localPath));
            if (username != null && !username.isBlank()) {
                clone.setCredentialsProvider(new UsernamePasswordCredentialsProvider(username, password));
            }
            Git git = clone.call();
            git.close();
            return "Clone realizado com sucesso em: " + localPath;
        } catch (GitAPIException e) {
            log.error("Erro no clone de '{}': {}", remoteUrl, e.getMessage());
            return "Erro no clone: " + e.getMessage();
        }
    }

    // ---- Tags ----

    public List<String> getTags(String path) {
        List<String> tags = new ArrayList<>();
        try (Git git = openGit(path)) {
            if (git == null) return tags;
            List<Ref> refs = git.tagList().call();
            for (Ref ref : refs) {
                tags.add(Repository.shortenRefName(ref.getName()));
            }
        } catch (Exception e) {
            log.debug("Erro ao listar tags de '{}': {}", path, e.getMessage());
        }
        return tags;
    }

    public String createTag(String path, String name, String message) {
        try (Git git = openGit(path)) {
            if (git == null) return "Repositório inacessível.";
            git.tag().setName(name).setMessage(message != null && !message.isBlank() ? message : name).call();
            return "Tag '" + name + "' criada.";
        } catch (Exception e) {
            log.error("Erro ao criar tag em '{}': {}", path, e.getMessage());
            return "Erro ao criar tag: " + e.getMessage();
        }
    }

    public String deleteTag(String path, String name) {
        try (Git git = openGit(path)) {
            if (git == null) return "Repositório inacessível.";
            git.tagDelete().setTags(name).call();
            return "Tag '" + name + "' removida.";
        } catch (Exception e) {
            log.error("Erro ao deletar tag em '{}': {}", path, e.getMessage());
            return "Erro ao deletar tag: " + e.getMessage();
        }
    }

    // ---- Stash ----

    public List<String> getStashes(String path) {
        List<String> stashes = new ArrayList<>();
        try (Git git = openGit(path)) {
            if (git == null) return stashes;
            Collection<RevCommit> stashRefs = git.stashList().call();
            int i = 0;
            for (RevCommit c : stashRefs) {
                stashes.add("stash@{" + i + "}: " + c.getShortMessage());
                i++;
            }
        } catch (Exception e) {
            log.debug("Erro ao listar stashes de '{}': {}", path, e.getMessage());
        }
        return stashes;
    }

    public String stashSave(String path, String message) {
        try (Git git = openGit(path)) {
            if (git == null) return "Repositório inacessível.";
            StashCreateCommand stashCreate = git.stashCreate();
            if (message != null && !message.isBlank()) {
                stashCreate.setWorkingDirectoryMessage(message);
            }
            RevCommit stash = stashCreate.call();
            return stash != null ? "Stash salvo: " + stash.getShortMessage() : "Nenhuma alteração para stash.";
        } catch (Exception e) {
            log.error("Erro ao criar stash em '{}': {}", path, e.getMessage());
            return "Erro ao criar stash: " + e.getMessage();
        }
    }

    public String stashPop(String path, int index) {
        try (Git git = openGit(path)) {
            if (git == null) return "Repositório inacessível.";
            git.stashApply().setStashRef("stash@{" + index + "}").call();
            git.stashDrop().setStashRef(index).call();
            return "Stash aplicado e removido.";
        } catch (Exception e) {
            log.error("Erro ao fazer stash pop em '{}': {}", path, e.getMessage());
            return "Erro ao aplicar stash: " + e.getMessage();
        }
    }

    public String stashApply(String path, int index) {
        try (Git git = openGit(path)) {
            if (git == null) return "Repositório inacessível.";
            git.stashApply().setStashRef("stash@{" + index + "}").call();
            return "Stash aplicado.";
        } catch (Exception e) {
            log.error("Erro ao aplicar stash em '{}': {}", path, e.getMessage());
            return "Erro ao aplicar stash: " + e.getMessage();
        }
    }

    public String stashDrop(String path, int index) {
        try (Git git = openGit(path)) {
            if (git == null) return "Repositório inacessível.";
            git.stashDrop().setStashRef(index).call();
            return "Stash removido.";
        } catch (Exception e) {
            log.error("Erro ao remover stash em '{}': {}", path, e.getMessage());
            return "Erro ao remover stash: " + e.getMessage();
        }
    }

    // ---- Reflog ----

    public List<String> getReflog(String path) {
        List<String> entries = new ArrayList<>();
        try (Git git = openGit(path)) {
            if (git == null) return entries;
            Collection<ReflogEntry> reflog = git.reflog().call();
            for (ReflogEntry e : reflog) {
                entries.add(e.getNewId().abbreviate(7).name() + " - " + e.getComment());
            }
        } catch (Exception e) {
            log.debug("Erro ao obter reflog de '{}': {}", path, e.getMessage());
        }
        return entries;
    }

    // ---- Reset ----

    public String reset(String path, String commitId, String mode) {
        try (Git git = openGit(path)) {
            if (git == null) return "Repositório inacessível.";
            ResetCommand reset = git.reset();
            if (commitId != null && !commitId.isBlank()) {
                reset.setRef(commitId);
            }
            String m = mode != null ? mode.toLowerCase() : "mixed";
            reset.setMode(switch (m) {
                case "soft" -> ResetCommand.ResetType.SOFT;
                case "hard" -> ResetCommand.ResetType.HARD;
                default -> ResetCommand.ResetType.MIXED;
            });
            reset.call();
            return "Reset " + m + " realizado para " + (commitId != null ? commitId : "HEAD") + ".";
        } catch (Exception e) {
            log.error("Erro no reset de '{}': {}", path, e.getMessage());
            return "Erro no reset: " + e.getMessage();
        }
    }

    /**
     * Valida o projeto contra o filesystem atual.
     */
    public void validateProject(GitProject project) {
        boolean existsOnDisk = Files.isDirectory(Path.of(project.getPath()));
        project.setExistsOnDisk(existsOnDisk);

        if (!existsOnDisk) {
            project.setHasGit(false);
            project.setCurrentBranch("N/A");
            project.setStatusSummary("Diretório não encontrado");
            return;
        }

        boolean hasGit = isValidGitRepo(project.getPath());
        project.setHasGit(hasGit);

        if (!hasGit) {
            project.setCurrentBranch("N/A");
            project.setStatusSummary("Sem repositório git");
            return;
        }

        project.setCurrentBranch(getCurrentBranch(project.getPath()));
        project.setStatusSummary(getStatusSummary(project.getPath()));

        Map<String, Object> sync = getSyncStatus(project.getPath());
        project.setAhead((Integer) sync.getOrDefault("ahead", 0));
        project.setBehind((Integer) sync.getOrDefault("behind", 0));
    }

    // ---- Status detalhado ----

    public List<GitFileChange> getFileChanges(String path) {
        List<GitFileChange> changes = new ArrayList<>();
        try (Git git = openGit(path)) {
            if (git == null) return changes;
            Status status = git.status().call();

            for (String s : status.getAdded()) {
                changes.add(new GitFileChange(s, GitFileChange.Type.ADDED, true));
            }
            for (String s : status.getChanged()) {
                changes.add(new GitFileChange(s, GitFileChange.Type.MODIFIED, true));
            }
            for (String s : status.getRemoved()) {
                changes.add(new GitFileChange(s, GitFileChange.Type.DELETED, true));
            }
            for (String s : status.getModified()) {
                changes.add(new GitFileChange(s, GitFileChange.Type.MODIFIED, false));
            }
            for (String s : status.getMissing()) {
                changes.add(new GitFileChange(s, GitFileChange.Type.DELETED, false));
            }
            for (String s : status.getUntracked()) {
                changes.add(new GitFileChange(s, GitFileChange.Type.UNTRACKED, false));
            }
            for (String s : status.getConflicting()) {
                changes.add(new GitFileChange(s, GitFileChange.Type.CONFLICTING, false));
            }
        } catch (Exception e) {
            log.debug("Erro ao obter status detalhado de '{}': {}", path, e.getMessage());
        }
        return changes;
    }

    public String getFileContent(String repoPath, String filePath) {
        Path p = Path.of(repoPath, filePath);
        if (!Files.exists(p)) return "(arquivo não existe no disco)";
        try {
            return Files.readString(p, StandardCharsets.UTF_8);
        } catch (IOException e) {
            try {
                byte[] bytes = Files.readAllBytes(p);
                return new String(bytes, StandardCharsets.UTF_8);
            } catch (IOException ex) {
                return "(erro ao ler arquivo: " + ex.getMessage() + ")";
            }
        }
    }

    public String getFileContentHead(String repoPath, String filePath) {
        try (Git git = openGit(repoPath)) {
            if (git == null) return "(repositório inacessível)";
            Repository repo = git.getRepository();
            ObjectId headId = repo.resolve("HEAD:" + filePath);
            if (headId == null) return "";
            try (ObjectReader reader = repo.newObjectReader()) {
                byte[] bytes = reader.open(headId).getBytes();
                return new String(bytes, StandardCharsets.UTF_8);
            }
        } catch (Exception e) {
            log.debug("Erro ao ler HEAD de '{}': {}", filePath, e.getMessage());
            return "";
        }
    }

    public String getFileDiff(String repoPath, String filePath, boolean staged) {
        // First try JGit diff command
        String jgitResult = diffViaJGit(repoPath, filePath, staged);
        if (jgitResult != null && !jgitResult.startsWith("Erro")) {
            return jgitResult;
        }
        // Fallback to manual diff by reading HEAD blob and disk content
        return diffManual(repoPath, filePath);
    }

    private String diffViaJGit(String repoPath, String filePath, boolean staged) {
        try (Git git = openGit(repoPath)) {
            if (git == null) return "Repositório inacessível.";
            Repository repo = git.getRepository();

            ByteArrayOutputStream out = new ByteArrayOutputStream();
            DiffFormatter formatter = new DiffFormatter(out);
            formatter.setRepository(repo);
            formatter.setContext(3);

            List<DiffEntry> diffs;
            if (staged) {
                diffs = git.diff()
                        .setCached(true)
                        .setPathFilter(PathFilter.create(filePath))
                        .call();
            } else {
                diffs = git.diff()
                        .setPathFilter(PathFilter.create(filePath))
                        .call();
            }

            if (diffs.isEmpty()) {
                return "Nenhuma alteração detectada.";
            }

            for (DiffEntry diff : diffs) {
                formatter.format(diff);
            }
            formatter.flush();
            String result = out.toString(StandardCharsets.UTF_8);
            return result.isBlank() ? "Sem diferenças textuais." : result;
        } catch (MissingObjectException e) {
            log.debug("MissingObjectException no diff de '{}', usando fallback manual", filePath);
            return null; // signal to use fallback
        } catch (Exception e) {
            log.debug("Erro ao obter diff de '{}': {}", filePath, e.getMessage());
            return "Erro ao obter diff: " + e.getMessage();
        }
    }

    private String diffManual(String repoPath, String filePath) {
        try (Repository repo = openRepo(repoPath)) {
            if (repo == null) return "Repositório inacessível.";

            // Read current disk content
            String diskContent = getFileContent(repoPath, filePath);
            if (diskContent.startsWith("(arquivo não existe no disco)")) {
                diskContent = "";
            }

            // Read HEAD content
            String headContent = "";
            ObjectId head = repo.resolve("HEAD");
            if (head != null) {
                try (RevWalk walk = new RevWalk(repo)) {
                    RevCommit commit = walk.parseCommit(head);
                    try (ObjectReader reader = repo.newObjectReader()) {
                        CanonicalTreeParser treeParser = new CanonicalTreeParser();
                        treeParser.reset(reader, commit.getTree());
                        while (!treeParser.eof()) {
                            String path = treeParser.getEntryPathString();
                            if (path.equals(filePath)) {
                                ObjectId blobId = treeParser.getEntryObjectId();
                                byte[] bytes = reader.open(blobId).getBytes();
                                headContent = new String(bytes, StandardCharsets.UTF_8);
                                break;
                            }
                            treeParser.next(1);
                        }
                    }
                }
            }

            return buildUnifiedDiff(headContent, diskContent, filePath);
        } catch (Exception e) {
            log.debug("Erro no diff manual de '{}': {}", filePath, e.getMessage());
            return "Erro ao calcular diff manual: " + e.getMessage();
        }
    }

    private String buildUnifiedDiff(String oldContent, String newContent, String filePath) {
        String[] oldLines = oldContent.isEmpty() ? new String[0] : oldContent.split("\n", -1);
        String[] newLines = newContent.isEmpty() ? new String[0] : newContent.split("\n", -1);

        StringBuilder sb = new StringBuilder();
        sb.append("--- a/").append(filePath).append("\n");
        sb.append("+++ b/").append(filePath).append("\n");

        int max = Math.max(oldLines.length, newLines.length);
        for (int i = 0; i < max; i++) {
            String o = i < oldLines.length ? oldLines[i] : null;
            String n = i < newLines.length ? newLines[i] : null;
            if (o != null && n != null && o.equals(n)) {
                sb.append(" ").append(o).append("\n");
            } else {
                if (o != null && !o.isEmpty()) sb.append("-").append(o).append("\n");
                if (n != null && !n.isEmpty()) sb.append("+").append(n).append("\n");
            }
        }
        return sb.toString();
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
