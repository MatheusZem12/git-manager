package com.gitmanager.service;

import com.gitmanager.model.BranchInfo;
import com.gitmanager.model.GitCommit;
import com.gitmanager.model.GitFileChange;
import com.gitmanager.model.GitProject;
import org.eclipse.jgit.api.*;
import org.eclipse.jgit.api.errors.GitAPIException;
import org.eclipse.jgit.diff.DiffEntry;
import org.eclipse.jgit.diff.DiffFormatter;
import org.eclipse.jgit.errors.MissingObjectException;
import org.eclipse.jgit.lib.*;
import org.eclipse.jgit.revwalk.RevCommit;
import org.eclipse.jgit.revwalk.RevWalk;
import org.eclipse.jgit.storage.file.FileRepositoryBuilder;
import org.eclipse.jgit.transport.FetchResult;
import org.eclipse.jgit.transport.PushResult;
import org.eclipse.jgit.transport.UsernamePasswordCredentialsProvider;
import org.eclipse.jgit.treewalk.AbstractTreeIterator;
import org.eclipse.jgit.treewalk.CanonicalTreeParser;
import org.eclipse.jgit.treewalk.FileTreeIterator;
import org.eclipse.jgit.treewalk.filter.PathFilter;
import org.eclipse.jgit.util.io.DisabledOutputStream;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Instant;
import java.util.*;

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

            AddCommand addCmd = git.add();
            for (String file : selectedFiles) {
                addCmd.addFilepattern(file);
            }
            addCmd.call();

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
