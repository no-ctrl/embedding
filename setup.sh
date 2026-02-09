#!/bin/bash
set -e

# Дефинирање на бои
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Default модели
DEFAULT_EMBEDDING_MODEL="BAAI/bge-m3"
DEFAULT_RERANKER_MODEL="BAAI/bge-reranker-v2-m3"

# Параметри
EMBEDDING_MODEL=""
RERANKER_MODEL=""
EMBEDDING_PORT="8001"
RERANKER_PORT="8002"
DEVICE="cuda"
DTYPE="float32"
INTERACTIVE=false
SKIP_EMBEDDING=false
SKIP_RERANKER=false

# Banner
echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════════════╗"
echo "║   🚀 Embedding & Reranker Server Setup                ║"
echo "║   Infinity Embedding v2 Installer                     ║"
echo "╚════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Parse аргументи
while [[ $# -gt 0 ]]; do
    case $1 in
        --embedding-model)
            EMBEDDING_MODEL="$2"
            shift 2
            ;;
        --reranker-model)
            RERANKER_MODEL="$2"
            shift 2
            ;;
        --embedding-port)
            EMBEDDING_PORT="$2"
            shift 2
            ;;
        --reranker-port)
            RERANKER_PORT="$2"
            shift 2
            ;;
        --device)
            DEVICE="$2"
            shift 2
            ;;
        --dtype)
            DTYPE="$2"
            shift 2
            ;;
        --interactive|-i)
            INTERACTIVE=true
            shift
            ;;
        --skip-embedding)
            SKIP_EMBEDDING=true
            shift
            ;;
        --skip-reranker)
            SKIP_RERANKER=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --embedding-model MODEL    Custom embedding model (default: BAAI/bge-m3)"
            echo "  --reranker-model MODEL     Custom reranker model (default: BAAI/bge-reranker-v2-m3)"
            echo "  --embedding-port PORT      Embedding server port (default: 8001)"
            echo "  --reranker-port PORT       Reranker server port (default: 8002)"
            echo "  --device DEVICE            Device: cuda or cpu (default: cuda)"
            echo "  --dtype DTYPE              Data type: float32 or float16 (default: float32)"
            echo "  --interactive, -i          Interactive mode - choose models"
            echo "  --skip-embedding           Skip embedding server setup"
            echo "  --skip-reranker            Skip reranker server setup"
            echo "  --help, -h                 Show this help"
            echo ""
            echo "Examples:"
            echo "  # Default setup:"
            echo "  curl -sL https://raw.githubusercontent.com/.../setup.sh | bash"
            echo ""
            echo "  # Custom models:"
            echo "  curl -sL https://raw.githubusercontent.com/.../setup.sh | bash -s -- \\"
            echo "    --embedding-model BAAI/bge-large-en-v1.5 \\"
            echo "    --reranker-model BAAI/bge-reranker-base"
            echo ""
            echo "  # Interactive mode:"
            echo "  curl -sL https://raw.githubusercontent.com/.../setup.sh | bash -s -- --interactive"
            echo ""
            echo "  # CPU only:"
            echo "  curl -sL https://raw.githubusercontent.com/.../setup.sh | bash -s -- --device cpu"
            echo ""
            echo "  # Only embedding server:"
            echo "  curl -sL https://raw.githubusercontent.com/.../setup.sh | bash -s -- --skip-reranker"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Популарни модели за избор
POPULAR_EMBEDDING_MODELS=(
    "BAAI/bge-m3|Multilingual, best quality (1024 dim)"
    "BAAI/bge-large-en-v1.5|English, large (1024 dim)"
    "BAAI/bge-base-en-v1.5|English, base (768 dim)"
    "BAAI/bge-small-en-v1.5|English, fast (384 dim)"
    "sentence-transformers/all-MiniLM-L6-v2|Fast & light (384 dim)"
    "intfloat/e5-large-v2|English, high quality (1024 dim)"
    "intfloat/multilingual-e5-large|Multilingual (1024 dim)"
)

POPULAR_RERANKER_MODELS=(
    "BAAI/bge-reranker-v2-m3|Multilingual, latest (default)"
    "BAAI/bge-reranker-base|English, fast"
    "BAAI/bge-reranker-large|English, best quality"
    "cross-encoder/ms-marco-MiniLM-L-6-v2|Fast reranker"
)

# Интерактивен мод
if [ "$INTERACTIVE" = true ]; then
    echo -e "${BLUE}═══ Interactive Setup Mode ═══${NC}\n"
    
    # Избери Embedding модел
    if [ "$SKIP_EMBEDDING" = false ]; then
        echo -e "${YELLOW}Select Embedding Model:${NC}"
        for i in "${!POPULAR_EMBEDDING_MODELS[@]}"; do
            IFS='|' read -r model desc <<< "${POPULAR_EMBEDDING_MODELS[$i]}"
            echo "  $((i+1)). $model - $desc"
        done
        echo "  $((${#POPULAR_EMBEDDING_MODELS[@]}+1)). Custom (enter manually)"
        echo ""
        read -p "Choice [1]: " emb_choice
        emb_choice=${emb_choice:-1}
        
        if [ "$emb_choice" -le "${#POPULAR_EMBEDDING_MODELS[@]}" ]; then
            IFS='|' read -r EMBEDDING_MODEL desc <<< "${POPULAR_EMBEDDING_MODELS[$((emb_choice-1))]}"
        else
            read -p "Enter custom embedding model: " EMBEDDING_MODEL
        fi
        echo ""
    fi
    
    # Избери Reranker модел
    if [ "$SKIP_RERANKER" = false ]; then
        echo -e "${YELLOW}Select Reranker Model:${NC}"
        for i in "${!POPULAR_RERANKER_MODELS[@]}"; do
            IFS='|' read -r model desc <<< "${POPULAR_RERANKER_MODELS[$i]}"
            echo "  $((i+1)). $model - $desc"
        done
        echo "  $((${#POPULAR_RERANKER_MODELS[@]}+1)). Custom (enter manually)"
        echo ""
        read -p "Choice [1]: " rerank_choice
        rerank_choice=${rerank_choice:-1}
        
        if [ "$rerank_choice" -le "${#POPULAR_RERANKER_MODELS[@]}" ]; then
            IFS='|' read -r RERANKER_MODEL desc <<< "${POPULAR_RERANKER_MODELS[$((rerank_choice-1))]}"
        else
            read -p "Enter custom reranker model: " RERANKER_MODEL
        fi
        echo ""
    fi
    
    # Порти
    read -p "Embedding port [$EMBEDDING_PORT]: " port_input
    EMBEDDING_PORT=${port_input:-$EMBEDDING_PORT}
    
    read -p "Reranker port [$RERANKER_PORT]: " port_input
    RERANKER_PORT=${port_input:-$RERANKER_PORT}
    
    # Device
    read -p "Device (cuda/cpu) [$DEVICE]: " device_input
    DEVICE=${device_input:-$DEVICE}
    
    echo ""
fi

# Постави default вредности ако не се зададени
EMBEDDING_MODEL=${EMBEDDING_MODEL:-$DEFAULT_EMBEDDING_MODEL}
RERANKER_MODEL=${RERANKER_MODEL:-$DEFAULT_RERANKER_MODEL}

# Прикажи конфигурација
echo -e "${BLUE}═══ Configuration ═══${NC}"
if [ "$SKIP_EMBEDDING" = false ]; then
    echo -e "${GREEN}Embedding Server:${NC}"
    echo "  Model: $EMBEDDING_MODEL"
    echo "  Port:  $EMBEDDING_PORT"
fi
if [ "$SKIP_RERANKER" = false ]; then
    echo -e "${GREEN}Reranker Server:${NC}"
    echo "  Model: $RERANKER_MODEL"
    echo "  Port:  $RERANKER_PORT"
fi
echo -e "${GREEN}Common Settings:${NC}"
echo "  Device: $DEVICE"
echo "  Dtype:  $DTYPE"
echo -e "${BLUE}═══════════════════════${NC}\n"

# Потврда
if [ "$INTERACTIVE" = true ]; then
    read -p "Proceed with installation? [Y/n]: " confirm
    confirm=${confirm:-Y}
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 0
    fi
    echo ""
fi

# Системска подготовка
echo -e "${YELLOW}[1/3] System Update & Dependencies...${NC}"
apt-get update -qq > /dev/null
apt-get install -y -qq python3.10 python3.10-venv python3.10-distutils curl coreutils procps > /dev/null

# Python околина
echo -e "${YELLOW}[2/3] Setting up Python Environment...${NC}"
if [ ! -d "/root/infinity_venv" ]; then
    python3.10 -m venv /root/infinity_venv
fi
source /root/infinity_venv/bin/activate

pip install --upgrade pip setuptools wheel -q
pip install "typer==0.12.5" "click==8.1.7" -q
pip install "transformers<4.49" "optimum>=1.24.0,<2.0.0" -q
pip install "infinity-emb[server,optimum,torch]==0.0.77" -q

# Стартување на сервери
echo -e "${YELLOW}[3/3] Starting Servers...${NC}"
echo "--------------------------------------------------------------------------"

# Embedding Server
if [ "$SKIP_EMBEDDING" = false ]; then
    echo -e "${CYAN}Starting Embedding Server...${NC}"
    pkill -f "infinity_emb.*$EMBEDDING_PORT" || true
    sleep 2
    
    nohup /root/infinity_venv/bin/infinity_emb v2 \
      --model-id "$EMBEDDING_MODEL" \
      --host 0.0.0.0 \
      --port "$EMBEDDING_PORT" \
      --device "$DEVICE" \
      --dtype "$DTYPE" \
      --url-prefix /v1 > /root/embedding.log 2>&1 &
    
    echo $! > /root/embedding.pid
    sleep 5
    
    if pgrep -f "infinity_emb.*$EMBEDDING_PORT" > /dev/null; then
        echo -e "${GREEN}✓ Embedding Server RUNNING${NC}"
        echo "  Model:    $EMBEDDING_MODEL"
        echo "  Endpoint: http://0.0.0.0:$EMBEDDING_PORT/v1"
        echo "  PID:      $(cat /root/embedding.pid)"
        echo "  Logs:     tail -f /root/embedding.log"
    else
        echo -e "${RED}✗ Failed to start. Check: tail -f /root/embedding.log${NC}"
    fi
    echo ""
fi

# Reranker Server
if [ "$SKIP_RERANKER" = false ]; then
    echo -e "${CYAN}Starting Reranker Server...${NC}"
    pkill -f "served-model-name rerank" || true
    sleep 2
    
    nohup /root/infinity_venv/bin/infinity_emb v2 \
      --model-id "$RERANKER_MODEL" \
      --served-model-name rerank \
      --host 0.0.0.0 \
      --port "$RERANKER_PORT" \
      --device "$DEVICE" \
      --dtype "$DTYPE" \
      --url-prefix /v1 > /root/reranker.log 2>&1 &
    
    echo $! > /root/reranker.pid
    sleep 5
    
    if pgrep -f "served-model-name rerank" > /dev/null; then
        echo -e "${GREEN}✓ Reranker Server RUNNING${NC}"
        echo "  Model:    $RERANKER_MODEL"
        echo "  Endpoint: http://0.0.0.0:$RERANKER_PORT/v1/rerank"
        echo "  PID:      $(cat /root/reranker.pid)"
        echo "  Logs:     tail -f /root/reranker.log"
    else
        echo -e "${RED}✗ Failed to start. Check: tail -f /root/reranker.log${NC}"
    fi
    echo ""
fi

# Зачувај конфигурацијата
cat > /root/server_config.env << EOF
# Server Configuration
EMBEDDING_MODEL="$EMBEDDING_MODEL"
RERANKER_MODEL="$RERANKER_MODEL"
EMBEDDING_PORT="$EMBEDDING_PORT"
RERANKER_PORT="$RERANKER_PORT"
DEVICE="$DEVICE"
DTYPE="$DTYPE"
EOF

echo -e "${GREEN}✅ Setup Complete!${NC}"
echo -e "Configuration saved to: /root/server_config.env"
echo ""
echo -e "${BLUE}Quick Commands:${NC}"
echo "  Status:  pgrep -af infinity_emb"
echo "  Stop:    pkill -f infinity_emb"
echo "  Logs:    tail -f /root/embedding.log /root/reranker.log"
