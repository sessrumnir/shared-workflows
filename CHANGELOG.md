# Changelog

## [0.20.0](https://github.com/sessrumnir/shared-workflows/compare/v0.19.1...v0.20.0) (2026-10-30)


### Features

* **renovate:** update tool versions in Containerfile ARGs ([#18](https://github.com/sessrumnir/shared-workflows/issues/18)) ([2170d85](https://github.com/sessrumnir/shared-workflows/commit/2170d855070966ce18a289c216dee12062f13807))

## [0.19.1](https://github.com/sessrumnir/shared-workflows/compare/v0.19.0...v0.19.1) (2026-10-30)


### Bug Fixes

* **renovate:** update the images' Python requirements ([#15](https://github.com/sessrumnir/shared-workflows/issues/15)) ([ff1d4d5](https://github.com/sessrumnir/shared-workflows/commit/ff1d4d5fa9a064269a380c9094f0bb6f1539d048))

## [0.19.0](https://github.com/sessrumnir/shared-workflows/compare/v0.18.1...v0.19.0) (2026-10-29)


### Features

* lint with the organization's tool images, no pre-commit or Python ([#11](https://github.com/sessrumnir/shared-workflows/issues/11)) ([9258a06](https://github.com/sessrumnir/shared-workflows/commit/9258a068b4d3844bb72707cdc51c0401fea4e4f8))


### Bug Fixes

* **image-build:** build on builder runners, test where no BuildKit credential is ([#12](https://github.com/sessrumnir/shared-workflows/issues/12)) ([eec404d](https://github.com/sessrumnir/shared-workflows/commit/eec404d07282e078f991e66586bd84787480e979))
* keep pinned images through rebuilds, pins follow own images at once ([#14](https://github.com/sessrumnir/shared-workflows/issues/14)) ([5daecce](https://github.com/sessrumnir/shared-workflows/commit/5daecceaca5e46df91803cceaa84807c1893b347))

## [0.18.1](https://github.com/sessrumnir/shared-workflows/compare/v0.18.0...v0.18.1) (2026-10-28)


### Bug Fixes

* **image-build:** pass the image digest as a checked step output ([#8](https://github.com/sessrumnir/shared-workflows/issues/8)) ([b414e89](https://github.com/sessrumnir/shared-workflows/commit/b414e893775c3747cc5112c9db78060b7ed034ae))

## [0.18.0](https://github.com/sessrumnir/shared-workflows/compare/v0.17.0...v0.18.0) (2026-10-28)


### Features

* **image-build:** sign pushed images keyless and attest their SBOM ([#5](https://github.com/sessrumnir/shared-workflows/issues/5)) ([0351617](https://github.com/sessrumnir/shared-workflows/commit/0351617beeb0a23b6351c11ac25009c07226fb22))


### Bug Fixes

* **collection-release:** build the pushed commit, release only from pushes to main ([#7](https://github.com/sessrumnir/shared-workflows/issues/7)) ([a3e6470](https://github.com/sessrumnir/shared-workflows/commit/a3e64708ec889fd4c028e1ae5266775a3b64950f))
* harden the shared workflows after the security review ([#4](https://github.com/sessrumnir/shared-workflows/issues/4)) ([dfebd6a](https://github.com/sessrumnir/shared-workflows/commit/dfebd6a93c7cbf4d7b92a3742457e9230cfc1bba))

## [0.17.0](https://github.com/sessrumnir/shared-workflows/compare/v0.16.0...v0.17.0) (2026-10-28)


### Features

* reusable workflows and Renovate presets for every repository ([07e12b2](https://github.com/sessrumnir/shared-workflows/commit/07e12b2c74dd8addfeeb71e529623419cbf232d1))
