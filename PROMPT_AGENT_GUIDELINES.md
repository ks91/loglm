# Prompt Agent Developer Guidelines

This guide is for repository authors who want their prompt agents to be installable via:

```bash
loglm agent install <owner/repo>
```

## 1. Provide Prompt Files at Repository Root

Place one or more of these files in the repository root:

- `AGENTS.md` (for codex)
- `CLAUDE.md` (for claude; optional if `AGENTS.md` is sufficient)
- `GEMINI.md` (for gemini; optional if `AGENTS.md` is sufficient)

`loglm` resolves files in this order:

- codex: `AGENTS.md`
- claude: `CLAUDE.md` -> fallback `AGENTS.md`
- gemini: `GEMINI.md` -> fallback `AGENTS.md`

## 2. Design for Layered Composition

`loglm` does not replace the whole local file by default.
It appends/updates a managed block for your repository.

Recommended style:

- Assume your instructions may coexist with other prompt agents.
- Keep your scope explicit (what your prompt controls, what it does not).
- Avoid hard requirements that conflict with general project safety rules.

## 3. Avoid `loglm` Marker Collisions

`loglm` manages blocks using comment markers like:

- `<!-- loglm:begin ... -->`
- `<!-- loglm:end ... -->`

Do not include these exact marker patterns in your distributed prompt files.

## 4. Keep Platform Assumptions Minimal

`loglm` injects platform notes (macOS, WSL2, Ubuntu on Lima, etc.) separately.
Your prompt should be portable unless platform-specific behavior is essential.

If platform-specific commands are needed:

- Provide alternatives (`open` / `wslview` / Linux-native tools).
- Explain when each command should be used.

## 5. Make Behavior Verifiable

Good prompt-agent files should include:

- Clear workflow steps
- Concrete command examples
- Validation steps (how to confirm success)
- Safety/guardrails (what to avoid)

Avoid vague policy-only text with no executable guidance.

## 6. Versioning Recommendations

For stable downstream behavior:

- Keep prompt files versioned in Git history.
- Prefer additive changes with clear changelog notes.
- If making breaking prompt changes, document migration notes in `README.md`.

## 7. Suggested Minimal Template

You can start with this structure:

```md
# <Agent Name>

## Purpose
- What this prompt-agent is for.

## Scope
- What tasks it should handle.
- What tasks it should not handle.

## Workflow
- Step-by-step process.

## Commands
- Frequently used commands and expected outcomes.

## Validation
- How to verify outputs.

## Safety
- Rules that must not be violated.
```

