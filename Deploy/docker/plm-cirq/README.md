plm-cirq
=========

This is a small Docker image that contains Python + Cirq.

Usage
-----
- Run locally: docker run --rm localhost:5000/networkarchetype/plm-cirq:1.0
- Or: docker run --rm localhost:5000/networkarchetype/plm-cirq:latest

Files
-----
- `Dockerfile` - simple one-stage image used for quick tests.
- `Dockerfile.ci` - multi-stage image optimized for a reproducible build and containing a test script.
- `requirements.txt` - pinned dependency list used by the CI Dockerfile.
- `test_repro.py` - example test script executed by the multi-stage image.

CI
--
A GitHub Actions workflow is provided at `.github/workflows/docker-ci.yml` to build and push the multi-stage image to Docker Hub. It expects `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` secrets (or adjust the workflow to your registry and secrets).
