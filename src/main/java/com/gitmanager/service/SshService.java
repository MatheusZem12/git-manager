package com.gitmanager.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.BufferedReader;
import java.io.File;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.TimeUnit;

public class SshService {

    private static final Logger log = LoggerFactory.getLogger(SshService.class);

    private final File sshDir;

    public SshService() {
        this.sshDir = new File(System.getProperty("user.home"), ".ssh");
    }

    public Map<String, Object> getSshStatus() {
        Map<String, Object> status = new LinkedHashMap<>();
        status.put("hasKey", false);
        status.put("publicKey", "");
        status.put("keyPath", "");

        File ed25519Pub = new File(sshDir, "id_ed25519.pub");
        File rsaPub = new File(sshDir, "id_rsa.pub");

        File pubFile = null;
        if (ed25519Pub.exists()) {
            pubFile = ed25519Pub;
            status.put("keyPath", ed25519Pub.getAbsolutePath());
        } else if (rsaPub.exists()) {
            pubFile = rsaPub;
            status.put("keyPath", rsaPub.getAbsolutePath());
        }

        if (pubFile != null) {
            status.put("hasKey", true);
            try {
                String content = Files.readString(pubFile.toPath(), StandardCharsets.UTF_8).trim();
                status.put("publicKey", content);
            } catch (Exception e) {
                log.error("Erro ao ler chave pública: {}", e.getMessage());
            }
        }

        return status;
    }

    public String generateSshKey() {
        try {
            if (!sshDir.exists()) {
                sshDir.mkdirs();
            }

            File privateKey = new File(sshDir, "id_ed25519");
            if (privateKey.exists()) {
                return "Chave SSH já existe.";
            }

            ProcessBuilder pb = new ProcessBuilder(
                "ssh-keygen", "-t", "ed25519",
                "-C", "git-manager",
                "-f", privateKey.getAbsolutePath(),
                "-N", ""
            );
            pb.redirectErrorStream(true);
            Process p = pb.start();
            boolean finished = p.waitFor(10, TimeUnit.SECONDS);
            if (!finished) {
                p.destroyForcibly();
                return "Erro: tempo excedido ao gerar chave SSH.";
            }

            try (BufferedReader reader = new BufferedReader(new InputStreamReader(p.getInputStream(), StandardCharsets.UTF_8))) {
                StringBuilder sb = new StringBuilder();
                String line;
                while ((line = reader.readLine()) != null) {
                    sb.append(line).append("\n");
                }
                if (p.exitValue() != 0) {
                    return "Erro ao gerar chave SSH:\n" + sb;
                }
            }

            return "Chave SSH gerada com sucesso.";
        } catch (Exception e) {
            log.error("Erro ao gerar chave SSH: {}", e.getMessage());
            return "Erro ao gerar chave SSH: " + e.getMessage();
        }
    }

    public String copyPublicKeyToClipboard() {
        Map<String, Object> status = getSshStatus();
        if (!(Boolean) status.get("hasKey")) {
            return "Nenhuma chave SSH encontrada.";
        }
        String pubKey = (String) status.get("publicKey");

        try {
            String os = System.getProperty("os.name").toLowerCase();
            if (os.contains("linux")) {
                ProcessBuilder pb = new ProcessBuilder("xclip", "-selection", "clipboard");
                Process p = pb.start();
                p.getOutputStream().write(pubKey.getBytes(StandardCharsets.UTF_8));
                p.getOutputStream().close();
                p.waitFor(3, TimeUnit.SECONDS);
                return "Chave pública copiada para a área de transferência.";
            } else if (os.contains("mac")) {
                ProcessBuilder pb = new ProcessBuilder("pbcopy");
                Process p = pb.start();
                p.getOutputStream().write(pubKey.getBytes(StandardCharsets.UTF_8));
                p.getOutputStream().close();
                p.waitFor(3, TimeUnit.SECONDS);
                return "Chave pública copiada para a área de transferência.";
            } else {
                return pubKey;
            }
        } catch (Exception e) {
            log.error("Erro ao copiar chave: {}", e.getMessage());
            return pubKey;
        }
    }
}
