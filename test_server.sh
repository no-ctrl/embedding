#!/bin/bash

echo "🧪 Testing Embedding Server"
echo "============================"
echo ""

# Test health endpoint
echo "1️⃣  Testing /health endpoint..."
curl -s http://localhost:8001/health | python3 -m json.tool
echo ""
echo ""

# Test embeddings endpoint
echo "2️⃣  Testing /v1/embeddings endpoint..."
curl -s -X POST "http://localhost:8001/v1/embeddings" \
  -H "Content-Type: application/json" \
  -d '{"inputs": ["Скопје е главен град на Македонија", "Охрид е туристички град"]}' \
  | python3 -m json.tool | head -20
echo "..."
echo ""
echo ""

# Test rerank endpoint
echo "3️⃣  Testing /rerank endpoint..."
curl -s -X POST "http://localhost:8001/rerank" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "Најголем град во Македонија",
    "docs": [
      "Скопје е главен град на Македонија",
      "Охрид е познат по езерото",
      "Битола е втор по големина град"
    ]
  }' | python3 -m json.tool
echo ""

echo "✅ Tests complete!"
