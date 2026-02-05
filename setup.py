from setuptools import setup, find_packages

setup(
    name="embedding_server",
    version="0.1.0",
    packages=find_packages(),
    install_requires=[
        "sentence-transformers",
        "torch==2.10.0",
        "torchvision==0.25.0",
        "fastapi",
        "uvicorn[standard]",
        "pydantic",
    ],
    entry_points={
        "console_scripts": [
            "embedding-server=embedding_server.server:main",
        ],
    },
    python_requires=">=3.12",
    description="Embedding + Reranker server with BGE-M3 models",
    author="Your Name",
    license="MIT",
)
