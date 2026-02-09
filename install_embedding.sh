#!/bin/bash
set -e  

echo "[1/4] Starting System Update..."
apt-get update -qq > /dev/null
apt-get install -y -qq python3.10 python3.10-venv python3.10-distutils curl > /dev/null

echo "[2/4] Setting up Python Environment (/root/infinity_venv)..."
# Креирај venv само ако не постои
if [ ! -d "/root/infinity_venv" ]; then
    python3.10 -m venv /root/infinity_venv
fi
source /root/infinity_venv/bin/activate

echo "[3/4] Installing Golden Dependencies (Stable Versions)..."
pip install --upgrade pip setuptools wheel -q
# Фиксирани верзии за да нема конфликти (Typer/Click fix)
pip install "typer==0.12.5" "click==8.1.7" -q
# Оптимизација за GPU (Transformers < 4.49)
pip install "transformers<4.49" "optimum>=1.24.0,<2.0.0" -q
# Infinity Server
pip install "infinity-emb[server,optimum,torch]==0.0.77" -q

echo "[4/4] Starting Embedding Server (BAAI/bge-m3) on Port 8001..."
echo "----------------------------------------------------------------"
# Стартување со float32 за стабилност
infinity_emb v2 \
  --model-id BAAI/bge-m3 \
  --host 0.0.0.0 \
  --port 8001 \
  --device cuda \
  --dtype float32