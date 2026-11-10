# sessrumnir/shared-workflows

Reusable GitHub Actions workflows and Renovate presets for the sessrumnir
repositories.

## Workflows

- `collection-ci.yml`: lint, build, `ansible-test` and Molecule for
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
  artifacts, so builds do not use the plan's storage.

  With the repository variable `CI_REGISTRY` (host and optional port),
  `main` hands the image on through `<CI_REGISTRY>/<owner>-ci/<repo>/<image>`
  instead and keeps its BuildKit layer cache there as `buildcache`. The push
  job copies the tested digest to GHCR unchanged. Pull requests only read
  that cache. The runners mount the registry's robot as
  `/etc/ci-registry/{username,password}`: a robot that may push on `main`'s
  builder only, a pull-only one elsewhere. They also mount its CA in
  `/etc/ci-registry-ca`. Each pushed image is
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

- `image-scan.yml`: scans the published `ghcr.io/<owner>/<image>:stable`
  (input `tag`) of every image under `images/<name>/` with trivy, with no
  build: a fixable finding is fixed by a version bump in a pull request. The
  trivy DB is cached for a day; a private repository may pull it from
  `TRIVY_DB_REPOSITORY`. One open issue tracks the result: a failed scan
  opens it or comments the failed images on it, a clean one closes it. The
  caller grants `packages: read`, `issues: write` and `actions: read`.
- `lint.yml`: the common checks, each a container action under
  `.github/actions/` with a pinned tool image and no network or Docker
  daemon needed: file hygiene, actionlint, gitleaks, the Renovate config
  validator and markdownlint, then optionally hadolint on the root
  `Containerfile`, checkov, trivy and lychee's link check (`lychee: true`,
  configured by the repository's `.lychee.toml`, offline there).
  `lychee-online-config` names a second config with `offline = false`; a
  `links` job on a runner with network then checks the external links too,
  with the run's own read-only token. zizmor runs in its own
  job with its image as the job container, so it can reach GitHub, and gets
  the job's own read-only token for its online audits. `trivy-lockfiles` (on
  by default) scans the lockfiles for fixable HIGH and CRITICAL
  vulnerabilities in a job with the trivy image as its container. It
  downloads the DB from Trivy's default source, or for a private repository
  from the registry in the repository variable `TRIVY_DB_REPOSITORY`, and
  caches it for a day. A private repository runs these jobs on `JOBS_RUNNER`,
  a runner that starts each step as its own container
  without Docker (ARC's Kubernetes container mode), or on `PRIVATE_RUNNER`
  where that is unset; public ones on GitHub-hosted runners. `make-targets`
  adds the repository's own make targets, on `PRIVATE_RUNNER`.
- `pr-title.yml`: requires a Conventional Commit pull request title. Runs
  where `lint.yml`'s checks run.

The workflows keep their decisions out of the YAML: each is a bash script
beside a composite action under `.github/actions/`, and `tests/` runs the
scripts directly.

- `select-images`: the images a push or pull request rebuilds.
- `select-checks`: what a `collection-ci.yml` run needs (skip, lint, fast or
  full) and which Molecule scenarios.
- `merge-release`: `collection-train.yml`'s checks before it merges a
  release.
- `ci-registry`: logs in to `CI_REGISTRY` with the mounted robot.
- `image-build`, `image-load`, `image-test`, `image-push`: the steps of
  `image-build.yml`'s build, test and push jobs, for both hand-offs.

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

`make lint` validates both with `renovate-config-validator --strict
--no-global`, as repository config, so a broken preset fails here before a
release instead of stopping Renovate in every repository.

## Development

```sh
make lint test   # every tool in its own pinned image; needs Docker
make hooks       # run make lint before every push
```
