package com.gitmanager.model;

public class BranchInfo {

    private final String name;
    private final String commitId;
    private final boolean remote;
    private final boolean head;

    public BranchInfo(String name, String commitId, boolean remote, boolean head) {
        this.name = name;
        this.commitId = commitId;
        this.remote = remote;
        this.head = head;
    }

    public String getName() { return name; }
    public String getCommitId() { return commitId; }
    public boolean isRemote() { return remote; }
    public boolean isHead() { return head; }

    @Override
    public String toString() {
        return name + (remote ? " (remoto)" : "");
    }
}
