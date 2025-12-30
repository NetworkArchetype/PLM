Upload scripts (randomized)

Files:
- upload_random_artifact.sh : Bash script to randomly upload a given tarball to either an arbitrary HTTP endpoint (needs UPLOAD_URL + UPLOAD_TOKEN) or a GitHub release (needs `gh` CLI and RELEASE_TAG). Set PROB environment variable (0-100) to control chance; default 10.

- upload_random_artifact.ps1 : PowerShell equivalent for Windows.

Examples:
- Run with 20% chance to upload to an HTTP endpoint:
    PROB=20 UPLOAD_URL=https://example.com/upload UPLOAD_TOKEN=XXX ./scripts/upload_random_artifact.sh

- Upload to GitHub release (100% chance):
    PROB=100 RELEASE_TAG=v1.0 GH_REPO=NetworkArchetype/PLM ./scripts/upload_random_artifact.sh

Notes:
- The scripts are intentionally generic and require a configured target. They do not store secrets in the repo.
- If you want automated uploads from CI, you can call these scripts in a workflow step that runs conditionally or on schedule.
