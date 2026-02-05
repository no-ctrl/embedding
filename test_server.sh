#!/bin/bash

echo "🧪 Testing Embedding Server"
echo "============================"
echo ""

# Wait for server to be ready
MAX_RETRIES=30
RETRY_COUNT=0

echo "⏳ Waiting for server to start..."
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -s http://localhost:8001/health > /dev/null 2>&1; then
        echo "✅ Server is ready!"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo -n "."
    sleep 1
done
echo ""

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "❌ Server did not start after ${MAX_RETRIES} seconds"
    echo ""
    echo "Check logs with: tail -50 embedding.log"
    exit 1
fi

echo ""

# Test 1: Health endpoint
echo "1️⃣  Testing /health endpoint..."
HEALTH=$(curl -s http://localhost:8001/health)
if [ $? -eq 0 ]; then
    echo "$HEALTH" | python3 -m json.tool
else
    echo "❌ Health check failed"
fi
echo ""

# Test 2: Embeddings endpoint
echo "2️⃣  Testing /v1/embeddings endpoint..."
EMBEDDING=$(curl -s -X POST "http://localhost:8001/v1/embeddings" \
  -H "Content-Type: application/json" \
  -d '{"inputs": ["Скопје е главен град на Македонија", "Охрид е туристички град"]}')

if [ $? -eq 0 ]; then
    echo "$EMBEDDING" | python3 -m json.tool | head -20
    echo "..."
else
    echo "❌ Embeddings test failed"
fi
echo ""

# Test 3: Rerank endpoint
echo "3️⃣  Testing /rerank endpoint..."
RERANK=$(curl -s -X POST "http://localhost:8001/rerank" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "Најголем град во Македонија",
    "docs": [
      "Скопје е главен град на Македонија",
      "Охрид е познат по езерото",
      "Битола е втор по големина град"
    ]
  }')

if [ $? -eq 0 ]; then
    echo "$RERANK" | python3 -m json.tool
else
    echo "❌ Rerank test failed"
fi
echo ""

echo "✅ Tests complete!"
