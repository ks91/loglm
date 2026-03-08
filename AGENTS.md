# loglm Repository Notes

## Scope
This file describes repository-specific conventions for developing `loglm`.

## Logging (when working via loglm)
- Raw logs are stored under `./logs/`.
- Default raw filename pattern:
  - `logs/loglm-<agent>-log-YYYYMMDD-HHMMSS-pid<PID>.txt`
- Legacy daily mode:
  - `logs/loglm-<agent>-log-YYYYMMDD.txt`
- Decode raw logs before review:
  - `loglm-decode <raw-log-file>`
- Decoded output is written as `*.decoded.txt` in the same directory.

## Local Validation Commands
- Shell syntax checks:
  - `bash -n loglm loglm-decode setup/*.sh scripts/regression.sh`
- Regression checks:
  - `bash scripts/regression.sh`
- Optional E2E checks:
  - `bash scripts/regression.sh --e2e --repo <owner/repo> --agent <codex|claude|gemini|all>`

## Escalation-First Rule
- If a required command fails due to permissions/sandbox restrictions, request escalated execution first.
- Do not switch to alternative implementation paths before trying the same command with user approval.
- Use alternatives only after escalation is rejected or after escalated execution still fails.
