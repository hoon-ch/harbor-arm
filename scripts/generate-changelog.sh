#!/bin/bash
set -e

# Generate CHANGELOG.md from git commit history
# Usage: ./generate-changelog.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Simple logging functions (don't source common.sh to avoid config.sh)
log_section() {
    echo ""
    echo "=========================================="
    echo "$1"
    echo "=========================================="
}

log_info() {
    echo "[INFO] $1"
}

log_success() {
    echo "[SUCCESS] $1"
}

CHANGELOG_FILE="${SCRIPT_DIR}/../CHANGELOG.md"
BUILT_VERSIONS_FILE="${SCRIPT_DIR}/../built_versions.txt"

log_section "Generating CHANGELOG"

# Initialize changelog
cat > "$CHANGELOG_FILE" <<'EOF'
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

EOF

# Get all tags sorted by version
TAGS=$(git tag --sort=-v:refname)

# Get commits since last tag or all commits
if [ -z "$TAGS" ]; then
    log_info "No tags found, generating changelog from all commits"
    COMMITS=$(git log --oneline --reverse)
else
    log_info "Found tags, generating changelog from tagged releases"
fi

# Function to categorize commit
categorize_commit() {
    local commit_msg=$1

    if [[ $commit_msg =~ ^feat ]]; then
        echo "### Added"
    elif [[ $commit_msg =~ ^fix ]]; then
        echo "### Fixed"
    elif [[ $commit_msg =~ ^docs ]]; then
        echo "### Documentation"
    elif [[ $commit_msg =~ ^refactor ]]; then
        echo "### Changed"
    elif [[ $commit_msg =~ ^test ]]; then
        echo "### Tests"
    elif [[ $commit_msg =~ ^chore ]]; then
        echo "### Maintenance"
    else
        echo "### Other"
    fi
}

# Function to clean commit message
clean_commit_msg() {
    local msg=$1
    # Remove conventional commit prefix
    echo "$msg" | sed -E 's/^(feat|fix|docs|refactor|test|chore)(\([^)]+\))?: //'
}

# Generate changelog for each version
if [ -f "$BUILT_VERSIONS_FILE" ]; then
    log_info "Adding built Harbor versions to changelog"

    echo "## Harbor ARM64 Builds" >> "$CHANGELOG_FILE"
    echo "" >> "$CHANGELOG_FILE"
    echo "List of Harbor versions built for ARM64:" >> "$CHANGELOG_FILE"
    echo "" >> "$CHANGELOG_FILE"

    while IFS= read -r version; do
        if [ -n "$version" ]; then
            # Get build date from git log if available
            BUILD_DATE=$(git log --all --grep="$version" --format="%ai" | head -1 | cut -d' ' -f1)
            if [ -z "$BUILD_DATE" ]; then
                BUILD_DATE="Unknown"
            fi
            echo "- **$version** - Built on $BUILD_DATE" >> "$CHANGELOG_FILE"
        fi
    done < <(sort -V -r "$BUILT_VERSIONS_FILE")

    echo "" >> "$CHANGELOG_FILE"
fi

# Generate changelog from git tags
if [ -n "$TAGS" ]; then
    log_info "Generating changelog from git tags"
    echo "## Project Changes" >> "$CHANGELOG_FILE"
    echo "" >> "$CHANGELOG_FILE"

    PREV_TAG=""
    for TAG in $TAGS; do
        echo "## [$TAG] - $(git log -1 --format=%ai $TAG | cut -d' ' -f1)" >> "$CHANGELOG_FILE"
        echo "" >> "$CHANGELOG_FILE"

        # Get commits for this tag
        if [ -z "$PREV_TAG" ]; then
            COMMITS=$(git log $TAG --oneline --no-merges --reverse)
        else
            COMMITS=$(git log ${PREV_TAG}..${TAG} --oneline --no-merges --reverse)
        fi

        # Output commits by category
        for CATEGORY in "### Added" "### Fixed" "### Changed" "### Documentation" "### Tests" "### Maintenance" "### Other"; do
            HAS_COMMITS=false

            while IFS= read -r commit; do
                if [ -n "$commit" ]; then
                    HASH=$(echo "$commit" | awk '{print $1}')
                    MSG=$(echo "$commit" | cut -d' ' -f2-)
                    COMMIT_CATEGORY=$(categorize_commit "$MSG")
                    CLEAN_MSG=$(clean_commit_msg "$MSG")

                    if [ "$COMMIT_CATEGORY" = "$CATEGORY" ]; then
                        if [ "$HAS_COMMITS" = false ]; then
                            echo "$CATEGORY" >> "$CHANGELOG_FILE"
                            echo "" >> "$CHANGELOG_FILE"
                            HAS_COMMITS=true
                        fi
                        echo "- $CLEAN_MSG (\`$HASH\`)" >> "$CHANGELOG_FILE"
                    fi
                fi
            done <<< "$COMMITS"

            if [ "$HAS_COMMITS" = true ]; then
                echo "" >> "$CHANGELOG_FILE"
            fi
        done

        echo "" >> "$CHANGELOG_FILE"
        PREV_TAG=$TAG
    done
else
    # Generate from commit history (no tags)
    log_info "Generating changelog from commit history"
    echo "## [Unreleased]" >> "$CHANGELOG_FILE"
    echo "" >> "$CHANGELOG_FILE"

    COMMITS=$(git log --oneline --no-merges --reverse)

    # Output commits by category
    for CATEGORY in "### Added" "### Fixed" "### Changed" "### Documentation" "### Tests" "### Maintenance" "### Other"; do
        HAS_COMMITS=false

        while IFS= read -r commit; do
            if [ -n "$commit" ]; then
                HASH=$(echo "$commit" | awk '{print $1}')
                MSG=$(echo "$commit" | cut -d' ' -f2-)
                COMMIT_CATEGORY=$(categorize_commit "$MSG")
                CLEAN_MSG=$(clean_commit_msg "$MSG")

                if [ "$COMMIT_CATEGORY" = "$CATEGORY" ]; then
                    if [ "$HAS_COMMITS" = false ]; then
                        echo "$CATEGORY" >> "$CHANGELOG_FILE"
                        echo "" >> "$CHANGELOG_FILE"
                        HAS_COMMITS=true
                    fi
                    echo "- $CLEAN_MSG (\`$HASH\`)" >> "$CHANGELOG_FILE"
                fi
            fi
        done <<< "$COMMITS"

        if [ "$HAS_COMMITS" = true ]; then
            echo "" >> "$CHANGELOG_FILE"
        fi
    done
fi

# Add footer
cat >> "$CHANGELOG_FILE" <<'EOF'

---

## Legend

- **Added**: New features
- **Fixed**: Bug fixes
- **Changed**: Changes in existing functionality
- **Documentation**: Documentation updates
- **Tests**: Test additions or modifications
- **Maintenance**: Build process, dependencies, or tooling changes

---

Generated with ❤️ by [generate-changelog.sh](scripts/generate-changelog.sh)
EOF

log_success "Changelog generated: $CHANGELOG_FILE"
log_info "Review and edit as needed before committing"
