# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Harbor ARM64 Builds

List of Harbor versions built for ARM64:

- **# This file tracks which Harbor versions have been built** - Built on Unknown
- **# Format: one version per line (e.g., v2.11.0)** - Built on Unknown
- **# Cleared for Phase 2 testing** - Built on Unknown
- **v2.14.0** - Built on 2025-11-18

## [Unreleased]

### Added

- switch to native ARM64 GitHub Actions runners (`6626053`)
- Add ARM64 builds for registry, registryctl, and exporter (`8e5d898`)
- Add push trigger to workflow for automatic execution (`12c5ffa`)

### Fixed

- implement two-stage build process for Harbor components (`950c9b9`)
- remove -arm64 suffix from base image names (`142703c`)
- update Go version to 1.24 for Harbor v2.14.0 (`130064b`)
- disable exporter to avoid missing base image error (`dfafe1f`)
- add exporter to BUILDBASETARGET (`1a75aac`)
- patch Makefile to remove exporter from build (`7ed615c`)
- use 'make compile build' instead of 'make install' (`26ee97c`)
- resolve image naming mismatch and Go version compatibility (`84fa5d0`)
- add BUILD_BASE=true to build base images (`513ab79`)
- remove BUILD_BASE to use official Harbor base images (`9f7b9ed`)
- update Go version to 1.23 for Harbor v2.13.0 compatibility (`1dd6839`)
- use correct base image tags with 'v' prefix (`f29960f`)
- force ARM64 architecture in Docker builds (`48c6ee1`)
- remove v2.14.0 from built versions to rebuild with ARM64 (`d12a0bc`)
- add --load flag to buildx and skip API linting (`8a4a912`)
- Remove incorrectly built versions to enable native ARM64 rebuild (`8aea022`)
- Correct ARM64 runner label to ubuntu-24.04-arm (`d489808`)
- Build ARM64 base images before main Harbor build (`e91144c`)
- Improve ARM64 base image building with better error handling (`63d217b`)
- Remove invalid --pull=missing flag from docker buildx (`ffb901e`)
- Aggressively patch Dockerfiles to use local ARM64 base images (`ac30075`)
- Force Harbor to use local ARM64 images by patching Makefile (`ca3d9ae`)
- Patch docker buildx build commands to use --pull=never (`c1a46d4`)
- Bypass Harbor Makefile and build images manually (`13a581d`)
- Change --pull=never to --pull=false for buildx compatibility (`7469da7`)
- Replace docker buildx with regular docker build (`2301b2e`)
- Add --build-arg parameters to all component builds (`dba3b0c`)
- Remove incorrectly built version to enable full rebuild (`791c940`)
- Add NODE build arg for portal and exclude components requiring binaries (`f7b86a9`)
- Add go mod download for registry build (`840db41`)
- Remove go mod download causing 'no modules specified' error (`9d8ce4a`)
- Use main branch for registry build and vendor dependencies (`69654fa`)
- Use explicit path for registry binary to avoid directory naming conflict (`69e5c79`)
- Add detailed logging for exporter build and binary verification (`79f60c6`)
- Build exporter manually using go build instead of make target (`a1b2cd8`)
- Use pre-built ARM64 exporter binary in Docker image (`5b6fc9e`)
- Move workflow_dispatch trigger to top to fix GitHub cache issue (`ba1a3ff`)
- Add default value to workflow_dispatch input to force GitHub refresh (`fb21556`)
- Rename workflow file to force GitHub Actions to recognize workflow_dispatch trigger (`7a421c2`)
- Remove push trigger to fix GitHub workflow_dispatch issue (`f96b85d`)
- Replace heredoc with echo commands to fix YAML parsing error (`c2d4c2b`)
- validate-images.sh: Replace (()) with $((expr)) for compatibility with set -e (`d1b8670`)
- add image pull/retag steps for Phase 2 tests (`8998cf0`)
- docker-compose.test.yml: Use consistent internal image names (`b6ce5b5`)
- container startup issues in integration tests (`7e889c7`)
- simplify integration tests to avoid config requirements (`4cd5820`)
- format built_versions.txt to move version to new line (`582c048`)

### Changed

- use Harbor official Makefile for ARM64 build (`5e2b520`)
- reorganize repository structure for better maintainability (`e7fedb4`)

### Documentation

- add comprehensive deployment guides for Docker, Compose, and Kubernetes (`3accd38`)

### Tests

- Trigger workflow to test exporter build fix (`d55ccb4`)

### Maintenance

- initial setup for Harbor ARM64 auto-build (`c40ba85`)
- upgrade Go to 1.24 for Harbor v2.14.0 support (`9f82303`)
- Remove v2.14.0 to test portal build fix (`8ea9e46`)
- Remove v2.14.0 to rebuild with registry/exporter support (`217e0f6`)
- Clear built_versions.txt to rebuild v2.14.0 with exporter fixes (`c351d1d`)
- Clear built_versions to test exporter fix (`7c925b4`)
- Clear built_versions for exporter Docker fix test (`00182dc`)
- Empty commit to trigger workflow parsing (`48dba7d`)
- make smoke tests optional in validation (`14ce7ff`)
- debug and simplify container startup in integration tests (`faabc98`)
- add built version v2.14.0 (`05871ab`)

### Other

- Add built version v2.13.0 (`bd6d82b`)
- Add built version v2.14.0 (`b3428b6`)
- Add built version v2.14.0 (`7eb1f4a`)
- Add built version v2.14.0 (`84c5b79`)
- Add built version v2.14.0 (`ba20a1d`)
- Add built version v2.14.0 (`f867614`)
- Add built version v2.14.0 (`77ff9cf`)
- Add built version v2.14.0 (`fe14cfd`)
- Add built version v2.14.0 (`b856270`)
- Add built version v2.14.0 (`471b64c`)
- Clear built_versions.txt to enable Harbor v2.12.1 build (`dfa38c0`)
- Add workflow to build Harbor v2.12.1 for ARM64 (`b1c362e`)
- Fix Harbor v2.12.1 workflow: Remove Docker Hub dependency (`b1cf34b`)
- Fix Harbor v2.12.1 build: Add missing base image namespace arguments (`063a675`)
- Add Phase 1 & 2: Refactor workflow and add comprehensive testing (`b9227fe`)
- Clear built_versions.txt for Phase 2 testing (`3bda70c`)
- Fix build-harbor job: Add harbor-arm repository checkout (`95d2bc6`)


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
