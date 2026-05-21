#!/bin/bash
# Git Manager Launcher
# Inicia o backend Java REST e o frontend Flutter Desktop

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_PORT=18765
JAR_PATH="$SCRIPT_DIR/target/git-manager-1.0.0.jar"
FLUTTER_APP="$SCRIPT_DIR/git_manager_ui/build/linux/x64/debug/bundle/git_manager_ui"

echo "========================================="
echo "   Git Manager — Flutter + Java"
echo "========================================="

# Verifica se o JAR existe
if [ ! -f "$JAR_PATH" ]; then
    echo "❌ JAR não encontrado. Compilando..."
    cd "$SCRIPT_DIR"
    mvn package -q -DskipTests
fi

# Verifica se o app Flutter existe
if [ ! -f "$FLUTTER_APP" ]; then
    echo "❌ App Flutter não encontrado. Compilando..."
    cd "$SCRIPT_DIR/git_manager_ui"
    if ! command -v flutter &> /dev/null; then
        echo "⚠️  Flutter não encontrado no PATH."
        echo "   Adicione /home/$(whoami)/flutter/bin ao seu PATH."
        exit 1
    fi
    flutter build linux --debug
fi

# Mata processos antigos na mesma porta
lsof -ti:$API_PORT | xargs kill -9 2>/dev/null || true

echo "🚀 Iniciando backend Java na porta $API_PORT..."
java -cp "$JAR_PATH" com.gitmanager.ApiMain > /tmp/git-manager-api.log 2>&1 &
API_PID=$!

# Aguarda o servidor subir
echo "⏳ Aguardando servidor..."
for i in {1..30}; do
    if curl -s http://localhost:$API_PORT/api/health > /dev/null 2>&1; then
        echo "✅ Backend pronto!"
        break
    fi
    sleep 0.5
done

echo "🎨 Iniciando Flutter Desktop..."
"$FLUTTER_APP" &
FLUTTER_PID=$!

echo ""
echo "========================================="
echo "   Git Manager está rodando!"
echo "   Backend PID: $API_PID"
echo "   Flutter PID: $FLUTTER_PID"
echo "========================================="
echo ""
echo "Pressione ENTER para encerrar..."
read -r

kill $FLUTTER_PID 2>/dev/null || true
kill $API_PID 2>/dev/null || true
echo "👋 Encerrado."
