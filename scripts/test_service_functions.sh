#!/bin/bash

# Test script for service functions
ENCLAVE_NAME="cdk"

echo "=== Testing Service Functions ==="

# Function to get list of services in enclave
get_services() {
    kurtosis enclave inspect "$ENCLAVE_NAME" | grep -E "^[[:space:]]*[a-zA-Z0-9-]+(-[0-9]+)?[[:space:]]" | awk '{print $2}' | grep -v "^$"
}

# Function to check if service exists
service_exists() {
    local service=$1
    kurtosis enclave inspect "$ENCLAVE_NAME" | grep -q "[[:space:]]${service}[[:space:]]"
}

# Function to check if service is running
service_is_running() {
    local service=$1
    kurtosis enclave inspect "$ENCLAVE_NAME" | grep -A 2 "[[:space:]]${service}[[:space:]]" | grep -q "RUNNING"
}

echo "1. All services found:"
get_services

echo ""
echo "2. Testing specific services:"

# Test some specific services
services_to_test=("postgres-001" "bs-backend-001" "grafana-001" "agglayer" "nonexistent-service")

for service in "${services_to_test[@]}"; do
    echo -n "Service '$service': "
    if service_exists "$service"; then
        echo -n "EXISTS, "
        if service_is_running "$service"; then
            echo "RUNNING"
        else
            echo "STOPPED"
        fi
    else
        echo "NOT FOUND"
    fi
done

echo ""
echo "3. Raw enclave inspect output (first few lines):"
kurtosis enclave inspect "$ENCLAVE_NAME" | head -20 