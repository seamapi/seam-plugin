#!/bin/bash
# Eval orchestrator — invokes the skill against fixture apps, runs scoring layers,
# and produces a summary table.
#
# Usage:
#   bash evals/run_evals.sh [--fixtures express-ts,flask-py] [--layers rubric,sandbox,both] \
#                            [--api-path reservation_automations] [--runs N]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

###############################################################################
# Logging — all log output to stderr
###############################################################################
log() { echo "[$(date +%H:%M:%S)] $*" >&2; }

###############################################################################
# 1. Argument parsing
###############################################################################
FIXTURES=""
LAYERS="both"
API_PATH=""
RUNS=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fixtures)  FIXTURES="$2"; shift 2 ;;
    --layers)    LAYERS="$2";   shift 2 ;;
    --api-path)  API_PATH="$2"; shift 2 ;;
    --runs)      RUNS="$2";     shift 2 ;;
    *)           log "Unknown option: $1"; exit 1 ;;
  esac
done

# Default fixtures: all dirs under evals/fixtures/ that contain eval_config.json
if [[ -z "$FIXTURES" ]]; then
  FIXTURES=""
  for dir in "${SCRIPT_DIR}"/fixtures/*/; do
    if [[ -f "${dir}eval_config.json" ]]; then
      FIXTURES="${FIXTURES:+${FIXTURES} }$(basename "$dir")"
    fi
  done
fi

# Convert comma-separated to space-separated
FIXTURES="${FIXTURES//,/ }"

# Filter by --api-path if provided
if [[ -n "$API_PATH" ]]; then
  FILTERED=""
  for fixture in $FIXTURES; do
    FIXTURE_DIR="${SCRIPT_DIR}/fixtures/${fixture}"
    EXPECTED=$(python3 -c "import json; print(json.load(open('${FIXTURE_DIR}/eval_config.json')).get('expected_api_path',''))")
    if [[ "$EXPECTED" == "$API_PATH" ]]; then
      FILTERED="${FILTERED:+${FILTERED} }${fixture}"
    fi
  done
  FIXTURES="$FILTERED"
fi

if [[ -z "$FIXTURES" ]]; then
  log "No fixtures matched. Exiting."
  exit 1
fi

log "Fixtures: ${FIXTURES}"
log "Layers:   ${LAYERS}"
log "Runs:     ${RUNS}"

###############################################################################
# Validations
###############################################################################
if ! command -v python3 &>/dev/null; then
  log "ERROR: python3 is required but not found."
  exit 1
fi

if ! command -v claude &>/dev/null; then
  log "ERROR: claude CLI is required but not found."
  exit 1
fi

if [[ "$LAYERS" == *sandbox* ]] || [[ "$LAYERS" == "both" ]]; then
  if [[ -z "${SEAM_API_KEY:-}" ]]; then
    log "ERROR: SEAM_API_KEY env var is required for sandbox layer."
    exit 1
  fi
  if ! command -v docker &>/dev/null; then
    log "ERROR: docker is required for sandbox layer."
    exit 1
  fi
fi

###############################################################################
# 2. invoke_skill(fixture_dir) — run Claude against a fixture, return workdir
###############################################################################
invoke_skill() {
  local fixture_dir="$1"

  # Create temp working directory
  local working_dir
  working_dir=$(mktemp -d)

  # Copy app contents to temp dir (exclude build artifacts)
  rsync -a --exclude='node_modules' --exclude='dist' --exclude='__pycache__' --exclude='.venv' "${fixture_dir}/app/" "$working_dir/"

  # Initialize git repo (needed for diff later)
  (cd "$working_dir" && git init -q && git add -A && git commit -q -m "pristine") 2>/dev/null

  # Read prompt and skill content
  local prompt
  prompt=$(python3 -c "import json; print(json.load(open('${fixture_dir}/eval_config.json'))['prompt'])")
  local skill_content
  skill_content=$(cat "${SCRIPT_DIR}/../SKILL.md")

  # Invoke Claude in headless mode with 10-minute timeout
  # Note: macOS doesn't have `timeout`, so we use a background process with kill
  # Note: Use full path to claude binary since aliases don't expand in bash scripts
  # Note: Claude CLI has no --cwd flag, so we cd into the working dir
  local claude_bin
  claude_bin=$(command -v claude 2>/dev/null || echo "claude")
  local claude_log="${working_dir}/.claude_output.log"
  log "  Claude working in: ${working_dir}"
  (
    cd "$working_dir" && \
    "$claude_bin" --dangerously-skip-permissions -p "${prompt}" \
      --system-prompt "${skill_content}" \
      --allowedTools Read,Write,Edit,Glob,Grep,Bash >"$claude_log" 2>&1
  ) &
  local claude_pid=$!
  local elapsed=0
  local timed_out="no"
  while kill -0 "$claude_pid" 2>/dev/null; do
    sleep 5
    elapsed=$((elapsed + 5))
    if [ "$elapsed" -ge 600 ]; then
      log "  WARNING: Claude timed out after 10 minutes, killing..."
      kill "$claude_pid" 2>/dev/null || true
      wait "$claude_pid" 2>/dev/null || true
      timed_out="yes"
      break
    fi
    log "  ...Claude working (${elapsed}s)"
  done

  local claude_exit=0
  if [ "$timed_out" = "no" ]; then
    wait "$claude_pid" 2>/dev/null
    claude_exit=$?
  else
    claude_exit=124  # timeout exit code
  fi

  if [ "$claude_exit" -ne 0 ]; then
    log "  ERROR: Claude exited with code ${claude_exit}"
    # Return failure — caller will skip scoring
    return 1
  fi

  # Verify Claude actually modified files (empty diff = skill didn't do anything)
  local changes
  changes=$(cd "$working_dir" && git status --short 2>/dev/null | wc -l | tr -d ' ')
  if [ "$changes" = "0" ]; then
    log "  WARNING: Claude ran but made no changes"
    return 1
  fi

  echo "$working_dir"
}

###############################################################################
# 3. run_rubric(pristine_dir, modified_dir, fixture_dir)
###############################################################################
run_rubric() {
  local pristine_dir="$1"
  local modified_dir="$2"
  local fixture_dir="$3"

  python3 "${SCRIPT_DIR}/rubric_checker.py" \
    --pristine "$pristine_dir" \
    --modified "$modified_dir" \
    --fixture-dir "$fixture_dir"
}

###############################################################################
# 4. run_sandbox(modified_dir, fixture_dir, run_id)
###############################################################################
run_sandbox() {
  local modified_dir="$1"
  local fixture_dir="$2"
  local run_id="$3"

  bash "${SCRIPT_DIR}/sandbox_validator.sh" \
    --modified-dir "$modified_dir" \
    --fixture-dir "$fixture_dir" \
    --run-id "$run_id"
}

###############################################################################
# 5. print_summary(results_base_dir) — formatted table to stdout
###############################################################################
print_summary() {
  local results_base="$1"

  python3 - "$results_base" "$FIXTURES" "$RUNS" <<'PYEOF'
import json, sys, os, glob

results_base = sys.argv[1]
fixtures = sys.argv[2].split()
runs = int(sys.argv[3])

rows = []
for fixture in fixtures:
    rubric_scores = []
    sandbox_scores = []
    combined_scores = []
    api_path = ""

    # Read api_path from eval_config
    script_dir = os.path.dirname(os.path.abspath(sys.argv[0])) if sys.argv[0] else "."
    # results_base already contains the path we need
    fixture_config = os.path.join(os.path.dirname(results_base), "fixtures", fixture, "eval_config.json")
    # Try a few paths
    for candidate in [
        fixture_config,
        os.path.join(results_base, "..", "..", "fixtures", fixture, "eval_config.json"),
    ]:
        try:
            with open(os.path.realpath(candidate)) as f:
                api_path = json.load(f).get("expected_api_path", "")
            break
        except (FileNotFoundError, OSError):
            continue

    for run in range(1, runs + 1):
        run_dir = os.path.join(results_base, fixture, f"run_{run}")

        rubric_file = os.path.join(run_dir, "rubric.json")
        sandbox_file = os.path.join(run_dir, "sandbox.json")

        r_score = None
        s_score = None

        if os.path.exists(rubric_file):
            try:
                with open(rubric_file) as f:
                    r_score = json.load(f)["total"]
                rubric_scores.append(r_score)
            except (json.JSONDecodeError, KeyError):
                pass

        if os.path.exists(sandbox_file):
            try:
                with open(sandbox_file) as f:
                    s_score = json.load(f)["total"]
                sandbox_scores.append(s_score)
            except (json.JSONDecodeError, KeyError):
                pass

        # Combined: 40% rubric + 60% sandbox
        if r_score is not None and s_score is not None:
            combined_scores.append(round(0.4 * r_score + 0.6 * s_score))
        elif r_score is not None:
            combined_scores.append(r_score)
        elif s_score is not None:
            combined_scores.append(s_score)

    def fmt(scores):
        if not scores:
            return "  -  "
        if len(scores) == 1:
            return f"  {scores[0]}  "
        mean = round(sum(scores) / len(scores))
        lo = min(scores)
        hi = max(scores)
        return f"{mean} ({lo}-{hi})"

    api_col = f"✓ {api_path}" if api_path else "-"
    rows.append((fixture, fmt(rubric_scores), fmt(sandbox_scores), fmt(combined_scores), api_col))

# Print table
hdr = f"{'Fixture':<15}| {'Rubric':^12}| {'Sandbox':^12}| {'Combined':^12}| API Path"
sep = f"{'-'*15}|{'-'*13}|{'-'*13}|{'-'*13}|{'-'*20}"
print(hdr)
print(sep)
for fixture, rubric, sandbox, combined, api in rows:
    print(f"{fixture:<15}| {rubric:^12}| {sandbox:^12}| {combined:^12}| {api}")
PYEOF
}

###############################################################################
# 6. Main loop
###############################################################################
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_BASE="${SCRIPT_DIR}/results/${TIMESTAMP}"

for fixture in $FIXTURES; do
  FIXTURE_DIR="${SCRIPT_DIR}/fixtures/${fixture}"
  PRISTINE_DIR="${FIXTURE_DIR}/app"

  for run in $(seq 1 "$RUNS"); do
    RUN_ID="${fixture}_${TIMESTAMP}_${run}"
    RESULTS_DIR="${RESULTS_BASE}/${fixture}/run_${run}"
    mkdir -p "$RESULTS_DIR"

    log "=== ${fixture} run ${run}/${RUNS} ==="

    # Invoke skill — don't let failures kill the whole run
    log "Invoking skill..."
    WORKING_DIR=""
    if WORKING_DIR=$(invoke_skill "$FIXTURE_DIR"); then
      log "Skill invocation complete."
      # Save Claude CLI logs for diagnosis
      cp "${WORKING_DIR}/.claude_output.log" "${RESULTS_DIR}/claude.log" 2>/dev/null || true
    else
      log "WARNING: Skill invocation failed for ${fixture} run ${run}. Skipping."
      # Still save logs if working dir exists
      if [ -n "$WORKING_DIR" ] && [ -f "${WORKING_DIR}/.claude_output.log" ]; then
        mkdir -p "$RESULTS_DIR"
        cp "${WORKING_DIR}/.claude_output.log" "${RESULTS_DIR}/claude.log" 2>/dev/null || true
      fi
      continue
    fi

    # Save diff (add all changes first so new files are included)
    (cd "$WORKING_DIR" && git add -A && git diff --cached HEAD) > "${RESULTS_DIR}/diff.patch" 2>/dev/null || true

    # Run layers
    RUBRIC_SCORE=""
    SANDBOX_SCORE=""

    if [[ "$LAYERS" == *rubric* ]] || [[ "$LAYERS" == "both" ]]; then
      log "Running rubric checker..."
      if RUBRIC_RESULT=$(run_rubric "$PRISTINE_DIR" "$WORKING_DIR" "$FIXTURE_DIR"); then
        echo "$RUBRIC_RESULT" > "${RESULTS_DIR}/rubric.json"
        RUBRIC_SCORE=$(echo "$RUBRIC_RESULT" | python3 -c "import sys,json; print(json.loads(sys.stdin.read())['total'])" 2>/dev/null) || true
        log "Rubric score: ${RUBRIC_SCORE:-error}"
      else
        log "WARNING: Rubric checker failed for ${fixture} run ${run}."
      fi
    fi

    if [[ "$LAYERS" == *sandbox* ]] || [[ "$LAYERS" == "both" ]]; then
      log "Running sandbox validator..."
      if SANDBOX_RESULT=$(run_sandbox "$WORKING_DIR" "$FIXTURE_DIR" "$RUN_ID"); then
        echo "$SANDBOX_RESULT" > "${RESULTS_DIR}/sandbox.json"
        SANDBOX_SCORE=$(echo "$SANDBOX_RESULT" | python3 -c "import sys,json; print(json.loads(sys.stdin.read())['total'])" 2>/dev/null) || true
        log "Sandbox score: ${SANDBOX_SCORE:-error}"
      else
        log "WARNING: Sandbox validator failed for ${fixture} run ${run}."
      fi
    fi

    # Log combined score
    if [[ -n "$RUBRIC_SCORE" ]] && [[ -n "$SANDBOX_SCORE" ]]; then
      COMBINED=$(python3 -c "print(round(0.4*${RUBRIC_SCORE} + 0.6*${SANDBOX_SCORE}))")
      log "Combined score: ${COMBINED}"
    elif [[ -n "$RUBRIC_SCORE" ]]; then
      log "Combined score: ${RUBRIC_SCORE} (rubric only)"
    elif [[ -n "$SANDBOX_SCORE" ]]; then
      log "Combined score: ${SANDBOX_SCORE} (sandbox only)"
    fi

    # Clean up working dir
    rm -rf "$WORKING_DIR"
  done
done

log "All runs complete. Results in: ${RESULTS_BASE}"
log "Printing summary..."
echo "" >&2

print_summary "$RESULTS_BASE"
