package com.gitmanager.model;

import java.time.Instant;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class GitCommit {

    private final String id;
    private final String shortId;
    private final String message;
    private final String authorName;
    private final String authorEmail;
    private final Instant commitTime;
    private final List<String> parentIds;
    private final List<String> branchNames;
    private boolean head;

    public GitCommit(String id, String shortId, String message, String authorName,
                     String authorEmail, Instant commitTime, List<String> parentIds) {
        this.id = id;
        this.shortId = shortId;
        this.message = message;
        this.authorName = authorName;
        this.authorEmail = authorEmail;
        this.commitTime = commitTime;
        this.parentIds = parentIds != null ? new ArrayList<>(parentIds) : new ArrayList<>();
        this.branchNames = new ArrayList<>();
        this.head = false;
    }

    public String getId() { return id; }
    public String getShortId() { return shortId; }
    public String getMessage() { return message; }
    public String getAuthorName() { return authorName; }
    public String getAuthorEmail() { return authorEmail; }
    public Instant getCommitTime() { return commitTime; }
    public List<String> getParentIds() { return Collections.unmodifiableList(parentIds); }
    public List<String> getBranchNames() { return Collections.unmodifiableList(branchNames); }
    public boolean isHead() { return head; }

    public void addBranchName(String name) {
        if (!branchNames.contains(name)) {
            branchNames.add(name);
        }
    }

    public void setHead(boolean head) {
        this.head = head;
    }

    @Override
    public String toString() {
        return shortId + " - " + message;
    }
}
