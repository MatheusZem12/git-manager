package com.gitmanager.api;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import com.gitmanager.model.BranchInfo;
import com.gitmanager.model.GitCommit;
import com.gitmanager.model.GitFileChange;
import com.gitmanager.model.GitProject;
import com.gitmanager.service.GitService;
import com.gitmanager.service.ProjectService;
import io.javalin.Javalin;
import io.javalin.http.Context;
import io.javalin.http.HttpStatus;
import io.javalin.plugin.bundled.CorsPluginConfig;

import java.util.List;
import java.util.Map;

/**
 * Servidor REST embutido que expõe GitService e ProjectService via HTTP.
 * Comunica com o frontend Flutter Desktop via localhost.
 */
public class RestServer {

    private final int port;
    private final ProjectService projectService;
    private final GitService gitService;
    private final ObjectMapper mapper;
    private Javalin app;

    public RestServer(int port) {
        this.port = port;
        this.projectService = new ProjectService();
        this.gitService = projectService.getGitService();
        this.mapper = new ObjectMapper();
        this.mapper.registerModule(new JavaTimeModule());
    }

    public void start() {
        app = Javalin.create(config -> {
            config.bundledPlugins.enableCors(cors -> cors.addRule(CorsPluginConfig.CorsRule::anyHost));
            config.showJavalinBanner = false;
            config.jsonMapper(new io.javalin.json.JavalinJackson().updateMapper(m -> {
                m.registerModule(new com.fasterxml.jackson.datatype.jsr310.JavaTimeModule());
                m.disable(com.fasterxml.jackson.databind.SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);
            }));
        });

        // Health check
        app.get("/api/health", ctx -> ctx.json(Map.of("status", "ok")));

        // ---------- Projects ----------
        app.get("/api/projects", this::getAllProjects);
        app.post("/api/projects", this::addProject);
        app.put("/api/projects", this::updateProject);
        app.delete("/api/projects", this::deleteProject);

        // ---------- Git Operations ----------
        app.get("/api/git/status", this::getStatus);
        app.get("/api/git/sync-status", this::getSyncStatus);
        app.get("/api/git/branches", this::getBranches);
        app.get("/api/git/commits", this::getCommits);
        app.get("/api/git/graph", this::getCommitGraph);
        app.get("/api/git/changes", this::getFileChanges);
        app.get("/api/git/tags", this::getTags);
        app.get("/api/git/stashes", this::getStashes);
        app.get("/api/git/reflog", this::getReflog);
        app.get("/api/git/file-content", this::getFileContent);
        app.get("/api/git/file-content-head", this::getFileContentHead);
        app.get("/api/git/file-diff", this::getFileDiff);

        app.post("/api/git/commit", this::doCommit);
        app.post("/api/git/commit-staged", this::doCommitStaged);
        app.post("/api/git/stage", this::doStage);
        app.post("/api/git/unstage", this::doUnstage);
        app.post("/api/git/push", this::doPush);
        app.post("/api/git/pull", this::doPull);
        app.post("/api/git/fetch", this::doFetch);
        app.post("/api/git/checkout", this::doCheckout);
        app.post("/api/git/create-branch", this::doCreateBranch);
        app.post("/api/git/create-tag", this::doCreateTag);
        app.post("/api/git/stash-save", this::doStashSave);
        app.post("/api/git/stash-pop", this::doStashPop);
        app.post("/api/git/stash-apply", this::doStashApply);
        app.post("/api/git/reset", this::doReset);
        app.delete("/api/git/branch", this::doDeleteBranch);
        app.delete("/api/git/tag", this::doDeleteTag);
        app.post("/api/git/amend", this::doAmend);
        app.post("/api/git/stash-drop", this::doStashDrop);
        app.post("/api/git/merge", this::doMerge);
        app.post("/api/git/cherry-pick", this::doCherryPick);
        app.post("/api/git/rebase", this::doRebase);
        app.get("/api/git/remotes", this::getRemotes);
        app.post("/api/git/clone", this::doClone);

        app.start(port);
        System.out.println("Git Manager REST API running on http://localhost:" + port);
    }

    public void stop() {
        if (app != null) {
            app.stop();
        }
    }

    // ========== Project Endpoints ==========

    private void getAllProjects(Context ctx) {
        List<GitProject> projects = projectService.loadAllProjects();
        ctx.json(projects);
    }

    private void addProject(Context ctx) {
        try {
            Map<String, String> body = mapper.readValue(ctx.body(), Map.class);
            String name = body.get("name");
            String path = body.get("path");
            String notes = body.getOrDefault("notes", "");
            GitProject project = projectService.addProject(name, path, notes);
            ctx.json(project);
        } catch (IllegalArgumentException e) {
            ctx.status(HttpStatus.BAD_REQUEST).json(Map.of("error", e.getMessage()));
        } catch (Exception e) {
            ctx.status(HttpStatus.INTERNAL_SERVER_ERROR).json(Map.of("error", e.getMessage()));
        }
    }

    private void updateProject(Context ctx) {
        try {
            GitProject project = mapper.readValue(ctx.body(), GitProject.class);
            GitProject updated = projectService.updateProject(project);
            ctx.json(updated);
        } catch (Exception e) {
            ctx.status(HttpStatus.BAD_REQUEST).json(Map.of("error", e.getMessage()));
        }
    }

    private void deleteProject(Context ctx) {
        String path = ctx.queryParam("path");
        if (path == null || path.isBlank()) {
            ctx.status(HttpStatus.BAD_REQUEST).json(Map.of("error", "path query param is required"));
            return;
        }
        projectService.deleteProject(path);
        ctx.json(Map.of("success", true));
    }

    // ========== Git Status Endpoints ==========

    private String requirePath(Context ctx) {
        String path = ctx.queryParam("path");
        if (path == null || path.isBlank()) {
            ctx.status(HttpStatus.BAD_REQUEST).json(Map.of("error", "path query param is required"));
            return null;
        }
        return path;
    }

    private void getStatus(Context ctx) {
        String path = requirePath(ctx);
        if (path == null) return;
        String branch = gitService.getCurrentBranch(path);
        String summary = gitService.getStatusSummary(path);
        String head = gitService.getHeadCommitId(path);
        String remote = gitService.getRemoteOriginUrl(path);
        ctx.json(Map.of(
                "branch", branch,
                "summary", summary,
                "head", head != null ? head : "",
                "remote", remote != null ? remote : ""
        ));
    }

    private void getSyncStatus(Context ctx) {
        String path = requirePath(ctx);
        if (path == null) return;
        ctx.json(gitService.getSyncStatus(path));
    }

    private void getBranches(Context ctx) {
        String path = requirePath(ctx);
        if (path == null) return;
        List<BranchInfo> branches = gitService.getBranchesInfo(path);
        ctx.json(branches);
    }

    private void getCommits(Context ctx) {
        String path = requirePath(ctx);
        if (path == null) return;
        int limit = ctx.queryParamAsClass("limit", Integer.class).getOrDefault(20);
        List<String> commits = gitService.getRecentCommits(path, limit);
        ctx.json(commits);
    }

    private void getCommitGraph(Context ctx) {
        String path = requirePath(ctx);
        if (path == null) return;
        int limit = ctx.queryParamAsClass("limit", Integer.class).getOrDefault(60);
        List<GitCommit> graph = gitService.getCommitGraph(path, limit);
        ctx.json(graph);
    }

    private void getFileChanges(Context ctx) {
        String path = requirePath(ctx);
        if (path == null) return;
        List<GitFileChange> changes = gitService.getFileChanges(path);
        ctx.json(changes);
    }

    private void getTags(Context ctx) {
        String path = requirePath(ctx);
        if (path == null) return;
        List<String> tags = gitService.getTags(path);
        ctx.json(tags);
    }

    private void getStashes(Context ctx) {
        String path = requirePath(ctx);
        if (path == null) return;
        List<String> stashes = gitService.getStashes(path);
        ctx.json(stashes);
    }

    private void getReflog(Context ctx) {
        String path = requirePath(ctx);
        if (path == null) return;
        List<String> reflog = gitService.getReflog(path);
        ctx.json(reflog);
    }

    private void getFileContent(Context ctx) {
        String path = requirePath(ctx);
        String file = ctx.queryParam("file");
        if (path == null) return;
        if (file == null || file.isBlank()) {
            ctx.status(HttpStatus.BAD_REQUEST).json(Map.of("error", "file query param is required"));
            return;
        }
        ctx.result(gitService.getFileContent(path, file));
    }

    private void getFileContentHead(Context ctx) {
        String path = requirePath(ctx);
        String file = ctx.queryParam("file");
        if (path == null) return;
        if (file == null || file.isBlank()) {
            ctx.status(HttpStatus.BAD_REQUEST).json(Map.of("error", "file query param is required"));
            return;
        }
        ctx.result(gitService.getFileContentHead(path, file));
    }

    private void getFileDiff(Context ctx) {
        String path = requirePath(ctx);
        String file = ctx.queryParam("file");
        boolean staged = ctx.queryParamAsClass("staged", Boolean.class).getOrDefault(false);
        if (path == null) return;
        if (file == null || file.isBlank()) {
            ctx.status(HttpStatus.BAD_REQUEST).json(Map.of("error", "file query param is required"));
            return;
        }
        ctx.result(gitService.getFileDiff(path, file, staged));
    }

    // ========== Git Action Endpoints ==========

    private void doCommit(Context ctx) {
        try {
            Map<String, Object> body = mapper.readValue(ctx.body(), Map.class);
            String path = (String) body.get("path");
            String message = (String) body.get("message");
            List<String> files = (List<String>) body.get("files");
            String author = (String) body.getOrDefault("authorName", "");
            String email = (String) body.getOrDefault("authorEmail", "");
            String result = gitService.commitSelected(path, message, files, author, email);
            ctx.json(Map.of("result", result));
        } catch (Exception e) {
            ctx.status(HttpStatus.BAD_REQUEST).json(Map.of("error", e.getMessage()));
        }
    }

    private void doCommitStaged(Context ctx) {
        try {
            Map<String, String> body = mapper.readValue(ctx.body(), Map.class);
            String path = body.get("path");
            String message = body.get("message");
            String author = body.getOrDefault("authorName", "");
            String email = body.getOrDefault("authorEmail", "");
            String result = gitService.commitStaged(path, message, author, email);
            ctx.json(Map.of("result", result));
        } catch (Exception e) {
            ctx.status(HttpStatus.BAD_REQUEST).json(Map.of("error", e.getMessage()));
        }
    }

    private void doStage(Context ctx) {
        try {
            Map<String, Object> body = mapper.readValue(ctx.body(), Map.class);
            String path = (String) body.get("path");
            List<String> files = (List<String>) body.get("files");
            String result = gitService.stageFiles(path, files);
            ctx.json(Map.of("result", result));
        } catch (Exception e) {
            ctx.status(HttpStatus.BAD_REQUEST).json(Map.of("error", e.getMessage()));
        }
    }

    private void doUnstage(Context ctx) {
        try {
            Map<String, Object> body = mapper.readValue(ctx.body(), Map.class);
            String path = (String) body.get("path");
            List<String> files = (List<String>) body.get("files");
            String result = gitService.unstageFiles(path, files);
            ctx.json(Map.of("result", result));
        } catch (Exception e) {
            ctx.status(HttpStatus.BAD_REQUEST).json(Map.of("error", e.getMessage()));
        }
    }

    private void doPush(Context ctx) {
        try {
            Map<String, String> body = mapper.readValue(ctx.body(), Map.class);
            String result = gitService.push(body.get("path"), body.get("username"), body.get("password"));
            ctx.json(Map.of("result", result));
        } catch (Exception e) {
            ctx.status(HttpStatus.BAD_REQUEST).json(Map.of("error", e.getMessage()));
        }
    }

    private void doPull(Context ctx) {
        try {
            Map<String, String> body = mapper.readValue(ctx.body(), Map.class);
            String result = gitService.pull(body.get("path"), body.get("username"), body.get("password"));
            ctx.json(Map.of("result", result));
        } catch (Exception e) {
            ctx.status(HttpStatus.BAD_REQUEST).json(Map.of("error", e.getMessage()));
        }
    }

    private void doFetch(Context ctx) {
        try {
            Map<String, String> body = mapper.readValue(ctx.body(), Map.class);
            String result = gitService.fetch(body.get("path"), body.get("username"), body.get("password"));
            ctx.json(Map.of("result", result));
        } catch (Exception e) {
            ctx.status(HttpStatus.BAD_REQUEST).json(Map.of("error", e.getMessage()));
        }
    }

    private void doCheckout(Context ctx) {
        try {
            Map<String, String> body = mapper.readValue(ctx.body(), Map.class);
            String result = gitService.checkout(body.get("path"), body.get("branch"));
            ctx.json(Map.of("result", result));
        } catch (Exception e) {
            ctx.status(HttpStatus.BAD_REQUEST).json(Map.of("error", e.getMessage()));
        }
    }

    private void doCreateBranch(Context ctx) {
        try {
            Map<String, String> body = mapper.readValue(ctx.body(), Map.class);
            String result = gitService.createBranch(body.get("path"), body.get("branch"));
            ctx.json(Map.of("result", result));
        } catch (Exception e) {
            ctx.status(HttpStatus.BAD_REQUEST).json(Map.of("error", e.getMessage()));
        }
    }

    private void doCreateTag(Context ctx) {
        try {
            Map<String, String> body = mapper.readValue(ctx.body(), Map.class);
            String result = gitService.createTag(body.get("path"), body.get("name"), body.get("message"));
            ctx.json(Map.of("result", result));
        } catch (Exception e) {
            ctx.status(HttpStatus.BAD_REQUEST).json(Map.of("error", e.getMessage()));
        }
    }

    private void doStashSave(Context ctx) {
        try {
            Map<String, String> body = mapper.readValue(ctx.body(), Map.class);
            String result = gitService.stashSave(body.get("path"), body.get("message"));
            ctx.json(Map.of("result", result));
        } catch (Exception e) {
            ctx.status(HttpStatus.BAD_REQUEST).json(Map.of("error", e.getMessage()));
        }
    }

    private void doStashPop(Context ctx) {
        try {
            Map<String, Object> body = mapper.readValue(ctx.body(), Map.class);
            String path = (String) body.get("path");
            int index = ((Number) body.getOrDefault("index", 0)).intValue();
            String result = gitService.stashPop(path, index);
            ctx.json(Map.of("result", result));
        } catch (Exception e) {
            ctx.status(HttpStatus.BAD_REQUEST).json(Map.of("error", e.getMessage()));
        }
    }

    private void doStashApply(Context ctx) {
        try {
            Map<String, Object> body = mapper.readValue(ctx.body(), Map.class);
            String path = (String) body.get("path");
            int index = ((Number) body.getOrDefault("index", 0)).intValue();
            String result = gitService.stashApply(path, index);
            ctx.json(Map.of("result", result));
        } catch (Exception e) {
            ctx.status(HttpStatus.BAD_REQUEST).json(Map.of("error", e.getMessage()));
        }
    }

    private void doReset(Context ctx) {
        try {
            Map<String, String> body = mapper.readValue(ctx.body(), Map.class);
            String result = gitService.reset(body.get("path"), body.get("commitId"), body.get("mode"));
            ctx.json(Map.of("result", result));
        } catch (Exception e) {
            ctx.status(HttpStatus.BAD_REQUEST).json(Map.of("error", e.getMessage()));
        }
    }

    private void doDeleteBranch(Context ctx) {
        try {
            String path = ctx.queryParam("path");
            String branch = ctx.queryParam("branch");
            String result = gitService.deleteBranch(path, branch);
            ctx.json(Map.of("result", result));
        } catch (Exception e) {
            ctx.status(HttpStatus.BAD_REQUEST).json(Map.of("error", e.getMessage()));
        }
    }

    private void doDeleteTag(Context ctx) {
        try {
            String path = ctx.queryParam("path");
            String name = ctx.queryParam("name");
            String result = gitService.deleteTag(path, name);
            ctx.json(Map.of("result", result));
        } catch (Exception e) {
            ctx.status(HttpStatus.BAD_REQUEST).json(Map.of("error", e.getMessage()));
        }
    }

    private void doAmend(Context ctx) {
        try {
            Map<String, String> body = mapper.readValue(ctx.body(), Map.class);
            String result = gitService.amendCommit(body.get("path"), body.get("message"), body.get("authorName"), body.get("authorEmail"));
            ctx.json(Map.of("result", result));
        } catch (Exception e) {
            ctx.status(HttpStatus.BAD_REQUEST).json(Map.of("error", e.getMessage()));
        }
    }

    private void doStashDrop(Context ctx) {
        try {
            Map<String, Object> body = mapper.readValue(ctx.body(), Map.class);
            String path = (String) body.get("path");
            int index = ((Number) body.getOrDefault("index", 0)).intValue();
            String result = gitService.stashDrop(path, index);
            ctx.json(Map.of("result", result));
        } catch (Exception e) {
            ctx.status(HttpStatus.BAD_REQUEST).json(Map.of("error", e.getMessage()));
        }
    }

    private void doMerge(Context ctx) {
        try {
            Map<String, String> body = mapper.readValue(ctx.body(), Map.class);
            String result = gitService.merge(body.get("path"), body.get("branch"));
            ctx.json(Map.of("result", result));
        } catch (Exception e) {
            ctx.status(HttpStatus.BAD_REQUEST).json(Map.of("error", e.getMessage()));
        }
    }

    private void doCherryPick(Context ctx) {
        try {
            Map<String, String> body = mapper.readValue(ctx.body(), Map.class);
            String result = gitService.cherryPick(body.get("path"), body.get("commitId"));
            ctx.json(Map.of("result", result));
        } catch (Exception e) {
            ctx.status(HttpStatus.BAD_REQUEST).json(Map.of("error", e.getMessage()));
        }
    }

    private void doRebase(Context ctx) {
        try {
            Map<String, String> body = mapper.readValue(ctx.body(), Map.class);
            String result = gitService.rebase(body.get("path"), body.get("branch"));
            ctx.json(Map.of("result", result));
        } catch (Exception e) {
            ctx.status(HttpStatus.BAD_REQUEST).json(Map.of("error", e.getMessage()));
        }
    }

    private void getRemotes(Context ctx) {
        String path = requirePath(ctx);
        if (path == null) return;
        ctx.json(gitService.getRemotes(path));
    }

    private void doClone(Context ctx) {
        try {
            Map<String, String> body = mapper.readValue(ctx.body(), Map.class);
            String result = gitService.cloneRepo(body.get("remoteUrl"), body.get("localPath"), body.get("username"), body.get("password"));
            ctx.json(Map.of("result", result));
        } catch (Exception e) {
            ctx.status(HttpStatus.BAD_REQUEST).json(Map.of("error", e.getMessage()));
        }
    }
}
