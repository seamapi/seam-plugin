# Design: Quantitative Evals for Seam PMS Integration Skill

## Context

The skill (v0.3.0) has qualitative evals — prompt/expected-behavior pairs with no real codebases — and integration tests that validate Seam API calls directly. What's missing is a way to measure how well the skill actually performs when dropped into a real codebase: does it find the right files, write correct code, and produce a working integration?

This spec defines a quantitative eval system that tests the skill against synthetic fixture apps, scoring both the structural quality of the generated code and whether it actually works against the Seam sandbox.

## Eval Pipeline

Three stages run in sequence per fixture:

```
Fixture App (pristine)
  → Skill runs against it (modifies code)
  → Layer 1: Structural rubric grades the diff (fast, deterministic)
  → Layer 2: Docker sandbox validation (slower, ground truth)
  → Score report (0-100 combined)
```

## Fixture Apps

Each fixture is a minimal but realistic PMS app. Small enough to be predictable, realistic enough that the skill has to explore and make decisions.

### What every fixture has

- A reservation/booking model (DB or in-memory)
- `POST /api/reservations` — creates a booking
- `PUT /api/reservations/:id` — modifies a booking
- `DELETE /api/reservations/:id` (or `POST /api/reservations/:id/cancel`) — cancels a booking
- A guest/user model tied to reservations
- A property/unit model with a room/unit concept
- An existing webhook handler for something else (e.g., payment webhook) as a pattern for the skill to follow
- A `/health` endpoint for Docker readiness checks

### What fixtures DON'T have

- No Seam SDK installed
- No Seam-related code
- No access code logic

The skill's job is to add all of that.

### Fixture lineup

| Fixture | Stack | Complexity | What makes it harder |
|---------|-------|-----------|---------------------|
| `express-ts` | TypeScript + Express | Simple | Flat-ish structure, service layer separate from routes |
| `flask-py` | Python + Flask | Medium | Blueprints, SQLAlchemy models, separate service module |
| `rails-rb` | Ruby on Rails | Hard | Convention-heavy, MVC, ActiveRecord callbacks, concerns |
| `nextjs-ts` | Next.js App Router | Hard | API routes in `app/api/`, server actions, different conventions |
| `php-laravel` | PHP + Laravel | Hard | Controllers, Eloquent models, service providers |

**Build order:** `express-ts` and `flask-py` first to prove the pipeline. Add the rest incrementally.

### Fixture directory structure

Each fixture is self-contained:

```
evals/
  fixtures/
    express-ts/
      app/                  # the actual app source code
      Dockerfile            # builds and runs the app
      answer_key.json       # expected files, API calls, parameters
      eval_config.json      # prompt, expected API path, test endpoints
    flask-py/
      ...
```

### eval_config.json

The `prompt` must front-load all context the skill would normally gather through its interactive interview (see "Skill Invocation" section). The `expected_api_path` is the single source of truth for which API path should be chosen — the answer key references it rather than duplicating it.

```json
{
  "fixture": "express-ts",
  "prompt": "I'm building a short-term rental PMS in TypeScript with Express. We have reservations with check-in/check-out times and want to automatically create access codes on smart locks when guests book. Our customers use August and Yale smart locks. We want property managers to connect their own locks without us building UI — we don't want to build device management ourselves. We just want to push reservation data and have Seam handle the rest. We already have a Seam account with sandbox devices. Don't ask me any setup questions — explore the codebase and write the integration.",
  "expected_api_path": "reservation_automations",
  "test_endpoints": {
    "create": { "method": "POST", "path": "/api/reservations", "payload": {
      "guestName": "Test Guest",
      "guestEmail": "eval_test_{{RUN_ID}}@example.com",
      "propertyId": "prop-1",
      "unitId": "unit-101",
      "checkIn": "{{STARTS_AT}}",
      "checkOut": "{{ENDS_AT}}"
    }},
    "update": { "method": "PUT", "path": "/api/reservations/{{RESERVATION_ID}}", "payload": {
      "checkOut": "{{NEW_ENDS_AT}}"
    }},
    "cancel": { "method": "DELETE", "path": "/api/reservations/{{RESERVATION_ID}}" }
  },
  "seam_env_var": "SEAM_API_KEY"
}
```

Template variables (`{{RUN_ID}}`, `{{STARTS_AT}}`, etc.) are resolved by the sandbox validator at runtime. `{{RESERVATION_ID}}` is a special case — it's extracted from the create response. To handle different response shapes across fixtures, `eval_config.json` includes a `response_id_path` per endpoint:

```json
{
  "test_endpoints": {
    "create": {
      "method": "POST",
      "path": "/api/reservations",
      "payload": { "..." : "..." },
      "response_id_path": "reservation.id"
    }
  }
}
```

The validator uses this JSONPath-style accessor to extract the reservation ID from the create response, then substitutes it into the update and cancel URLs.

### answer_key.json

References `expected_api_path` from `eval_config.json` — does not duplicate it. Includes `expected_placements` mapping SDK calls to the function/method they should appear in, for the "integration placement" rubric category.

```json
{
  "expected_files_modified": [
    "src/routes/reservations.ts",
    "src/services/reservationService.ts"
  ],
  "expected_new_files_allowed": [
    "src/services/seamService.ts",
    "src/routes/webhooks.ts"
  ],
  "expected_calls": {
    "create": ["customers.push_data"],
    "update": ["customers.push_data"],
    "cancel": ["customers.delete_data"]
  },
  "expected_placements": {
    "customers.push_data": ["createReservation", "updateReservation"],
    "customers.delete_data": ["cancelReservation", "deleteReservation"]
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

## Layer 1: Structural Rubric

Runs against the git diff between pristine fixture and skill-modified version. Produces a 0-100 score.

### Scoring categories

| Category | Weight | What it checks | How |
|----------|--------|---------------|-----|
| **API path selection** | 15% | Chose the right API path? | Check which Seam API calls appear in the diff (`push_data` vs `access_grants.create` vs `access_codes.create`) |
| **File targeting** | 20% | Modified the correct files? Avoided unnecessary new files? | Compare modified file list against `answer_key.json` |
| **Integration placement** | 20% | Seam calls landed inside the right functions? | Check that Seam calls appear within expected function/method bodies |
| **API correctness** | 20% | Correct SDK method names and required parameters? | Pattern match for required fields per `answer_key.json` |
| **Lifecycle completeness** | 15% | Handles create AND update AND cancel? | Check all three handlers were modified |
| **Webhook setup** | 10% | Added a webhook endpoint? | Check for new route handling Seam events |

Note: "API path selection" and "API correctness" intentionally double-penalize a wrong API path. If the skill chooses `access_codes.create` instead of `push_data`, it fails path selection AND has the wrong method names. This is intended — choosing the wrong path is a fundamental error.

### rubric.json

Defines scoring categories, weights, and check types so `rubric_checker.py` is data-driven:

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

Each `check` type maps to a function in `rubric_checker.py`. The answer key provides the fixture-specific data each check evaluates against.

### Implementation

A Python script (`evals/rubric_checker.py`) that:
1. Takes the pristine and modified app directories
2. For diff-based checks (file targeting, lifecycle completeness, webhook setup): computes the git diff
3. For content-based checks (integration placement, API correctness): reads the **full modified files**, not just the diff — this is necessary because function boundaries may not be visible in a diff's context lines
4. Loads `rubric.json` for category definitions and `answer_key.json` for expected values
5. Grades each category — scoring is **proportional within categories** (e.g., if 2 of 3 lifecycle handlers are modified, that's 66% of the lifecycle score, not 0%)
6. Outputs a JSON score breakdown

## Layer 2: Docker Sandbox Validation

Builds and runs the skill-modified app in Docker, then validates against the real Seam sandbox. Produces a 0-100 score.

### Sandbox Bootstrapping

Before the Docker container starts, the validator must set up the Seam sandbox so the app's integration has something to work with. This mirrors the setup in the existing `tests/test_reservation_automations.sh`:

1. **List devices** — find an access-code-capable device in the sandbox
2. **Create a space** — with a known `space_key` (e.g., `eval_unit_{{RUN_ID}}`) and assign the device to it
3. **Create a customer** — with a known `customer_key` (e.g., `eval_pm_{{RUN_ID}}`)

The fixture app's test payloads use unit/property IDs that map to these known space keys. The skill is expected to use the unit/property model data from the app to construct `space_keys` in its `push_data` calls — the validator verifies the end result (access code on device), not the exact key format.

Bootstrapping runs once per fixture eval. Cleanup (delete space, delete customer data) runs at teardown regardless of pass/fail.

### Flow

1. **Bootstrap Seam sandbox** — create space + device assignment (see above)
2. Copy skill-modified app to temp directory
3. `docker build` using the fixture's Dockerfile (builds from the modified source, so skill-added dependencies are installed)
4. `docker run` with env vars injected: `SEAM_API_KEY` (or whatever `seam_env_var` is set to in `eval_config.json`)
5. Poll `/health` until ready (timeout: 30s)
6. Run validation script using test payloads from `eval_config.json`:
   - `POST` create endpoint with resolved payload → poll Seam sandbox for access code on device (up to 60s)
   - `PUT` update endpoint with extended checkout → verify update propagated
   - `DELETE` cancel endpoint → verify access code removed (up to 30s)
7. Capture pass/fail per lifecycle step
8. **Teardown** — stop container, delete Seam space + customer data

### Dockerfiles

Minimal per fixture. The Docker build runs on the **skill-modified** source, so any dependencies the skill added to `package.json` / `requirements.txt` are installed during the build.

Express-ts example:

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

Flask-py example:

```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt ./
RUN pip install -r requirements.txt
COPY . .
EXPOSE 5000
CMD ["python", "app.py"]
```

If the skill adds a dependency via import but doesn't update the manifest file (`package.json`, `requirements.txt`), the build will fail. This is a legitimate eval failure — the rubric also checks for expected package additions via `expected_package_additions` in the answer key.

### Sandbox isolation

Each eval run uses a unique `RUN_ID` (timestamp-based, same pattern as existing `tests/*.sh`). All Seam resources (spaces, customers, reservations) use `RUN_ID`-namespaced keys so concurrent runs don't collide. Cleanup runs at the end regardless of pass/fail.

### Timing expectations

A single fixture's Layer 2 run takes approximately 2-3 minutes: ~10s build, ~5s startup, ~60s create polling, ~10s update, ~30s delete polling, ~5s teardown. With `--runs 3` across 2 fixtures, expect ~15 minutes total.

### Scoring

| Check | Points |
|-------|--------|
| App builds and starts | 10 |
| Create reservation → access code appears on device | 30 |
| Update reservation → code updated | 30 |
| Cancel reservation → code removed | 30 |

## Combined Score

Per fixture: **40% rubric + 60% sandbox**.

Sandbox is weighted higher because it's ground truth. If the app doesn't build, the rubric score still provides useful signal about what the skill got right structurally.

## Eval Orchestrator

Top-level script: `evals/run_evals.sh`

```
./evals/run_evals.sh [--fixtures express-ts,flask-py] [--layers rubric,sandbox] [--api-path reservation_automations] [--runs N]
```

### Flags

- `--fixtures` — run specific fixtures (default: all)
- `--layers` — `rubric`, `sandbox`, or `both` (default: both)
- `--api-path` — filter to fixtures with this expected API path (default: run all). Does not override the fixture's `eval_config.json` — it's a filter, not an override. Testing the same fixture with different API paths requires separate `eval_config.json` variants (future work).
- `--runs N` — run each fixture N times for consistency measurement (default: 1). All N result directories are preserved under `evals/results/<timestamp>/`. The summary table shows mean/min/max when N > 1.

### Skill invocation

The skill is interactive by design — it asks questions one at a time (Step 1 in SKILL.md). In eval mode, we bypass this by crafting prompts that front-load all the information the skill would ask for, plus an explicit instruction to skip the interview: `"Don't ask me any setup questions — explore the codebase and write the integration."`

The orchestrator runs Claude in headless mode with the skill loaded:

```bash
claude -p "$(cat eval_config.json | jq -r .prompt)" \
  --allowedTools Read,Write,Edit,Glob,Grep,Bash \
  --cwd "$WORKING_DIR"
```

The prompt in `eval_config.json` must include:
- What the platform does (short-term rentals, coworking, etc.)
- What locks they use (August, Yale, etc.)
- What level of control they need (maps to the API path)
- Whether they have a Seam account / devices already
- Explicit instruction to skip questions and start working

This ensures the skill routes to the correct API path and begins codebase exploration immediately.

### Output

Summary table to stdout:

```
Fixture        | Rubric | Sandbox | Combined | API Path
-------------- | ------ | ------- | -------- | --------
express-ts     |   85   |   90    |    88    | ✓ reservation_automations
flask-py       |   72   |   70    |    71    | ✓ reservation_automations
```

Detailed results to `evals/results/<timestamp>/` (gitignored):
- Per-fixture score breakdowns
- Raw diffs
- Docker build/run logs
- Sandbox validation logs

### Non-determinism

LLM outputs vary between runs. The `--runs N` flag supports running each fixture multiple times. Results output shows mean, min, and max per fixture when N > 1.

## Directory Structure (full)

```
evals/
  evals.json                          # existing qualitative evals (unchanged)
  rubric.json                         # rubric category definitions and weights
  run_evals.sh                        # orchestrator
  rubric_checker.py                   # Layer 1 scoring script
  sandbox_validator.sh                # Layer 2 Docker + Seam validation
  fixtures/
    express-ts/
      app/                            # pristine TypeScript Express app
        src/
          index.ts
          routes/
            reservations.ts
            webhooks.ts               # existing payment webhook
          services/
            reservationService.ts
          models/
            reservation.ts
            guest.ts
            property.ts
        package.json
        tsconfig.json
      Dockerfile
      answer_key.json
      eval_config.json
    flask-py/
      app/                            # pristine Flask app
        app.py
        blueprints/
          reservations.py
          webhooks.py                 # existing payment webhook
        services/
          reservation_service.py
        models/
          reservation.py
          guest.py
          property.py
        requirements.txt
      Dockerfile
      answer_key.json
      eval_config.json
    rails-rb/                         # stretch
    nextjs-ts/                        # stretch
    php-laravel/                      # stretch
  results/                            # gitignored
```

## Build Order

1. **express-ts fixture** — simplest app, proves the full pipeline
2. **rubric_checker.py** — Layer 1 scoring
3. **sandbox_validator.sh** — Layer 2 Docker validation
4. **run_evals.sh** — orchestrator
5. **flask-py fixture** — second fixture, validates cross-language support
6. **Remaining fixtures** — rails-rb, nextjs-ts, php-laravel

## Scope

This spec covers evals for the **Reservation Automations** API path only. This is the recommended default path and the most common PMS use case. Testing other API paths (Access Grants, lower-level API) across fixtures would require:
- Additional `eval_config.json` variants with different prompts per fixture
- Different answer keys per path
- Different sandbox validation flows (Access Grants uses `access_grants.create`, lower-level uses `access_codes.create`)

This is future work — get Reservation Automations evals solid first.

## Success Criteria

- Eval pipeline runs end-to-end for express-ts and flask-py
- Rubric produces repeatable scores for the same diff
- Docker validation catches broken integrations that look correct statically
- Running with `--runs 3` produces useful consistency data
- Adding a new fixture requires only: app code, Dockerfile, answer_key.json, eval_config.json
