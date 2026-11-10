# Releasing

This repository uses **git-cliff** for semantic version suggestions and release
notes. Releases are created from a tag or from the **Release** workflow's
manual-dispatch input; ordinary pushes and pull requests never publish a release.

## Published artifact immutability

A published tag and its source ZIP are a provenance-bound snapshot of the exact tagged commit. Do not rewrite or replace an existing release asset to add documentation or code merged after publication. Land corrections on `main` under `[Unreleased]`, keep the old release asset unchanged, and include the corrected tree in the next release after all validation gates pass. Record the GitHub release-asset API size and digest; state explicitly whether the ZIP was independently downloaded and re-hashed during review.

The dual-guest VM definition `vm-xml/win10.xml` remains outside the ancestor-build release allowlist until libvirt/QEMU semantic validation and real Windows and installed-NixOS guest boot tests are documented. The 11 November 2026 owner-reported smoke test passed QEMU conversion, virsh define --validate, and one first start of a derived NixOS-only XML with the Windows vda disk omitted; it does not validate the unmodified dual-guest template or satisfy the real Windows and installed-NixOS guest boot requirements.

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
   `DISCLAIMER.md`,
   `docs/REPAIR-AND-VALIDATION-REPORT.md`,
   `docs/UUID-AND-MACHINE-IDENTITY.md`,
   `docs/OPTISCALER.md`,
   `docs/OPTISCALER-MANAGER.md`,
   `docs/MAKO.md`,
   `docs/archive/DEGISIKLIK_GECMISI.md`,
   `docs/archive/README.md`,
   `docs/archive/HISTORICAL-AUDITS.md`,
   `scripts/check-home-snapper-layout.py`,
   `scripts/test-home-snapper-layout.py`,
   `scripts/check-vm-iso-paths.py`,
   `scripts/test-vm-iso-paths.py`,
   `scripts/test-vm-xml.py`,
   `scripts/test-vm-xml-structure.py`,
   `scripts/extract-embedded-scripts.py`,
   `scripts/test-extract-embedded-scripts.py`,
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
   `scripts/prepare-vm-diagnostic.py`,
   `scripts/test-vm-diagnostic.py`,
   `scripts/test-vm-xml-paths.py`,
   `scripts/test-installer-rollback.sh`,
   `.github/workflows/check.yml`,
   `.github/workflows/kernel-build.yml`,
   `.github/workflows/release.yml`

   The list is intentionally limited to documentation, CI/release metadata, standalone migration helpers, and offline tests that do not change the installed NixOS toplevel or selected kernel. The VM XML structural test is included because it is an offline regression test; the live `vm-xml/win10.xml` definition is deliberately excluded until libvirt/QEMU semantic validation and real Windows and NixOS guest boot tests are documented. A file is not eligible merely because it lives under `scripts/` or is labelled a test: each accepted path is named explicitly and reviewed against the runtime/build boundary.

   Any later change outside this exact list, including a documentation or test file not named above, blocks publication by default and requires a new full-system build. In particular, changes to `install.sh` remain gated by a new full-system build and are intentionally excluded from this ancestor-build allowlist.

   For a manual **Release** dispatch from `main`, the workflow also exposes a
   `target_host_validated` checkbox. This is a narrow maintainer attestation
   for post-build changes that have actually been deployed to and validated on
   the reference host. Select it only after the current source has been applied,
   the host has booted successfully, and the Windows VM has completed a normal
   start/shutdown cycle with GPU handback and Hyprland recovery. A clean install
   is suitable evidence when it used the current source. The attestation bypasses
   only the post-build changed-path rejection; it does **not** bypass exact-commit
   normal CI, the existence of a successful ancestor full-system build, version
   and tag validation, or release-artifact checks. Tag-triggered releases cannot
   use it. GitHub records this as a maintainer assertion; it does not independently
   verify physical hardware testing.
The UUID identity guide above is documentation-only: it explains existing host storage identifiers and VM identity handling but does not alter either. It is included as one exact path, not as a wildcard documentation exemption. The two VM XML sync Python paths above are narrowly scoped migration-time helpers outside the NixOS flake/derivation graph and are covered by the dedicated mock-backed VM XML sync suite in normal CI. The VM diagnostic helper creates a separate temporary XML file and never edits the production input; its dedicated regression test covers libvirt's single-quoted `dumpxml` output. The VM XML path test and installer rollback test are offline regression harnesses. The `scripts/test-manual-vm-bootstrap.sh` and `scripts/test-installer-invariants.sh` paths are CI-only mock regression harnesses; they do not run host mutations or alter the NixOS system closure. NixOS modules/flake outputs/inputs and machine storage configuration (including `nixos/configuration.nix`, `nixos/flake.nix`, `nixos/flake.lock`, `nixos/hardware-configuration.nix`, and `nixos/mako-renderer.nix`), `vm-xml/win10.xml`, `install.sh`, runtime hooks, and other system-closure-affecting paths remain gated by a new full-system build.

5. Review the release version and changelog before publishing.

This is intentional: documentation and release automation do not alter the
NixOS system derivation, and a successful evaluation-only CI run is not a
substitute for a full NixOS system/kernel build. The post-build hardware
attestation is an explicit operator override for the reference machine; it
does not create a GitHub full-system build result or establish compatibility
for other hardware. A release still does not claim that every machine has
passed a physical GPU/VFIO/VM lifecycle test.

## Publish a release

Open **Actions → Release → Run workflow**, select the `main` branch, and enter
a **new, unused** stable semantic version. The input intentionally has no
preselected default; check the existing releases/tags before choosing a version.
The workflow rejects a requested tag that already exists and refuses a manual
release when the selected commit already carries another stable version tag.
It then validates the CI/build prerequisites and generates release notes from
the explicit previous-tag-to-HEAD commit range while setting the requested
release version. Before creating any tag, it requires the first release-note
heading to match `## <requested-tag> - YYYY-MM-DD`. It then builds the canonical
source ZIP and its SHA-256 manifest, creates the annotated tag, and finally
publishes the GitHub Release.

The history contains a legacy annotated `v1.4.3` tag at the same commit as the
published `v1.4.4` release. The `v1.4.3` tag originally had no associated
GitHub Release, but its release entry was restored and published on 10 November
2026 at 11:52:57 UTC (Release ID `440298465`): [v1.4.3](https://github.com/kUmutUK/nixos-hyprland-vfio/releases/tag/v1.4.3).
This remains a historical tag/release-note anomaly, not an absent current
release. The older v1.4.4 release description still carries its incorrect
v1.4.3 heading.

The current published version is intentionally not copied into this guide. Use
[GitHub Releases](https://github.com/kUmutUK/nixos-hyprland-vfio/releases/latest)
to resolve the latest published release. This link stays current when a new
version is published, so a release does not require a follow-up documentation
commit just to replace an old version number. You still choose the exact version
in the manual **Release** workflow input; the workflow validates the stable
version format and release-note heading before creating the tag and publishing
the canonical source ZIP.

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
