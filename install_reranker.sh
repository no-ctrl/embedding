#!/bin/bash
set -e

# Definiranje na boi za poubav izlez
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}[1/5] Starting System Update...${NC}"
apt-get update -qq > /dev/null
apt-get install -y -qq python3.10 python3.10-venv python3.10-distutils curl coreutils procps > /dev/null

echo -e "${YELLOW}[2/5] Cleaning up old processes...${NC}"
# Ubij go stariot proces ako postoi za da oslobodime porta 8002
pkill -f "served-model-name rerank" || true
sleep 2

echo -e "${YELLOW}[3/5] Setting up Python Environment (/root/infinity_venv)...${NC}"
if [ ! -d "/root/infinity_venv" ]; then
    python3.10 -m venv /root/infinity_venv
fi
source /root/infinity_venv/bin/activate

echo -e "${YELLOW}[4/5] Installing/Verifying Dependencies...${NC}"
pip install --upgrade pip setuptools wheel -q
# Fiksirani verzii za stabilnost
pip install "typer==0.12.5" "click==8.1.7" -q
pip install "transformers<4.49" "optimum>=1.24.0,<2.0.0" -q
pip install "infinity-emb[server,optimum,torch]==0.0.77" -q

echo -e "${YELLOW}[5/5] Starting Reranker Server (Port 8002)...${NC}"
echo "--------------------------------------------------------------------------"

# Startuvanje vo pozadina so nohup
# VNIMANIE: --url-prefix /v1 e vklucen za OpenAI kompatibilnost
nohup infinity_emb v2 \
  --model-id BAAI/bge-reranker-v2-m3 \
  --served-model-name rerank \
  --host 0.0.0.0 \
  --port 8002 \
  --device cuda \
  --dtype float32 \
  --url-prefix /v1 > /root/reranker.log 2>&1 &

# Cekame malku za da se inicijalizira
echo "Waiting 10 seconds for server to initialize..."
sleep 10

# Proverka dali procesot e ziv
if pgrep -f "served-model-name rerank" > /dev/null; then
    echo -e "${GREEN}SUCCESS! Reranker is running in the background.${NC}"
    echo -e "Logs: /root/reranker.log"
    echo -e "Endpoint: http://0.0.0.0:8002/v1/rerank"
else
    echo -e "\033[0;31mERROR: Server failed to start. Checking logs:${NC}"
    tail -n 20 /root/reranker.log
    exit 1
fi
