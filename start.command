#!/bin/bash
# Git Manager Launcher for macOS
# Inicia o backend Java REST e o frontend Flutter Desktop

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_PORT=18765
JAR_PATH="$SCRIPT_DIR/target/git-manager-1.0.0.jar"
FLUTTER_APP="$SCRIPT_DIR/git_manager_ui/build/macos/Build/Products/Release/git_manager_ui.app"

echo "========================================="
echo "   Git Manager — Flutter + Java"
echo "========================================="

# Verifica se o JAR existe
if [ ! -f "$JAR_PATH" ]; then
    echo "JAR nao encontrado. Compilando..."
    cd "$SCRIPT_DIR"
    mvn package -q -DskipTests
fi

# Verifica se o app Flutter existe
if [ ! -d "$FLUTTER_APP" ]; then
    FLUTTER_APP="$SCRIPT_DIR/git_manager_ui/build/macos/Build/Products/Debug/git_manager_ui.app"
fi

# Mata processos antigos na mesma porta
lsof -ti:$API_PORT | xargs kill -9 2>/dev/null || true

echo "Iniciando backend Java na porta $API_PORT..."
java -cp "$JAR_PATH" com.gitmanager.ApiMain > /tmp/git-manager-api.log 2>&1 &
API_PID=$!

# Aguarda o servidor subir
echo "Aguardando servidor..."
for i in {1..30}; do
    if curl -s http://localhost:$API_PORT/api/health > /dev/null 2>&1; then
        echo "Backend pronto!"
        break
    fi
    sleep 0.5
done

if [ -d "$FLUTTER_APP" ]; then
    echo "Abrindo Flutter macOS..."
    open "$FLUTTER_APP" &
    FLUTTER_PID=$!
    echo ""
    echo "========================================="
    echo "   Git Manager esta rodando!"
    echo "   Backend PID: $API_PID"
    echo "========================================="
    echo ""
    echo "Pressione ENTER para encerrar..."
    read -r
    kill $FLUTTER_PID 2>/dev/null || true
    kill $API_PID 2>/dev/null || true
    echo "Encerrado."
else
    echo ""
    echo "App Flutter macOS nao encontrado."
    echo "Compile primeiro com: flutter build macos --release"
    echo ""
    echo "Pressione ENTER para encerrar o backend..."
    read -r
    kill $API_PID 2>/dev/null || true
fi
