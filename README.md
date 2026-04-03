# Seam PMS Integration Skill

An AI skill that helps developers integrate [Seam](https://seam.co) smart lock access code automation into their property management system (PMS).

## What it does

When loaded into an AI coding assistant (Claude Code, Cursor, etc.), this skill guides the developer through:

1. **Choosing the right API path** — Reservation Automations, Access Grants, or Lower-level API
2. **Exploring the codebase** — finding reservation handlers, routes, and models
3. **Writing the integration** — adding Seam SDK calls directly into existing code
4. **Setting up webhooks** — handling access code lifecycle events

The skill works across TypeScript, JavaScript, Python, Ruby, and PHP codebases.

## Install

```bash
# Via skills.sh
npx skills add seamapi/seam-integration-skill

# Or clone directly
git clone https://github.com/seamapi/seam-integration-skill.git
```

## Usage

Load `SKILL.md` as a system prompt or skill in your AI coding assistant, then describe your integration needs:

> "I'm building a short-term rental PMS in TypeScript with Express. We want to automatically create access codes on smart locks when guests book. We use August and Yale locks."

The skill will explore your codebase, choose the right Seam API path, and write the integration code.

## Seam API paths

| Path | When to use | Complexity |
|------|------------|-----------|
| **Reservation Automations** | Push reservation data, Seam handles access codes automatically | Lowest |
| **Access Grants** | Per-door control, multiple credential types (PIN, mobile key) | Medium |
| **Lower-level API** | Full manual control over access codes | Highest |

The skill recommends Reservation Automations by default — it covers most PMS use cases with minimal code.

## Eval system

The skill includes a quantitative eval system that tests it against 5 synthetic PMS fixture apps:

| Fixture | Stack | Latest Score |
|---------|-------|-------------|
| `express-ts` | TypeScript + Express | 99 |
| `flask-py` | Python + Flask | 96 |
| `nextjs-ts` | Next.js App Router | 94 |
| `rails-rb` | Ruby on Rails | 96 |
| `php-laravel` | PHP + Laravel | 96 |

### Two scoring layers

- **Layer 1: Structural rubric** — checks file targeting, API path selection, integration placement, parameter correctness, lifecycle completeness, webhook setup
- **Layer 2: Sandbox validation** — builds the modified app in Docker, runs it against the real Seam sandbox API, verifies access codes are created/updated/removed

### Running evals

```bash
# Rubric only (fast, no API key needed)
bash evals/run_evals.sh --fixtures express-ts --layers rubric

# Full pipeline with sandbox validation
SEAM_API_KEY=<sandbox_key> bash evals/run_evals.sh --layers both

# Multiple runs for consistency data
SEAM_API_KEY=<sandbox_key> bash evals/run_evals.sh --runs 3
```

**Requirements:** Docker, Python 3, Claude CLI (`claude`), Seam sandbox API key (for Layer 2)

## Docs

- [Design spec](docs/2026-03-23-quantitative-evals-design.md) — eval system architecture
- [Implementation plan](docs/2026-03-23-quantitative-evals-plan.md) — build plan for the eval system
- [Original design](docs/design.md) — skill design document

## Links

- [Seam docs](https://docs.seam.co)
- [Seam Console](https://console.seam.co)
- [Seam MCP server](https://mcp.seam.co/mcp) — docs search for AI assistants
