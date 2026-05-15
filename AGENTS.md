# Repository Guidelines

## Project Overview

Coder template dotfiles — config and setup scripts for standardized Coder cloud dev environments. The `install.sh` bootstrap provisions a full toolbox (runtimes, shells, tools) on a fresh Linux VM. Shell configs (Fish/Bash) wire PATH and invoke Starship prompt.

## Architecture & Data Flow

1. **Bootstrap**: Coder runtime clones repo → runs `install.sh` as root.
2. **install.sh** idempotently installs tools via curl pipes and apt, copies shell configs to `~/.config/fish/config.fish`, `~/.bash_profile`, `~/.bashenv`, copies `scripts/` to `~/.local/bin`, generates dynamic crontab with S3 credentials from Coder env vars for beads healthcheck, sets Fish as login shell.
3. **Shell init chain**:
   - `bash_profile` → sources `~/.bashrc`, sets `PATH`, execs Fish if SSH+interactive
   - `bashenv` — minimal PATH export (used by non-interactive shells)
   - `config.fish` — initializes Starship prompt, appends `bun`/`.local`/`deno` to PATH
4. **Git workflow** (local dev only, not in Coder): Husky hooks → commitlint validates conventional commit format → devmoji adds emoji.

## Key Directories

| Path | Purpose |
|---|---|
| `.husky/` | Git hooks (prepare-commit-msg runs devmoji, commit-msg runs commitlint) |
| `.claude/` | Claude Code local settings |
| `scripts/` | Custom shell scripts (copied to `~/.local/bin` by install.sh) |

No `src/`, `tests/`, `lib/`, or `docs/` directories. Monorepo root is the only source of truth.

## Development Commands

| Command | What it does |
|---|---|
| `bun run prepare` | Install Husky hooks |
| `bun run commit` | Commitizen interactive commit (`git-cz`) |

No test runner. No build step. No linter (beyond commitlint).

## Code Conventions & Common Patterns

- **Shell scripts (bash)**: `set -e` not used explicitly. Functions defined with `()` syntax. `log_step` helper for progress.
- **Config files**: Minimal, single-purpose files. No comments in production configs.
- **Git commits**: Conventional Commits enforced via commitlint (`@commitlint/config-conventional`). Use `bun run commit` for guided prompts.
- **Error handling**: curl/bash install patterns use `|| true` sparingly, rely on `set -e` implicit from top-level script flow.
- **No application code** — this is infrastructure-as-config. No state management, DI, or async patterns to follow.

## Important Files

| File | Role |
|---|---|
| `install.sh` | **Entry point** — provisions entire dev environment. Installs: Fish, NVM+Node, Bun, Deno, Tailscale, Starship, Zoxide, UV, Claude Code, Beads, pipx packages (skill-seekers, code-review-graph), bun globals (@servicenow/sdk, @oh-my-pi/pi-coding-agent, playwright), pi agent caveman skill |
| `config.fish` | Fish shell config — Starship init, PATH additions |
| `bash_profile` | Bash login profile — PATH, BASH_ENV, auto-exec Fish |
| `bashenv` | Non-interactive bash env — PATH only |
| `commitlint.config.js` | Commitlint config (extends conventional) |
| `.husky/prepare-commit-msg` | Husky hook — runs devmoji |
| `.husky/commit-msg` | Husky hook — runs commitlint |
| `package.json` | Name `coder-template-dotfiles`, scripts, devDependencies |
|| `crontab` | Crontab file with schedule entries for beads healthcheck (`*/30` + `@reboot`). `install.sh` prepends S3 env vars from Coder before installing. |
|| `scripts/beads-healthcheck.ts` | Cron job — runs `beads ready --json`, validates output, uploads to RustFS S3 (`s3://lobe/beads/latest.json`). Credentials injected via crontab env vars from Coder. |

## Runtime/Tooling Preferences

| Concern | Choice |
|---|---|
| **Package manager** | Bun (`bun install`, `bun run`, `bun commitlint`) |
| **Shell** | Fish (primary, set as login shell by install.sh) |
| **Bash fallback** | `bash_profile` + `bashenv` for non-Fish contexts |
| **Node version mgmt** | NVM (installed by install.sh, `nvm install node`) |
| **TypeScript** | Peer dependency `typescript ^5`, `@types/bun` |
| **Prompt** | Starship (no-runtime-versions preset) |
| **Git commit tooling** | commitizen + commitlint + devmoji via Husky |
| **Secondary runtimes** | Deno, UV (Python), Beads |

## Testing & QA

No test framework, test files, or coverage tooling present. QA is manual — validate by running `install.sh` in ephemeral Coder VM. CI not configured in this repo.
