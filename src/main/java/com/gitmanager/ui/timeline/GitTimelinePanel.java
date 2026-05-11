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

public class GitTimelinePanel extends BorderPane {

    private static final int LANE_WIDTH = 52;
    private static final int ROW_HEIGHT = 64;
    private static final int LEFT_MARGIN = 150;
    private static final int TOP_MARGIN = 32;
    private static final int RIGHT_MARGIN = 60;
    private static final int BOTTOM_MARGIN = 32;
    private static final int NODE_RADIUS = 8;
    private static final int NODE_GLOW_RADIUS = 14;

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
        // Paleta vibrante sem vermelho
        NAMED_COLORS.put("main", "#fd7e14");      // laranja vibrante
        NAMED_COLORS.put("master", "#fd7e14");    // laranja vibrante
        NAMED_COLORS.put("develop", "#40c057");   // verde vibrante
        NAMED_COLORS.put("dev", "#40c057");       // verde vibrante
        NAMED_COLORS.put("feature", "#4dabf7");   // azul céu
        NAMED_COLORS.put("hotfix", "#fcc419");    // amarelo/dourado
        NAMED_COLORS.put("release", "#be4bdb");   // roxo vibrante
        NAMED_COLORS.put("origin/main", "#ffa94d");
        NAMED_COLORS.put("origin/master", "#ffa94d");
        NAMED_COLORS.put("origin/develop", "#69db7c");
    }

    private final DateTimeFormatter dateFormatter = DateTimeFormatter.ofPattern("dd/MM/yy HH:mm")
            .withZone(ZoneId.systemDefault());

    public GitTimelinePanel(String repoPath, GitService gitService) {
        this.repoPath = repoPath;
        this.gitService = gitService;
        this.isDark = ThemeManager.isDark();

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

        tooltip = new Tooltip();
        tooltip.setAutoHide(true);
        tooltip.setWrapText(true);
        tooltip.setMaxWidth(380);

        setCenter(scroll);
        setPrefHeight(480);

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
                // Evitar vermelho (hue 0-25 e 335-360)
                if (hue < 25f) hue += 35f;
                else if (hue > 335f) hue -= 35f;
                float sat = 0.80f;
                float bri = isDark ? 0.88f : 0.58f;
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

        // Centralizar o grafo dentro do canvas
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

        // Background
        g.setFill(isDark ? Color.web("#2b2b2b") : Color.web("#ffffff"));
        g.fillRect(0, 0, w, h);

        int lanes = Math.max(maxLane + 1, 1);
        double textX = graphBaseX() + lanes * LANE_WIDTH + 24;

        // Subtle horizontal row separators
        g.setStroke(isDark ? Color.web("#3e3e42", 0.25) : Color.web("#f1f3f4", 0.9));
        g.setLineWidth(1);
        for (int i = 0; i < commits.size(); i++) {
            double y = TOP_MARGIN + i * ROW_HEIGHT;
            g.strokeLine(graphBaseX() - 30, y + ROW_HEIGHT / 2.0, w - RIGHT_MARGIN + 30, y + ROW_HEIGHT / 2.0);
        }

        // Connections
        g.setLineCap(StrokeLineCap.ROUND);
        g.setLineJoin(StrokeLineJoin.ROUND);
        g.setLineWidth(3.0);
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
                Color lineColorTransparent = Color.color(lineColor.getRed(), lineColor.getGreen(), lineColor.getBlue(), 0.65);
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

            // Glow / shadow
            g.setFill(Color.color(nodeColor.getRed(), nodeColor.getGreen(), nodeColor.getBlue(), 0.18));
            g.fillOval(pos.getX() - NODE_GLOW_RADIUS, pos.getY() - NODE_GLOW_RADIUS,
                    NODE_GLOW_RADIUS * 2, NODE_GLOW_RADIUS * 2);

            // Node
            g.setFill(nodeColor);
            g.fillOval(pos.getX() - NODE_RADIUS, pos.getY() - NODE_RADIUS,
                    NODE_RADIUS * 2, NODE_RADIUS * 2);

            // White inner highlight (modern glass effect)
            g.setFill(Color.web("#ffffff", 0.35));
            g.fillOval(pos.getX() - NODE_RADIUS + 1, pos.getY() - NODE_RADIUS + 1,
                    NODE_RADIUS * 2 - 4, NODE_RADIUS * 2 - 4);

            // Border
            g.setStroke(isDark ? Color.web("#ffffff", 0.85) : Color.web("#ffffff", 0.9));
            g.setLineWidth(1.8);
            g.strokeOval(pos.getX() - NODE_RADIUS, pos.getY() - NODE_RADIUS,
                    NODE_RADIUS * 2, NODE_RADIUS * 2);

            // HEAD indicator
            if (c.isHead()) {
                g.setStroke(isDark ? Color.web("#ffd43b") : Color.web("#fab005"));
                g.setLineWidth(3);
                g.strokeOval(pos.getX() - NODE_RADIUS - 5, pos.getY() - NODE_RADIUS - 5,
                        NODE_RADIUS * 2 + 10, NODE_RADIUS * 2 + 10);

                g.setFill(isDark ? Color.web("#ffd43b") : Color.web("#fab005"));
                g.setFont(Font.font("System", FontWeight.BOLD, 12));
                g.fillText("★ HEAD", pos.getX() + NODE_RADIUS + 8, pos.getY() - NODE_RADIUS + 2);
            }

            // Branch pills
            for (String b : c.getBranchNames()) {
                String bare = bareBranchName(b);
                Color bc = branchColorMap.getOrDefault(bare, isDark ? Color.LIGHTGRAY : Color.DARKGRAY);

                String text = bare;
                Font pillFont = Font.font("System", FontWeight.BOLD, 10);
                double tw = textWidth(text, pillFont);
                double pillW = Math.max(tw + 18, 42);
                double pillH = 22;
                double pillX = graphBaseX() + lane * LANE_WIDTH - 10;
                double pillY = pos.getY() - pillH / 2.0;

                // Shadow
                g.setFill(Color.color(0, 0, 0, 0.12));
                g.fillRoundRect(pillX - pillW + 1, pillY + 1, pillW, pillH, 11, 11);

                // Pill background
                g.setFill(bc);
                g.fillRoundRect(pillX - pillW, pillY, pillW, pillH, 11, 11);

                // Pill border
                g.setStroke(Color.color(bc.getRed(), bc.getGreen(), bc.getBlue(), 0.5).brighter());
                g.setLineWidth(1.2);
                g.strokeRoundRect(pillX - pillW, pillY, pillW, pillH, 11, 11);

                g.setFill(isDark ? Color.BLACK : Color.WHITE);
                g.setFont(pillFont);
                g.setTextAlign(TextAlignment.RIGHT);
                g.fillText(text, pillX - 9, pos.getY() + 4);
                g.setTextAlign(TextAlignment.LEFT);
            }

            // Hash
            g.setFill(isDark ? Color.web("#868e96") : Color.web("#868e96"));
            g.setFont(Font.font("Monospaced", 11));
            g.fillText(c.getShortId(), textX, pos.getY() - 4);

            // Message
            g.setFill(isDark ? Color.web("#f1f3f4") : Color.web("#212529"));
            g.setFont(Font.font("System", FontWeight.BOLD, 13));
            String msg = c.getMessage();
            if (msg.length() > 75) msg = msg.substring(0, 72) + "...";
            g.fillText(msg, textX + 70, pos.getY() - 4);

            // Metadata (author + date)
            g.setFill(isDark ? Color.web("#909296") : Color.web("#6c757d"));
            g.setFont(Font.font("System", 11));
            String meta = c.getAuthorName() + " · " + dateFormatter.format(c.getCommitTime());
            g.fillText(meta, textX + 70, pos.getY() + 14);
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
            return branchColorMap.getOrDefault(bare, isDark ? Color.web("#a0a0a0") : Color.web("#6c757d"));
        }
        return isDark ? Color.web("#a0a0a0") : Color.web("#6c757d");
    }

    private Color pickLineColor(GitCommit child, int childLane, int parentLane) {
        if (!child.getBranchNames().isEmpty()) {
            String bare = bareBranchName(child.getBranchNames().get(0)).toLowerCase();
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
            if (dx * dx + dy * dy <= (NODE_RADIUS + 6) * (NODE_RADIUS + 6)) {
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

            tooltip.show(canvas, e.getScreenX() + 16, e.getScreenY() + 16);
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
