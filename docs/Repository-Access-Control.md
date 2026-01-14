# PLM Repository Access Control

## Overview
This repository enforces strict access controls to ensure only **networkarchetype@gmail.com** can commit changes, while maintaining public read access.

## Local Protection (Git Hooks)

### Pre-commit Hook
Location: `.githooks/pre-commit`

The pre-commit hook validates:
1. **Email Authorization**: Blocks commits unless `user.email` is set to `networkarchetype@gmail.com`
2. **Version Bumping**: Automatically bumps patch version on each commit

To authorize your local commits:
```bash
git config user.email "networkarchetype@gmail.com"
git config user.name "NetworkArchetype"
```

## CI Protection (GitHub Actions)

### Project Safety Workflow
Location: `.github/workflows/project-safety.yml`

Validates that commits to protected paths:
- Come from the repository owner (NetworkArchetype)
- Have the correct author email (networkarchetype@gmail.com)

Protected paths:
- `.githooks/`
- `.github/workflows/`
- `scripts/auto_version.py`
- `scripts/plm_security/`
- `VERSION`

## GitHub Repository Settings

To enforce repository-wide access control, configure the following settings on GitHub:

### 1. Repository Visibility
**Settings → General → Danger Zone**
- Set to **Public** (allows world read access)

### 2. Branch Protection Rules
**Settings → Branches → Branch protection rules → Add rule**

For branch: `master`
- ✅ **Require a pull request before merging**
  - Required approvals: 1
  - Dismiss stale pull request approvals when new commits are pushed
- ✅ **Require status checks to pass before merging**
  - Required checks (use the full "workflow / job" name shown in Actions):
    - `Project Safety Check / policy-check`
    - `Version Validation / validate-version`
    - `Security Checks / security-scan`
    - (Optional, PR-only) `Security Checks / dependency-review`
- ✅ **Require branches to be up to date before merging**
- ✅ **Do not allow bypassing the above settings**
- ✅ **Restrict who can push to matching branches**
  - Add: `NetworkArchetype` (owner only)

Notes:
- The "no direct pushes to master" enforcement is primarily handled by the branch protection settings above.
- The `enforce-pr-only` workflow runs on `push` to `master` as an additional guardrail. If branch protection is configured correctly, it should normally never run on unauthorized direct pushes because those pushes should be blocked.

For branch: `develop` (if used)
- Same settings as `master`

### 3. Collaborators
**Settings → Collaborators and teams → Manage access**
- No collaborators (only owner has write access)
- Public can read/fork/open issues

### 4. Rulesets (Enhanced Protection)
**Settings → Rules → Rulesets → New ruleset**

Create ruleset: "Protect Infrastructure"
- Target branches: `master`, `develop`
- Bypass list: None (no one can bypass)
- Rules:
  - ✅ **Restrict creations**
  - ✅ **Restrict updates** (require pull request)
  - ✅ **Restrict deletions**
  - ✅ **Require status checks**
  - ✅ **Block force pushes**

### 5. Actions Permissions
**Settings → Actions → General**
- ✅ **Allow all actions and reusable workflows**
- Workflow permissions:
  - ✅ **Read and write permissions**
  - ✅ **Allow GitHub Actions to create and approve pull requests**

### 6. Secrets and Variables
**Settings → Secrets and variables → Actions**

Required secrets:
- `GITHUB_TOKEN` (automatically provided by GitHub)

## Testing Access Controls

### Test Local Protection
```powershell
# Set incorrect email
git config user.email "test@example.com"

# Try to commit (should fail)
git commit -m "test"
# Expected: ❌ Error: Unauthorized commit email

# Set correct email
git config user.email "networkarchetype@gmail.com"

# Commit (should succeed)
git commit -m "authorized commit"
# Expected: ✓ Authorized: NetworkArchetype <networkarchetype@gmail.com>
```

### Test CI Protection
1. Create a pull request from a fork or branch
2. Modify a protected file (e.g., `.github/workflows/project-safety.yml`)
3. CI check `project-safety` should fail if not from authorized account
4. Check Actions logs for denial message

## Security Audit

Run security audit to verify protection:
```powershell
python scripts/version_audit.py
python scripts/plm_security/check_commit_auth.py
```

## Emergency Access

If legitimate access is blocked:

1. **Check git config**:
   ```bash
   git config user.email
   git config user.name
   ```

2. **Fix configuration**:
   ```bash
   git config user.email "networkarchetype@gmail.com"
   git config user.name "NetworkArchetype"
   ```

3. **Verify hooks are active**:
   ```bash
   git config core.hooksPath
   # Should output: .githooks
   ```

4. **Test authorization**:
   ```bash
   python scripts/plm_security/check_commit_auth.py
   ```

## Maintenance

### Update Authorized Email
If the authorized email changes:

1. Update `AUTHORIZED_EMAIL` in:
   - `.githooks/pre-commit`
   - `scripts/plm_security/check_commit_auth.py`
   - `scripts/plm_security/ci_policy_check.py`

2. Commit changes with current authorized email
3. Configure new email locally
4. Test commit authorization

### Update Protected Paths
Edit `PROTECTED_PREFIXES` in:
- `scripts/plm_security/ci_policy_check.py`

## Support

For access issues or questions:
- Email: networkarchetype@gmail.com
- GitHub Issues: https://github.com/NetworkArchetype/PLM/issues

## License
This repository is licensed under the terms specified in LICENSE file.
Public read access is permitted. Modifications require owner authorization.
