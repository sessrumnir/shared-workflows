# sessrumnir/shared-workflows

Reusable GitHub Actions workflows and Renovate presets for the sessrumnir
repositories.

## Workflows

- `collection-ci.yml`: Trivy, lint, build, `ansible-test` and Molecule for
  an Ansible collection.
- `collection-release.yml`: Release Please, then build, checksum and attest
  a collection release.
- `collection-train.yml`: merges a waiting collection release after a green
  nightly run.
- `image-build.yml`: lint, build, test, scan and push the images under
  `images/<name>/`; `test.sh` may print `version=<x>` to tag `<x>`. The
  build runs on the runner the `BUILD_RUNNER` variable names, which holds
  the BuildKit credential and runs no repository code; the test, scan and
  SBOM run on `PRIVATE_RUNNER`, the scan and SBOM with the owner's pinned
  `trivy` image. Each pushed image is signed keyless and carries its SBOM
  as an attestation:

  ```sh
  cosign verify --certificate-oidc-issuer https://token.actions.githubusercontent.com \
    --certificate-identity-regexp '^https://github\.com/sessrumnir/shared-workflows/\.github/workflows/image-build\.yml@' \
    --certificate-github-workflow-repository <owner>/<repo> \
    --certificate-github-workflow-ref refs/heads/main <image>@<digest>
  ```

  The certificate names this reusable workflow; the calling repository and
  branch are checked separately. `verify-attestation --type spdxjson` with
  the same flags checks the SBOM.

- `lint.yml`: checks out the repository and runs its `make lint`, the
  building block for repositories without their own pipeline.
- `pr-title.yml`: requires a Conventional Commit pull request title.

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
