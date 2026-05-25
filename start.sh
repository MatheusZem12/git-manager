#!/bin/bash
# Git Manager Launcher
# Inicia o backend Java REST e o frontend Flutter Desktop

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_PORT=18765
JAR_PATH="$SCRIPT_DIR/target/git-manager-1.0.0.jar"
FLUTTER_DIR="$SCRIPT_DIR/git_manager_ui"
FLUTTER_APP="$FLUTTER_DIR/build/linux/x64/release/bundle/git_manager_ui"

BUILD_MODE="release"
FORCE_REBUILD=false

for arg in "$@"; do
    case "$arg" in
        debug) BUILD_MODE="debug" ;;
        release) BUILD_MODE="release" ;;
        --rebuild) FORCE_REBUILD=true ;;
    esac
done

if [ "$BUILD_MODE" != "release" ] && [ "$BUILD_MODE" != "debug" ]; then
    echo "Uso: $0 [debug|release] [--rebuild]"
    echo "  debug       - build Flutter em modo debug (mais rápido)"
    echo "  release     - build Flutter em modo release (padrão, mais performance)"
    echo "  --rebuild   - força recompilação completa do Flutter e do backend"
    exit 1
fi

echo "========================================="
echo "   Git Manager — Flutter + Java"
echo "   Modo: $BUILD_MODE"
echo "========================================="

# Verifica dependências
check_dep() {
    if ! command -v "$1" &> /dev/null; then
        echo "❌ $1 não encontrado no PATH."
        echo "   Instale $1 e adicione ao PATH antes de continuar."
        exit 1
    fi
}

check_dep java
check_dep mvn
check_dep flutter

# Build do backend Java
echo ""
echo "🔧 Verificando backend Java..."
if [ "$FORCE_REBUILD" = true ]; then
    echo "   --rebuild ativo. Recompilando backend..."
    cd "$SCRIPT_DIR"
    mvn package -q -DskipTests
    echo "   ✅ Backend recompilado."
elif [ ! -f "$JAR_PATH" ]; then
    echo "   JAR não encontrado. Compilando..."
    cd "$SCRIPT_DIR"
    mvn package -q -DskipTests
    echo "   ✅ Backend compilado."
else
    echo "   ✅ JAR encontrado."
fi

# Ajusta caminho do app baseado no modo
if [ "$BUILD_MODE" = "debug" ]; then
    FLUTTER_APP="$FLUTTER_DIR/build/linux/x64/debug/bundle/git_manager_ui"
else
    FLUTTER_APP="$FLUTTER_DIR/build/linux/x64/release/bundle/git_manager_ui"
fi

# Build do Flutter
echo ""
echo "🔧 Verificando frontend Flutter..."

NEEDS_BUILD=false
if [ "$FORCE_REBUILD" = true ]; then
    NEEDS_BUILD=true
    echo "   --rebuild ativo. Forçando recompilação do Flutter..."
    rm -rf "$FLUTTER_DIR/build/linux"
elif [ ! -f "$FLUTTER_APP" ]; then
    NEEDS_BUILD=true
    echo "   App Flutter não encontrado."
else
    # Verifica se algum arquivo .dart foi modificado depois do build
    LATEST_DART=$(find "$FLUTTER_DIR/lib" -name "*.dart" -type f -printf '%T@\n' 2>/dev/null | sort -n | tail -1)
    BUILD_TIME=$(stat -c %Y "$FLUTTER_APP" 2>/dev/null || echo 0)
    
    if [ -n "$LATEST_DART" ] && [ "${LATEST_DART%.*}" -gt "$BUILD_TIME" ]; then
        NEEDS_BUILD=true
        echo "   Código fonte modificado desde o último build."
    fi
fi

if [ "$NEEDS_BUILD" = true ]; then
    echo "   Compilando Flutter em modo $BUILD_MODE..."
    cd "$FLUTTER_DIR"
    if [ "$FORCE_REBUILD" = true ]; then
        echo "   Limpando caches do Flutter..."
        flutter clean > /dev/null 2>&1 || true
        rm -rf .dart_tool/build
    fi
    flutter config --enable-linux-desktop > /dev/null 2>&1 || true
    flutter pub get > /dev/null 2>&1 || true
    flutter build linux --"$BUILD_MODE"
    echo "   ✅ Flutter compilado."
else
    echo "   ✅ App Flutter está atualizado."
fi

# Mata processos antigos
echo ""
echo "🧹 Limpando processos antigos..."
lsof -ti:$API_PORT | xargs kill -9 2>/dev/null || true
killall -9 git_manager_ui 2>/dev/null || true

echo ""
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

# Verifica se o backend subiu
if ! kill -0 $API_PID 2>/dev/null; then
    echo "❌ Falha ao iniciar o backend. Verifique o log: /tmp/git-manager-api.log"
    exit 1
fi

echo ""
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
