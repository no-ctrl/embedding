from fastapi import FastAPI, HTTPException, Body
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from sentence_transformers import SentenceTransformer
from typing import List, Dict, Any, Optional, Literal, Union
import uvicorn
import torch
import numpy as np
import time
from datetime import datetime

# ============================================================================
# MODEL LOADING
# ============================================================================
print("🔄 Loading BGE-M3 models...")
embedding_model = SentenceTransformer('BAAI/bge-m3', device='cuda:0')
reranker_model = SentenceTransformer('BAAI/bge-reranker-v2-m3', device='cuda:0')
print("✅ Models loaded successfully!")

# Model metadata
EMBEDDING_MODEL_NAME = "bge-m3"
EMBEDDING_DIMENSION = 1024
RERANKER_MODEL_NAME = "bge-reranker-v2-m3"

# ============================================================================
# FASTAPI APP
# ============================================================================
app = FastAPI(
    title="BGE-M3 Embedding & Reranker API",
    description="OpenAI-compatible embedding API with reranking capabilities",
    version="1.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ============================================================================
# PYDANTIC MODELS (OpenAI Compatible)
# ============================================================================

class EmbeddingRequest(BaseModel):
    """OpenAI-compatible embedding request"""
    input: Union[List[str], str] = Field(..., description="Text(s) to embed")
    model: str = Field(default=EMBEDDING_MODEL_NAME, description="Model to use")
    encoding_format: Optional[Literal["float", "base64"]] = Field(
        default="float", 
        description="Encoding format"
    )
    dimensions: Optional[int] = Field(
        default=None, 
        description="Output dimensions (not supported, always returns 1024)"
    )
    user: Optional[str] = Field(default=None, description="User identifier")


class EmbeddingData(BaseModel):
    """Single embedding object"""
    object: str = "embedding"
    embedding: List[float]
    index: int


class EmbeddingUsage(BaseModel):
    """Token usage statistics"""
    prompt_tokens: int
    total_tokens: int


class EmbeddingResponse(BaseModel):
    """OpenAI-compatible embedding response"""
    object: str = "list"
    data: List[EmbeddingData]
    model: str
    usage: EmbeddingUsage


class RerankRequest(BaseModel):
    """Reranking request"""
    query: str = Field(..., description="Search query")
    documents: List[str] = Field(..., description="Documents to rerank")
    top_k: Optional[int] = Field(default=10, description="Number of top results")
    model: Optional[str] = Field(default=RERANKER_MODEL_NAME)
    
    class Config:
        populate_by_name = True
        # Allow both 'documents' and 'docs' as field names
        fields = {'documents': {'alias': 'docs'}}


class RerankResult(BaseModel):
    """Single reranking result"""
    index: int
    document: str
    relevance_score: float


class RerankResponse(BaseModel):
    """Reranking response"""
    results: List[RerankResult]
    model: str
    query: str
    usage: Dict[str, int]


# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def estimate_tokens(text: str) -> int:
    """Estimate token count (rough approximation)"""
    return len(text.split())


def normalize_input(input_data: Union[List[str], str]) -> List[str]:
    """Normalize input to list of strings"""
    if isinstance(input_data, str):
        return [input_data]
    return input_data


# ============================================================================
# ENDPOINTS
# ============================================================================

@app.get("/")
def root():
    """Root endpoint with API information"""
    return {
        "service": "BGE-M3 Embedding & Reranker API",
        "version": "1.0.0",
        "models": {
            "embedding": {
                "name": EMBEDDING_MODEL_NAME,
                "dimensions": EMBEDDING_DIMENSION,
                "max_tokens": 8192
            },
            "reranker": {
                "name": RERANKER_MODEL_NAME
            }
        },
        "endpoints": {
            "embeddings": "/v1/embeddings",
            "rerank": "/v1/rerank",
            "models": "/v1/models",
            "health": "/health"
        },
        "compatible_with": "OpenAI API"
    }


@app.get("/health")
def health():
    """Health check endpoint"""
    gpu_name = torch.cuda.get_device_name(0) if torch.cuda.is_available() else "CPU"
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "gpu": gpu_name,
        "cuda_available": torch.cuda.is_available(),
        "models_loaded": True,
        "models": {
            "embedding": EMBEDDING_MODEL_NAME,
            "reranker": RERANKER_MODEL_NAME
        }
    }


@app.get("/v1/models")
def list_models():
    """OpenAI-compatible model listing"""
    return {
        "object": "list",
        "data": [
            {
                "id": EMBEDDING_MODEL_NAME,
                "object": "model",
                "created": int(time.time()),
                "owned_by": "BAAI",
                "permission": [],
                "root": EMBEDDING_MODEL_NAME,
                "parent": None,
            },
            {
                "id": RERANKER_MODEL_NAME,
                "object": "model",
                "created": int(time.time()),
                "owned_by": "BAAI",
                "permission": [],
                "root": RERANKER_MODEL_NAME,
                "parent": None,
            }
        ]
    }


@app.post("/v1/embeddings", response_model=EmbeddingResponse)
async def create_embeddings(request: EmbeddingRequest):
    """
    OpenAI-compatible embeddings endpoint
    
    Example:
        POST /v1/embeddings
        {
            "input": ["Hello world", "Goodbye world"],
            "model": "bge-m3"
        }
    """
    try:
        # Normalize input
        texts = normalize_input(request.input)
        
        if not texts:
            raise HTTPException(status_code=400, detail="No input provided")
        
        # Generate embeddings
        start_time = time.time()
        embeddings = embedding_model.encode(
            texts,
            batch_size=32,
            normalize_embeddings=True,
            show_progress_bar=False
        )
        processing_time = time.time() - start_time
        
        # Calculate usage
        total_tokens = sum(estimate_tokens(text) for text in texts)
        
        # Build response
        data = [
            EmbeddingData(
                embedding=emb.tolist(),
                index=i
            )
            for i, emb in enumerate(embeddings)
        ]
        
        response = EmbeddingResponse(
            data=data,
            model=request.model,
            usage=EmbeddingUsage(
                prompt_tokens=total_tokens,
                total_tokens=total_tokens
            )
        )
        
        print(f"✅ Embedded {len(texts)} texts in {processing_time:.2f}s")
        return response
        
    except Exception as e:
        print(f"❌ Embedding error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/v1/rerank", response_model=RerankResponse)
async def rerank_documents(request: RerankRequest):
    """
    Rerank documents based on query relevance
    
    Example:
        POST /v1/rerank
        {
            "query": "What is the capital of North Macedonia?",
            "documents": [
                "Skopje is the capital",
                "Ohrid is a tourist city",
                "Bitola is the second largest"
            ],
            "top_k": 3
        }
    """
    try:
        query = request.query
        docs = request.documents
        top_k = min(request.top_k or 10, len(docs))
        
        if not query:
            raise HTTPException(status_code=400, detail="Query is required")
        
        if not docs:
            raise HTTPException(status_code=400, detail="Documents are required")
        
        # Create query-document pairs
        pairs = [[query, doc] for doc in docs]
        
        # Get reranker scores
        start_time = time.time()
        scores = reranker_model.encode(
            pairs,
            batch_size=16,
            convert_to_tensor=True,
            show_progress_bar=False
        )
        processing_time = time.time() - start_time
        
        # Convert to numpy
        if torch.is_tensor(scores):
            similarities = scores.cpu().numpy()
        else:
            similarities = np.array(scores)
        
        # Handle different output shapes
        if len(similarities.shape) > 1:
            # For reranker models, take first column or mean
            similarities = similarities[:, 0] if similarities.shape[1] > 0 else similarities.mean(axis=1)
        
        # Get top-k indices
        ranked_indices = np.argsort(similarities)[::-1][:top_k]
        
        # Build results
        results = [
            RerankResult(
                index=int(idx),
                document=docs[idx],
                relevance_score=float(similarities[idx])
            )
            for idx in ranked_indices
        ]
        
        # Calculate usage
        total_tokens = estimate_tokens(query) + sum(estimate_tokens(doc) for doc in docs)
        
        response = RerankResponse(
            results=results,
            model=request.model or RERANKER_MODEL_NAME,
            query=query,
            usage={
                "total_tokens": total_tokens,
                "query_tokens": estimate_tokens(query),
                "documents_tokens": sum(estimate_tokens(doc) for doc in docs)
            }
        )
        
        print(f"✅ Reranked {len(docs)} docs in {processing_time:.2f}s")
        return response
        
    except Exception as e:
        print(f"❌ Reranking error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================================
# LEGACY ENDPOINTS (backwards compatibility)
# ============================================================================

@app.post("/embeddings")
async def legacy_embeddings(body: Dict[str, Any] = Body(...)):
    """Legacy embedding endpoint (non-OpenAI format)"""
    inputs = body.get("inputs", [])
    request = EmbeddingRequest(input=inputs)
    response = await create_embeddings(request)
    
    # Convert to legacy format
    return {
        "data": [{"embedding": item.embedding, "index": item.index} for item in response.data],
        "model": response.model,
        "count": len(response.data)
    }


@app.post("/rerank")
async def legacy_rerank(body: Dict[str, Any] = Body(...)):
    """Legacy rerank endpoint"""
    docs = body.get("docs", body.get("documents", []))
    request = RerankRequest(
        query=body.get("query", ""),
        documents=docs,
        top_k=body.get("top_k", 10)
    )
    response = await rerank_documents(request)
    
    # Return in legacy format if needed
    return {
        "results": [
            {"index": r.index, "document": r.document, "relevance_score": r.relevance_score}
            for r in response.results
        ],
        "model": response.model
    }


# ============================================================================
# MAIN
# ============================================================================

def main():
    """Start the server"""
    print("\n" + "="*60)
    print("🌐 BGE-M3 Embedding & Reranker Server")
    print("="*60)
    print(f"📍 URL: http://0.0.0.0:8001")
    print(f"📚 Docs: http://0.0.0.0:8001/docs")
    print(f"🔧 Models: {EMBEDDING_MODEL_NAME}, {RERANKER_MODEL_NAME}")
    print(f"🎯 OpenAI Compatible: Yes")
    print("="*60 + "\n")
    
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8001,
        log_level="info",
        access_log=True
    )


if __name__ == "__main__":
    main()
