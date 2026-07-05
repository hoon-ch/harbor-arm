#!/usr/bin/env bash
set -euo pipefail

# End-to-end Harbor smoke test using the prepare-generated compose flow.
# Usage: ./e2e-harbor-smoke.sh <version> <docker_username>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common.sh"

if [ $# -lt 2 ]; then
    log_error "Usage: $0 <version> <docker_username>"
    log_info "Example: $0 v2.15.1 myusername"
    exit 1
fi

VERSION=$1
DOCKER_USERNAME=$2
VERSION_TAG=$(clean_version_tag "$VERSION")
WORK_DIR="$(mktemp -d)"
COMPOSE_FILE="${WORK_DIR}/docker-compose.yml"

# Harbor is designed to run as root: prepare writes env_files/configs owned by
# root and the service containers run as their own uids. Drive docker compose
# (and workspace cleanup) via sudo so it can read those root-owned env_files,
# mirroring a real Harbor deployment.
SUDO=""
if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
fi

compose() {
    $SUDO docker compose "$@"
}

# shellcheck disable=SC2317,SC2329  # cleanup runs indirectly via `trap cleanup EXIT`
cleanup() {
    if [ -f "$COMPOSE_FILE" ]; then
        compose -f "$COMPOSE_FILE" down -v >/dev/null 2>&1 || true
    fi
    $SUDO rm -rf "$WORK_DIR"
}
trap cleanup EXIT

log_section "Harbor ARM64 E2E Smoke Test"
log_info "Version: $VERSION"
log_info "Version Tag: $VERSION_TAG"
log_info "Docker Username: $DOCKER_USERNAME"
log_info "Workspace: $WORK_DIR"

mkdir -p "${WORK_DIR}/common/config" "${WORK_DIR}/data" "${WORK_DIR}/secret"

cat > "${WORK_DIR}/harbor.yml" <<EOF
hostname: localhost
http:
  port: 8080
harbor_admin_password: Harbor12345
database:
  password: root123
data_volume: ${WORK_DIR}/data
jobservice:
  max_job_workers: 10
  job_loggers:
    - STD_OUTPUT
    - FILE
  logger_sweeper_duration: 1
notification:
  webhook_job_max_retry: 3
  webhook_job_http_client_timeout: 3
log:
  level: info
  local:
    rotate_count: 50
    rotate_size: 200M
    location: ${WORK_DIR}/logs
EOF

log_info "Generating Harbor configuration with prepare image"
docker run --rm \
    --privileged \
    -v /:/hostfs \
    -v "${WORK_DIR}:/input" \
    -v "${WORK_DIR}:/compose_location" \
    -v "${WORK_DIR}/common/config:/config" \
    -v "${WORK_DIR}/data:/data" \
    -v "${WORK_DIR}/secret:/secret" \
    "${DOCKER_USERNAME}/harbor-prepare-arm64:${VERSION_TAG}" \
    prepare \
    --conf /input/harbor.yml

if [ ! -f "$COMPOSE_FILE" ]; then
    log_error "prepare did not generate docker-compose.yml"
    log_info "Workspace files:"
    find "$WORK_DIR" -maxdepth 3 -type f | sort || true
    exit 1
fi

# prepare runs as root inside the container and writes docker-compose.yml owned
# by root, so reclaim just that file for the host-side rewrite below. Do NOT
# touch the generated config/data tree: prepare sets it to the uids the service
# containers run as (e.g. 999/10000), and chowning it to the runner would break
# each service with "permission denied" on its config.
if [ ! -w "$COMPOSE_FILE" ] && command -v sudo >/dev/null 2>&1; then
    sudo chown "$(id -u):$(id -g)" "$COMPOSE_FILE" || true
fi

log_info "Rewriting generated compose file to use rebuilt ARM64 images"
python3 - "$COMPOSE_FILE" "$DOCKER_USERNAME" "$VERSION_TAG" <<'PY'
import re
import sys
from pathlib import Path

compose = Path(sys.argv[1])
user = sys.argv[2]
tag = sys.argv[3]
text = compose.read_text()
replacements = {
    "prepare": "harbor-prepare-arm64",
    "harbor-core": "harbor-core-arm64",
    "harbor-jobservice": "harbor-jobservice-arm64",
    "harbor-portal": "harbor-portal-arm64",
    "nginx-photon": "harbor-nginx-arm64",
    "harbor-log": "harbor-log-arm64",
    "harbor-db": "harbor-db-arm64",
    "valkey-photon": "harbor-valkey-arm64",
    "registry-photon": "harbor-registry-arm64",
    "harbor-registryctl": "harbor-registryctl-arm64",
    "harbor-exporter": "harbor-exporter-arm64",
}

for source, target in replacements.items():
    text = re.sub(
        rf"goharbor/{re.escape(source)}:[^\s\"']+",
        f"{user}/{target}:{tag}",
        text,
    )

# Drop Harbor's per-service syslog logging driver. It points every container at
# harbor-log's rsyslog on tcp://localhost:1514, which fails on this single-host
# smoke runner (localhost resolves to IPv6 ::1, rsyslog listens on IPv4 only),
# aborting container startup. Default json-file logging is fine for a smoke test.
text = re.sub(
    r'\n[ ]*logging:\n[ ]*driver: "syslog"\n[ ]*options:\n[ ]*syslog-address: "[^"]*"\n[ ]*tag: "[^"]*"',
    "",
    text,
)

compose.write_text(text)
PY

if grep -q 'goharbor/' "$COMPOSE_FILE"; then
    log_error "Generated compose file still references upstream goharbor images"
    grep 'goharbor/' "$COMPOSE_FILE" || true
    exit 1
fi

log_info "Starting generated Harbor stack"
compose -f "$COMPOSE_FILE" up -d

for attempt in $(seq 1 60); do
    if curl -fsS http://localhost:8080/api/v2.0/ping >/dev/null 2>&1; then
        log_success "Harbor ping endpoint responded"
        exit 0
    fi

    log_info "Waiting for Harbor ping endpoint, attempt ${attempt}/60"
    sleep 5
done

compose -f "$COMPOSE_FILE" ps || true
compose -f "$COMPOSE_FILE" logs --tail=200 || true
log_error "Harbor ping endpoint did not respond"
exit 1
