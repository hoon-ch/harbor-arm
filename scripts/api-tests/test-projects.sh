#!/bin/bash

# Harbor API Project Management Tests
# Tests project CRUD operations

test_project_management() {
    local base_url=$1
    local cookie_file=$2

    log_section "Project Management API Tests"

    PROJECT_NAME="test-project-$$"
    PROJECT_ID=""

    # Test 1: Create a public project
    log_info "Creating project: $PROJECT_NAME..."

    response=$(curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -b "$cookie_file" \
        -d "{\"project_name\":\"$PROJECT_NAME\",\"public\":true,\"metadata\":{\"public\":\"true\"}}" \
        "${base_url}/api/v2.0/projects")

    http_code=$(echo "$response" | tail -n1)
    response_body=$(echo "$response" | head -n-1)

    if [ "$http_code" = "201" ]; then
        log_success "✅ Create Project: PASSED (HTTP $http_code)"
        echo "- ✅ Create Project: PASSED" >> "$REPORT_FILE"
        ((PASSED_TESTS++))

        # Extract project ID from Location header or by querying
        sleep 2
    else
        log_error "❌ Create Project: FAILED (Expected: 201, Got: $http_code)"
        log_error "Response: $response_body"
        echo "- ❌ Create Project: FAILED (HTTP $http_code)" >> "$REPORT_FILE"
        echo "  \`\`\`" >> "$REPORT_FILE"
        echo "  $response_body" >> "$REPORT_FILE"
        echo "  \`\`\`" >> "$REPORT_FILE"
        ((FAILED_TESTS++))
    fi
    ((TOTAL_TESTS++))

    # Test 2: List projects
    log_info "Listing projects..."

    response=$(curl -s -w "\n%{http_code}" \
        -X GET \
        -b "$cookie_file" \
        "${base_url}/api/v2.0/projects?page=1&page_size=100")

    http_code=$(echo "$response" | tail -n1)
    response_body=$(echo "$response" | head -n-1)

    if [ "$http_code" = "200" ]; then
        # Check if our project is in the list
        if echo "$response_body" | jq -e ".[] | select(.name == \"$PROJECT_NAME\")" > /dev/null 2>&1; then
            PROJECT_ID=$(echo "$response_body" | jq -r ".[] | select(.name == \"$PROJECT_NAME\") | .project_id")
            log_success "✅ List Projects: PASSED (Found $PROJECT_NAME, ID: $PROJECT_ID)"
            echo "- ✅ List Projects: PASSED (Project ID: $PROJECT_ID)" >> "$REPORT_FILE"
            ((PASSED_TESTS++))
        else
            log_warning "⚠️  List Projects: Project not found in list"
            echo "- ⚠️  List Projects: Project not found" >> "$REPORT_FILE"
        fi
    else
        log_error "❌ List Projects: FAILED (Expected: 200, Got: $http_code)"
        echo "- ❌ List Projects: FAILED (HTTP $http_code)" >> "$REPORT_FILE"
        ((FAILED_TESTS++))
    fi
    ((TOTAL_TESTS++))

    if [ -z "$PROJECT_ID" ]; then
        log_warning "Project ID not found, skipping remaining project tests"
        return 1
    fi

    # Test 3: Get specific project
    test_api_with_cookie \
        "Get Project Details" \
        "GET" \
        "/api/v2.0/projects/$PROJECT_NAME" \
        "200" \
        "" \
        "$base_url" \
        "$cookie_file"

    # Test 4: Update project metadata
    log_info "Updating project metadata..."

    response=$(curl -s -w "\n%{http_code}" \
        -X PUT \
        -H "Content-Type: application/json" \
        -b "$cookie_file" \
        -d '{"metadata":{"public":"false"}}' \
        "${base_url}/api/v2.0/projects/$PROJECT_ID")

    http_code=$(echo "$response" | tail -n1)

    if [ "$http_code" = "200" ]; then
        log_success "✅ Update Project: PASSED (HTTP $http_code)"
        echo "- ✅ Update Project: PASSED" >> "$REPORT_FILE"
        ((PASSED_TESTS++))
    else
        log_error "❌ Update Project: FAILED (Expected: 200, Got: $http_code)"
        echo "- ❌ Update Project: FAILED (HTTP $http_code)" >> "$REPORT_FILE"
        ((FAILED_TESTS++))
    fi
    ((TOTAL_TESTS++))

    # Test 5: Get project summary
    test_api_with_cookie \
        "Get Project Summary" \
        "GET" \
        "/api/v2.0/projects/$PROJECT_NAME/summary" \
        "200" \
        "" \
        "$base_url" \
        "$cookie_file"

    # Test 6: Delete project
    log_info "Deleting project: $PROJECT_NAME..."

    response=$(curl -s -w "\n%{http_code}" \
        -X DELETE \
        -b "$cookie_file" \
        "${base_url}/api/v2.0/projects/$PROJECT_ID")

    http_code=$(echo "$response" | tail -n1)

    if [ "$http_code" = "200" ]; then
        log_success "✅ Delete Project: PASSED (HTTP $http_code)"
        echo "- ✅ Delete Project: PASSED" >> "$REPORT_FILE"
        ((PASSED_TESTS++))
    else
        log_error "❌ Delete Project: FAILED (Expected: 200, Got: $http_code)"
        echo "- ❌ Delete Project: FAILED (HTTP $http_code)" >> "$REPORT_FILE"
        ((FAILED_TESTS++))
    fi
    ((TOTAL_TESTS++))

    # Verify deletion
    sleep 2
    response=$(curl -s -w "\n%{http_code}" \
        -X GET \
        -b "$cookie_file" \
        "${base_url}/api/v2.0/projects/$PROJECT_NAME")

    http_code=$(echo "$response" | tail -n1)

    if [ "$http_code" = "404" ]; then
        log_success "✅ Verify Project Deleted: PASSED"
        echo "- ✅ Verify Project Deleted: PASSED" >> "$REPORT_FILE"
        ((PASSED_TESTS++))
    else
        log_warning "⚠️  Verify Project Deleted: Project still exists (HTTP $http_code)"
        echo "- ⚠️  Verify Project Deleted: HTTP $http_code" >> "$REPORT_FILE"
    fi
    ((TOTAL_TESTS++))
}
