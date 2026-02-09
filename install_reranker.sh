#!/bin/bash
set -e  # Прекини ако се случи било каква грешка

echo "[1/4] Starting System Update..."
apt-get update -qq > /dev/null
apt-get install -y -qq python3.10 python3.10-venv python3.10-distutils curl > /dev/null

echo "[2/4] Setting up Python Environment (/root/infinity_venv)..."
if [ ! -d "/root/infinity_venv" ]; then
    python3.10 -m venv /root/infinity_venv
fi
source /root/infinity_venv/bin/activate

echo "[3/4] Checking Dependencies..."
pip install --upgrade pip setuptools wheel -q
pip install "typer==0.12.5" "click==8.1.7" -q
pip install "transformers<4.49" "optimum>=1.24.0,<2.0.0" -q
pip install "infinity-emb[server,optimum,torch]==0.0.77" -q

echo "[4/4] Starting Reranker Server (BAAI/bge-reranker-v2-m3) on Port 8002..."
echo "--------------------------------------------------------------------------"
infinity_emb v2 \
  --model-id BAAI/bge-reranker-v2-m3 \
  --served-model-name rerank \
  --host 0.0.0.0 \
  --port 8002 \
  --device cuda \
  --dtype float32 \
  --url-prefix /v1
