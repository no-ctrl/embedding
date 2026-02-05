from fastapi import FastAPI, Body
from pydantic import BaseModel
from sentence_transformers import SentenceTransformer
from typing import List, Dict, Any
import uvicorn
import torch
import numpy as np

print("🔄 Loading BGE-M3 models...")
embedding_model = SentenceTransformer('BAAI/bge-m3', device='cuda:0')
reranker_model = SentenceTransformer('BAAI/bge-reranker-v2-m3', device='cuda:0')
print("✅ Models loaded successfully!")

app = FastAPI(title="Embedding & Reranker Server", version="1.0.0")


@app.get("/")
def root():
    return {
        "service": "Embedding & Reranker Server",
        "models": {
            "embedding": "BAAI/bge-m3",
            "reranker": "BAAI/bge-reranker-v2-m3"
        },
        "endpoints": ["/v1/embeddings", "/rerank", "/health"]
    }


@app.get("/health")
def health():
    gpu_name = torch.cuda.get_device_name(0) if torch.cuda.is_available() else "CPU"
    return {
        "status": "OK",
        "gpu": gpu_name,
        "cuda_available": torch.cuda.is_available(),
        "models_loaded": True
    }


@app.post("/v1/embeddings")
def embeddings(body: Dict[str, Any] = Body(...)):
    """
    Generate embeddings for input texts.
    Request: {"inputs": ["text1", "text2", ...]}
    Response: {"data": [{"embedding": [...]}, ...]}
    """
    inputs = body.get("inputs", [])
    
    if not inputs:
        return {"error": "No inputs provided"}, 400
    
    # Generate embeddings
    embeddings = embedding_model.encode(inputs, batch_size=32, normalize_embeddings=True)
    
    return {
        "data": [
            {"embedding": emb.tolist(), "index": i} 
            for i, emb in enumerate(embeddings)
        ],
        "model": "BAAI/bge-m3",
        "count": len(embeddings)
    }


@app.post("/rerank")
def rerank(body: Dict[str, Any] = Body(...)):
    """
    Rerank documents based on query relevance.
    Request: {"query": "...", "docs": ["doc1", "doc2", ...]}
    Response: {"results": [{"index": 0, "relevance_score": 0.95}, ...]}
    """
    query = body.get("query", "")
    docs = body.get("docs", [])
    top_k = body.get("top_k", 10)
    
    if not query or not docs:
        return {"error": "Missing query or docs"}, 400
    
    # Create pairs for reranking
    pairs = [[query, doc] for doc in docs]
    
    # Get similarity scores
    scores = reranker_model.encode(pairs, batch_size=16)
    
    # Calculate dot product for similarity
    similarities = (scores[:, 0] * scores[:, 1]).sum(dim=1).cpu().numpy()
    
    # Sort by relevance
    ranked_indices = np.argsort(similarities)[::-1][:top_k]
    
    results = [
        {
            "index": int(idx),
            "document": docs[idx],
            "relevance_score": float(similarities[idx])
        }
        for idx in ranked_indices
    ]
    
    return {
        "results": results,
        "model": "BAAI/bge-reranker-v2-m3",
        "query": query,
        "total_docs": len(docs)
    }


def main():
    print("\n" + "="*50)
    print("🌐 Starting Embedding Server on http://0.0.0.0:8001")
    print("="*50 + "\n")
    
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8001,
        log_level="info"
    )


if __name__ == "__main__":
    main()
