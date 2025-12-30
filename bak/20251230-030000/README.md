PLM CI debug artifact set (one-time archive)

Contents:
- plm-ci-debug-20251230-030000.tar.gz : gzip tarball of selected CI/debug files
- Included files inside the tarball:
  - .github/workflows/docker-ci.yml
  - Deploy/docker/plm-cirq/Dockerfile.ci
  - Deploy/docker/plm-cirq/test_repro.py
  - Deploy/docker/plm-cirq/requirements.txt
  - Deploy/PLM-Environment-AdminGUI.fixed.ps1
  - bak/20251230-020000/ci-jobs-20593569025.json
  - bak/20251230-020000/ci-jobs-20593576670.json

Upload scripts (in repo `scripts/`) implement an optional randomized upload of the tarball to an arbitrary HTTP endpoint or GitHub Release. See `scripts/README.md` for usage.
