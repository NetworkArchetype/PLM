# PLM Authentication Guide

This project prompts for credentials when required and caches them only for the current session using local, DPAPI-protected storage. Use the environment variables below to run noninteractively (CI, automation) without prompts.

## Surfaces that request auth
- `start_plm.ps1` (GUI and CLI modes)
- Admin GUI: `Deploy/PLM-Environment-AdminGUI.ps1`
- CLI console: `scripts/plm_cli.py` (invoked via `start_plm.ps1`)
- QA helpers: `qa_test/windows_cli_smoke.ps1`, `qa_test/windows_sandbox_matrix.ps1`, `qa_test/linux_cli_smoke.sh`

## Noninteractive / CI usage
- Preferred: set `PLM_AUTH_TOKEN` in the environment before invoking scripts.
- Alternative: set `PLM_AUTH_TOKEN_FILE` to a file containing the token.
- When set, prompts are skipped and the token is exported to child processes.

## Prompted usage (interactive)
- CLI prompt hides input.
- GUI prompt (WinForms) hides input and allows cancel.
- After the first successful prompt per session, the token is cached in-memory and written as a DPAPI-protected SecureString under `%TEMP%\plm_session\auth.dat` with a companion SHA-256 hash at `%TEMP%\plm_session\auth.sha256` for debug/reference. No plaintext token is written to disk.
- To clear cache: `pwsh -File scripts/test_auth_hooks.ps1 -Clear`.

## Token hashing and logging
- A SHA-256 hash of the token is computed for diagnostics (`PLM_AUTH_HASH`).
- Logs are sanitized to redact common token/password patterns before writing to host or UI logs.

## Environment propagation
- `start_plm.ps1` sets `PLM_AUTH_TOKEN` and `PLM_AUTH_HASH` for child processes (GUI/CLI).
- Admin GUI sets the same env vars on launch.
- Downstream tools should read `PLM_AUTH_TOKEN` rather than prompting again.

## Best practices
- Prefer short-lived tokens and least privilege scopes.
- Do not commit tokens or token files. Keep `PLM_AUTH_TOKEN_FILE` paths outside the repo tree.
- For CI secrets, use your CI secret store and inject as env vars at runtime.
- Avoid writing tokens to logs; rely on the provided sanitization and hashes for verification.
