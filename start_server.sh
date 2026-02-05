#!/bin/bash

# Активирај виртуелно окружување
source /opt/venvs/infinity/bin/activate

# Стартувај го серверот
echo "🚀 Starting embedding server..."
python embedding_server.py
