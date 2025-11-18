#!/bin/bash

# Harbor API Health Check Tests
# Tests basic health and system info endpoints

test_health_checks() {
    local base_url=$1

    log_section "Health Check API Tests"

    # Test 1: Ping endpoint
    test_api \
        "Ping Endpoint" \
        "GET" \
        "/api/v2.0/ping" \
        "200" \
        "" \
        "$base_url"

    # Test 2: Health endpoint
    test_api \
        "Health Endpoint" \
        "GET" \
        "/api/v2.0/health" \
        "200" \
        "" \
        "$base_url"

    # Test 3: System Info endpoint (unauthenticated)
    test_api \
        "System Info (Unauthenticated)" \
        "GET" \
        "/api/v2.0/systeminfo" \
        "200" \
        "" \
        "$base_url"

    # Test 4: Docker Registry V2 API
    test_api \
        "Docker Registry V2" \
        "GET" \
        "/v2/" \
        "200,401" \
        "" \
        "$base_url"

    # Test 5: Statistics endpoint
    test_api \
        "Statistics Endpoint" \
        "GET" \
        "/api/v2.0/statistics" \
        "200,401" \
        "" \
        "$base_url"
}
