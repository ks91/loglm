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
- `~/.local/share/loglm/setup/*` managed by loglm

## Supported Platforms

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

If the selected agent command is missing (`codex`, `claude`, or `gemini`),
`loglm` prompts and runs an installer from `~/.local/share/loglm/setup`.
Before agent install, `doctor.sh` runs base checks (such as `script` command availability).
On macOS, setup prefers Homebrew for agent installation when a brew package is available;
otherwise it falls back to npm.
If Homebrew is missing on macOS, setup can install Homebrew interactively.
When npm fallback is used and npm is missing, setup can install Node.js / npm interactively.
When npm fallback is used, setup configures npm global installs to user space (`~/.local`) to avoid permission errors.

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
- `--agent`: Re-select the AI coding agent (`codex` / `claude` / `gemini`).
- `-X`, `--dangerous`: Start the agent in dangerous/no-approval mode.
  - `codex`: `--dangerously-bypass-approvals-and-sandbox`
  - `claude`: `--dangerously-skip-permissions`
  - `gemini`: `--yolo`
- `-h`, `--help`: Show help.

## Decode Logs

Decode raw `script` logs before reading:

```bash
loglm-decode logs/loglm-codex-log-20260305.txt
```

This writes:

- `logs/loglm-codex-log-20260305.decoded.txt`

## Install Layout

- `~/.local/bin/loglm`
- `~/.local/bin/loglm-decode`
- `~/.local/share/loglm/setup/ensure-agent.sh`
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
