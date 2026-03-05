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

## Usage

Run from any directory:

```bash
loglm
```

`loglm` creates:

- `./logs/` for session logs
- `./.loglm_agent` for the selected agent

Both are scoped to the directory where you run `loglm`.
