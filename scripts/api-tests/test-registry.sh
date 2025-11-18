#!/bin/bash

# Harbor Docker Registry Functionality Tests
# Tests image push, pull, and artifact management

test_registry_operations() {
    local base_url=$1
    local cookie_file=$2
    local registry_host=${3:-"localhost:8080"}

    log_section "Docker Registry Functionality Tests"

    PROJECT_NAME="test-registry-$$"
    IMAGE_NAME="alpine"
    IMAGE_TAG="test"

    # Test 1: Create project for registry test
    log_info "Creating project for registry test: $PROJECT_NAME..."

    response=$(curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -b "$cookie_file" \
        -d "{\"project_name\":\"$PROJECT_NAME\",\"public\":true,\"metadata\":{\"public\":\"true\"}}" \
        "${base_url}/api/v2.0/projects")

    http_code=$(echo "$response" | tail -n1)

    if [ "$http_code" = "201" ]; then
        log_success "✅ Create Registry Test Project: PASSED"
        echo "- ✅ Create Registry Test Project: PASSED" >> "$REPORT_FILE"
        ((PASSED_TESTS++))
    else
        log_error "❌ Create Registry Test Project: FAILED (HTTP $http_code)"
        echo "- ❌ Create Registry Test Project: FAILED" >> "$REPORT_FILE"
        ((FAILED_TESTS++))
        return 1
    fi
    ((TOTAL_TESTS++))

    # Test 2: Docker login
    log_info "Testing Docker login to $registry_host..."

    # Logout first
    docker logout "$registry_host" 2>/dev/null || true

    if echo "Harbor12345" | docker login "$registry_host" -u admin --password-stdin 2>&1 | grep -q "Login Succeeded"; then
        log_success "✅ Docker Login: PASSED"
        echo "- ✅ Docker Login: PASSED" >> "$REPORT_FILE"
        ((PASSED_TESTS++))
    else
        log_error "❌ Docker Login: FAILED"
        echo "- ❌ Docker Login: FAILED" >> "$REPORT_FILE"
        ((FAILED_TESTS++))
        return 1
    fi
    ((TOTAL_TESTS++))

    # Test 3: Pull a small test image
    log_info "Pulling alpine image for test..."

    if docker pull alpine:latest > /dev/null 2>&1; then
        log_success "Pulled alpine:latest"
    else
        log_error "Failed to pull alpine:latest"
        return 1
    fi

    # Test 4: Tag image for Harbor
    local full_image_name="$registry_host/$PROJECT_NAME/$IMAGE_NAME:$IMAGE_TAG"
    log_info "Tagging image as $full_image_name..."

    if docker tag alpine:latest "$full_image_name"; then
        log_success "✅ Docker Tag: PASSED"
        echo "- ✅ Docker Tag: PASSED" >> "$REPORT_FILE"
        ((PASSED_TESTS++))
    else
        log_error "❌ Docker Tag: FAILED"
        echo "- ❌ Docker Tag: FAILED" >> "$REPORT_FILE"
        ((FAILED_TESTS++))
        return 1
    fi
    ((TOTAL_TESTS++))

    # Test 5: Push image to Harbor
    log_info "Pushing image to Harbor: $full_image_name..."

    push_output=$(docker push "$full_image_name" 2>&1)
    push_result=$?

    if [ $push_result -eq 0 ]; then
        log_success "✅ Docker Push: PASSED"
        echo "- ✅ Docker Push: PASSED" >> "$REPORT_FILE"
        ((PASSED_TESTS++))
    else
        log_error "❌ Docker Push: FAILED"
        log_error "Output: $push_output"
        echo "- ❌ Docker Push: FAILED" >> "$REPORT_FILE"
        echo "  \`\`\`" >> "$REPORT_FILE"
        echo "  $push_output" >> "$REPORT_FILE"
        echo "  \`\`\`" >> "$REPORT_FILE"
        ((FAILED_TESTS++))
    fi
    ((TOTAL_TESTS++))

    # Wait for image to be indexed
    sleep 3

    # Test 6: List repositories in project
    log_info "Listing repositories in project..."

    response=$(curl -s -w "\n%{http_code}" \
        -X GET \
        -b "$cookie_file" \
        "${base_url}/api/v2.0/projects/$PROJECT_NAME/repositories")

    http_code=$(echo "$response" | tail -n1)
    response_body=$(echo "$response" | head -n-1)

    if [ "$http_code" = "200" ]; then
        if echo "$response_body" | jq -e ".[] | select(.name == \"$PROJECT_NAME/$IMAGE_NAME\")" > /dev/null 2>&1; then
            log_success "✅ List Repositories: PASSED (Found $IMAGE_NAME)"
            echo "- ✅ List Repositories: PASSED" >> "$REPORT_FILE"
            ((PASSED_TESTS++))
        else
            log_warning "⚠️  List Repositories: Repository not found"
            echo "- ⚠️  List Repositories: Repository not found" >> "$REPORT_FILE"
            echo "  Response: $response_body" >> "$REPORT_FILE"
        fi
    else
        log_error "❌ List Repositories: FAILED (HTTP $http_code)"
        echo "- ❌ List Repositories: FAILED" >> "$REPORT_FILE"
        ((FAILED_TESTS++))
    fi
    ((TOTAL_TESTS++))

    # Test 7: List artifacts in repository
    log_info "Listing artifacts in repository..."

    response=$(curl -s -w "\n%{http_code}" \
        -X GET \
        -b "$cookie_file" \
        "${base_url}/api/v2.0/projects/$PROJECT_NAME/repositories/$IMAGE_NAME/artifacts")

    http_code=$(echo "$response" | tail -n1)
    response_body=$(echo "$response" | head -n-1)

    if [ "$http_code" = "200" ]; then
        artifact_count=$(echo "$response_body" | jq '. | length')
        log_success "✅ List Artifacts: PASSED (Found $artifact_count artifact(s))"
        echo "- ✅ List Artifacts: PASSED ($artifact_count artifact(s))" >> "$REPORT_FILE"
        ((PASSED_TESTS++))
    else
        log_error "❌ List Artifacts: FAILED (HTTP $http_code)"
        echo "- ❌ List Artifacts: FAILED" >> "$REPORT_FILE"
        ((FAILED_TESTS++))
    fi
    ((TOTAL_TESTS++))

    # Test 8: Remove local image and pull from Harbor
    log_info "Removing local image..."
    docker rmi "$full_image_name" > /dev/null 2>&1 || true

    log_info "Pulling image from Harbor: $full_image_name..."

    pull_output=$(docker pull "$full_image_name" 2>&1)
    pull_result=$?

    if [ $pull_result -eq 0 ]; then
        log_success "✅ Docker Pull: PASSED"
        echo "- ✅ Docker Pull: PASSED" >> "$REPORT_FILE"
        ((PASSED_TESTS++))
    else
        log_error "❌ Docker Pull: FAILED"
        log_error "Output: $pull_output"
        echo "- ❌ Docker Pull: FAILED" >> "$REPORT_FILE"
        ((FAILED_TESTS++))
    fi
    ((TOTAL_TESTS++))

    # Cleanup: Delete repository
    log_info "Cleaning up: Deleting repository..."

    response=$(curl -s -w "\n%{http_code}" \
        -X DELETE \
        -b "$cookie_file" \
        "${base_url}/api/v2.0/projects/$PROJECT_NAME/repositories/$IMAGE_NAME")

    http_code=$(echo "$response" | tail -n1)

    if [ "$http_code" = "200" ]; then
        log_success "Deleted repository"
    else
        log_warning "Failed to delete repository (HTTP $http_code)"
    fi

    # Cleanup: Delete project
    sleep 2
    log_info "Cleaning up: Deleting project..."

    curl -s -X DELETE -b "$cookie_file" "${base_url}/api/v2.0/projects/$PROJECT_NAME" > /dev/null

    # Cleanup: Remove local images
    docker rmi "$full_image_name" alpine:latest > /dev/null 2>&1 || true
    docker logout "$registry_host" > /dev/null 2>&1 || true

    log_success "Registry tests cleanup completed"
}
