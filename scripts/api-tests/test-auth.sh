#!/bin/bash

# Harbor API Authentication Tests
# Tests login, logout, and authenticated endpoints

test_authentication() {
    local base_url=$1
    local cookie_file=$2

    log_section "Authentication API Tests"

    # Test 1: Login with default admin credentials
    log_info "Attempting login as admin..."

    response=$(curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -c "$cookie_file" \
        -d '{"principal":"admin","password":"Harbor12345"}' \
        "${base_url}/c/login")

    http_code=$(echo "$response" | tail -n1)
    response_body=$(echo "$response" | head -n-1)

    if [ "$http_code" = "200" ]; then
        log_success "✅ Login: PASSED (HTTP $http_code)"
        echo "- ✅ Login: PASSED" >> "$REPORT_FILE"
        ((PASSED_TESTS++))
        LOGGED_IN=true
    else
        log_error "❌ Login: FAILED (Expected: 200, Got: $http_code)"
        log_error "Response: $response_body"
        echo "- ❌ Login: FAILED (HTTP $http_code)" >> "$REPORT_FILE"
        ((FAILED_TESTS++))
        LOGGED_IN=false
        return 1
    fi
    ((TOTAL_TESTS++))

    # Test 2: Get current user info (requires authentication)
    test_api_with_cookie \
        "Get Current User" \
        "GET" \
        "/api/v2.0/users/current" \
        "200" \
        "" \
        "$base_url" \
        "$cookie_file"

    # Test 3: List users (requires admin)
    test_api_with_cookie \
        "List Users" \
        "GET" \
        "/api/v2.0/users" \
        "200" \
        "" \
        "$base_url" \
        "$cookie_file"

    # Test 4: Get system info (authenticated)
    test_api_with_cookie \
        "System Info (Authenticated)" \
        "GET" \
        "/api/v2.0/systeminfo" \
        "200" \
        "" \
        "$base_url" \
        "$cookie_file"

    # Test 5: Logout
    log_info "Attempting logout..."

    response=$(curl -s -w "\n%{http_code}" \
        -X POST \
        -b "$cookie_file" \
        "${base_url}/c/logout")

    http_code=$(echo "$response" | tail -n1)

    if [ "$http_code" = "200" ]; then
        log_success "✅ Logout: PASSED (HTTP $http_code)"
        echo "- ✅ Logout: PASSED" >> "$REPORT_FILE"
        ((PASSED_TESTS++))
    else
        log_warning "⚠️  Logout: Got HTTP $http_code (expected 200)"
        echo "- ⚠️  Logout: HTTP $http_code" >> "$REPORT_FILE"
    fi
    ((TOTAL_TESTS++))

    # Re-login for subsequent tests
    if [ "$LOGGED_IN" = "true" ]; then
        curl -s -X POST \
            -H "Content-Type: application/json" \
            -c "$cookie_file" \
            -d '{"principal":"admin","password":"Harbor12345"}' \
            "${base_url}/c/login" > /dev/null
    fi
}
