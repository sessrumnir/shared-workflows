# sessrumnir/shared-workflows

Reusable GitHub Actions workflows and Renovate presets for the sessrumnir
repositories.

## Workflows

- `collection-ci.yml`: Trivy, lint, build, `ansible-test` and Molecule for
  an Ansible collection. The common checks run through `lint.yml`; the
  collection's own lint, `make-targets` (default `checkov ansible-lint`),
  runs on `PRIVATE_RUNNER` beside the private collections it may need.
- `collection-release.yml`: Release Please, then build, checksum and attest
  a collection release; the tarball reaches the publish job through the
  Actions cache.
- `collection-train.yml`: merges a waiting collection release after a green
  nightly run.
- `image-build.yml`: lint, build, test, scan and push the images under
  `images/<name>/`; `test.sh` may print `version=<x>` to tag `<x>`. The
  changed images are selected on `JOBS_RUNNER`, else `PRIVATE_RUNNER`. The
  build runs on a runner that holds a BuildKit credential and runs no
  repository code: `BUILD_RUNNER` for `main`'s push, schedule and dispatch
  runs, `PR_BUILD_RUNNER` (a separate BuildKit) for everything else; a
  pull request build fails when `PR_BUILD_RUNNER` is unset. The test, scan and
  SBOM run on `PRIVATE_RUNNER`, the scan and SBOM with the owner's pinned
  `trivy` image. The jobs hand the image on through the Actions cache, not
  artifacts, so builds do not use the plan's storage. Each pushed image is
  signed keyless and carries its SBOM as an attestation:

  ```sh
  cosign verify --certificate-oidc-issuer https://token.actions.githubusercontent.com \
    --certificate-identity-regexp '^https://github\.com/sessrumnir/shared-workflows/\.github/workflows/image-build\.yml@' \
    --certificate-github-workflow-repository <owner>/<repo> \
    --certificate-github-workflow-ref refs/heads/main <image>@<digest>
  ```

  The certificate names this reusable workflow; the calling repository and
  branch are checked separately. `verify-attestation --type spdxjson` with
  the same flags checks the SBOM.

- `lint.yml`: the common checks, each a container action under
  `.github/actions/` with a pinned tool image and no network or Docker
  daemon needed: file hygiene, actionlint, gitleaks, the Renovate config
  validator and markdownlint, then optionally hadolint on the root
  `Containerfile`, checkov and trivy. zizmor runs in its own job with its
  image as the job container, so it can reach GitHub, and gets the job's
  own read-only token for its online audits. A private repository runs them on
  `JOBS_RUNNER`, a runner that starts each step as its own container
  without Docker (ARC's Kubernetes container mode), or on `PRIVATE_RUNNER`
  where that is unset; public ones on GitHub-hosted runners. `make-targets`
  adds the repository's own make targets, on `PRIVATE_RUNNER`.
- `pr-title.yml`: requires a Conventional Commit pull request title. Runs
  where `lint.yml`'s checks run.

Pin a release by commit SHA:

```yaml
jobs:
  ci:
    uses: sessrumnir/shared-workflows/.github/workflows/collection-ci.yml@<sha> # vX.Y.Z
```

Inputs and secrets are declared at the top of each workflow.

## Renovate presets

- `local>sessrumnir/shared-workflows//renovate/default`
- `local>sessrumnir/shared-workflows//renovate/collection`

## Development

```sh
make lint test   # every tool in its own pinned image; needs Docker
make hooks       # run make lint before every push
```
