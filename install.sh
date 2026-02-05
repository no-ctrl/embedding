#!/bin/bash
# RunPod Брз Старт - Еднолиниско инсталирање

set -e

echo "🚀 RunPod Embedding Server - Автоматска Инсталација"
echo "====================================================="
echo ""

# Провери дали постои git
if ! command -v git &> /dev/null; then
    echo "⚠️  Git не е инсталиран. Инсталирам..."
    apt-get update && apt-get install -y git
fi

# Клонирај репо (замени го URL-то)
REPO_URL="${1:-https://github.com/no-ctrl/embedding.git}"
INSTALL_DIR="runpod-embedding-server"

if [ -d "$INSTALL_DIR" ]; then
    echo "📁 Директориумот веќе постои. Бришам..."
    rm -rf "$INSTALL_DIR"
fi

echo "📥 Клонирам репозиториум..."
git clone "$REPO_URL" "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Направи ги скриптите извршни
chmod +x *.sh

# Пушти setup
echo ""
echo "🔧 Стартувам setup..."
./setup.sh

echo ""
echo "✅ Инсталацијата е завршена!"
echo ""
echo "Следни чекори:"
echo "  cd $INSTALL_DIR"
echo "  ./start_background.sh    # Стартувај го серверот"
echo "  ./test_server.sh         # Тестирај го API-то"
echo ""
