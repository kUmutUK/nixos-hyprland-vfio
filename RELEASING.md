# Releasing

This repository uses **git-cliff** for semantic version suggestions and release
notes. Releases are created from a tag or from the **Release** workflow's
manual-dispatch input; ordinary pushes and pull requests never publish a release.

## Release prerequisites

1. Merge the intended stable code into `main`.
2. Confirm that **Nix Flake Check** passed for the exact commit to be released.
3. Confirm that a successful **Full NixOS System Build (manual)** exists on
   that commit or an ancestor of it.
4. If the full-system build is from an ancestor, the release workflow verifies
   that every later changed path is explicitly allowlisted as release,
   documentation, or CI metadata: `.git-cliff.toml`, `RELEASING.md`, `README.md`,
   `DEGISIKLIK_GECMISI.md`, `CONTRIBUTING.md`, `CHANGELOG.md`, `docs/REPAIR-AND-VALIDATION-REPORT.md`,
   `scripts/test-documentation-integrity.py`, `.github/workflows/check.yml`, or
   `.github/workflows/release.yml`. Any later change to NixOS, VM, installer,
   runtime hooks, or other system-affecting source paths blocks publication and
   requires a new full-system build.
5. Review the release version and changelog before publishing.

This is intentional: documentation and release automation do not alter the
NixOS system derivation, but a successful evaluation-only CI run is not a
substitute for building the full NixOS system and selected RT-Bore-LTO kernel.
A release still does not claim that every machine has passed a physical
GPU/VFIO/VM lifecycle test.

## Publish a release

Open **Actions → Release → Run workflow**, select the `main` branch, and enter
a stable semantic version such as `v1.4.0`. The workflow validates the version,
checks the CI/build prerequisites, generates the notes, creates and pushes an
annotated tag, builds the canonical source ZIP, creates its SHA-256 manifest,
and publishes the GitHub Release.

Alternatively, a maintainer can create and push the annotated tag locally:

```bash
VERSION="v1.4.0"  # replace with the reviewed release version
git status --short
git tag -a "$VERSION" -m "Release $VERSION"
git push origin "$VERSION"
```

The tag must point to a commit reachable from `main`. The same checks run for
both the manual workflow and a pushed version tag.

## Version calculation

Install/run git-cliff without adding it to the NixOS system:

```bash
nix run nixpkgs#git-cliff -- --config .git-cliff.toml --bumped-version
```

The historical Turkish changelog ends at `1.3.8`, but that historical entry is
not a Git tag. The current workflow's first-release notes therefore come from
the curated `CHANGELOG.md` `[Unreleased]` section instead of treating the
entire repository history as one release. The first release version is entered
explicitly in the workflow. Once a version tag exists, git-cliff generates
subsequent notes from commits since the previous matching tag.

## What the release workflow publishes

- git-cliff release notes (curated `[Unreleased]` notes for the first release);
- a canonical source ZIP from `scripts/package-source-zip.sh`, excluding
  `.git/` and preserving tracked executable modes;
- a SHA-256 checksum file;
- a GitHub Release with the ZIP, checksum, and notes.

The automation never overwrites the hand-maintained `CHANGELOG.md`.

## Version rules

Release tags must use the stable `vMAJOR.MINOR.PATCH` form (for example,
`v1.4.0`). The `v` prefix is required, and numeric components must not contain
leading zeroes. The release workflow and git-cliff use the same rule.

- `feat:` → minor version.
- `fix:` and other changes not excluded by the bump rules → patch version.
- Conventional breaking changes (for example, `feat!:`) → major version.
- Documentation, style, test, chore, CI, and build-only commits do not bump the
  version by themselves.

The parser includes an `Other Changes` group so non-Conventional commits are
not silently omitted from release notes. Prefer Conventional Commit messages
for future commits to keep grouping and version suggestions predictable.
