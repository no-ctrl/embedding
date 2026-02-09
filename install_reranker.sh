#!/bin/bash
set -e

# Дефинирање на бои
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}[1/5] Starting System Update...${NC}"
apt-get update -qq > /dev/null
apt-get install -y -qq python3.10 python3.10-venv python3.10-distutils curl coreutils procps > /dev/null

echo -e "${YELLOW}[2/5] Cleaning up old processes...${NC}"
# Убиј го старото ако постои
pkill -f "served-model-name rerank" || true
sleep 2

echo -e "${YELLOW}[3/5] Setting up Python Environment (/root/infinity_venv)...${NC}"
if [ ! -d "/root/infinity_venv" ]; then
    python3.10 -m venv /root/infinity_venv
fi
source /root/infinity_venv/bin/activate

echo -e "${YELLOW}[4/5] Installing/Verifying Dependencies...${NC}"
pip install --upgrade pip setuptools wheel -q
pip install "typer==0.12.5" "click==8.1.7" -q
pip install "transformers<4.49" "optimum>=1.24.0,<2.0.0" -q
pip install "infinity-emb[server,optimum,torch]==0.0.77" -q

echo -e "${YELLOW}[5/5] Starting Reranker Server in Background (Port 8002)...${NC}"
echo "--------------------------------------------------------------------------"

# Стартување во позадина со nohup
nohup /root/infinity_venv/bin/infinity_emb v2 \
  --model-id BAAI/bge-reranker-v2-m3 \
  --served-model-name rerank \
  --host 0.0.0.0 \
  --port 8002 \
  --device cuda \
  --dtype float32 \
  --url-prefix /v1 > /root/reranker.log 2>&1 &

# Зачувај го PID
echo $! > /root/reranker.pid

# Чекај малку за иницијализација
echo "Waiting 10 seconds for server to initialize..."
sleep 10

# Проверка дали работи
if pgrep -f "served-model-name rerank" > /dev/null; then
    echo -e "${GREEN}✓ SUCCESS! Reranker server is running in background.${NC}"
    echo -e "  PID: $(cat /root/reranker.pid)"
    echo -e "  Logs: tail -f /root/reranker.log"
    echo -e "  Endpoint: http://0.0.0.0:8002/v1/rerank"
    echo -e "  Stop: kill \$(cat /root/reranker.pid)"
else
    echo -e "${RED}✗ ERROR: Server failed to start. Checking logs:${NC}"
    tail -n 30 /root/reranker.log
    exit 1
fi

# Креирај systemd сервис за автоматско рестартирање (само ако не е Docker)
if [ -f /.dockerenv ] || grep -q docker /proc/1/cgroup 2>/dev/null; then
    echo -e "\n${YELLOW}⚠ Docker detected - skipping systemd setup${NC}"
    echo -e "  Server is running with nohup and will persist in background"
    echo -e "  To restart container with server: docker restart <container>"
else
    echo -e "\n${YELLOW}Creating systemd service...${NC}"
    cat > /etc/systemd/system/reranker-server.service << 'EOF'
[Unit]
Description=Reranker Server (BAAI/bge-reranker-v2-m3)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root
ExecStart=/root/infinity_venv/bin/infinity_emb v2 --model-id BAAI/bge-reranker-v2-m3 --served-model-name rerank --host 0.0.0.0 --port 8002 --device cuda --dtype float32 --url-prefix /v1
Restart=always
RestartSec=10
StandardOutput=append:/root/reranker.log
StandardError=append:/root/reranker.log

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable reranker-server.service

    echo -e "${GREEN}✓ Systemd service created and enabled!${NC}"
    echo -e "  Start: systemctl start reranker-server"
    echo -e "  Stop: systemctl stop reranker-server"
    echo -e "  Status: systemctl status reranker-server"
    echo -e "  Logs: journalctl -u reranker-server -f"
fi
