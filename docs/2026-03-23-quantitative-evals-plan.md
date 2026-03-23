# Quantitative Evals Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a two-layer eval system that tests the Seam PMS integration skill against synthetic fixture apps, producing numeric scores from both structural analysis and real Seam sandbox validation.

**Architecture:** Fixture apps are minimal PMS codebases the skill modifies. Layer 1 (rubric_checker.py) statically scores the diff. Layer 2 (sandbox_validator.sh) builds the modified app in Docker, runs it, and validates against the real Seam sandbox API. An orchestrator (run_evals.sh) ties both layers together and produces a summary table.

**Tech Stack:** Python (rubric checker), Bash (orchestrator + sandbox validator), Docker (app containers), Seam sandbox API, TypeScript/Express + Python/Flask (fixture apps)

**Spec:** `docs/2026-03-23-quantitative-evals-design.md`

---

## File Map

### Eval infrastructure
| File | Responsibility |
|------|---------------|
| `evals/rubric.json` | Scoring category definitions and weights |
| `evals/rubric_checker.py` | Layer 1: grades diff/modified files against answer key |
| `evals/sandbox_validator.sh` | Layer 2: Docker build/run + Seam sandbox validation |
| `evals/run_evals.sh` | Orchestrator: invokes skill, runs both layers, prints summary |
| `evals/results/.gitignore` | Ignore eval results directory |

### express-ts fixture
| File | Responsibility |
|------|---------------|
| `evals/fixtures/express-ts/eval_config.json` | Prompt, expected API path, test endpoints/payloads |
| `evals/fixtures/express-ts/answer_key.json` | Expected files, calls, placements, parameters |
| `evals/fixtures/express-ts/Dockerfile` | Builds and runs the Express app |
| `evals/fixtures/express-ts/app/package.json` | Node.js dependencies (no seam) |
| `evals/fixtures/express-ts/app/tsconfig.json` | TypeScript config |
| `evals/fixtures/express-ts/app/src/index.ts` | Express server setup, health endpoint |
| `evals/fixtures/express-ts/app/src/routes/reservations.ts` | CRUD routes for reservations |
| `evals/fixtures/express-ts/app/src/routes/webhooks.ts` | Existing payment webhook handler |
| `evals/fixtures/express-ts/app/src/services/reservationService.ts` | Business logic for reservation lifecycle |
| `evals/fixtures/express-ts/app/src/models/types.ts` | TypeScript interfaces for Reservation, Guest, Property, Unit |
| `evals/fixtures/express-ts/app/src/models/store.ts` | In-memory data store with seed data |

### flask-py fixture
| File | Responsibility |
|------|---------------|
| `evals/fixtures/flask-py/eval_config.json` | Prompt, expected API path, test endpoints/payloads |
| `evals/fixtures/flask-py/answer_key.json` | Expected files, calls, placements, parameters |
| `evals/fixtures/flask-py/Dockerfile` | Builds and runs the Flask app |
| `evals/fixtures/flask-py/app/requirements.txt` | Python dependencies (no seam) |
| `evals/fixtures/flask-py/app/app.py` | Flask app factory, health endpoint |
| `evals/fixtures/flask-py/app/blueprints/reservations.py` | CRUD routes for reservations |
| `evals/fixtures/flask-py/app/blueprints/webhooks.py` | Existing payment webhook handler |
| `evals/fixtures/flask-py/app/services/reservation_service.py` | Business logic for reservation lifecycle |
| `evals/fixtures/flask-py/app/models/reservation.py` | Reservation, Guest models |
| `evals/fixtures/flask-py/app/models/property.py` | Property, Unit models |
| `evals/fixtures/flask-py/app/models/store.py` | In-memory data store with seed data |

---

## Task 1: Express-TS Fixture App

Build the minimal TypeScript Express PMS app. This is the simplest fixture — flat structure, in-memory data, service layer separate from routes.

**Files:**
- Create: `evals/fixtures/express-ts/app/package.json`
- Create: `evals/fixtures/express-ts/app/tsconfig.json`
- Create: `evals/fixtures/express-ts/app/src/models/types.ts`
- Create: `evals/fixtures/express-ts/app/src/models/store.ts`
- Create: `evals/fixtures/express-ts/app/src/services/reservationService.ts`
- Create: `evals/fixtures/express-ts/app/src/routes/reservations.ts`
- Create: `evals/fixtures/express-ts/app/src/routes/webhooks.ts`
- Create: `evals/fixtures/express-ts/app/src/index.ts`
- Create: `evals/fixtures/express-ts/Dockerfile`
- Create: `evals/fixtures/express-ts/eval_config.json`
- Create: `evals/fixtures/express-ts/answer_key.json`

- [ ] **Step 1: Create package.json and tsconfig.json**

`package.json` — dependencies: express, typescript, @types/express, ts-node. Scripts: `build` (tsc), `start` (node dist/index.js), `dev` (ts-node src/index.ts).

`tsconfig.json` — target ES2020, outDir dist, rootDir src, strict mode.

- [ ] **Step 2: Create type definitions**

`src/models/types.ts` — interfaces for:
- `Guest` (id, name, email)
- `Property` (id, name, address)
- `Unit` (id, propertyId, name — e.g., "Unit 101")
- `Reservation` (id, guestId, unitId, checkIn, checkOut, status)

- [ ] **Step 3: Create in-memory data store**

`src/models/store.ts` — export a simple object with arrays for guests, properties, units, reservations. Seed with:
- 1 property ("Sunset Rentals", id: "prop-1")
- 2 units ("Unit 101" id: "unit-101", "Unit 202" id: "unit-202", both under prop-1)
- No reservations (created via API)

Expose helper functions: `generateId()`, `findUnit(id)`, `findGuest(id)`.

- [ ] **Step 4: Create reservation service**

`src/services/reservationService.ts` — business logic functions:
- `createReservation(data)` — validates unit exists, creates guest if needed, creates reservation, returns it
- `updateReservation(id, data)` — finds reservation, updates fields (checkIn, checkOut), returns updated
- `cancelReservation(id)` — finds reservation, sets status to "cancelled", returns it
- `getReservation(id)` — returns reservation by id

These are the functions the skill needs to find and add Seam calls to.

- [ ] **Step 5: Create reservation routes**

`src/routes/reservations.ts` — Express router:
- `POST /api/reservations` — calls `createReservation`, returns 201 with `{ reservation: { id, ... } }`
- `PUT /api/reservations/:id` — calls `updateReservation`, returns 200
- `DELETE /api/reservations/:id` — calls `cancelReservation`, returns 200
- `GET /api/reservations/:id` — calls `getReservation`, returns 200

- [ ] **Step 6: Create existing webhook handler**

`src/routes/webhooks.ts` — Express router with a `POST /webhooks/payments` handler that logs the event and returns 200. This gives the skill a pattern to follow when adding Seam webhook handling.

- [ ] **Step 7: Create server entry point**

`src/index.ts` — creates Express app, mounts reservation routes at `/api`, webhook routes at `/webhooks`, adds a `GET /health` endpoint returning `{ status: "ok" }`, listens on `PORT` env var (default 3000).

- [ ] **Step 8: Create Dockerfile**

```dockerfile
FROM node:20-slim
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build
EXPOSE 3000
CMD ["node", "dist/index.js"]
```

- [ ] **Step 9: Verify the app builds and runs locally**

Run: `cd evals/fixtures/express-ts/app && npm install && npm run build && npm start`
Expected: Server starts on port 3000, `curl localhost:3000/health` returns `{"status":"ok"}`, `POST /api/reservations` creates a reservation.

Then test Docker (note: `-f` flag because Dockerfile is outside the app dir):
```bash
cd evals/fixtures/express-ts && docker build -t eval-express-ts -f Dockerfile ./app && docker run -p 3000:3000 eval-express-ts
```

Kill container after verifying.

- [ ] **Step 10: Create eval_config.json**

```json
{
  "fixture": "express-ts",
  "prompt": "I'm building a short-term rental PMS in TypeScript with Express. We have reservations with check-in/check-out times and want to automatically create access codes on smart locks when guests book. Our customers use August and Yale smart locks. We want property managers to connect their own locks without us building UI — we don't want to build device management ourselves. We just want to push reservation data and have Seam handle the rest. We already have a Seam account with sandbox devices. Don't ask me any setup questions — explore the codebase and write the integration.",
  "expected_api_path": "reservation_automations",
  "seam_env_var": "SEAM_API_KEY",
  "app_port": 3000,
  "test_endpoints": {
    "create": {
      "method": "POST",
      "path": "/api/reservations",
      "payload": {
        "guestName": "Test Guest",
        "guestEmail": "eval_test_{{RUN_ID}}@example.com",
        "propertyId": "prop-1",
        "unitId": "unit-101",
        "checkIn": "{{STARTS_AT}}",
        "checkOut": "{{ENDS_AT}}"
      },
      "response_id_path": "reservation.id"
    },
    "update": {
      "method": "PUT",
      "path": "/api/reservations/{{RESERVATION_ID}}",
      "payload": {
        "checkOut": "{{NEW_ENDS_AT}}"
      }
    },
    "cancel": {
      "method": "DELETE",
      "path": "/api/reservations/{{RESERVATION_ID}}"
    }
  }
}
```

- [ ] **Step 11: Create answer_key.json**

```json
{
  "expected_files_modified": [
    "src/routes/reservations.ts",
    "src/services/reservationService.ts"
  ],
  "expected_new_files_allowed": [
    "src/services/seamService.ts",
    "src/routes/webhooks.ts",
    "src/config/seam.ts",
    "src/lib/seam.ts"
  ],
  "expected_calls": {
    "create": ["customers.push_data"],
    "update": ["customers.push_data"],
    "cancel": ["customers.delete_data"]
  },
  "expected_placements": {
    "customers.push_data": ["createReservation", "updateReservation"],
    "customers.delete_data": ["cancelReservation"]
  },
  "required_parameters": {
    "push_data": ["customer_key", "reservations", "user_identities"],
    "delete_data": ["customer_key", "reservation_keys"]
  },
  "expected_package_additions": {
    "package.json": ["seam"]
  }
}
```

- [ ] **Step 12: Commit**

```bash
git add evals/fixtures/express-ts/
git commit -m "feat: add express-ts fixture app for quantitative evals"
```

---

## Task 2: Rubric Checker (Layer 1)

Build the Python script that scores a skill-modified fixture against its answer key.

**Files:**
- Create: `evals/rubric.json`
- Create: `evals/rubric_checker.py`

- [ ] **Step 1: Create rubric.json**

```json
{
  "categories": [
    { "name": "api_path_selection", "weight": 15, "check": "api_path_match" },
    { "name": "file_targeting", "weight": 20, "check": "files_modified_match" },
    { "name": "integration_placement", "weight": 20, "check": "calls_in_expected_functions" },
    { "name": "api_correctness", "weight": 20, "check": "required_params_present" },
    { "name": "lifecycle_completeness", "weight": 15, "check": "all_handlers_modified" },
    { "name": "webhook_setup", "weight": 10, "check": "webhook_route_added" }
  ]
}
```

- [ ] **Step 2: Write rubric_checker.py — file loading and diff computation**

The script takes 3 args: `--pristine <dir>` `--modified <dir>` `--fixture-dir <dir>` (for answer_key.json and eval_config.json).

Core structure:
- `load_config(fixture_dir)` — loads answer_key.json, eval_config.json, rubric.json
- `compute_diff(pristine_dir, modified_dir)` — returns list of changed files and their diffs (use `filecmp` + file reading, no git dependency)
- `read_modified_files(modified_dir, file_list)` — reads full content of modified files for content-based checks

- [ ] **Step 3: Write check functions — api_path_match**

`check_api_path_match(modified_files, eval_config)`:
- Maps API paths to signature calls: `reservation_automations` → `push_data`, `access_grants` → `access_grants.create`, `lower_level` → `access_codes.create`
- Searches all modified file contents for these signatures
- Returns 1.0 if the expected path's signature is found (and others aren't), 0.5 if expected is found alongside wrong ones, 0.0 if wrong path or no Seam calls

- [ ] **Step 4: Write check functions — files_modified_match**

`check_files_modified_match(changed_files, answer_key)`:
- Compare `changed_files` against `expected_files_modified` — proportion of expected files that were actually modified
- Check `expected_new_files_allowed` — any new files created that aren't in the allow-list deduct proportionally
- Return score 0.0-1.0

- [ ] **Step 5: Write check functions — calls_in_expected_functions**

`check_calls_in_expected_functions(modified_files, answer_key)`:
- For each entry in `expected_placements`, search the full file content for the SDK call
- Use a heuristic: find function definitions using multiple regex patterns to cover common styles:
  - `function funcName` / `async function funcName` (JS/TS)
  - `const funcName = ` / `const funcName = async` (arrow functions)
  - `funcName(` at method-definition indent level (class methods)
  - `def funcName` (Python)
- Check if the SDK call string appears between that function's opening and the next function definition (or end of file)
- Known limitations: deeply nested functions or unusual patterns may be missed. This is acceptable — the heuristic catches the common cases. If a placement check fails due to a pattern miss, the other rubric categories (API correctness, lifecycle completeness) still catch the core behavior.
- Score proportionally: if 2/3 placements are correct, score is 0.66

- [ ] **Step 6: Write check functions — required_params_present**

`check_required_params_present(modified_files, answer_key)`:
- For each SDK call in `required_parameters`, search file contents for the call and nearby parameter names
- Use string matching: look for each required parameter name (e.g., `customer_key`, `reservations`) within 20 lines of the SDK call
- Score proportionally per call, averaged across all calls

- [ ] **Step 7: Write check functions — all_handlers_modified**

`check_all_handlers_modified(changed_files, modified_files, answer_key)`:
- For each lifecycle phase (create, update, cancel) in `expected_calls`, check that at least one of the expected SDK calls appears in the modified files
- Score: proportion of lifecycle phases covered (0/3, 1/3, 2/3, 3/3)

- [ ] **Step 8: Write check functions — webhook_route_added**

`check_webhook_route_added(changed_files, modified_files)`:
- Search for new route definitions containing "seam" or "webhook" (case-insensitive) in modified/new files
- Look for Seam event type strings: `access_code.set_on_device`, `access_method.issued`, `device.disconnected`
- Score: 1.0 if webhook route with Seam events found, 0.5 if webhook route but no Seam events, 0.0 if no webhook route

- [ ] **Step 9: Write main scoring function**

`score(pristine_dir, modified_dir, fixture_dir)`:
- Load configs
- Compute diff + read modified files
- Run each check function
- Multiply each score by its weight from rubric.json
- Return JSON: `{ "total": 85, "categories": { "api_path_selection": { "score": 1.0, "weighted": 15 }, ... } }`

- [ ] **Step 10: Add CLI entry point**

```python
if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--pristine", required=True)
    parser.add_argument("--modified", required=True)
    parser.add_argument("--fixture-dir", required=True)
    args = parser.parse_args()
    result = score(args.pristine, args.modified, args.fixture_dir)
    print(json.dumps(result, indent=2))
```

- [ ] **Step 11: Create a "golden" test modification for express-ts**

Create `evals/fixtures/express-ts/test_golden/` — a pre-modified version of the app that represents a perfect skill output. This is used to test both the rubric checker and sandbox validator.

Changes to make (relative to `app/`):
1. `package.json` — add `"seam": "latest"` to dependencies
2. `src/services/reservationService.ts` — import Seam, initialize with `SEAM_API_KEY` env var. Add `seam.customers.push_data(...)` call inside `createReservation()` and `updateReservation()` with `customer_key`, `user_identities`, `reservations` (with `reservation_key`, `user_identity_key`, `starts_at`, `ends_at`, `space_keys`). Add `seam.customers.delete_data(...)` call inside `cancelReservation()` with `customer_key`, `reservation_keys`, `user_identity_keys`.
3. `src/routes/webhooks.ts` — add a `POST /webhooks/seam` handler that switches on `event_type` for `access_code.set_on_device`, `access_code.failed_to_set_on_device`, `device.disconnected`.

Copy the app to `test_golden/`, apply these changes.

- [ ] **Step 12: Test rubric_checker against the golden modification**

Run: `python evals/rubric_checker.py --pristine evals/fixtures/express-ts/app --modified evals/fixtures/express-ts/test_golden --fixture-dir evals/fixtures/express-ts`
Expected: Score near 100 with all categories passing.

Then test with a deliberately wrong modification (copy golden, change `push_data` to `access_codes.create`) and verify the API path selection score drops to 0.

- [ ] **Step 12: Commit**

```bash
git add evals/rubric.json evals/rubric_checker.py
git commit -m "feat: add rubric checker (Layer 1) for quantitative evals"
```

---

## Task 3: Sandbox Validator (Layer 2)

Build the bash script that Dockerizes the modified app, runs it, and validates against the Seam sandbox.

**Files:**
- Create: `evals/sandbox_validator.sh`

- [ ] **Step 1: Write sandbox bootstrapping functions**

Functions at the top of `sandbox_validator.sh`:
- `bootstrap_sandbox()` — lists devices, finds an access-code-capable device, creates a space with `eval_unit_${RUN_ID}` space_key and assigns the device. Exports `DEVICE_ID`, `SPACE_KEY`, `CUSTOMER_KEY`. Note: the customer (`eval_pm_${RUN_ID}`) is created implicitly by the app's first `push_data` call — there is no separate `/customers/create` endpoint. The `CUSTOMER_KEY` is just a known string the validator uses for cleanup via `delete_data`.
- `cleanup_sandbox()` — deletes space, deletes customer data. Runs via `trap` on EXIT so it always fires.
- `api()` — same curl wrapper as existing tests: `POST` to Seam API with bearer token.

Pattern from: `tests/test_reservation_automations.sh` lines 23-30 (api function), lines 32-67 (device + space setup).

- [ ] **Step 2: Write Docker build and run functions**

- `build_app(modified_dir, fixture_dir)` — copies modified app to temp dir, runs `docker build -t eval-${FIXTURE}-${RUN_ID} -f "${fixture_dir}/Dockerfile" "${temp_dir}"`. The `-f` flag is required because the Dockerfile lives at the fixture level, not inside the app directory. Returns image tag.
- `start_app(image_tag, eval_config)` — `docker run -d --name eval-${FIXTURE}-${RUN_ID} -p ${HOST_PORT}:${APP_PORT} -e ${SEAM_ENV_VAR}=${SEAM_API_KEY} ${image_tag}`. Returns container ID.
- `wait_for_health(port, timeout)` — polls `GET localhost:${port}/health` every 2s until 200 or timeout.
- `stop_app(container_id)` — `docker stop` and `docker rm`.

- [ ] **Step 3: Write template variable resolution**

`resolve_template(template_str)` — replaces `{{RUN_ID}}`, `{{STARTS_AT}}`, `{{ENDS_AT}}`, `{{NEW_ENDS_AT}}` with computed values:
- `RUN_ID` = timestamp
- `STARTS_AT` = now + 1 hour (ISO8601)
- `ENDS_AT` = now + 25 hours
- `NEW_ENDS_AT` = now + 49 hours

`resolve_payload(payload_json)` — resolves all template vars in a JSON payload string.

`extract_id(response_json, id_path)` — extracts a value from JSON using a dot-path (e.g., `reservation.id`). Use `python3 -c` for JSONPath extraction (same pattern as existing tests).

- [ ] **Step 4: Write validation functions**

`validate_create(eval_config, app_port)`:
- Resolve create payload templates
- `curl -X POST localhost:${app_port}${create_path}` with resolved payload
- Extract reservation ID from response using `response_id_path`
- Poll Seam sandbox: `api /access_codes/list -d '{"device_id":"${DEVICE_ID}"}'` up to 60s for an access code to appear
- Return pass/fail + reservation ID

`validate_update(eval_config, app_port, reservation_id)`:
- Resolve update URL (replace `{{RESERVATION_ID}}`) and payload
- `curl -X PUT` the update endpoint
- Brief wait (5s) then check Seam sandbox — access code should still exist
- Return pass/fail

`validate_cancel(eval_config, app_port, reservation_id)`:
- Resolve cancel URL
- `curl -X DELETE` the cancel endpoint
- Poll Seam sandbox up to 30s for access codes to be removed/removing
- Return pass/fail

- [ ] **Step 5: Write main validation flow and scoring**

`validate(modified_dir, fixture_dir)`:
1. Load `eval_config.json`
2. `bootstrap_sandbox`
3. `build_app` → `start_app` → `wait_for_health`
4. Score tracking: `BUILD_SCORE=0`, `CREATE_SCORE=0`, `UPDATE_SCORE=0`, `CANCEL_SCORE=0`
5. If app starts: `BUILD_SCORE=10`
6. `validate_create` → if pass: `CREATE_SCORE=30`
7. `validate_update` → if pass: `UPDATE_SCORE=30`
8. `validate_cancel` → if pass: `CANCEL_SCORE=30`
9. Total = sum of scores
10. Output JSON: `{ "total": N, "checks": { "build": 10, "create": 30, ... } }`
11. `stop_app` + `cleanup_sandbox` (via trap)

- [ ] **Step 6: Add CLI interface**

Script takes args: `--modified-dir <dir>` `--fixture-dir <dir>` `--run-id <id>`

Requires `SEAM_API_KEY` env var.

```bash
#!/bin/bash
set -euo pipefail
# ... parse args, run validate(), output JSON result
```

- [ ] **Step 7: Test sandbox_validator with the golden modification**

Use the golden test modification from Task 2, Step 11 (`evals/fixtures/express-ts/test_golden/`). Run:

```bash
SEAM_API_KEY=<sandbox_key> bash evals/sandbox_validator.sh \
  --modified-dir evals/fixtures/express-ts/test_golden \
  --fixture-dir evals/fixtures/express-ts \
  --run-id test_$(date +%s)
```

Expected: App builds, starts, create/update/cancel all pass. Score: 100.

Note: This requires a valid Seam sandbox API key with devices connected.

- [ ] **Step 8: Commit**

```bash
git add evals/sandbox_validator.sh
git commit -m "feat: add sandbox validator (Layer 2) for quantitative evals"
```

---

## Task 4: Eval Orchestrator

Build the top-level script that invokes the skill, runs both layers, and produces the summary.

**Files:**
- Create: `evals/run_evals.sh`
- Create: `evals/results/.gitignore`

- [ ] **Step 1: Write argument parsing and fixture discovery**

`run_evals.sh` parses flags:
- `--fixtures` (comma-separated, default: all dirs under `evals/fixtures/` that contain `eval_config.json`)
- `--layers` (`rubric`, `sandbox`, `both`; default: `both`)
- `--api-path` (filter fixtures by `expected_api_path` in their eval_config; default: no filter)
- `--runs N` (default: 1)

Validate: `SEAM_API_KEY` must be set if `--layers` includes `sandbox`. Docker must be available if sandbox layer is requested.

- [ ] **Step 2: Write skill invocation function**

`invoke_skill(fixture_dir, working_dir)`:
1. Copy `fixture_dir/app/` to a temp working directory
2. Initialize a git repo in the working dir (`git init && git add -A && git commit -m "pristine"`) — needed for diff computation later
3. Read prompt from `eval_config.json`
4. Run: `claude -p "$PROMPT" --allowedTools Read,Write,Edit,Glob,Grep,Bash --cwd "$working_dir"`
5. Return the working dir path (now contains skill-modified code)

The skill must be loaded into the Claude session. Use the `--systemPrompt` flag to inject SKILL.md content:

```bash
SKILL_CONTENT=$(cat SKILL.md)
claude -p "$PROMPT" \
  --systemPrompt "You are using the following skill to guide your work:\n\n$SKILL_CONTENT" \
  --allowedTools Read,Write,Edit,Glob,Grep,Bash \
  --cwd "$working_dir"
```

If `--systemPrompt` is not available in the CLI version, fall back to prepending the skill content to the prompt itself: `"[SKILL INSTRUCTIONS]\n$SKILL_CONTENT\n[/SKILL INSTRUCTIONS]\n\n$PROMPT"`.

Add a timeout of 10 minutes per skill invocation (`timeout 600 claude -p ...`) to prevent hung invocations from blocking the pipeline.

- [ ] **Step 3: Write layer execution functions**

`run_rubric(pristine_dir, modified_dir, fixture_dir)`:
- Calls `python3 evals/rubric_checker.py --pristine "$pristine_dir" --modified "$modified_dir" --fixture-dir "$fixture_dir"`
- Captures JSON output
- Returns rubric score

`run_sandbox(modified_dir, fixture_dir, run_id)`:
- Calls `bash evals/sandbox_validator.sh --modified-dir "$modified_dir" --fixture-dir "$fixture_dir" --run-id "$run_id"`
- Captures JSON output
- Returns sandbox score

- [ ] **Step 4: Write result aggregation and summary table**

`aggregate_results(fixture, rubric_scores[], sandbox_scores[])`:
- For single run: combined = 0.4 * rubric + 0.6 * sandbox
- For N runs: compute mean/min/max for rubric, sandbox, and combined
- Check API path: did rubric detect the correct path?

`print_summary(all_results)`:
- Prints the table format from the spec
- For `--runs N > 1`, show mean (min-max) in each column

- [ ] **Step 5: Write main loop**

```bash
for fixture in $FIXTURES; do
  for run in $(seq 1 $RUNS); do
    RUN_ID="${fixture}_$(date +%s)_${run}"
    RESULTS_DIR="evals/results/$(date +%Y%m%d_%H%M%S)/${fixture}/run_${run}"
    mkdir -p "$RESULTS_DIR"

    # Invoke skill (runs are sequential per fixture to avoid port conflicts)
    WORKING_DIR=$(invoke_skill "$FIXTURE_DIR" ...)

    # Save diff
    (cd "$WORKING_DIR" && git diff HEAD~1) > "$RESULTS_DIR/diff.patch"

    # Run layers
    if [[ "$LAYERS" == *rubric* ]]; then
      run_rubric ... > "$RESULTS_DIR/rubric.json"
    fi
    if [[ "$LAYERS" == *sandbox* ]]; then
      run_sandbox ... > "$RESULTS_DIR/sandbox.json"
    fi
  done
done

print_summary ...
```

- [ ] **Step 6: Create results .gitignore**

```
evals/results/.gitignore:
*
!.gitignore
```

- [ ] **Step 7: Test orchestrator end-to-end with express-ts (rubric only)**

Run without sandbox to verify the skill invocation + rubric pipeline:

```bash
bash evals/run_evals.sh --fixtures express-ts --layers rubric --runs 1
```

Expected: Skill runs, modifies the fixture, rubric scores the output. Summary table prints.

- [ ] **Step 8: Test orchestrator end-to-end with express-ts (both layers)**

```bash
SEAM_API_KEY=<key> bash evals/run_evals.sh --fixtures express-ts --layers both --runs 1
```

Expected: Full pipeline — skill runs, rubric scores, Docker builds and runs, sandbox validates. Summary table with both scores.

- [ ] **Step 9: Commit**

```bash
git add evals/run_evals.sh evals/results/.gitignore
git commit -m "feat: add eval orchestrator tying rubric and sandbox layers together"
```

---

## Task 5: Flask-Py Fixture App

Build the second fixture to validate cross-language support. Flask with blueprints, separate service module, in-memory store.

**Files:**
- Create: `evals/fixtures/flask-py/app/requirements.txt`
- Create: `evals/fixtures/flask-py/app/app.py`
- Create: `evals/fixtures/flask-py/app/models/reservation.py`
- Create: `evals/fixtures/flask-py/app/models/property.py`
- Create: `evals/fixtures/flask-py/app/models/store.py`
- Create: `evals/fixtures/flask-py/app/services/reservation_service.py`
- Create: `evals/fixtures/flask-py/app/blueprints/reservations.py`
- Create: `evals/fixtures/flask-py/app/blueprints/webhooks.py`
- Create: `evals/fixtures/flask-py/Dockerfile`
- Create: `evals/fixtures/flask-py/eval_config.json`
- Create: `evals/fixtures/flask-py/answer_key.json`

- [ ] **Step 1: Create requirements.txt**

```
flask==3.1.0
```

No seam package — the skill adds it.

- [ ] **Step 2: Create models**

`models/reservation.py` — dataclasses for `Guest` (id, name, email) and `Reservation` (id, guest_id, unit_id, check_in, check_out, status).

`models/property.py` — dataclasses for `Property` (id, name, address) and `Unit` (id, property_id, name).

`models/store.py` — in-memory store dict with seed data: 1 property, 2 units. Helper functions: `generate_id()`, `find_unit(id)`, `find_guest(id)`.

- [ ] **Step 3: Create reservation service**

`services/reservation_service.py` — functions:
- `create_reservation(data)` — validates unit, creates guest if needed, creates reservation, returns it
- `update_reservation(reservation_id, data)` — finds reservation, updates check_in/check_out, returns it
- `cancel_reservation(reservation_id)` — finds reservation, sets status to "cancelled", returns it
- `get_reservation(reservation_id)` — returns reservation by id

- [ ] **Step 4: Create blueprints**

`blueprints/reservations.py` — Flask blueprint `reservations_bp`:
- `POST /api/reservations` → calls `create_reservation`, returns JSON with 201
- `PUT /api/reservations/<id>` → calls `update_reservation`, returns JSON with 200
- `DELETE /api/reservations/<id>` → calls `cancel_reservation`, returns JSON with 200
- `GET /api/reservations/<id>` → calls `get_reservation`, returns JSON with 200

`blueprints/webhooks.py` — Flask blueprint `webhooks_bp`:
- `POST /webhooks/payments` — logs event, returns 200. Pattern for skill to follow.

- [ ] **Step 5: Create app.py**

Flask app factory pattern:
- Creates app
- Registers `reservations_bp` and `webhooks_bp`
- `GET /health` returns `{"status": "ok"}`
- Runs on host `0.0.0.0`, port from `PORT` env var (default 5000)

- [ ] **Step 6: Create Dockerfile**

```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt ./
RUN pip install -r requirements.txt
COPY . .
EXPOSE 5000
CMD ["python", "app.py"]
```

- [ ] **Step 7: Verify app builds and runs**

Run: `cd evals/fixtures/flask-py/app && pip install -r requirements.txt && python app.py`
Expected: Server on port 5000, health check works, CRUD endpoints work.

Docker: `cd evals/fixtures/flask-py && docker build -t eval-flask-py -f Dockerfile ./app && docker run -p 5000:5000 eval-flask-py`

- [ ] **Step 8: Create eval_config.json**

Same structure as express-ts but with Python-appropriate prompt:

```json
{
  "fixture": "flask-py",
  "prompt": "I'm building a short-term rental property management system in Python with Flask. We have reservations with check-in/check-out times and want to automatically create access codes on smart locks when guests book. Our customers use August and Yale smart locks. We want property managers to connect their own locks without us building UI. We just want to push reservation data and have Seam handle the rest. We already have a Seam account with sandbox devices. Don't ask me any setup questions — explore the codebase and write the integration.",
  "expected_api_path": "reservation_automations",
  "seam_env_var": "SEAM_API_KEY",
  "app_port": 5000,
  "test_endpoints": {
    "create": {
      "method": "POST",
      "path": "/api/reservations",
      "payload": {
        "guest_name": "Test Guest",
        "guest_email": "eval_test_{{RUN_ID}}@example.com",
        "property_id": "prop-1",
        "unit_id": "unit-101",
        "check_in": "{{STARTS_AT}}",
        "check_out": "{{ENDS_AT}}"
      },
      "response_id_path": "reservation.id"
    },
    "update": {
      "method": "PUT",
      "path": "/api/reservations/{{RESERVATION_ID}}",
      "payload": {
        "check_out": "{{NEW_ENDS_AT}}"
      }
    },
    "cancel": {
      "method": "DELETE",
      "path": "/api/reservations/{{RESERVATION_ID}}"
    }
  }
}
```

- [ ] **Step 9: Create answer_key.json**

```json
{
  "expected_files_modified": [
    "blueprints/reservations.py",
    "services/reservation_service.py"
  ],
  "expected_new_files_allowed": [
    "services/seam_service.py",
    "blueprints/seam_webhooks.py",
    "config/seam.py",
    "lib/seam.py"
  ],
  "expected_calls": {
    "create": ["customers.push_data"],
    "update": ["customers.push_data"],
    "cancel": ["customers.delete_data"]
  },
  "expected_placements": {
    "customers.push_data": ["create_reservation", "update_reservation"],
    "customers.delete_data": ["cancel_reservation"]
  },
  "required_parameters": {
    "push_data": ["customer_key", "reservations", "user_identities"],
    "delete_data": ["customer_key", "reservation_keys"]
  },
  "expected_package_additions": {
    "requirements.txt": ["seam"]
  }
}
```

- [ ] **Step 10: Run evals against flask-py**

```bash
bash evals/run_evals.sh --fixtures flask-py --layers rubric --runs 1
```

Then with sandbox:
```bash
SEAM_API_KEY=<key> bash evals/run_evals.sh --fixtures flask-py --layers both --runs 1
```

- [ ] **Step 11: Commit**

```bash
git add evals/fixtures/flask-py/
git commit -m "feat: add flask-py fixture app for quantitative evals"
```

---

## Task 6: Multi-Fixture Eval Run and Polish

Run both fixtures together, fix any issues, polish the output.

**Files:**
- Modify: `evals/run_evals.sh` (if needed)
- Modify: `evals/sandbox_validator.sh` (if needed)

- [ ] **Step 1: Run full eval suite**

```bash
SEAM_API_KEY=<key> bash evals/run_evals.sh --fixtures express-ts,flask-py --layers both --runs 1
```

Expected: Both fixtures run, summary table prints with scores for both.

- [ ] **Step 2: Run with --runs 3 for consistency data**

```bash
SEAM_API_KEY=<key> bash evals/run_evals.sh --fixtures express-ts,flask-py --layers both --runs 3
```

Expected: Each fixture runs 3 times, summary shows mean/min/max.

- [ ] **Step 3: Fix any issues discovered in multi-run testing**

Address flaky tests, timeout issues, cleanup failures, port conflicts between concurrent runs, etc.

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "fix: polish eval pipeline after multi-fixture testing"
```
