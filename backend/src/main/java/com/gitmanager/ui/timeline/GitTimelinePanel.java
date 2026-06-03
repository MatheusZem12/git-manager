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
import javafx.scene.shape.StrokeLineCap;
import javafx.scene.shape.StrokeLineJoin;
import javafx.scene.text.Font;
import javafx.scene.text.FontWeight;
import javafx.scene.text.Text;
import javafx.scene.text.TextAlignment;

import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.*;

/**
 * Painel de timeline gráfica de commits com Canvas.
 * Visual premium com glow suave, gradientes e interatividade refinada.
 */
public class GitTimelinePanel extends BorderPane {

    private static final int LANE_WIDTH = 60;
    private static final int ROW_HEIGHT = 72;
    private static final int LEFT_MARGIN = 170;
    private static final int TOP_MARGIN = 40;
    private static final int RIGHT_MARGIN = 70;
    private static final int BOTTOM_MARGIN = 40;
    private static final int NODE_RADIUS = 10;
    private static final int NODE_GLOW_RADIUS = 18;

    private final String repoPath;
    private final GitService gitService;
    private final Canvas canvas;
    private final Pane canvasContainer;
    private final Tooltip tooltip;
    private final StackPane centeredWrapper;

    private List<GitCommit> commits = new ArrayList<>();
    private Map<String, Integer> commitIndexMap = new HashMap<>();
    private Map<String, Integer> commitLaneMap = new HashMap<>();
    private Map<String, Color> branchColorMap = new HashMap<>();
    private int maxLane = 0;
    private boolean isDark = false;
    private double offsetX = LEFT_MARGIN;

    private static final List<String> BRANCH_PRIORITY = List.of("main", "master", "develop", "dev");
    private static final Map<String, String> NAMED_COLORS = new LinkedHashMap<>();
    static {
        NAMED_COLORS.put("main", "#f97316");
        NAMED_COLORS.put("master", "#f97316");
        NAMED_COLORS.put("develop", "#22c55e");
        NAMED_COLORS.put("dev", "#22c55e");
        NAMED_COLORS.put("feature", "#3b82f6");
        NAMED_COLORS.put("hotfix", "#eab308");
        NAMED_COLORS.put("release", "#a855f7");
        NAMED_COLORS.put("origin/main", "#fb923c");
        NAMED_COLORS.put("origin/master", "#fb923c");
        NAMED_COLORS.put("origin/develop", "#4ade80");
    }

    private final DateTimeFormatter dateFormatter = DateTimeFormatter.ofPattern("dd/MM/yy HH:mm")
            .withZone(ZoneId.systemDefault());

    public GitTimelinePanel(String repoPath, GitService gitService) {
        this.repoPath = repoPath;
        this.gitService = gitService;
        this.isDark = true;

        canvas = new Canvas(900, 500);
        canvasContainer = new Pane(canvas);
        canvasContainer.setPrefSize(900, 500);

        centeredWrapper = new StackPane(canvasContainer);
        centeredWrapper.setAlignment(Pos.CENTER);
        centeredWrapper.getStyleClass().add("gm-timeline-bg");

        ScrollPane scroll = new ScrollPane(centeredWrapper);
        scroll.setFitToWidth(false);
        scroll.setFitToHeight(false);
        scroll.setPannable(true);
        scroll.getStyleClass().add("gm-timeline-bg");
        scroll.setStyle("-fx-background-color: transparent;");

        tooltip = new Tooltip();
        tooltip.setAutoHide(true);
        tooltip.setWrapText(true);
        tooltip.setMaxWidth(420);
        tooltip.setStyle("-fx-font-size: 12.5px; -fx-padding: 12 16;");

        setCenter(scroll);
        setPrefHeight(500);

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

        Map<String, Integer> branchLane = new LinkedHashMap<>();
        Set<String> seenBranches = new LinkedHashSet<>();

        for (GitCommit c : commits) {
            for (String b : c.getBranchNames()) {
                String bare = bareBranchName(b);
                seenBranches.add(bare);
            }
        }

        List<String> ordered = new ArrayList<>(seenBranches);
        ordered.sort(this::compareBranchPriority);

        for (String b : ordered) {
            String key = b.toLowerCase();
            if (!branchLane.containsKey(key)) {
                branchLane.put(key, maxLane++);
            }
        }

        for (int i = commits.size() - 1; i >= 0; i--) {
            GitCommit c = commits.get(i);
            int lane = -1;

            for (String b : c.getBranchNames()) {
                String bare = bareBranchName(b);
                Integer l = branchLane.get(bare.toLowerCase());
                if (l != null) {
                    if (lane == -1 || l < lane) {
                        lane = l;
                    }
                }
            }

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
            String key = b.toLowerCase();
            String hex = NAMED_COLORS.get(key);
            if (hex != null) {
                branchColorMap.put(key, Color.web(hex));
            } else {
                float hue = (unnamedIndex * 47.0f) % 360f;
                if (hue < 25f) hue += 35f;
                else if (hue > 335f) hue -= 35f;
                float sat = 0.78f;
                float bri = isDark ? 0.85f : 0.55f;
                branchColorMap.put(key, Color.hsb(hue, sat, bri));
                unnamedIndex++;
            }
        }
    }

    private void resizeCanvas() {
        int lanes = Math.max(maxLane + 1, 1);
        double contentWidth = LEFT_MARGIN + lanes * LANE_WIDTH + 500;
        double minCanvasWidth = 1000;
        double w = Math.max(minCanvasWidth, contentWidth + RIGHT_MARGIN);
        double h = TOP_MARGIN + commits.size() * ROW_HEIGHT + BOTTOM_MARGIN;

        offsetX = (w - contentWidth) / 2.0 + LEFT_MARGIN / 2.0;
        if (offsetX < LEFT_MARGIN) {
            offsetX = LEFT_MARGIN;
        }

        canvas.setWidth(w);
        canvas.setHeight(h);
        canvasContainer.setPrefSize(w, h);
    }

    private void draw() {
        GraphicsContext g = canvas.getGraphicsContext2D();
        double w = canvas.getWidth();
        double h = canvas.getHeight();

        // Background — premium subtle pattern
        g.setFill(isDark ? Color.web("#0d0f12") : Color.web("#f3f4f6"));
        g.fillRect(0, 0, w, h);

        // Subtle dot grid pattern for premium feel
        g.setFill(isDark ? Color.web("#1a1d24", 0.4) : Color.web("#e5e7eb", 0.5));
        for (int x = 0; x < w; x += 24) {
            for (int y = 0; y < h; y += 24) {
                g.fillOval(x, y, 1.5, 1.5);
            }
        }

        int lanes = Math.max(maxLane + 1, 1);
        double textX = graphBaseX() + lanes * LANE_WIDTH + 32;

        // Subtle horizontal row separators
        g.setStroke(isDark ? Color.web("#2b303a", 0.5) : Color.web("#e2e8f0", 0.8));
        g.setLineWidth(1);
        for (int i = 0; i < commits.size(); i++) {
            double y = TOP_MARGIN + i * ROW_HEIGHT;
            g.strokeLine(graphBaseX() - 30, y + ROW_HEIGHT / 2.0, w - RIGHT_MARGIN + 30, y + ROW_HEIGHT / 2.0);
        }

        // Connections — thicker and with glow
        g.setLineCap(StrokeLineCap.ROUND);
        g.setLineJoin(StrokeLineJoin.ROUND);
        g.setLineWidth(3.5);
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
                Color lineColorTransparent = Color.color(lineColor.getRed(), lineColor.getGreen(), lineColor.getBlue(), 0.55);
                g.setStroke(lineColorTransparent);

                if (childLane == parentLane) {
                    g.strokeLine(childPos.getX(), childPos.getY(), parentPos.getX(), parentPos.getY());
                } else {
                    double midY = (childPos.getY() + parentPos.getY()) / 2.0;
                    g.beginPath();
                    g.moveTo(childPos.getX(), childPos.getY());
                    g.bezierCurveTo(childPos.getX(), midY, parentPos.getX(), midY, parentPos.getX(), parentPos.getY());
                    g.stroke();
                }
            }
        }

        // Commits
        for (int i = 0; i < commits.size(); i++) {
            GitCommit c = commits.get(i);
            Point2D pos = commitPos(i);
            int lane = commitLaneMap.getOrDefault(c.getId(), 0);

            Color nodeColor = pickNodeColor(c, lane);

            // Outer glow
            g.setFill(Color.color(nodeColor.getRed(), nodeColor.getGreen(), nodeColor.getBlue(), 0.15));
            g.fillOval(pos.getX() - NODE_GLOW_RADIUS, pos.getY() - NODE_GLOW_RADIUS,
                    NODE_GLOW_RADIUS * 2, NODE_GLOW_RADIUS * 2);

            // Main node
            g.setFill(nodeColor);
            g.fillOval(pos.getX() - NODE_RADIUS, pos.getY() - NODE_RADIUS,
                    NODE_RADIUS * 2, NODE_RADIUS * 2);

            // Inner highlight (glass effect)
            g.setFill(Color.web("#ffffff", 0.35));
            g.fillOval(pos.getX() - NODE_RADIUS + 2, pos.getY() - NODE_RADIUS + 2,
                    NODE_RADIUS * 2 - 6, NODE_RADIUS * 2 - 6);

            // Border
            g.setStroke(isDark ? Color.web("#ffffff", 0.85) : Color.web("#ffffff", 0.9));
            g.setLineWidth(2.5);
            g.strokeOval(pos.getX() - NODE_RADIUS, pos.getY() - NODE_RADIUS,
                    NODE_RADIUS * 2, NODE_RADIUS * 2);

            // HEAD indicator with glow
            if (c.isHead()) {
                g.setStroke(isDark ? Color.web("#fbbf24") : Color.web("#f59e0b"));
                g.setLineWidth(3.5);
                g.strokeOval(pos.getX() - NODE_RADIUS - 7, pos.getY() - NODE_RADIUS - 7,
                        NODE_RADIUS * 2 + 14, NODE_RADIUS * 2 + 14);

                g.setFill(isDark ? Color.web("#fbbf24") : Color.web("#f59e0b"));
                g.setFont(Font.font("Inter", FontWeight.BOLD, 13));
                g.fillText("★ HEAD", pos.getX() + NODE_RADIUS + 12, pos.getY() - NODE_RADIUS + 4);
            }

            // Branch pills — modern rounded badges
            for (String b : c.getBranchNames()) {
                String bare = bareBranchName(b);
                Color bc = branchColorMap.getOrDefault(bare, isDark ? Color.web("#a0aab8") : Color.web("#5f6775"));

                String text = bare;
                Font pillFont = Font.font("Inter", FontWeight.BOLD, 10.5);
                double tw = textWidth(text, pillFont);
                double pillW = Math.max(tw + 20, 48);
                double pillH = 24;
                double pillX = graphBaseX() + lane * LANE_WIDTH - 12;
                double pillY = pos.getY() - pillH / 2.0;

                // Shadow
                g.setFill(Color.color(0, 0, 0, 0.12));
                g.fillRoundRect(pillX - pillW + 2, pillY + 3, pillW, pillH, 12, 12);

                // Pill background
                g.setFill(bc);
                g.fillRoundRect(pillX - pillW, pillY, pillW, pillH, 12, 12);

                // Pill border
                g.setStroke(Color.color(bc.getRed(), bc.getGreen(), bc.getBlue(), 0.5).brighter());
                g.setLineWidth(1.2);
                g.strokeRoundRect(pillX - pillW, pillY, pillW, pillH, 12, 12);

                g.setFill(isDark ? Color.BLACK : Color.WHITE);
                g.setFont(pillFont);
                g.setTextAlign(TextAlignment.RIGHT);
                g.fillText(text, pillX - 10, pos.getY() + 4.5);
                g.setTextAlign(TextAlignment.LEFT);
            }

            // Hash
            g.setFill(isDark ? Color.web("#5e6a7a") : Color.web("#9ba3b0"));
            g.setFont(Font.font("JetBrains Mono", 11.5));
            g.fillText(c.getShortId(), textX, pos.getY() - 5);

            // Message
            g.setFill(isDark ? Color.web("#eceff4") : Color.web("#1a1d21"));
            g.setFont(Font.font("Inter", FontWeight.BOLD, 13.5));
            String msg = c.getMessage();
            if (msg.length() > 70) msg = msg.substring(0, 67) + "...";
            g.fillText(msg, textX + 75, pos.getY() - 5);

            // Metadata
            g.setFill(isDark ? Color.web("#a0aab8") : Color.web("#5f6775"));
            g.setFont(Font.font("Inter", 11.5));
            String meta = c.getAuthorName() + " · " + dateFormatter.format(c.getCommitTime());
            g.fillText(meta, textX + 75, pos.getY() + 18);
        }
    }

    private double graphBaseX() {
        return offsetX;
    }

    private Point2D commitPos(int index) {
        int lane = commitLaneMap.getOrDefault(commits.get(index).getId(), 0);
        double x = graphBaseX() + lane * LANE_WIDTH;
        double y = TOP_MARGIN + index * ROW_HEIGHT + ROW_HEIGHT / 2.0;
        return new Point2D(x, y);
    }

    private Color pickNodeColor(GitCommit c, int lane) {
        if (!c.getBranchNames().isEmpty()) {
            String bare = bareBranchName(c.getBranchNames().get(0)).toLowerCase();
            return branchColorMap.getOrDefault(bare, isDark ? Color.web("#a0aab8") : Color.web("#5f6775"));
        }
        return isDark ? Color.web("#a0aab8") : Color.web("#5f6775");
    }

    private Color pickLineColor(GitCommit child, int childLane, int parentLane) {
        if (!child.getBranchNames().isEmpty()) {
            String bare = bareBranchName(child.getBranchNames().get(0)).toLowerCase();
            Color bc = branchColorMap.get(bare);
            if (bc != null) return bc;
        }
        return isDark ? Color.web("#2b303a") : Color.web("#d1d5db");
    }

    private void onMouseMoved(MouseEvent e) {
        double mx = e.getX();
        double my = e.getY();
        GitCommit hovered = null;
        for (int i = 0; i < commits.size(); i++) {
            Point2D p = commitPos(i);
            double dx = mx - p.getX();
            double dy = my - p.getY();
            if (dx * dx + dy * dy <= (NODE_RADIUS + 8) * (NODE_RADIUS + 8)) {
                hovered = commits.get(i);
                break;
            }
        }
        if (hovered != null) {
            StringBuilder sb = new StringBuilder();
            sb.append(hovered.getShortId()).append("\n");
            sb.append(hovered.getMessage()).append("\n\n");
            sb.append("Autor: ").append(hovered.getAuthorName()).append("\n");
            sb.append("Data: ").append(dateFormatter.format(hovered.getCommitTime())).append("\n");
            if (!hovered.getBranchNames().isEmpty()) {
                sb.append("Branches: ").append(String.join(", ", hovered.getBranchNames())).append("\n");
            }
            if (hovered.isHead()) {
                sb.append("★ HEAD atual\n");
            }
            tooltip.setText(sb.toString());

            tooltip.show(canvas, e.getScreenX() + 18, e.getScreenY() + 18);
        } else {
            tooltip.hide();
        }
    }

    private double textWidth(String text, Font font) {
        Text t = new Text(text);
        t.setFont(font);
        return t.getLayoutBounds().getWidth();
    }
}
