#!/bin/bash
# Layer 2 Sandbox Validator
# Dockerizes a skill-modified app, runs it, and validates against the real Seam sandbox API.
# CLI: bash sandbox_validator.sh --modified-dir <dir> --fixture-dir <dir> --run-id <id>

set -euo pipefail

# All log output goes to stderr; only final JSON to stdout
log() { echo "[$(date +%H:%M:%S)] $*" >&2; }

###############################################################################
# 1. api() — curl wrapper for Seam API
###############################################################################
api() {
  local endpoint="$1"
  shift
  curl -s -X POST "https://connect.getseam.com${endpoint}" \
    -H "Authorization: Bearer ${SEAM_API_KEY}" \
    -H "Content-Type: application/json" \
    "$@"
}

###############################################################################
# 2. bootstrap_sandbox()
###############################################################################
bootstrap_sandbox() {
  log "Bootstrapping sandbox..."

  # Clean any orphaned access codes from prior runs on this device
  log "Cleaning orphaned access codes..."
  local devices
  devices=$(api /devices/list)
  DEVICE_ID=$(echo "$devices" | python3 -c "
import sys, json
devices = json.loads(sys.stdin.read())['devices']
capable = [d for d in devices if 'access_code' in d.get('capabilities_supported', [])]
if capable:
    print(capable[-1]['device_id'])
")

  if [ -z "$DEVICE_ID" ]; then
    log "ERROR: No access-code-capable device found"
    exit 1
  fi
  log "Found device: $DEVICE_ID"

  # Delete any existing access grants from prior runs
  local existing_grants
  existing_grants=$(api /access_grants/list)
  local grant_count
  grant_count=$(echo "$existing_grants" | python3 -c "
import sys, json
grants = json.loads(sys.stdin.read()).get('access_grants', [])
print(len(grants))
" 2>/dev/null || echo "0")
  if [ "$grant_count" -gt 0 ]; then
    echo "$existing_grants" | python3 -c "
import sys, json
grants = json.loads(sys.stdin.read()).get('access_grants', [])
for g in grants:
    print(g['access_grant_id'])
" 2>/dev/null | while read -r grant_id; do
      api /access_grants/delete -d "{\"access_grant_id\": \"${grant_id}\"}" > /dev/null 2>&1 || true
    done
    log "  Cleaned ${grant_count} orphaned access grants"
  fi

  # Delete any existing access codes on this device from prior runs
  local existing_codes
  existing_codes=$(api /access_codes/list -d "{\"device_id\":\"${DEVICE_ID}\"}")
  local code_count
  code_count=$(echo "$existing_codes" | python3 -c "
import sys, json
codes = json.loads(sys.stdin.read()).get('access_codes', [])
print(len(codes))
" 2>/dev/null || echo "0")
  if [ "$code_count" -gt 0 ]; then
    echo "$existing_codes" | python3 -c "
import sys, json
codes = json.loads(sys.stdin.read()).get('access_codes', [])
for c in codes:
    print(c['access_code_id'])
" 2>/dev/null | while read -r code_id; do
      api /access_codes/delete -d "{\"access_code_id\": \"${code_id}\"}" > /dev/null 2>&1 || true
    done
    log "  Cleaned ${code_count} orphaned access codes"
  fi

  # Check if this fixture needs space creation (Reservation Automations) or not (Access Grants, Lower-level)
  local skip_space
  skip_space=$(echo "$EVAL_CONFIG" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('sandbox_skip_space', False))" 2>/dev/null || echo "False")

  if [ "$skip_space" = "True" ]; then
    log "Skipping space creation (fixture uses device_ids directly)"
    SPACE_KEY=""
    SPACE_ID=""
    CUSTOMER_KEY=""
  else
    # Create space — use "unit-101" as space_key so the app's push_data call
    # (which uses the unit ID from the fixture's data model) finds this space.
    SPACE_KEY="unit-101"
    CUSTOMER_KEY="prop-1"

    # Try to create space; if it already exists, look it up instead
    local space_result
    space_result=$(api /spaces/create -d "{
      \"name\": \"Unit 101 (eval ${RUN_ID})\",
      \"space_key\": \"${SPACE_KEY}\",
      \"device_ids\": [\"${DEVICE_ID}\"]
    }")

    SPACE_ID=$(echo "$space_result" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('space',{}).get('space_id',''))")

    if [ -z "$SPACE_ID" ]; then
      log "Space create returned error, looking up existing space..."
      local spaces_result
      spaces_result=$(api /spaces/list)
      SPACE_ID=$(echo "$spaces_result" | SPACE_KEY="$SPACE_KEY" python3 -c "
import sys, json, os
spaces = json.loads(sys.stdin.read()).get('spaces', [])
key = os.environ['SPACE_KEY']
for s in spaces:
    if s.get('space_key') == key:
        print(s['space_id'])
        break
")
      if [ -z "$SPACE_ID" ]; then
        log "ERROR: Failed to create or find space"
        echo "$space_result" >&2
        exit 1
      fi
      log "Found existing space: $SPACE_ID (key: $SPACE_KEY)"
    else
      log "Space created: $SPACE_ID (key: $SPACE_KEY)"
    fi
  fi
}

###############################################################################
# 3. cleanup_sandbox()
###############################################################################
cleanup_sandbox() {
  log "Cleaning up sandbox resources..."
  # Delete customer data with correct plural customer_keys and run-specific keys
  if [ -n "${CUSTOMER_KEY:-}" ]; then
    local delete_payload="{\"customer_keys\": [\"${CUSTOMER_KEY}\"]"
    if [ -n "${RESERVATION_ID:-}" ]; then
      delete_payload="${delete_payload}, \"reservation_keys\": [\"res_${RESERVATION_ID}\"]"
    fi
    delete_payload="${delete_payload}}"
    api /customers/delete_data -d "$delete_payload" > /dev/null 2>&1 || true
  fi
  if [ -n "${SPACE_ID:-}" ]; then
    api /spaces/delete -d "{\"space_id\": \"${SPACE_ID}\"}" > /dev/null 2>&1 || true
  fi
  stop_app || true
}

trap cleanup_sandbox EXIT

###############################################################################
# 4. build_app(modified_dir, fixture_dir)
###############################################################################
build_app() {
  local modified_dir="$1"
  local fixture_dir="$2"

  log "Building Docker image..."
  local temp_dir
  temp_dir=$(mktemp -d)
  rsync -a --exclude='node_modules' --exclude='dist' --exclude='__pycache__' --exclude='.venv' --exclude='.git' --exclude='package-lock.json' --exclude='.npmrc' "${modified_dir}/" "${temp_dir}/"

  IMAGE_TAG="eval-${FIXTURE_NAME}-${RUN_ID}"
  docker build -t "${IMAGE_TAG}" -f "${fixture_dir}/Dockerfile" "${temp_dir}" >&2
  rm -rf "${temp_dir}"
  log "Image built: ${IMAGE_TAG}"
}

###############################################################################
# 5. start_app(image_tag)
###############################################################################
start_app() {
  local image_tag="$1"

  log "Starting app container..."

  # Find a free port
  HOST_PORT=$(python3 -c "import socket; s=socket.socket(); s.bind(('',0)); print(s.getsockname()[1]); s.close()")

  CONTAINER_NAME="eval-${FIXTURE_NAME}-${RUN_ID}"
  # Pass Seam API key + device ID as env vars
  # For Access Grants fixtures, the app needs to know which device to target.
  # We expose DEVICE_ID under multiple common env var names so the skill
  # can find it regardless of what convention Claude uses.
  CONTAINER_ID=$(docker run -d \
    --name "${CONTAINER_NAME}" \
    -p "${HOST_PORT}:${APP_PORT}" \
    -e "${SEAM_ENV_VAR}=${SEAM_API_KEY}" \
    -e "SEAM_DEVICE_ID=${DEVICE_ID}" \
    -e "SEAM_DEVICE_ROOM_101=${DEVICE_ID}" \
    -e "SEAM_DEVICE_ROOM_205=${DEVICE_ID}" \
    -e "SEAM_DEVICE_ROOM_PH1=${DEVICE_ID}" \
    "${image_tag}")

  log "Container started: ${CONTAINER_ID:0:12} on port ${HOST_PORT}"
}

###############################################################################
# 6. wait_for_health(port, timeout_seconds)
###############################################################################
wait_for_health() {
  local port="$1"
  local timeout="${2:-30}"
  local elapsed=0

  log "Waiting for app health on port ${port} (timeout: ${timeout}s)..."
  while [ "$elapsed" -lt "$timeout" ]; do
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:${port}/health" 2>/dev/null | grep -q "200"; then
      log "App is healthy"
      return 0
    fi
    sleep 2
    elapsed=$((elapsed + 2))
    log "  ...waiting (${elapsed}/${timeout}s)"
  done

  log "ERROR: App failed to become healthy within ${timeout}s"
  docker logs "${CONTAINER_NAME}" >&2 2>/dev/null || true
  return 1
}

###############################################################################
# 7. stop_app()
###############################################################################
stop_app() {
  if [ -n "${CONTAINER_NAME:-}" ]; then
    log "Stopping container ${CONTAINER_NAME}..."
    docker stop "${CONTAINER_NAME}" > /dev/null 2>&1 || true
    docker rm "${CONTAINER_NAME}" > /dev/null 2>&1 || true
  fi
}

###############################################################################
# 8. resolve_payload(payload_json)
###############################################################################
resolve_payload() {
  local payload="$1"
  local starts_at ends_at new_ends_at

  starts_at=$(date -u -v+1H +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d "+1 hour" +"%Y-%m-%dT%H:%M:%SZ")
  ends_at=$(date -u -v+25H +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d "+25 hours" +"%Y-%m-%dT%H:%M:%SZ")
  new_ends_at=$(date -u -v+49H +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d "+49 hours" +"%Y-%m-%dT%H:%M:%SZ")

  echo "$payload" \
    | sed "s/{{RUN_ID}}/${RUN_ID}/g" \
    | sed "s/{{STARTS_AT}}/${starts_at}/g" \
    | sed "s/{{ENDS_AT}}/${ends_at}/g" \
    | sed "s/{{NEW_ENDS_AT}}/${new_ends_at}/g" \
    | sed "s/{{RESERVATION_ID}}/${RESERVATION_ID:-}/g"
}

###############################################################################
# 9. extract_id(response_json, id_path)
###############################################################################
extract_id() {
  local response="$1"
  local id_path="$2"
  echo "$response" | python3 -c "
import sys, json
data = json.loads(sys.stdin.read())
path = '${id_path}'.split('.')
val = data
for key in path:
    val = val[key]
print(val)
"
}

###############################################################################
# 10. validate_create()
###############################################################################
validate_create() {
  log "=== Validate CREATE ==="

  local path method payload response
  path=$(echo "$EVAL_CONFIG" | python3 -c "import sys,json; print(json.loads(sys.stdin.read())['test_endpoints']['create']['path'])")
  method=$(echo "$EVAL_CONFIG" | python3 -c "import sys,json; print(json.loads(sys.stdin.read())['test_endpoints']['create']['method'])")
  payload=$(echo "$EVAL_CONFIG" | python3 -c "import sys,json; print(json.dumps(json.loads(sys.stdin.read())['test_endpoints']['create']['payload']))")
  local id_path
  id_path=$(echo "$EVAL_CONFIG" | python3 -c "import sys,json; print(json.loads(sys.stdin.read())['test_endpoints']['create']['response_id_path'])")

  payload=$(resolve_payload "$payload")
  path=$(resolve_payload "$path")

  log "POST http://localhost:${HOST_PORT}${path}"
  log "Payload: ${payload}"

  response=$(curl -s -X "${method}" "http://localhost:${HOST_PORT}${path}" \
    -H "Content-Type: application/json" \
    -d "${payload}")

  log "Response: ${response}"

  RESERVATION_ID=$(extract_id "$response" "$id_path" 2>/dev/null) || true

  if [ -z "${RESERVATION_ID:-}" ]; then
    log "FAIL: Could not extract reservation ID from response"
    return 1
  fi
  log "Reservation created: ${RESERVATION_ID}"

  # Snapshot existing access code IDs before polling (to detect NEW codes only)
  local pre_codes pre_code_ids
  pre_codes=$(api /access_codes/list -d "{\"device_id\":\"${DEVICE_ID}\"}")
  pre_code_ids=$(echo "$pre_codes" | python3 -c "
import sys, json
codes = json.loads(sys.stdin.read())['access_codes']
print(','.join(c['access_code_id'] for c in codes))
" 2>/dev/null || echo "")

  # Poll Seam sandbox for a NEW access code to appear (up to 60s)
  log "Polling Seam for access codes on device (up to 60s)..."
  CREATED_CODE_ID=""
  for i in $(seq 1 12); do
    sleep 5
    local codes
    codes=$(api /access_codes/list -d "{\"device_id\":\"${DEVICE_ID}\"}")
    CREATED_CODE_ID=$(echo "$codes" | PRE="$pre_code_ids" python3 -c "
import sys, json, os
codes = json.loads(sys.stdin.read())['access_codes']
pre_ids = set(os.environ.get('PRE','').split(','))
new_codes = [c for c in codes if c['access_code_id'] not in pre_ids and c.get('status') not in ('removing', 'removed')]
if new_codes:
    print(new_codes[0]['access_code_id'])
" 2>/dev/null || echo "")

    if [ -n "$CREATED_CODE_ID" ]; then
      log "Access code found on device after $((i * 5))s (id: ${CREATED_CODE_ID})"
      break
    fi
    log "  ...not yet (${i}/12)"
  done

  if [ -n "$CREATED_CODE_ID" ]; then
    log "PASS: CREATE validation succeeded"
    return 0
  else
    log "FAIL: No access code appeared on device within 60s"
    return 1
  fi
}

###############################################################################
# 11. validate_update()
###############################################################################
validate_update() {
  log "=== Validate UPDATE ==="

  local path method payload response
  path=$(echo "$EVAL_CONFIG" | python3 -c "import sys,json; print(json.loads(sys.stdin.read())['test_endpoints']['update']['path'])")
  method=$(echo "$EVAL_CONFIG" | python3 -c "import sys,json; print(json.loads(sys.stdin.read())['test_endpoints']['update']['method'])")
  payload=$(echo "$EVAL_CONFIG" | python3 -c "import sys,json; print(json.dumps(json.loads(sys.stdin.read())['test_endpoints']['update']['payload']))")

  payload=$(resolve_payload "$payload")
  path=$(resolve_payload "$path")

  log "PUT http://localhost:${HOST_PORT}${path}"
  log "Payload: ${payload}"

  response=$(curl -s -X "${method}" "http://localhost:${HOST_PORT}${path}" \
    -H "Content-Type: application/json" \
    -d "${payload}")

  log "Response: ${response}"

  # Verify the specific access code still exists AND its ends_at was updated
  # Poll for up to 30s since the update may take a moment to propagate
  local new_ends_at
  new_ends_at=$(echo "$EVAL_CONFIG" | python3 -c "import sys,json; print(json.loads(sys.stdin.read())['test_endpoints']['update']['payload'].get('checkOut', json.loads(sys.stdin.read())['test_endpoints']['update']['payload'].get('check_out', '')))" 2>/dev/null || echo "")
  new_ends_at=$(resolve_payload "$new_ends_at")

  log "Checking access code ${CREATED_CODE_ID:-unknown} updated (expected ends_at contains: ${new_ends_at:-any})..."
  sleep 5

  local codes update_ok
  codes=$(api /access_codes/list -d "{\"device_id\":\"${DEVICE_ID}\"}")
  update_ok=$(echo "$codes" | CODE_ID="${CREATED_CODE_ID:-}" NEW_ENDS="${new_ends_at:-}" python3 -c "
import sys, json, os
codes = json.loads(sys.stdin.read())['access_codes']
code_id = os.environ.get('CODE_ID', '')
new_ends = os.environ.get('NEW_ENDS', '')
if code_id:
    match = [c for c in codes if c['access_code_id'] == code_id and c.get('status') not in ('removing', 'removed')]
    if not match:
        print('missing')  # code was deleted — update broke something
    elif new_ends and new_ends not in match[0].get('ends_at', ''):
        print('not_updated')  # code exists but ends_at wasn't changed
    else:
        print('ok')
else:
    # Fallback: just check any code exists
    active = [c for c in codes if c.get('status') not in ('removing', 'removed')]
    print('ok' if active else 'missing')
" 2>/dev/null || echo "missing")

  if [ "$update_ok" = "ok" ]; then
    log "PASS: UPDATE validation succeeded (access code present and updated)"
    return 0
  elif [ "$update_ok" = "not_updated" ]; then
    log "FAIL: Access code exists but ends_at was not updated"
    return 1
  else
    log "FAIL: Access code missing after update"
    return 1
  fi
}

###############################################################################
# 12. validate_cancel()
###############################################################################
validate_cancel() {
  log "=== Validate CANCEL ==="

  local path method response
  path=$(echo "$EVAL_CONFIG" | python3 -c "import sys,json; print(json.loads(sys.stdin.read())['test_endpoints']['cancel']['path'])")
  method=$(echo "$EVAL_CONFIG" | python3 -c "import sys,json; print(json.loads(sys.stdin.read())['test_endpoints']['cancel']['method'])")

  path=$(resolve_payload "$path")

  log "DELETE http://localhost:${HOST_PORT}${path}"

  response=$(curl -s -X "${method}" "http://localhost:${HOST_PORT}${path}" \
    -H "Content-Type: application/json")

  log "Response: ${response}"

  # Poll Seam sandbox for the SPECIFIC access code created during CREATE to be removed
  # (checking all codes fails when orphaned codes from prior runs exist on the device)
  log "Polling Seam for access code removal (up to 60s)..."
  local removed="no"
  if [ -z "${CREATED_CODE_ID:-}" ]; then
    log "WARNING: No CREATED_CODE_ID to track — checking all codes instead"
  fi
  for i in $(seq 1 12); do
    sleep 5
    local codes
    codes=$(api /access_codes/list -d "{\"device_id\":\"${DEVICE_ID}\"}")
    local code_gone
    code_gone=$(echo "$codes" | CODE_ID="${CREATED_CODE_ID:-}" python3 -c "
import sys, json, os
codes = json.loads(sys.stdin.read())['access_codes']
code_id = os.environ.get('CODE_ID', '')
if code_id:
    # Check if our specific code is gone or removing
    match = [c for c in codes if c['access_code_id'] == code_id]
    if not match or match[0].get('status') in ('removing', 'removed'):
        print('yes')
    else:
        print('no')
else:
    # Fallback: check if all codes are gone
    active = [c for c in codes if c.get('status') not in ('removing', 'removed')]
    print('yes' if len(active) == 0 else 'no')
" 2>/dev/null || echo "no")

    if [ "$code_gone" = "yes" ]; then
      removed="yes"
      log "Access code removed after $((i * 5))s"
      break
    fi
    log "  ...still active (${i}/12)"
  done

  if [ "$removed" = "yes" ]; then
    log "PASS: CANCEL validation succeeded"
    return 0
  else
    log "FAIL: Active access codes still on device after cancellation"
    return 1
  fi
}

###############################################################################
# 13. Main flow
###############################################################################

# Parse arguments
MODIFIED_DIR=""
FIXTURE_DIR=""
RUN_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --modified-dir) MODIFIED_DIR="$2"; shift 2 ;;
    --fixture-dir)  FIXTURE_DIR="$2";  shift 2 ;;
    --run-id)       RUN_ID="$2";       shift 2 ;;
    *) log "Unknown argument: $1"; exit 1 ;;
  esac
done

if [ -z "$MODIFIED_DIR" ] || [ -z "$FIXTURE_DIR" ] || [ -z "$RUN_ID" ]; then
  log "Usage: sandbox_validator.sh --modified-dir <dir> --fixture-dir <dir> --run-id <id>"
  exit 1
fi

# Validate SEAM_API_KEY
: "${SEAM_API_KEY:?SEAM_API_KEY must be set}"

# Read eval config
EVAL_CONFIG=$(cat "${FIXTURE_DIR}/eval_config.json")
FIXTURE_NAME=$(echo "$EVAL_CONFIG" | python3 -c "import sys,json; print(json.loads(sys.stdin.read())['fixture'])")
APP_PORT=$(echo "$EVAL_CONFIG" | python3 -c "import sys,json; print(json.loads(sys.stdin.read())['app_port'])")
SEAM_ENV_VAR=$(echo "$EVAL_CONFIG" | python3 -c "import sys,json; print(json.loads(sys.stdin.read())['seam_env_var'])")

# Initialize global state
DEVICE_ID=""
SPACE_ID=""
SPACE_KEY=""
CUSTOMER_KEY=""
RESERVATION_ID=""
IMAGE_TAG=""
CONTAINER_NAME=""
CONTAINER_ID=""
HOST_PORT=""

# Scores
BUILD_SCORE=0
CREATE_SCORE=0
UPDATE_SCORE=0
CANCEL_SCORE=0

# Bootstrap sandbox
bootstrap_sandbox

# Build and start app
if build_app "$MODIFIED_DIR" "$FIXTURE_DIR"; then
  if start_app "$IMAGE_TAG"; then
    if wait_for_health "$HOST_PORT" 30; then
      BUILD_SCORE=10
      log "BUILD: PASS (10 points)"
    else
      log "BUILD: FAIL (app did not become healthy)"
    fi
  else
    log "BUILD: FAIL (container failed to start)"
  fi
else
  log "BUILD: FAIL (docker build failed)"
fi

# Run validations only if build succeeded
if [ "$BUILD_SCORE" -gt 0 ]; then
  # validate_create
  if validate_create; then
    CREATE_SCORE=30
    log "CREATE: PASS (30 points)"
  else
    CREATE_SCORE=0
    log "CREATE: FAIL (0 points)"
  fi

  # validate_update (only if create succeeded and we have a RESERVATION_ID)
  if [ "$CREATE_SCORE" -gt 0 ] && [ -n "${RESERVATION_ID:-}" ]; then
    if validate_update; then
      UPDATE_SCORE=30
      log "UPDATE: PASS (30 points)"
    else
      UPDATE_SCORE=0
      log "UPDATE: FAIL (0 points)"
    fi
  else
    log "UPDATE: SKIPPED (create failed)"
  fi

  # validate_cancel (only if create succeeded)
  if [ "$CREATE_SCORE" -gt 0 ] && [ -n "${RESERVATION_ID:-}" ]; then
    if validate_cancel; then
      CANCEL_SCORE=30
      log "CANCEL: PASS (30 points)"
    else
      CANCEL_SCORE=0
      log "CANCEL: FAIL (0 points)"
    fi
  else
    log "CANCEL: SKIPPED (create failed)"
  fi
fi

TOTAL=$((BUILD_SCORE + CREATE_SCORE + UPDATE_SCORE + CANCEL_SCORE))

log "=== FINAL SCORE: ${TOTAL}/100 ==="

# Output JSON to stdout (only output to stdout in the entire script)
cat <<EOF
{"total": ${TOTAL}, "checks": {"build": ${BUILD_SCORE}, "create": ${CREATE_SCORE}, "update": ${UPDATE_SCORE}, "cancel": ${CANCEL_SCORE}}}
EOF
