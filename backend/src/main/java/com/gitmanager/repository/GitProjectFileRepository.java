package com.gitmanager.repository;

import com.gitmanager.model.GitProject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.BufferedWriter;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

public class GitProjectFileRepository {

    private static final Logger log = LoggerFactory.getLogger(GitProjectFileRepository.class);
    private final Path filePath;

    public GitProjectFileRepository() {
        String home = System.getProperty("user.home");
        Path dir = Path.of(home, ".git-manager");
        try {
            Files.createDirectories(dir);
        } catch (IOException e) {
            log.warn("Não foi possível criar diretório ~/.git-manager", e);
        }
        this.filePath = dir.resolve("repos.txt");
    }

    public List<GitProject> loadAll() {
        List<GitProject> list = new ArrayList<>();
        if (!Files.exists(filePath)) {
            return list;
        }
        try {
            List<String> lines = Files.readAllLines(filePath);
            for (String line : lines) {
                line = line.trim();
                if (line.isEmpty() || line.startsWith("#")) continue;
                String[] parts = line.split("\\|", 4);
                if (parts.length >= 2) {
                    GitProject p = new GitProject();
                    p.setName(unescape(parts[0]));
                    p.setPath(unescape(parts[1]));
                    if (parts.length == 3) {
                        p.setGroup("");
                        p.setNotes(unescape(parts[2]));
                    } else {
                        p.setGroup(parts.length >= 3 ? unescape(parts[2]) : "");
                        p.setNotes(parts.length >= 4 ? unescape(parts[3]) : "");
                    }
                    list.add(p);
                }
            }
        } catch (IOException e) {
            log.error("Erro ao ler arquivo de repositórios", e);
        }
        return list;
    }

    public void saveAll(List<GitProject> projects) {
        try (BufferedWriter w = Files.newBufferedWriter(filePath)) {
            w.write("# Git Manager - Repositórios cadastrados\n");
            w.write("# Formato: nome|caminho|grupo|notas\n");
            for (GitProject p : projects) {
                w.write(
                    escape(p.getName()) + "|" +
                    escape(p.getPath()) + "|" +
                    escape(p.getGroup() != null ? p.getGroup() : "") + "|" +
                    escape(p.getNotes() != null ? p.getNotes() : "") + "\n"
                );
            }
        } catch (IOException e) {
            log.error("Erro ao salvar arquivo de repositórios", e);
            throw new RuntimeException("Falha ao salvar repositórios: " + e.getMessage(), e);
        }
    }

    private String escape(String s) {
        if (s == null) return "";
        return s.replace("\\", "\\\\")
                .replace("|", "\\|")
                .replace("\n", "\\n")
                .replace("\r", "");
    }

    private String unescape(String s) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            if (c == '\\' && i + 1 < s.length()) {
                char next = s.charAt(i + 1);
                if (next == '\\') { sb.append('\\'); i++; }
                else if (next == '|') { sb.append('|'); i++; }
                else if (next == 'n') { sb.append('\n'); i++; }
            } else {
                sb.append(c);
            }
        }
        return sb.toString();
    }
}
