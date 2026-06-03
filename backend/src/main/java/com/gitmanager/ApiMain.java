package com.gitmanager;

import com.gitmanager.api.RestServer;

/**
 * Entry point para iniciar apenas o servidor REST backend.
 * Usado quando o frontend Flutter Desktop é o client.
 */
public class ApiMain {
    public static void main(String[] args) {
        int port = 18765; // porta fixa para comunicação local Flutter-Java
        RestServer server = new RestServer(port);
        server.start();

        // Mantém o processo vivo
        Runtime.getRuntime().addShutdownHook(new Thread(server::stop));
    }
}
