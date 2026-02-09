#!/bin/bash
# Скрипта за управување со Embedding и Reranker сервери

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

show_status() {
    echo -e "${BLUE}=== Server Status ===${NC}\n"
    
    # Embedding Server
    if pgrep -f "infinity_emb.*8001" > /dev/null; then
        echo -e "${GREEN}✓ Embedding Server (Port 8001)${NC} - RUNNING"
        if [ -f /root/embedding.pid ]; then
            echo -e "  PID: $(cat /root/embedding.pid)"
        fi
    else
        echo -e "${RED}✗ Embedding Server (Port 8001)${NC} - STOPPED"
    fi
    
    # Reranker Server
    if pgrep -f "served-model-name rerank" > /dev/null; then
        echo -e "${GREEN}✓ Reranker Server (Port 8002)${NC} - RUNNING"
        if [ -f /root/reranker.pid ]; then
            echo -e "  PID: $(cat /root/reranker.pid)"
        fi
    else
        echo -e "${RED}✗ Reranker Server (Port 8002)${NC} - STOPPED"
    fi
    
    echo -e "\n${BLUE}=== Systemd Services ===${NC}\n"
    systemctl is-active --quiet embedding-server && echo -e "${GREEN}✓ embedding-server${NC}" || echo -e "${RED}✗ embedding-server${NC}"
    systemctl is-active --quiet reranker-server && echo -e "${GREEN}✓ reranker-server${NC}" || echo -e "${RED}✗ reranker-server${NC}"
}

stop_all() {
    echo -e "${YELLOW}Stopping all servers...${NC}"
    pkill -f "infinity_emb.*8001" || true
    pkill -f "served-model-name rerank" || true
    systemctl stop embedding-server 2>/dev/null || true
    systemctl stop reranker-server 2>/dev/null || true
    echo -e "${GREEN}✓ All servers stopped${NC}"
}

start_with_systemd() {
    echo -e "${YELLOW}Starting servers with systemd...${NC}"
    systemctl start embedding-server
    systemctl start reranker-server
    sleep 3
    show_status
}

view_logs() {
    echo -e "${BLUE}=== Recent Logs ===${NC}\n"
    echo -e "${YELLOW}Embedding Server:${NC}"
    tail -n 20 /root/embedding.log 2>/dev/null || echo "No logs found"
    echo -e "\n${YELLOW}Reranker Server:${NC}"
    tail -n 20 /root/reranker.log 2>/dev/null || echo "No logs found"
}

case "$1" in
    status)
        show_status
        ;;
    stop)
        stop_all
        ;;
    start)
        start_with_systemd
        ;;
    restart)
        stop_all
        sleep 2
        start_with_systemd
        ;;
    logs)
        view_logs
        ;;
    *)
        echo -e "${BLUE}Управување со Embedding и Reranker Сервери${NC}\n"
        echo "Usage: $0 {status|start|stop|restart|logs}"
        echo ""
        echo "Commands:"
        echo "  status   - Прикажи статус на серверите"
        echo "  start    - Стартувај ги серверите (systemd)"
        echo "  stop     - Стопирај ги серверите"
        echo "  restart  - Рестартирај ги серверите"
        echo "  logs     - Прикажи логови"
        echo ""
        echo "Manual commands:"
        echo "  Embedding logs: tail -f /root/embedding.log"
        echo "  Reranker logs:  tail -f /root/reranker.log"
        echo "  Kill embedding: kill \$(cat /root/embedding.pid)"
        echo "  Kill reranker:  kill \$(cat /root/reranker.pid)"
        exit 1
        ;;
esac
