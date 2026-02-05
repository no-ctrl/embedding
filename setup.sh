#!/bin/bash
set -e

echo "🚀 RunPod Embedding Server Setup"
echo "=================================="

# Креирај виртуелно окружување
echo "📦 Creating virtual environment..."
python3.12 -m venv /opt/venvs/infinity

# Активирај го
echo "🔧 Activating environment..."
source /opt/venvs/infinity/bin/activate

# Инсталирај зависности
echo "📥 Installing dependencies..."
pip install --upgrade pip
pip install sentence-transformers fastapi "uvicorn[standard]" torch torchvision \
  --extra-index-url https://download.pytorch.org/whl/cu121

echo "✅ Setup complete!"
echo ""
echo "To start the server, run:"
echo "  source /opt/venvs/infinity/bin/activate"
echo "  python embedding_server.py"
