#!/bin/bash
# Управување со Embedding и Reranker сервери во Docker

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

show_status() {
    echo -e "${BLUE}=== Server Status (Docker) ===${NC}\n"
    
    # Embedding Server
    if pgrep -f "infinity_emb.*8001" > /dev/null; then
        echo -e "${GREEN}✓ Embedding Server (Port 8001)${NC} - RUNNING"
        if [ -f /root/embedding.pid ]; then
            echo -e "  PID: $(cat /root/embedding.pid)"
        fi
        echo -e "  Endpoint: http://0.0.0.0:8001/v1"
    else
        echo -e "${RED}✗ Embedding Server (Port 8001)${NC} - STOPPED"
    fi
    
    # Reranker Server
    if pgrep -f "served-model-name rerank" > /dev/null; then
        echo -e "${GREEN}✓ Reranker Server (Port 8002)${NC} - RUNNING"
        if [ -f /root/reranker.pid ]; then
            echo -e "  PID: $(cat /root/reranker.pid)"
        fi
        echo -e "  Endpoint: http://0.0.0.0:8002/v1/rerank"
    else
        echo -e "${RED}✗ Reranker Server (Port 8002)${NC} - STOPPED"
    fi
}

stop_all() {
    echo -e "${YELLOW}Stopping all servers...${NC}"
    pkill -f "infinity_emb.*8001" || true
    pkill -f "served-model-name rerank" || true
    echo -e "${GREEN}✓ All servers stopped${NC}"
}

start_embedding() {
    echo -e "${YELLOW}Starting Embedding server...${NC}"
    if pgrep -f "infinity_emb.*8001" > /dev/null; then
        echo -e "${RED}✗ Server already running!${NC}"
        return 1
    fi
    
    source /root/infinity_venv/bin/activate
    nohup /root/infinity_venv/bin/infinity_emb v2 \
      --model-id BAAI/bge-m3 \
      --host 0.0.0.0 \
      --port 8001 \
      --device cuda \
      --dtype float32 \
      --url-prefix /v1 > /root/embedding.log 2>&1 &
    
    echo $! > /root/embedding.pid
    sleep 5
    
    if pgrep -f "infinity_emb.*8001" > /dev/null; then
        echo -e "${GREEN}✓ Embedding server started (PID: $(cat /root/embedding.pid))${NC}"
    else
        echo -e "${RED}✗ Failed to start. Check: tail -f /root/embedding.log${NC}"
    fi
}

start_reranker() {
    echo -e "${YELLOW}Starting Reranker server...${NC}"
    if pgrep -f "served-model-name rerank" > /dev/null; then
        echo -e "${RED}✗ Server already running!${NC}"
        return 1
    fi
    
    source /root/infinity_venv/bin/activate
    nohup /root/infinity_venv/bin/infinity_emb v2 \
      --model-id BAAI/bge-reranker-v2-m3 \
      --served-model-name rerank \
      --host 0.0.0.0 \
      --port 8002 \
      --device cuda \
      --dtype float32 \
      --url-prefix /v1 > /root/reranker.log 2>&1 &
    
    echo $! > /root/reranker.pid
    sleep 5
    
    if pgrep -f "served-model-name rerank" > /dev/null; then
        echo -e "${GREEN}✓ Reranker server started (PID: $(cat /root/reranker.pid))${NC}"
    else
        echo -e "${RED}✗ Failed to start. Check: tail -f /root/reranker.log${NC}"
    fi
}

start_all() {
    start_embedding
    start_reranker
    echo ""
    show_status
}

view_logs() {
    case "$1" in
        embedding)
            echo -e "${BLUE}=== Embedding Logs (Press Ctrl+C to exit) ===${NC}"
            tail -f /root/embedding.log
            ;;
        reranker)
            echo -e "${BLUE}=== Reranker Logs (Press Ctrl+C to exit) ===${NC}"
            tail -f /root/reranker.log
            ;;
        *)
            echo -e "${BLUE}=== Recent Logs ===${NC}\n"
            echo -e "${YELLOW}Embedding Server:${NC}"
            tail -n 20 /root/embedding.log 2>/dev/null || echo "No logs found"
            echo -e "\n${YELLOW}Reranker Server:${NC}"
            tail -n 20 /root/reranker.log 2>/dev/null || echo "No logs found"
            ;;
    esac
}

create_startup_script() {
    echo -e "${YELLOW}Creating auto-start script for Docker...${NC}"
    
    cat > /root/start_servers.sh << 'STARTEOF'
#!/bin/bash
# Auto-start скрипта за Docker контејнер

echo "🚀 Starting Embedding & Reranker servers..."

# Чекај малку за да се иницијализира системот
sleep 2

# Embedding Server
if ! pgrep -f "infinity_emb.*8001" > /dev/null; then
    source /root/infinity_venv/bin/activate
    nohup /root/infinity_venv/bin/infinity_emb v2 \
      --model-id BAAI/bge-m3 \
      --host 0.0.0.0 \
      --port 8001 \
      --device cuda \
      --dtype float32 \
      --url-prefix /v1 > /root/embedding.log 2>&1 &
    echo $! > /root/embedding.pid
    echo "✓ Embedding server started"
fi

sleep 3

# Reranker Server
if ! pgrep -f "served-model-name rerank" > /dev/null; then
    source /root/infinity_venv/bin/activate
    nohup /root/infinity_venv/bin/infinity_emb v2 \
      --model-id BAAI/bge-reranker-v2-m3 \
      --served-model-name rerank \
      --host 0.0.0.0 \
      --port 8002 \
      --device cuda \
      --dtype float32 \
      --url-prefix /v1 > /root/reranker.log 2>&1 &
    echo $! > /root/reranker.pid
    echo "✓ Reranker server started"
fi

echo "✅ Servers are running!"
STARTEOF

    chmod +x /root/start_servers.sh
    echo -e "${GREEN}✓ Created /root/start_servers.sh${NC}"
    echo -e "\n${YELLOW}To auto-start on container restart, add to your Dockerfile:${NC}"
    echo -e "  CMD [\"/root/start_servers.sh\", \"&&\", \"tail\", \"-f\", \"/dev/null\"]"
    echo -e "\n${YELLOW}Or run manually when container starts:${NC}"
    echo -e "  docker exec -it <container> /root/start_servers.sh"
}

case "$1" in
    status)
        show_status
        ;;
    stop)
        stop_all
        ;;
    start)
        start_all
        ;;
    start-embedding)
        start_embedding
        ;;
    start-reranker)
        start_reranker
        ;;
    restart)
        stop_all
        sleep 2
        start_all
        ;;
    logs)
        view_logs "$2"
        ;;
    setup-autostart)
        create_startup_script
        ;;
    *)
        echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
        echo -e "${BLUE}  Управување со Embedding и Reranker Сервери (Docker)${NC}"
        echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}\n"
        echo "Usage: $0 {command} [options]"
        echo ""
        echo "Commands:"
        echo "  status              - Прикажи статус на серверите"
        echo "  start               - Стартувај ги двата сервери"
        echo "  start-embedding     - Стартувај само Embedding"
        echo "  start-reranker      - Стартувај само Reranker"
        echo "  stop                - Стопирај ги серверите"
        echo "  restart             - Рестартирај ги серверите"
        echo "  logs [embedding|reranker] - Логови (real-time или recent)"
        echo "  setup-autostart     - Креирај auto-start скрипта"
        echo ""
        echo "Examples:"
        echo "  $0 status"
        echo "  $0 logs embedding     # Live logs за embedding"
        echo "  $0 logs reranker      # Live logs за reranker"
        echo "  $0 logs               # Последни 20 линии од секој"
        echo ""
        echo "Manual commands:"
        echo "  Embedding logs:  tail -f /root/embedding.log"
        echo "  Reranker logs:   tail -f /root/reranker.log"
        echo "  Kill embedding:  kill \$(cat /root/embedding.pid)"
        echo "  Kill reranker:   kill \$(cat /root/reranker.pid)"
        echo ""
        echo "Docker tips:"
        echo "  Keep container running: docker run -d --gpus all -p 8001:8001 -p 8002:8002 <image>"
        echo "  Run startup script:     docker exec <container> /root/start_servers.sh"
        exit 1
        ;;
esac
