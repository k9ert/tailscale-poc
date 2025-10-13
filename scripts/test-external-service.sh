#!/bin/bash

# Test script for external service access
# This script helps test connectivity from Kubernetes to external Tailscale services

set -e

echo "🔍 Testing external service access from Kubernetes cluster..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed or not in PATH"
    exit 1
fi

# Check if we're connected to a cluster
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Not connected to a Kubernetes cluster"
    exit 1
fi

echo "✅ Connected to Kubernetes cluster"

# Function to test service connectivity
test_service() {
    local service_name=$1
    local port=$2
    local path=${3:-"/"}
    
    echo "🧪 Testing connectivity to service: $service_name:$port"
    
    # Create a temporary test pod if it doesn't exist
    if ! kubectl get pod test-connectivity -n tailscale-egress &> /dev/null; then
        echo "📦 Creating test pod..."
        kubectl run test-connectivity --image=curlimages/curl:latest --restart=Never -n tailscale-egress -- sleep 3600
        kubectl wait --for=condition=Ready pod/test-connectivity -n tailscale-egress --timeout=60s
    fi
    
    # Test the connection
    echo "🌐 Testing HTTP connection..."
    if kubectl exec test-connectivity -n tailscale-egress -- curl -s --connect-timeout 10 "http://$service_name:$port$path" > /dev/null; then
        echo "✅ Successfully connected to $service_name:$port"
        return 0
    else
        echo "❌ Failed to connect to $service_name:$port"
        return 1
    fi
}

# Function to check service status
check_service_status() {
    local service_name=$1
    
    echo "🔍 Checking service status: $service_name"
    
    if kubectl get service "$service_name" -n tailscale-egress &> /dev/null; then
        echo "✅ Service $service_name exists"

        # Check if externalName is set (indicates operator has processed it)
        external_name=$(kubectl get service "$service_name" -n tailscale-egress -o jsonpath='{.spec.externalName}')
        if [[ "$external_name" != "placeholder" && "$external_name" != "unused" ]]; then
            echo "✅ Service $service_name has been processed by Tailscale operator"
            echo "   External name: $external_name"
        else
            echo "⏳ Service $service_name is still being processed by Tailscale operator"
            echo "   Current external name: $external_name"
        fi
    else
        echo "❌ Service $service_name does not exist"
        return 1
    fi
}

# Main test function
main() {
    echo "🚀 Starting external service connectivity tests..."
    
    # List of services to test (you can modify this based on your configuration)
    services=(
        "external-service:8080"
        "my-laptop-webserver:8080"
    )
    
    # Check service statuses
    echo ""
    echo "📋 Checking service statuses..."
    for service_port in "${services[@]}"; do
        service_name=$(echo "$service_port" | cut -d':' -f1)
        if kubectl get service "$service_name" -n tailscale-egress &> /dev/null; then
            check_service_status "$service_name"
        fi
    done
    
    echo ""
    echo "🧪 Testing connectivity..."
    
    # Test connectivity to existing services
    success_count=0
    total_count=0
    
    for service_port in "${services[@]}"; do
        service_name=$(echo "$service_port" | cut -d':' -f1)
        port=$(echo "$service_port" | cut -d':' -f2)
        
        if kubectl get service "$service_name" -n tailscale-egress &> /dev/null; then
            total_count=$((total_count + 1))
            if test_service "$service_name" "$port"; then
                success_count=$((success_count + 1))
            fi
            echo ""
        fi
    done
    
    # Keep test pod for manual testing
    echo "🔧 Test pod 'test-connectivity' is available for manual testing"
    echo ""
    echo "📋 Manual Testing Commands:"
    echo "   # Get a shell in the test pod:"
    echo "   kubectl exec -it test-connectivity -n tailscale-egress -- sh"
    echo ""
    echo "   # Test connectivity from within the pod:"
    for service_port in "${services[@]}"; do
        service_name=$(echo "$service_port" | cut -d':' -f1)
        port=$(echo "$service_port" | cut -d':' -f2)
        if kubectl get service "$service_name" -n tailscale-egress &> /dev/null; then
            echo "   kubectl exec test-connectivity -n tailscale-egress -- curl -v http://$service_name:$port/"
        fi
    done
    echo ""
    echo "   # Check DNS resolution:"
    for service_port in "${services[@]}"; do
        service_name=$(echo "$service_port" | cut -d':' -f1)
        if kubectl get service "$service_name" -n tailscale-egress &> /dev/null; then
            echo "   kubectl exec test-connectivity -n tailscale-egress -- nslookup $service_name"
        fi
    done
    echo ""
    echo "   # Clean up when done:"
    echo "   kubectl delete pod test-connectivity -n tailscale-egress"
    echo ""

    # Summary
    echo "📊 Test Summary:"
    echo "   Successful connections: $success_count/$total_count"

    if [[ $success_count -eq $total_count && $total_count -gt 0 ]]; then
        echo "🎉 All tests passed!"
        exit 0
    elif [[ $total_count -eq 0 ]]; then
        echo "ℹ️  No external services found to test"
        echo "   Deploy some external services first using the examples in examples/external-service-values.yaml"
        exit 0
    else
        echo "⚠️  Some tests failed. Check your external service configuration and Tailscale connectivity."
        echo "   Use the manual testing commands above to debug further."
        exit 1
    fi
}

# Show usage if help is requested
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Test external service access from Kubernetes to Tailscale nodes"
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help message"
    echo ""
    echo "This script will:"
    echo "1. Check if external services are configured"
    echo "2. Verify that the Tailscale operator has processed them"
    echo "3. Test connectivity from within the cluster"
    echo ""
    echo "Make sure you have:"
    echo "- kubectl configured and connected to your cluster"
    echo "- External services configured in your Helm values"
    echo "- Services running on your Tailscale nodes"
    exit 0
fi

# Run the main function
main
