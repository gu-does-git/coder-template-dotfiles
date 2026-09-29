# ⚙️ Coder Template Dotfiles

Configuration files and bootstrap scripts for a standardized **[Coder](https://coder.com/)** cloud development environment. The Coder workspace runtime clones this repo and runs `install.sh`, which provisions a complete toolbox (runtimes, shells, CLI tools, agents) and wires the shell environment.

Everything is **idempotent** — the workspace home persists across restarts, so re-running `install.sh` only fills in what is missing.

## 🚀 What `install.sh` installs

| Group | Tools |
|---|---|
| **Runtimes** | [Node.js](https://github.com/nvm-sh/nvm) (via NVM), [Bun](https://bun.sh/), [Deno](https://deno.com/), [UV](https://astral.sh/uv/) (Python) |
| **Shell & prompt** | [Fish](https://fishshell.com/) (set as login shell), [Starship](https://starship.rs/) (`no-runtime-versions` preset), [Zoxide](https://github.com/ajeetdsouza/zoxide) (+ `icezyclon/zoxide.fish` Fisher plugin) |
| **CLI tools** (apt) | [gh](https://cli.github.com/), `jq`, [bat](https://github.com/sharkdp/bat), [fzf](https://github.com/junegunn/fzf), [eza](https://github.com/eza-community/eza), [ripgrep](https://github.com/BurntSushi/ripgrep), `fd-find`, `bubblewrap` |
| **CLI tools** (binaries) | [timetrace](https://github.com/dominikbraun/timetrace), [Worktrunk](https://worktrunk.dev/) (`wt` — git worktree CLI, with Fish shell integration), [yq](https://mikefarah.gitbook.io/yq), [Tailscale](https://tailscale.com/) |
| **Agents & dev tooling** | [Claude Code](https://claude.ai/code), [oh-my-pi / pi coding agent](https://www.npmjs.com/package/@oh-my-pi/pi-coding-agent) (+ `pi-caveman` plugin), [beads](https://github.com/steveyegge/beads), [Playwright](https://playwright.dev/) Chromium (with deps), [ServiceNow SDK](https://www.npmjs.com/package/@servicenow/sdk), `vercel`, `skillkit`, `bun-docx` |
| **Python tooling** (uv) | [skill-seekers](https://pypi.org/project/skill-seekers/), [code-review-graph](https://code-review-graph.com/) |

Worktrunk ships as a prebuilt musl binary into `/usr/local/bin/wt`, then `wt config shell install fish --yes` writes `~/.config/fish/functions/wt.fish` + completions — without that wrapper `wt switch` cannot change the shell directory.

## 🏃 How to run

```bash
./install.sh
```

Designed to run in the Coder workspace bootstrap (as root, non-interactive; `DEBIAN_FRONTEND=noninteractive`).

### Order of operations

1. **Background installers** — `bun`, `starship`, `zoxide`, `deno`, `uv`, `claude`, `beads`, `timetrace`, `wt`, `yq` start in parallel (no apt, so they overlap the apt work).
2. **apt** — adds the Fish PPA + GitHub CLI apt repo, one `apt-get update`, a conditional `apt upgrade` (simulated first: skipped when nothing is pending), then a single consolidated `apt install`.
3. **`wait`** — joins the background installers, then PATH is expanded with `~/.bun/bin` and `~/.local/bin`.
4. **NVM + Node** — sequential (`nvm install node`).
5. **Shell config** — copies `config.fish`, `bash_profile`, `bashenv`; appends the NVM node bin dir to Fish PATH; generates `~/.config/starship.toml` (the preset leaves `add_newline` at its `true` default, which renders a blank line before every prompt — the install sets it to `false`); sets Fish as login shell; installs Fisher + plugins; installs Worktrunk shell integration.
6. **Tailscale** — installs the client; joins the tailnet **only if `OAUTH_CLIENT_SECRET` is set**.
7. **Container DNS probe** — if `pypi.org` fails to resolve, rewrites `/etc/resolv.conf` to `1.1.1.1` / `9.9.9.9` (the container inherits the host `resolv.conf` pointing at `100.100.100.100` MagicDNS, which does not route from inside the container).
8. **uv tool packages** — `skill-seekers`, `code-review-graph`.
9. **Scripts + crontab** — copies `scripts/*` to `~/.local/bin`, installs `/etc/cron.d/coder-template`.
10. **Bun globals + Playwright** — global npm packages, `pi-caveman` plugin, Chromium download.

### Flags

| Flag | Effect |
|---|---|
| `SKIP_UPGRADE=1` | Skips `apt upgrade` (the slowest step) |
| `SKIP_PLAYWRIGHT=1` | Skips the Chromium download (`--with-deps`) |
| `FORCE=1` | Re-installs tools even when already present |

### Environment variables

| Variable | Used for |
|---|---|
| `OAUTH_CLIENT_SECRET` | Tailscale auth key → `tailscale up --advertise-tags=tag:coder --accept-dns=false` |
| `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY` | Injected as env vars into `/etc/cron.d/coder-template` for the beads healthcheck upload |
| `S3_ENDPOINT` | S3 endpoint (default `https://s3.gupve.dev`) |
| `S3_BUCKET` | S3 bucket (default `lobe`) |

## 🐚 Shell configuration

| File | Purpose |
|---|---|
| `config.fish` | Copied to `~/.config/fish/config.fish` — Starship init, PATH (`~/.bun/bin`, `~/.local/bin`, `~/.deno/bin`), aliases (`cat`→`bat`, `ls`/`ll`/`la`→`eza`), disabled greeting banner (`set -g fish_greeting`) |
| `bash_profile` | Copied to `~/.bash_profile` — sources `~/.bashrc`, sets PATH + `BASH_ENV`, aliases, and `exec`s Fish on interactive SSH sessions |
| `bashenv` | Copied to `~/.bashenv` — minimal PATH export for non-interactive Bash (used via `BASH_ENV`) |

`install.sh` also repairs the image's `~/.local/bin/env` PATH shim. It sits before `/usr/bin/env` on `PATH`, so without a passthrough it swallowed every `env VAR=x cmd` call — the Worktrunk shell wrapper runs `env WORKTRUNK_DIRECTIVE_CD_FILE=… wt …`, which is why `wt` silently did nothing under Fish. The install appends an `exec /usr/bin/env "$@"` guard that only fires when the file is executed, leaving `source`ing from `~/.bashrc` / `~/.profile` untouched.

## ⏰ Scripts & crontab

`scripts/*` is copied to `~/.local/bin` and `crontab` is installed as `/etc/cron.d/coder-template` (with the S3 credentials prepended when present):

```cron
*/30 * * * * root bun $HOME/.local/bin/beads-healthcheck.ts >> /tmp/beads-healthcheck.log 2>&1
@reboot sleep 300 && root bun $HOME/.local/bin/beads-healthcheck.ts >> /tmp/beads-healthcheck.log 2>&1
```

`scripts/beads-healthcheck.ts` runs `beads ready --json` inside `/mnt/projects/newSnUtils`, validates the JSON, and uploads it to `s3://lobe/beads/latest.json` (logs at `/tmp/beads-healthcheck.log`).

## 📁 Repository layout

| Path | Role |
|---|---|
| `install.sh` | **Entry point** — provisions the whole environment |
| `config.fish` | Fish config deployed to `~/.config/fish/config.fish` |
| `bash_profile` | Bash login profile deployed to `~/.bash_profile` |
| `bashenv` | Non-interactive Bash env deployed to `~/.bashenv` |
| `crontab` | Cron entries deployed to `/etc/cron.d/coder-template` |
| `scripts/` | Helper scripts deployed to `~/.local/bin` (includes the beads healthcheck) |
| `package.json` | Dev tooling only: husky, commitlint, commitizen, devmoji |
| `commitlint.config.js` | Conventional Commits rules |
| `.husky/` | `prepare-commit-msg` → devmoji, `commit-msg` → commitlint |
| `.claude/` | Claude Code local settings |
| `AGENTS.md` | Repository guidelines for coding agents |

No `src/`, `tests/`, or `lib/` — this repo is infrastructure-as-config; `install.sh` is the single source of truth.

## 🛠️ Local development

Commits are validated by **Husky + commitlint** (Conventional Commits) and decorated with emoji by **devmoji**:

```bash
bun install          # installs the git hooks (husky prepare)
bun run commit       # commitizen prompt (git-cz + commitlint adapter)
```

There is no build step, linter, or test suite — QA is running `install.sh` in a fresh Coder workspace.
