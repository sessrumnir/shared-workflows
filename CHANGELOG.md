# Changelog

## [0.29.0](https://github.com/sessrumnir/shared-workflows/compare/v0.28.0...v0.29.0) (2026-11-11)


### Features

* **image-build:** take the CI registry host from the runner's robot ([#69](https://github.com/sessrumnir/shared-workflows/issues/69)) ([165e5f0](https://github.com/sessrumnir/shared-workflows/commit/165e5f00a745fd6c90c2095dffd7b586ab5665d5))

## [0.28.0](https://github.com/sessrumnir/shared-workflows/compare/v0.27.1...v0.28.0) (2026-11-10)


### Features

* **image-build:** hand main's images over through the CI registry ([#67](https://github.com/sessrumnir/shared-workflows/issues/67)) ([01c42db](https://github.com/sessrumnir/shared-workflows/commit/01c42db936ffdc32a5885bfc01b5fa8600d64f39))

## [0.27.1](https://github.com/sessrumnir/shared-workflows/compare/v0.27.0...v0.27.1) (2026-11-10)


### Bug Fixes

* **renovate:** drop the Molecule manager that kept the tag in the package name ([#61](https://github.com/sessrumnir/shared-workflows/issues/61)) ([27d7e04](https://github.com/sessrumnir/shared-workflows/commit/27d7e04b793fe5fbc3a8e12c64c8a6831f0ddd5a))

## [0.27.0](https://github.com/sessrumnir/shared-workflows/compare/v0.26.1...v0.27.0) (2026-11-09)


### Features

* **lint:** optional online external-link check with lychee ([#58](https://github.com/sessrumnir/shared-workflows/issues/58)) ([e8ef025](https://github.com/sessrumnir/shared-workflows/commit/e8ef0255576c017f2055525b95e4e73ed0ca3d12))
* lychee link check as a container action, opt-in in lint.yml ([#56](https://github.com/sessrumnir/shared-workflows/issues/56)) ([2d5d862](https://github.com/sessrumnir/shared-workflows/commit/2d5d86299bba9ed37892b44c0fc3666c3b0137c5))


### Bug Fixes

* validate the Renovate presets as repository config ([#54](https://github.com/sessrumnir/shared-workflows/issues/54)) ([82142e6](https://github.com/sessrumnir/shared-workflows/commit/82142e69545e17f1570a005071567b5fd3b7e90a))

## [0.26.1](https://github.com/sessrumnir/shared-workflows/compare/v0.26.0...v0.26.1) (2026-11-09)


### Bug Fixes

* pass images and collections between jobs through the Actions cache ([#52](https://github.com/sessrumnir/shared-workflows/issues/52)) ([b21f022](https://github.com/sessrumnir/shared-workflows/commit/b21f022868c1091de0cd405b0157594204d03beb))

## [0.26.0](https://github.com/sessrumnir/shared-workflows/compare/v0.25.1...v0.26.0) (2026-11-07)


### Features

* run zizmor online in its own lint job ([#46](https://github.com/sessrumnir/shared-workflows/issues/46)) ([313369c](https://github.com/sessrumnir/shared-workflows/commit/313369c6370395ecca0d80e158a38fb74af5f754))

## [0.25.1](https://github.com/sessrumnir/shared-workflows/compare/v0.25.0...v0.25.1) (2026-11-04)


### Bug Fixes

* run container job steps with bash ([#44](https://github.com/sessrumnir/shared-workflows/issues/44)) ([3da7bcc](https://github.com/sessrumnir/shared-workflows/commit/3da7bcc6ceddf36b054866435648698cb102d570))

## [0.25.0](https://github.com/sessrumnir/shared-workflows/compare/v0.24.0...v0.25.0) (2026-11-04)


### Features

* pr-title and image selection on JOBS_RUNNER, PRIVATE_RUNNER fallback ([#41](https://github.com/sessrumnir/shared-workflows/issues/41)) ([6d71ed0](https://github.com/sessrumnir/shared-workflows/commit/6d71ed06a0d96c4fa477bb640fc337e88e26cae6))

## [0.24.0](https://github.com/sessrumnir/shared-workflows/compare/v0.23.0...v0.24.0) (2026-11-04)


### Features

* **lint:** common checks as container actions, no Docker daemon needed ([#38](https://github.com/sessrumnir/shared-workflows/issues/38)) ([f9731b1](https://github.com/sessrumnir/shared-workflows/commit/f9731b19a14867de7ad84938d973f15dc54ad0c5))

## [0.23.0](https://github.com/sessrumnir/shared-workflows/compare/v0.22.0...v0.23.0) (2026-11-03)


### Features

* **image-build:** build pull requests on their own BuildKit ([#34](https://github.com/sessrumnir/shared-workflows/issues/34)) ([f72ce3e](https://github.com/sessrumnir/shared-workflows/commit/f72ce3ec036b1b6936e7988f529d32a5b90bcee7))

## [0.22.0](https://github.com/sessrumnir/shared-workflows/compare/v0.21.0...v0.22.0) (2026-10-31)


### Features

* **renovate:** track Molecule platform images pinned by version and digest ([#26](https://github.com/sessrumnir/shared-workflows/issues/26)) ([5c40db4](https://github.com/sessrumnir/shared-workflows/commit/5c40db419b4da7352a79143d4048469c750d483a))

## [0.21.0](https://github.com/sessrumnir/shared-workflows/compare/v0.20.0...v0.21.0) (2026-10-30)


### Documentation

* **readme:** the scans run our pinned Trivy image ([#24](https://github.com/sessrumnir/shared-workflows/issues/24)) ([d05e8c5](https://github.com/sessrumnir/shared-workflows/commit/d05e8c57b0f30a34ad21a281e507971863751cd7))

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
