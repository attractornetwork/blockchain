#!/bin/bash

for i in {1..60}; do
    if docker info > /dev/null 2>&1; then
        echo "Docker is running!"
        break
    else
        echo "Waiting for Docker to start... ($i/60)"
        sleep 1
    fi
done

if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker did not start in time."
    exit 1
fi

ENGINE_STATUS=$(kurtosis engine status 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ] || echo "$ENGINE_STATUS" | grep -q "No Kurtosis engine is running"; then
    echo "Kurtosis engine is not running. Starting..."
    kurtosis engine restart
    if [ $? -eq 0 ]; then
        echo "✅ Kurtosis engine started successfully."
    else
        echo "❌ Failed to start Kurtosis engine."
        exit 1
    fi
elif echo "$ENGINE_STATUS" | grep -q "A Kurtosis engine is running"; then
    echo "Kurtosis engine is already running."
    echo "$ENGINE_STATUS" | grep "Version:"
else
    echo "❌ Unexpected engine status output:"
    echo "$ENGINE_STATUS"
    exit 1
fi
