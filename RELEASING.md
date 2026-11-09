# Releasing

This repository uses **git-cliff** for semantic version suggestions and release
notes. Releases are created from a tag or from the **Release** workflow's
manual-dispatch input; ordinary pushes and pull requests never publish a release.

## Release prerequisites

1. Merge the intended stable code into `main`.
2. Confirm that **Nix Flake Check** passed for the exact commit to be released.
3. Confirm that a successful **Full NixOS System Build (manual)** exists on
   that commit or an ancestor of it.
4. If the full-system build is from an ancestor, the release workflow checks every later changed path against the **literal, exhaustive allowlist** below. The category descriptions are explanatory only: there are no wildcard rules or blanket exemptions for all documentation, CI files, or helper scripts.

   **Exact release allowlist (literal paths only):**
   `.git-cliff.toml`,
   `RELEASING.md`,
   `README.md`,
   `INSTALLATION.md`,
   `DEGISIKLIK_GECMISI.md`,
   `CONTRIBUTING.md`,
   `CHANGELOG.md`,
   `docs/REPAIR-AND-VALIDATION-REPORT.md`,
   `docs/UUID-AND-MACHINE-IDENTITY.md`,
   `docs/OPTISCALER.md`,
   `docs/OPTISCALER-MANAGER.md`,
   `docs/MAKO.md`,
   `docs/archive/DEGISIKLIK_GECMISI.md`,
   `docs/archive/README.md`,
   `scripts/test-mako-renderer.py`,
   `scripts/optiscaler_manager.py`,
   `scripts/test-optiscaler-manager.py`,
   `scripts/sync-vm-xml.py`,
   `scripts/test-vm-xml-sync.py`,
   `scripts/test-manual-vm-bootstrap.sh`,
   `scripts/test-installer-invariants.sh`,
   `scripts/test-vfio-hook-driver-state.sh`,
   `scripts/test-documentation-integrity.py`,
   `scripts/test-lsfg-vk-v2.py`,
   `.github/workflows/check.yml`,
   `.github/workflows/kernel-build.yml`,
   `.github/workflows/release.yml`

   Any later change outside this exact list, including a documentation or test file not named above, blocks publication and requires a new full-system build.
The UUID identity guide above is documentation-only: it explains existing host storage identifiers and VM identity handling but does not alter either. It is included as one exact path, not as a wildcard documentation exemption. The two VM XML sync Python paths above are narrowly scoped migration-time helpers outside the NixOS flake/derivation graph and are covered by the dedicated mock-backed VM XML sync suite in normal CI. The `scripts/test-manual-vm-bootstrap.sh` and `scripts/test-installer-invariants.sh` paths are CI-only mock regression harnesses; they do not run host mutations or alter the NixOS system closure. NixOS modules/flake outputs/inputs and machine storage configuration (including `nixos/configuration.nix`, `nixos/flake.nix`, `nixos/flake.lock`, `nixos/hardware-configuration.nix`, and `nixos/mako-renderer.nix`), `vm-xml/win10.xml`, `install.sh`, runtime hooks, and other system-closure-affecting paths remain gated by a new full-system build.

5. Review the release version and changelog before publishing.

This is intentional: documentation and release automation do not alter the
NixOS system derivation, but a successful evaluation-only CI run is not a
substitute for building the full NixOS system and selected RT-Bore-LTO kernel.
A release still does not claim that every machine has passed a physical
GPU/VFIO/VM lifecycle test.

## Publish a release

Open **Actions → Release → Run workflow**, select the `main` branch, and enter
a **new, unused** stable semantic version. The input intentionally has no
preselected default; check the existing releases/tags before choosing a version.
The workflow rejects a requested tag that already exists and refuses a manual
release when the selected commit already carries another stable version tag.
It then validates the CI/build prerequisites and generates release notes from
the explicit previous-tag-to-HEAD commit range while setting the requested
release version. Before creating any tag, it requires the first release-note
heading to match `## <requested-tag> - YYYY-MM-DD`. It then creates the annotated
tag, builds the canonical source ZIP, creates its SHA-256 manifest, and publishes
the GitHub Release.

The history contains a legacy annotated `v1.4.3` tag at the same commit as the
published `v1.4.4` release; `v1.4.3` has no associated GitHub Release. That is a
historical tag anomaly, not the current release state. The current published
release is [v1.4.5](https://github.com/kUmutUK/nixos-hyprland-vfio/releases/tag/v1.4.5),
published by release run #17 on 5 November 2026. The workflow now prevents
additional manual version tags from being attached to an already-tagged commit.

Alternatively, a maintainer can create and push the annotated tag locally:

```bash
VERSION="vMAJOR.MINOR.PATCH"  # replace with a new, unused stable version
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
explicitly in the workflow. For a manual release, git-cliff receives the exact `<previous-tag>..HEAD`
range and `--tag <requested-version>`; a pushed tag uses `--current`. The
workflow checks the generated first heading against the requested version so
an older tag at the same commit cannot silently label a new release.

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
