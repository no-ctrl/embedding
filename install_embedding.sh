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
pkill -f "infinity_emb.*8001" || true
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

echo -e "${YELLOW}[5/5] Starting Embedding Server in Background (Port 8001)...${NC}"
echo "--------------------------------------------------------------------------"

# Стартување во позадина со nohup
nohup /root/infinity_venv/bin/infinity_emb v2 \
  --model-id BAAI/bge-m3 \
  --host 0.0.0.0 \
  --port 8001 \
  --device cuda \
  --dtype float32 \
  --url-prefix /v1 > /root/embedding.log 2>&1 &

# Зачувај го PID
echo $! > /root/embedding.pid

# Чекај малку за иницијализација
echo "Waiting 10 seconds for server to initialize..."
sleep 10

# Проверка дали работи
if pgrep -f "infinity_emb.*8001" > /dev/null; then
    echo -e "${GREEN}✓ SUCCESS! Embedding server is running in background.${NC}"
    echo -e "  PID: $(cat /root/embedding.pid)"
    echo -e "  Logs: tail -f /root/embedding.log"
    echo -e "  Endpoint: http://0.0.0.0:8001/v1"
    echo -e "  Stop: kill \$(cat /root/embedding.pid)"
else
    echo -e "${RED}✗ ERROR: Server failed to start. Checking logs:${NC}"
    tail -n 30 /root/embedding.log
    exit 1
fi

# Креирај systemd сервис за автоматско рестартирање
echo -e "\n${YELLOW}Creating systemd service...${NC}"
cat > /etc/systemd/system/embedding-server.service << 'EOF'
[Unit]
Description=Embedding Server (BAAI/bge-m3)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root
ExecStart=/root/infinity_venv/bin/infinity_emb v2 --model-id BAAI/bge-m3 --host 0.0.0.0 --port 8001 --device cuda --dtype float32 --url-prefix /v1
Restart=always
RestartSec=10
StandardOutput=append:/root/embedding.log
StandardError=append:/root/embedding.log

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable embedding-server.service

echo -e "${GREEN}✓ Systemd service created and enabled!${NC}"
echo -e "  Start: systemctl start embedding-server"
echo -e "  Stop: systemctl stop embedding-server"
echo -e "  Status: systemctl status embedding-server"
echo -e "  Logs: journalctl -u embedding-server -f"
