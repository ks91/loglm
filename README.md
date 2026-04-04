# loglm
Logged launcher for AI coding agents: Claude Code, Codex, and Gemini.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/ks91/loglm/main/install.sh | bash
```

or

```bash
wget -qO- https://raw.githubusercontent.com/ks91/loglm/main/install.sh | bash
```

The installer places `loglm` in `~/.local/bin` by default.
It also installs:

- `loglm-decode` into `~/.local/bin`
- `loglm-timeline` into `~/.local/bin`
- setup scripts into `~/.local/share/loglm/setup`

If the install bin directory is not in `PATH`, `install.sh` appends it to your shell profile automatically.

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/ks91/loglm/main/uninstall.sh | bash
```

or

```bash
wget -qO- https://raw.githubusercontent.com/ks91/loglm/main/uninstall.sh | bash
```

Removes only:

- `loglm`
- `loglm-decode`
- `loglm-timeline`
- `~/.local/share/loglm/setup/*` managed by loglm

## Supported Platforms

Tested:

- macOS
- Ubuntu
- Ubuntu on Lima (macOS)
- Ubuntu on WSL2
- Raspberry Pi OS
- Chrome OS (Linux container / Crostini)

## Usage

Run from any directory:

```bash
loglm
```

`loglm` creates:

- `./logs/` for session logs
- `./.loglm_agent` for the selected agent

Both are scoped to the directory where you run `loglm`.
By default, each launch writes to a unique log file:

- `logs/loglm-<agent>-log-YYYYMMDD-HHMMSS-pid<PID>.txt`

If the selected agent command is missing (`codex`, `claude`, or `gemini`),
`loglm` prompts and runs an installer from `~/.local/share/loglm/setup`.
Before agent install, `doctor.sh` runs base checks (such as `script` command availability).
On macOS, setup prefers Homebrew for agent installation when a brew package is available;
otherwise it falls back to npm.
If Homebrew is missing on macOS, setup can install Homebrew interactively.
When npm fallback is used and npm is missing, setup can install Node.js / npm interactively.
On Linux/WSL/Raspberry Pi/Chrome OS, Node.js is installed via `nvm` (latest LTS) by setup.
When npm fallback is used, setup configures npm global installs to user space (`~/.local`) to avoid permission errors.
If `~/.npmrc` has incompatible `prefix`/`globalconfig` entries, setup adjusts them automatically for nvm.

Claude Code (all supported platforms):

- Native installation is recommended.
- If you installed via Homebrew or npm first, run `claude install` to switch to native installation.

Setup dialogue language:

- auto: from locale (`LC_ALL` > `LC_MESSAGES` > `LANG`; `ja*` => Japanese, otherwise English)
- override with `LOGLM_LANG=ja|en|both`

Example:

```bash
LOGLM_LANG=both loglm
```

## Options

- `--new`: Start a new context (ignore saved session).
- `--resume`: Open the agent's built-in session picker.
- For Gemini, default launch uses `gemini --resume`; `--new` starts a new session.
  If context is not restored as expected, run `/resume` (or `/chat resume`) inside Gemini after launch.
- `--agent`: Re-select the AI coding agent (`codex` / `claude` / `gemini`).
- `--daily-log`: Use one log file per day (legacy behavior).
- `-X`, `--dangerous`: Start the agent in dangerous/no-approval mode.
  - `codex`: `--dangerously-bypass-approvals-and-sandbox`
  - `claude`: `--dangerously-skip-permissions`
  - `gemini`: `--yolo`
- `-h`, `--help`: Show help.
- `-v`, `--version`: Show loglm version.

## Agent Prompt Install

Manage prompt-agent blocks in the current directory:

```bash
loglm agent install ks91/gamer-pat
loglm agent install ../gamer-pat
loglm agent list
loglm agent remove ks91/gamer-pat
loglm agent update --all
```

Supported repository spec:

- `owner/repo`
- `https://github.com/owner/repo`
- local repository path (for development/private use), e.g. `../gamer-pat` or `/path/to/repo`

Supported options:

- `--agent codex|claude|gemini|all` (default: current `./.loglm_agent`)
- `--verbose` (for `list`): show prompt file and prompt-agent version metadata

File mapping:

- codex source -> `AGENT_INSTALL_CODEX.md` -> `AGENT_INSTALL.md`
- claude source -> `AGENT_INSTALL_CLAUDE.md` -> `AGENT_INSTALL.md`
- gemini source -> `AGENT_INSTALL_GEMINI.md` -> `AGENT_INSTALL.md`
- `loglm` uses only the first existing file in that order (no merge).
- For local source paths, the same file mapping/rules apply.

Prompt-agent version metadata (recommended in `AGENT_INSTALL*.md`):

- HTML comment: `<!-- prompt-agent-version: 1.2.3 -->`
- or YAML front matter: `prompt_agent_version: 1.2.3`

Then view with:

```bash
loglm agent list --verbose
```

Behavior:

- `install` downloads prompt content into `<REPO-NAME-UPPER>.md` in the current directory
  (example: `ks91/gamer-pat` -> `GAMER-PAT.md`).
- `install` appends/updates managed reference blocks in `AGENTS.md` / `CLAUDE.md` / `GEMINI.md`
  that point to `<REPO-NAME-UPPER>.md`, instead of replacing whole files.
- Each installed prompt-agent block includes a small heading (`### Prompt Agent: <owner/repo>`)
  for readability.
- Managed reference blocks include strong instructions (`MUST read`, `MUST follow`) for consistency
  across codex / claude / gemini.
- Multiple repositories can be installed into the same file.
- A platform block is maintained automatically (macOS / WSL2 / Ubuntu on Lima / etc.).
- A common execution-policy block is maintained automatically (escalation-first on permission/sandbox failures).
- The platform block also includes loglm runtime notes (log directory/pattern, decode command, repository URL).
- `remove` deletes only the matching repo block(s), leaving other content intact.
- `remove` also deletes `<REPO-NAME-UPPER>.md` when no agent file references that repo anymore.
- `update` refreshes installed source block(s) (`github/local source` or `--all`).
- After `loglm agent install ...` completes, `loglm` starts the current coding agent in a new context.
- After auto-launch, send a short kickoff cue to begin the installed prompt-agent workflow
  (for example: `Let's begin.` or `はじめよう。`).
  - Set `LOGLM_AGENT_INSTALL_NO_LAUNCH=1` to disable auto-launch (used by tests).

Developer guide for prompt-agent authors:

- See [`PROMPT_AGENT_GUIDELINES.md`](./PROMPT_AGENT_GUIDELINES.md)

## Decode Logs

For log anonymization workflow, see [`PII_REDACTION_GUIDE.md`](./PII_REDACTION_GUIDE.md).

Decode raw `script` logs before reading:

```bash
loglm-decode logs/loglm-codex-log-20260307-100915-pid12345.txt
```

This writes:

- `logs/loglm-codex-log-20260307-100915-pid12345.decoded.txt`

Build a compact timeline from decoded logs:

```bash
loglm-timeline logs/*.decoded.txt
```

You can also use redacted/anonymized logs:

```bash
loglm-timeline logs/*.redacted.txt
loglm-timeline logs/*.redacted.decoded.txt
```

This prints, for each session:

- start time / agent
- opening user request
- later user turns
- key events such as `Ran`, `Edited`, `Shell`, `Update(...)`, and interruptions

If `--daily-log` was used, decode that daily file instead.

You can decode multiple files with shell globbing, for example:

```bash
loglm-decode logs/loglm-codex-log-20260307-*.txt
```

Review and redact grouped PII candidates interactively:

```bash
loglm-decode --review-pii examples/pii-candidates.txt logs/*.decoded.txt
```

This writes:

- `*.redacted.txt`

Behavior:

- raw `*.txt` and `*.decoded.txt` are preserved
- `--review-pii` never edits raw log files
- if the input is already `*.redacted.txt`, it is reviewed in place
- candidates show their first matching line number and line text for review
- the candidate list is grouped by blank lines
- each group is replaced with a numbered token such as `***1*`, `***2*`

For bulk redaction without interactive prompts:

```bash
loglm-decode --review-pii --replace-all examples/pii-candidates.txt logs/*.decoded.txt
```

## Dev Install (Branch)

For development testing, install from the current branch without editing `REPO_RAW_BASE` manually:

```bash
bash scripts/dev-install.sh
```

Optional:

```bash
bash scripts/dev-install.sh --branch feature/post-v0.1.0
bash scripts/dev-install.sh --repo ks91/loglm --print-only
```

## Regression Test

Run local regression checks (no network required):

```bash
bash scripts/regression.sh
```

Run E2E checks against a real GitHub repository:

```bash
bash scripts/regression.sh --e2e --repo ks91/gamer-pat --agent codex
```

## Install Layout

- `~/.local/bin/loglm`
- `~/.local/bin/loglm-decode`
- `~/.local/share/loglm/setup/ensure-agent.sh`
- `~/.local/share/loglm/setup/agent-install.sh`
- `~/.local/share/loglm/setup/doctor.sh`
- `~/.local/share/loglm/setup/install-node.sh`
- `~/.local/share/loglm/setup/platform-detect.sh`
- `~/.local/share/loglm/setup/lib.sh`
- `~/.local/share/loglm/setup/agent-codex.sh`
- `~/.local/share/loglm/setup/agent-claude.sh`
- `~/.local/share/loglm/setup/agent-gemini.sh`

Environment variables:

- `LOGLM_INSTALL_DIR`: install target for executables (default: `~/.local/bin`)
- `LOGLM_HOME`: install target for setup scripts (default: `~/.local/share/loglm`)
- `REPO_RAW_BASE`: raw file base URL used by installer
- `LOGLM_INSTALL_DIR` / `LOGLM_HOME` are also honored by `uninstall.sh`
- `LOGLM_LANG`: setup prompt language (`ja`, `en`, or `both`)
- `LOGLM_PLATFORM`: platform override for setup scripts (advanced/debug)

## License

GNU General Public License v3.0 or later (`GPL-3.0-or-later`).
