package com.gitmanager.ui.timeline;

import com.gitmanager.model.GitCommit;
import com.gitmanager.service.GitService;
import com.gitmanager.ui.theme.ThemeManager;
import javafx.application.Platform;
import javafx.geometry.Insets;
import javafx.geometry.Point2D;
import javafx.geometry.Pos;
import javafx.scene.canvas.Canvas;
import javafx.scene.canvas.GraphicsContext;
import javafx.scene.control.Label;
import javafx.scene.control.ScrollPane;
import javafx.scene.control.Tooltip;
import javafx.scene.input.MouseEvent;
import javafx.scene.layout.*;
import javafx.scene.paint.Color;
import javafx.scene.text.Font;
import javafx.scene.text.FontWeight;
import javafx.scene.text.TextAlignment;

import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.*;

public class GitTimelinePanel extends BorderPane {

    private static final int LANE_WIDTH = 32;
    private static final int ROW_HEIGHT = 34;
    private static final int LEFT_MARGIN = 110;
    private static final int TOP_MARGIN = 16;
    private static final int RIGHT_MARGIN = 40;
    private static final int BOTTOM_MARGIN = 20;
    private static final int NODE_RADIUS = 5;

    private final String repoPath;
    private final GitService gitService;
    private final Canvas canvas;
    private final Pane canvasContainer;
    private final Tooltip tooltip;

    private List<GitCommit> commits = new ArrayList<>();
    private Map<String, Integer> commitIndexMap = new HashMap<>();
    private Map<String, Integer> commitLaneMap = new HashMap<>();
    private Map<String, Color> branchColorMap = new HashMap<>();
    private int maxLane = 0;
    private boolean isDark = false;

    private static final List<String> BRANCH_PRIORITY = List.of("main", "master", "develop", "dev");
    private static final Map<String, String> NAMED_COLORS = new LinkedHashMap<>();
    static {
        NAMED_COLORS.put("main", "#f85149");
        NAMED_COLORS.put("master", "#f85149");
        NAMED_COLORS.put("develop", "#2ea043");
        NAMED_COLORS.put("dev", "#2ea043");
        NAMED_COLORS.put("feature", "#79c0ff");
        NAMED_COLORS.put("hotfix", "#d7ba7d");
        NAMED_COLORS.put("release", "#bc8cff");
        NAMED_COLORS.put("origin/main", "#ff9f9f");
        NAMED_COLORS.put("origin/master", "#ff9f9f");
        NAMED_COLORS.put("origin/develop", "#7ee787");
    }

    private final DateTimeFormatter dateFormatter = DateTimeFormatter.ofPattern("dd/MM HH:mm")
            .withZone(ZoneId.systemDefault());

    public GitTimelinePanel(String repoPath, GitService gitService) {
        this.repoPath = repoPath;
        this.gitService = gitService;
        this.isDark = ThemeManager.isDark();

        canvas = new Canvas(800, 400);
        canvasContainer = new Pane(canvas);
        canvasContainer.setPrefSize(800, 400);

        ScrollPane scroll = new ScrollPane(canvasContainer);
        scroll.setFitToWidth(false);
        scroll.setFitToHeight(false);
        scroll.setPannable(true);
        scroll.getStyleClass().add("gm-timeline-bg");

        tooltip = new Tooltip();
        tooltip.setAutoHide(true);
        tooltip.setWrapText(true);
        tooltip.setMaxWidth(350);

        setCenter(scroll);
        setPrefHeight(320);

        canvas.addEventHandler(MouseEvent.MOUSE_MOVED, this::onMouseMoved);
        canvas.addEventHandler(MouseEvent.MOUSE_EXITED, e -> tooltip.hide());

        loadData();
    }

    private void loadData() {
        new Thread(() -> {
            List<GitCommit> data = gitService.getCommitGraph(repoPath, 60);
            Platform.runLater(() -> {
                this.commits = data != null ? data : new ArrayList<>();
                buildIndexMap();
                assignLanes();
                computeBranchColors();
                resizeCanvas();
                draw();
            });
        }).start();
    }

    private void buildIndexMap() {
        commitIndexMap.clear();
        for (int i = 0; i < commits.size(); i++) {
            commitIndexMap.put(commits.get(i).getId(), i);
        }
    }

    private void assignLanes() {
        commitLaneMap.clear();
        maxLane = 0;

        // Assign branch priorities and lanes
        Map<String, Integer> branchLane = new LinkedHashMap<>();
        Set<String> seenBranches = new LinkedHashSet<>();

        // Collect branch names ordered by priority
        for (GitCommit c : commits) {
            for (String b : c.getBranchNames()) {
                String bare = bareBranchName(b);
                seenBranches.add(bare);
            }
        }

        List<String> ordered = new ArrayList<>(seenBranches);
        ordered.sort(this::compareBranchPriority);

        for (String b : ordered) {
            if (!branchLane.containsKey(b)) {
                branchLane.put(b, maxLane++);
            }
        }

        // Assign lanes to commits from oldest to newest (reverse list)
        for (int i = commits.size() - 1; i >= 0; i--) {
            GitCommit c = commits.get(i);
            int lane = -1;

            // If commit has branches, pick the highest priority (lowest lane number)
            for (String b : c.getBranchNames()) {
                String bare = bareBranchName(b);
                Integer l = branchLane.get(bare);
                if (l != null) {
                    if (lane == -1 || l < lane) {
                        lane = l;
                    }
                }
            }

            // Otherwise inherit from first parent
            if (lane == -1 && !c.getParentIds().isEmpty()) {
                Integer parentLane = commitLaneMap.get(c.getParentIds().get(0));
                if (parentLane != null) {
                    lane = parentLane;
                }
            }

            if (lane == -1) {
                lane = 0;
            }
            commitLaneMap.put(c.getId(), lane);
        }
    }

    private String bareBranchName(String branchLabel) {
        if (branchLabel == null) return "";
        String s = branchLabel.trim();
        if (s.endsWith(" (remoto)")) {
            s = s.substring(0, s.length() - " (remoto)".length()).trim();
        }
        return s;
    }

    private int compareBranchPriority(String a, String b) {
        int ia = indexOfPriority(a);
        int ib = indexOfPriority(b);
        if (ia != ib) return Integer.compare(ia, ib);
        // Locais before remotes
        boolean ra = a.startsWith("origin/");
        boolean rb = b.startsWith("origin/");
        if (ra != rb) return ra ? 1 : -1;
        return a.compareToIgnoreCase(b);
    }

    private int indexOfPriority(String name) {
        String lower = name.toLowerCase();
        for (int i = 0; i < BRANCH_PRIORITY.size(); i++) {
            if (lower.equals(BRANCH_PRIORITY.get(i))) return i;
        }
        return Integer.MAX_VALUE;
    }

    private void computeBranchColors() {
        branchColorMap.clear();
        Set<String> seen = new LinkedHashSet<>();
        for (GitCommit c : commits) {
            for (String b : c.getBranchNames()) {
                seen.add(bareBranchName(b));
            }
        }
        List<String> ordered = new ArrayList<>(seen);
        ordered.sort(this::compareBranchPriority);

        int unnamedIndex = 0;
        for (String b : ordered) {
            String hex = NAMED_COLORS.get(b.toLowerCase());
            if (hex != null) {
                branchColorMap.put(b, Color.web(hex));
            } else {
                // Distribute hues sequentially using a prime step to avoid collisions
                float hue = (unnamedIndex * 47.0f) % 360f;
                float sat = 0.72f;
                float bri = isDark ? 0.88f : 0.58f;
                branchColorMap.put(b, Color.hsb(hue, sat, bri));
                unnamedIndex++;
            }
        }
    }

    private void resizeCanvas() {
        int lanes = Math.max(maxLane + 1, 1);
        double w = LEFT_MARGIN + lanes * LANE_WIDTH + RIGHT_MARGIN + 400; // extra for text
        double h = TOP_MARGIN + commits.size() * ROW_HEIGHT + BOTTOM_MARGIN;
        canvas.setWidth(w);
        canvas.setHeight(h);
        canvasContainer.setPrefSize(w, h);
    }

    private void draw() {
        GraphicsContext g = canvas.getGraphicsContext2D();
        double w = canvas.getWidth();
        double h = canvas.getHeight();

        // Background
        g.setFill(isDark ? Color.web("#2b2b2b") : Color.web("#ffffff"));
        g.fillRect(0, 0, w, h);

        // Draw connections first (behind nodes)
        g.setLineWidth(1.8);
        for (int i = 0; i < commits.size(); i++) {
            GitCommit child = commits.get(i);
            Point2D childPos = commitPos(i);
            int childLane = commitLaneMap.getOrDefault(child.getId(), 0);

            for (String parentId : child.getParentIds()) {
                Integer pi = commitIndexMap.get(parentId);
                if (pi == null) continue;
                Point2D parentPos = commitPos(pi);
                int parentLane = commitLaneMap.getOrDefault(parentId, 0);

                Color lineColor = pickLineColor(child, childLane, parentLane);
                g.setStroke(lineColor);

                if (childLane == parentLane) {
                    g.strokeLine(childPos.getX(), childPos.getY(), parentPos.getX(), parentPos.getY());
                } else {
                    // Bezier curve
                    double midY = (childPos.getY() + parentPos.getY()) / 2.0;
                    g.beginPath();
                    g.moveTo(childPos.getX(), childPos.getY());
                    g.bezierCurveTo(childPos.getX(), midY, parentPos.getX(), midY, parentPos.getX(), parentPos.getY());
                    g.stroke();
                }
            }
        }

        // Draw lane guides (subtle vertical lines)
        g.setStroke(isDark ? Color.web("#3e3e42", 0.3) : Color.web("#dee2e6", 0.6));
        g.setLineWidth(1);
        int lanes = Math.max(maxLane + 1, 1);
        for (int lane = 0; lane < lanes; lane++) {
            double x = LEFT_MARGIN + lane * LANE_WIDTH;
            g.strokeLine(x, TOP_MARGIN, x, h - BOTTOM_MARGIN);
        }

        // Draw commits and text
        for (int i = 0; i < commits.size(); i++) {
            GitCommit c = commits.get(i);
            Point2D pos = commitPos(i);
            int lane = commitLaneMap.getOrDefault(c.getId(), 0);

            // Node color
            Color nodeColor = pickNodeColor(c, lane);
            g.setFill(nodeColor);
            g.fillOval(pos.getX() - NODE_RADIUS, pos.getY() - NODE_RADIUS, NODE_RADIUS * 2, NODE_RADIUS * 2);

            // HEAD ring
            if (c.isHead()) {
                g.setStroke(isDark ? Color.WHITE : Color.BLACK);
                g.setLineWidth(2);
                g.strokeOval(pos.getX() - NODE_RADIUS - 3, pos.getY() - NODE_RADIUS - 3,
                        NODE_RADIUS * 2 + 6, NODE_RADIUS * 2 + 6);
            }

            // Branch labels on left side (first occurrence only)
            for (String b : c.getBranchNames()) {
                String bare = bareBranchName(b);
                Color bc = branchColorMap.getOrDefault(bare, isDark ? Color.LIGHTGRAY : Color.DARKGRAY);
                double labelX = LEFT_MARGIN + lane * LANE_WIDTH - 6;
                double labelY = pos.getY() - 5;
                g.setFill(bc);
                g.fillRoundRect(labelX - 80, labelY - 8, 78, 16, 6, 6);
                g.setFill(isDark ? Color.BLACK : Color.WHITE);
                g.setFont(Font.font("System", FontWeight.BOLD, 9));
                g.setTextAlign(TextAlignment.RIGHT);
                g.fillText(bare, labelX - 6, labelY + 3);
                g.setTextAlign(TextAlignment.LEFT);
            }

            // Text: hash and message
            double textX = LEFT_MARGIN + lanes * LANE_WIDTH + 10;
            g.setFill(isDark ? Color.web("#a0a0a0") : Color.web("#6c757d"));
            g.setFont(Font.font("Monospaced", 11));
            g.fillText(c.getShortId(), textX, pos.getY() + 4);

            g.setFill(isDark ? Color.web("#e0e0e0") : Color.web("#212529"));
            g.setFont(Font.font("System", 12));
            String msg = c.getMessage();
            if (msg.length() > 60) msg = msg.substring(0, 57) + "...";
            g.fillText(msg, textX + 60, pos.getY() + 4);
        }
    }

    private Point2D commitPos(int index) {
        int lane = commitLaneMap.getOrDefault(commits.get(index).getId(), 0);
        double x = LEFT_MARGIN + lane * LANE_WIDTH;
        double y = TOP_MARGIN + index * ROW_HEIGHT + ROW_HEIGHT / 2.0;
        return new Point2D(x, y);
    }

    private Color pickNodeColor(GitCommit c, int lane) {
        if (!c.getBranchNames().isEmpty()) {
            String bare = bareBranchName(c.getBranchNames().get(0));
            return branchColorMap.getOrDefault(bare, isDark ? Color.LIGHTGRAY : Color.DARKGRAY);
        }
        return isDark ? Color.web("#a0a0a0") : Color.web("#6c757d");
    }

    private Color pickLineColor(GitCommit child, int childLane, int parentLane) {
        // Try to match branch color of child or parent lane
        if (!child.getBranchNames().isEmpty()) {
            String bare = bareBranchName(child.getBranchNames().get(0));
            Color bc = branchColorMap.get(bare);
            if (bc != null) return bc;
        }
        return isDark ? Color.web("#555555") : Color.web("#adb5bd");
    }

    private void onMouseMoved(MouseEvent e) {
        double mx = e.getX();
        double my = e.getY();
        GitCommit hovered = null;
        for (int i = 0; i < commits.size(); i++) {
            Point2D p = commitPos(i);
            double dx = mx - p.getX();
            double dy = my - p.getY();
            if (dx * dx + dy * dy <= (NODE_RADIUS + 4) * (NODE_RADIUS + 4)) {
                hovered = commits.get(i);
                break;
            }
        }
        if (hovered != null) {
            StringBuilder sb = new StringBuilder();
            sb.append("Commit: ").append(hovered.getShortId()).append("\n");
            sb.append("Autor: ").append(hovered.getAuthorName()).append("\n");
            sb.append("Data: ").append(dateFormatter.format(hovered.getCommitTime())).append("\n");
            if (!hovered.getBranchNames().isEmpty()) {
                sb.append("Branches: ").append(String.join(", ", hovered.getBranchNames())).append("\n");
            }
            if (hovered.isHead()) {
                sb.append("★ HEAD atual\n");
            }
            sb.append("\n").append(hovered.getMessage());
            tooltip.setText(sb.toString());

            tooltip.show(canvas, e.getScreenX() + 14, e.getScreenY() + 14);
        } else {
            tooltip.hide();
        }
    }
}
