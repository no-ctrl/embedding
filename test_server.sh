#!/bin/bash

echo "🧪 Testing BGE-M3 Embedding & Reranker Server"
echo "=============================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Wait for server to be ready
MAX_RETRIES=30
RETRY_COUNT=0

echo "⏳ Waiting for server to start..."
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -s http://localhost:8001/health > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Server is ready!${NC}"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo -n "."
    sleep 1
done
echo ""

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo -e "${RED}❌ Server did not start after ${MAX_RETRIES} seconds${NC}"
    echo ""
    echo "Check logs with: tail -50 embedding.log"
    exit 1
fi

echo ""

# ============================================================================
# Test 1: Root endpoint
# ============================================================================
echo -e "${YELLOW}1️⃣  Testing / (root) endpoint...${NC}"
ROOT=$(curl -s http://localhost:8001/)
if [ $? -eq 0 ]; then
    echo "$ROOT" | python3 -m json.tool
else
    echo -e "${RED}❌ Root endpoint failed${NC}"
fi
echo ""

# ============================================================================
# Test 2: Health endpoint
# ============================================================================
echo -e "${YELLOW}2️⃣  Testing /health endpoint...${NC}"
HEALTH=$(curl -s http://localhost:8001/health)
if [ $? -eq 0 ]; then
    echo "$HEALTH" | python3 -m json.tool
else
    echo -e "${RED}❌ Health check failed${NC}"
fi
echo ""

# ============================================================================
# Test 3: Models endpoint (OpenAI compatible)
# ============================================================================
echo -e "${YELLOW}3️⃣  Testing /v1/models endpoint (OpenAI format)...${NC}"
MODELS=$(curl -s http://localhost:8001/v1/models)
if [ $? -eq 0 ]; then
    echo "$MODELS" | python3 -m json.tool
else
    echo -e "${RED}❌ Models endpoint failed${NC}"
fi
echo ""

# ============================================================================
# Test 4: OpenAI-compatible embeddings (single string)
# ============================================================================
echo -e "${YELLOW}4️⃣  Testing /v1/embeddings (OpenAI format - single string)...${NC}"
EMBEDDING_SINGLE=$(curl -s -X POST "http://localhost:8001/v1/embeddings" \
  -H "Content-Type: application/json" \
  -d '{
    "input": "Скопје е главен град на Македонија",
    "model": "bge-m3"
  }')

if [ $? -eq 0 ]; then
    echo "$EMBEDDING_SINGLE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(json.dumps({
    'object': data['object'],
    'model': data['model'],
    'usage': data['usage'],
    'data_count': len(data['data']),
    'embedding_dim': len(data['data'][0]['embedding']) if data['data'] else 0,
    'first_5_values': data['data'][0]['embedding'][:5] if data['data'] else []
}, indent=2))
"
else
    echo -e "${RED}❌ Embeddings test failed${NC}"
fi
echo ""

# ============================================================================
# Test 5: OpenAI-compatible embeddings (array)
# ============================================================================
echo -e "${YELLOW}5️⃣  Testing /v1/embeddings (OpenAI format - array)...${NC}"
EMBEDDING_ARRAY=$(curl -s -X POST "http://localhost:8001/v1/embeddings" \
  -H "Content-Type: application/json" \
  -d '{
    "input": [
      "Скопје е главен град на Македонија",
      "Охрид е туристички град",
      "Битола е втор по големина град"
    ],
    "model": "bge-m3"
  }')

if [ $? -eq 0 ]; then
    echo "$EMBEDDING_ARRAY" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(json.dumps({
    'object': data['object'],
    'model': data['model'],
    'usage': data['usage'],
    'embeddings_count': len(data['data']),
    'embedding_dimension': len(data['data'][0]['embedding']) if data['data'] else 0
}, indent=2))
"
else
    echo -e "${RED}❌ Array embeddings test failed${NC}"
fi
echo ""

# ============================================================================
# Test 6: Reranking endpoint
# ============================================================================
echo -e "${YELLOW}6️⃣  Testing /v1/rerank endpoint...${NC}"
RERANK=$(curl -s -X POST "http://localhost:8001/v1/rerank" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "Најголем град во Македонија",
    "documents": [
      "Скопје е главен град на Македонија со преку 500,000 жители",
      "Охрид е познат по своето прекрасно езеро",
      "Битола е втор по големина град со богата историја",
      "Тетово е град во западна Македонија",
      "Куманово е град во источна Македонија"
    ],
    "top_k": 3,
    "model": "bge-reranker-v2-m3"
  }')

if [ $? -eq 0 ]; then
    echo "$RERANK" | python3 -m json.tool
else
    echo -e "${RED}❌ Rerank test failed${NC}"
fi
echo ""

# ============================================================================
# Test 7: Legacy endpoints (backwards compatibility)
# ============================================================================
echo -e "${YELLOW}7️⃣  Testing /embeddings (legacy format)...${NC}"
LEGACY_EMB=$(curl -s -X POST "http://localhost:8001/embeddings" \
  -H "Content-Type: application/json" \
  -d '{
    "inputs": ["Test legacy format"]
  }')

if [ $? -eq 0 ]; then
    echo "$LEGACY_EMB" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(json.dumps({
    'model': data.get('model'),
    'count': data.get('count'),
    'embedding_dim': len(data['data'][0]['embedding']) if data.get('data') else 0
}, indent=2))
"
else
    echo -e "${RED}❌ Legacy embeddings test failed${NC}"
fi
echo ""

echo -e "${YELLOW}8️⃣  Testing /rerank (legacy format with 'docs')...${NC}"
LEGACY_RERANK=$(curl -s -X POST "http://localhost:8001/rerank" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "Главен град",
    "docs": [
      "Скопје е главен град",
      "Охрид е туристички град"
    ],
    "top_k": 2
  }')

if [ $? -eq 0 ]; then
    echo "$LEGACY_RERANK" | python3 -m json.tool
else
    echo -e "${RED}❌ Legacy rerank test failed${NC}"
fi
echo ""

# ============================================================================
# Summary
# ============================================================================
echo ""
echo -e "${GREEN}✅ All tests complete!${NC}"
echo ""
echo "📚 API Documentation: http://localhost:8001/docs"
echo "🔍 ReDoc: http://localhost:8001/redoc"
echo ""
echo "OpenAI-compatible endpoints:"
echo "  POST /v1/embeddings"
echo "  POST /v1/rerank"
echo "  GET  /v1/models"
echo ""
echo "Legacy endpoints:"
echo "  POST /embeddings"
echo "  POST /rerank"
