#!/bin/bash

if [ -f server.pid ]; then
    PID=$(cat server.pid)
    echo "🛑 Stopping server (PID: $PID)..."
    kill $PID
    rm server.pid
    echo "✅ Server stopped"
else
    echo "⚠️  No server.pid file found"
    echo "Trying to find process..."
    pkill -f "python embedding_server.py"
fi
