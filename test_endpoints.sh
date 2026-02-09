#!/bin/bash

# Тест скрипта за Embedding и Reranker endpoints

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

EMBEDDING_PORT=${1:-8001}
RERANKER_PORT=${2:-8002}

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  🧪 Testing Embedding & Reranker       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Провери дали серверите работат
echo -e "${YELLOW}[1/4] Checking if servers are running...${NC}"

if pgrep -f "infinity_emb.*$EMBEDDING_PORT" > /dev/null; then
    echo -e "${GREEN}✓ Embedding server is running (port $EMBEDDING_PORT)${NC}"
else
    echo -e "${RED}✗ Embedding server is NOT running!${NC}"
    echo "Start it with: curl -sL ... | bash"
    exit 1
fi

if pgrep -f "served-model-name rerank" > /dev/null; then
    echo -e "${GREEN}✓ Reranker server is running (port $RERANKER_PORT)${NC}"
else
    echo -e "${YELLOW}⚠ Reranker server is NOT running (skipping reranker test)${NC}"
fi

echo ""

# Тест Embedding
echo -e "${YELLOW}[2/4] Testing Embedding endpoint...${NC}"

EMBEDDING_RESPONSE=$(curl -s -X POST "http://localhost:$EMBEDDING_PORT/v1/embeddings" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "BAAI/bge-m3",
    "input": "Hello, this is a test!"
  }')

if echo "$EMBEDDING_RESPONSE" | jq -e '.data[0].embedding' > /dev/null 2>&1; then
    EMBEDDING_DIM=$(echo "$EMBEDDING_RESPONSE" | jq '.data[0].embedding | length')
    echo -e "${GREEN}✓ Embedding test PASSED${NC}"
    echo "  Dimensions: $EMBEDDING_DIM"
    echo "  Sample (first 5 values): $(echo "$EMBEDDING_RESPONSE" | jq '.data[0].embedding[0:5]')"
else
    echo -e "${RED}✗ Embedding test FAILED${NC}"
    echo "Response: $EMBEDDING_RESPONSE"
    exit 1
fi

echo ""

# Тест Reranker (ако работи)
if pgrep -f "served-model-name rerank" > /dev/null; then
    echo -e "${YELLOW}[3/4] Testing Reranker endpoint...${NC}"
    
    RERANKER_RESPONSE=$(curl -s -X POST "http://localhost:$RERANKER_PORT/v1/rerank" \
      -H "Content-Type: application/json" \
      -d '{
        "model": "rerank",
        "query": "What is artificial intelligence?",
        "documents": [
          "AI is the simulation of human intelligence by machines.",
          "The weather today is sunny.",
          "Machine learning is a subset of AI."
        ]
      }')
    
    if echo "$RERANKER_RESPONSE" | jq -e '.results[0].relevance_score' > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Reranker test PASSED${NC}"
        echo "  Results:"
        echo "$RERANKER_RESPONSE" | jq -r '.results[] | "    [\(.index)] Score: \(.relevance_score) - \(.document)"' | head -3
    else
        echo -e "${RED}✗ Reranker test FAILED${NC}"
        echo "Response: $RERANKER_RESPONSE"
        exit 1
    fi
else
    echo -e "${YELLOW}[3/4] Skipping reranker test (server not running)${NC}"
fi

echo ""

# Performance тест
echo -e "${YELLOW}[4/4] Running quick performance test...${NC}"

START=$(date +%s%N)
for i in {1..5}; do
    curl -s -X POST "http://localhost:$EMBEDDING_PORT/v1/embeddings" \
      -H "Content-Type: application/json" \
      -d "{\"model\": \"BAAI/bge-m3\", \"input\": \"Test $i\"}" > /dev/null
done
END=$(date +%s%N)

ELAPSED=$((($END - $START) / 1000000))
AVG=$(($ELAPSED / 5))

echo -e "${GREEN}✓ Performance test completed${NC}"
echo "  5 requests in ${ELAPSED}ms"
echo "  Average: ${AVG}ms per request"

echo ""
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  ✅ All tests PASSED!                  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Endpoints ready to use:${NC}"
echo "  Embedding: http://localhost:$EMBEDDING_PORT/v1/embeddings"
if pgrep -f "served-model-name rerank" > /dev/null; then
    echo "  Reranker:  http://localhost:$RERANKER_PORT/v1/rerank"
fi
