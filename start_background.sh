#!/bin/bash

# Активирај виртуелно окружување
source /opt/venvs/infinity/bin/activate

# Стартувај во позадина со nohup
echo "🚀 Starting embedding server in background..."
nohup python embedding_server.py > embedding.log 2>&1 &

# Зачувај PID
echo $! > server.pid
echo "✅ Server started with PID: $(cat server.pid)"
echo "📄 Logs: tail -f embedding.log"
