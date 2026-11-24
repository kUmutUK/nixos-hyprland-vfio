# Releasing

This repository uses **git-cliff** for semantic version suggestions and release
notes. Releases are created from a tag or from the **Release** workflow's
manual-dispatch input; ordinary pushes and pull requests never publish a release.

## Published artifact immutability

A published tag and its source ZIP are a provenance-bound snapshot of the exact tagged commit. Do not rewrite or replace an existing release asset to add documentation or code merged after publication. Land corrections on `main` under `[Unreleased]`, keep the old release asset unchanged, and include the corrected tree in the next release after all validation gates pass. A semantic version is **single-use**: never delete and recreate, retarget, or recycle a published `vMAJOR.MINOR.PATCH` tag. If a tag or release is accidentally removed, publish the correction under the next unused version. Configure a GitHub repository ruleset for tag pattern `v*` that prevents tag deletion and updates; this is a repository setting and must be checked separately from the committed workflow. Record the GitHub release-asset API size and digest; state explicitly whether the ZIP was independently downloaded and re-hashed during review.

**Maintainer-attestation evidence rule:** set `target_host_validated=true` or `vm_xml_validated=true` only after the exact required tests have actually been completed for the source commit being released. Record the tested commit, date, scope, and result in the validation report. A successful Release workflow only proves that the input was accepted; it does not independently prove the host or guest test. Release #48 for v1.5.8 logged both inputs as true. The currently published v1.6.0 Release #52 log records `TARGET_HOST_VALIDATED=true` accepted for exact source `3c518e45d979db3234f7628ccbf3979a0057dcf2`; this is a maintainer declaration, but the supporting host transcript is not committed. Release #52 also supplied `vm_xml_validated=true`, but `vm-xml/win10.xml` was unchanged from v1.5.9 to v1.6.0, so the changed-XML gate did not trigger. Earlier same-version attempts #50 and #51 are superseded historical runs, not provenance for the current published tag. Preserve the evidence boundary: these inputs prove what the maintainer declared and what the workflow accepted, not independent CI or guest-boot results.

The dual-guest VM definitions (`vm-xml/win10.xml` and the `vm-xml/win11.xml` Windows 11 template) remain outside the ancestor-build release allowlist. The remaining gate requires real Windows and installed-NixOS guest boot tests, as well as libvirt/QEMU semantic validation, before this VM definition can enter the release allowlist. The 11 November 2026 owner-reported smoke test passed QEMU conversion, `virsh define --validate`, and one first start of a derived NixOS-only XML with the Windows `vda` disk omitted; it did not validate the unmodified dual-guest template or complete either real guest boot path. The Release workflow compares the whole `vm-xml/` directory with the previous stable version tag, so a change to either template triggers the same gate. When one changed, publication requires a separate `vm_xml_validated=true` checkbox on a manual Release dispatch from `main`, attesting that libvirt/QEMU semantic validation and real Windows plus installed-NixOS `vdb` guest boots were completed for that exact commit. Tag-triggered releases cannot use this exception. The general `target_host_validated` checkbox cannot substitute for the VM-specific attestation. Because the VM XML is also outside the ancestor-build allowlist, a post-build XML change independently remains subject to the generic full-system-build/target-host gate; a successful full-system build containing the exact XML change satisfies that build-path requirement but not the VM-specific guest tests.

## Release prerequisites

1. Merge the intended stable code into `main`.
2. Confirm that **Nix Flake Check** passed for the exact commit to be released.
3. Confirm that a successful **Full NixOS System Build** (manual dispatch, or
   the workflow's weekly scheduled run on `main`) exists on that commit or an
   ancestor of it.
4. If the full-system build is from an ancestor, the release workflow checks every later changed path against the **literal, exhaustive allowlist** below. The category descriptions are explanatory only: there are no wildcard rules or blanket exemptions for all documentation, CI files, or helper scripts.

   The nine superseded one-off archive snapshots and the retired Turkish release-history file are listed only to permit deletion. The workflow requires Git status `D` for all ten paths; editing or reintroducing any of them is rejected.

   **Exact release allowlist (literal paths only):**
   `.git-cliff.toml`,
   `RELEASING.md`,
   `README.md`,
   `INSTALLATION.md`,
   `KURULUM.md`,
   `DEGISIKLIK_GECMISI.md`,
   `CONTRIBUTING.md`,
   `CHANGELOG.md`,
   `DISCLAIMER.md`,
   `docs/REPAIR-AND-VALIDATION-REPORT.md`,
   `docs/UUID-AND-MACHINE-IDENTITY.md`,
   `docs/OPTISCALER.md`,
   `docs/OPTISCALER-MANAGER.md`,
   `docs/MAKO.md`,
   `docs/SERPANTINUM.md`,
   `docs/BTRFS-AND-KERNEL-MANAGEMENT.md`,
   `docs/archive/DEGISIKLIK_GECMISI.md`,
   `docs/archive/README.md`,
   `docs/archive/HISTORICAL-AUDITS.md`,
   `docs/archive/ANALYSIS-2026-10-05-ZIP3-SUPERSEDED.md`,
   `docs/archive/APPLIED-FIXES.md`,
   `docs/archive/FIX-REPORT-2026-10-13.md`,
   `docs/archive/INSTALL-SAFETY-FIXES-2026-10-12.md`,
   `docs/archive/NIXOS-HYPRLAND-VFIO-ANALYSIS.md`,
   `docs/archive/POST-FIX-VALIDATION-2026-10-12.md`,
   `docs/archive/REMAINING-ISSUES-AUDIT-2026-10-09.md`,
   `docs/archive/nixos-hyprland-vfio-analysis-v2-SUPERSEDED.md`,
   `docs/archive/nixos-hyprland-vfio-review-report.md`,
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
   `scripts/test-release-workflow-python.py`,
   `scripts/test-lsfg-vk-v2.py`,
   `scripts/prepare-vm-diagnostic.py`,
   `scripts/test-vm-diagnostic.py`,
   `scripts/test-vm-xml-paths.py`,
   `scripts/test-installer-rollback.sh`,
   `scripts/package-source-zip.sh`,
   `scripts/vfio-health.sh`,
   `scripts/test-vfio-health.sh`,
   `.pre-commit-config.yaml`,
   `scripts/test-backup-vm.sh`,
   `scripts/test-waybar-amdgpu.sh`,
   `scripts/test-host-profile.sh`,
   `scripts/test-automated-vm-backup.sh`,
   `scripts/test-benchmark-report.py`,
   `scripts/benchmark-capture.sh`,
   `scripts/benchmark-report.py`,
   `.github/renovate.json`,
   `.github/workflows/check.yml`,
   `.github/workflows/kernel-build.yml`,
   `.github/workflows/release.yml`,
   `.github/workflows/cache.yml`,
   `.github/workflows/flake-update.yml`,
   `.github/workflows/full-system-build.yml`,
   `docs/MIGRATION-GUIDE.md`,
   `docs/GAMING.md`,
   `.envrc`,
   `.gitignore`,
   `docs/AUDIT-2026-10-28-VM-XML-VFIO.md`,
   `nixos/hosts/.template/configuration.nix`,
   `nixos/hosts/.template/host-settings.nix`

   The nine superseded one-off archive reports listed above are included solely as deletion paths. The release workflow verifies that each has Git diff status `D`; editing or recreating one remains outside this exception.

   The list is intentionally limited to documentation, CI/release metadata, the canonical source-archive packaging/validation helper, standalone migration helpers, and offline tests that do not change the installed NixOS toplevel or selected kernel. The VM XML structural test is included because it is an offline regression test; the live `vm-xml/win10.xml` definition and the `vm-xml/win11.xml` template are deliberately excluded until libvirt/QEMU semantic validation and real Windows and NixOS guest boot tests are documented. A file is not eligible merely because it lives under `scripts/` or is labelled a test: each accepted path is named explicitly and reviewed against the runtime/build boundary.

   Any later change outside this exact list, including a documentation or test file not named above, blocks publication by default and requires a new full-system build unless the explicit manual-attestation path below is used. The `install.sh` installer intentionally remains outside the automatic ancestor-build allowlist: a post-build installer change is treated as a non-allowlisted change, not as a release-only change. A fresh successful full-system build always satisfies this path check; alternatively, a manual **Release** dispatch from `main` may accept it only with `target_host_validated=true` and the clean-install and target-host validation described below.

   For a manual **Release** dispatch from `main`, the workflow exposes a
   `target_host_validated` checkbox. This is a narrow maintainer attestation
   for post-build changes that have actually been deployed to and validated on
   the reference host. Select it only after the exact current source has been
   used for a clean installation, the host has booted successfully, and the
   Windows VM has completed a normal start/shutdown cycle with GPU handback and
   Hyprland recovery. This clean-install requirement explicitly includes the
   current `install.sh` whenever that file changed after the build baseline.
   The attestation can waive the remaining non-allowlisted post-build changed-path
   rejection, including an `install.sh` change, but it does **not** bypass
   exact-commit normal CI, the existence of a successful ancestor full-system
   build, version and tag validation, or release-artifact checks. Tag-triggered releases cannot use it. It also cannot waive the separate `vm_xml_validated` requirement when `vm-xml/win10.xml` changed. GitHub records this as a maintainer assertion; it does not independently verify physical hardware testing.
   The UUID identity guide above is documentation-only: it explains existing host storage identifiers and VM identity handling but does not alter either. It is included as one exact path, not as a wildcard documentation exemption. The two VM XML sync Python paths above are narrowly scoped migration-time helpers outside the NixOS flake/derivation graph and are covered by the dedicated mock-backed VM XML sync suite in normal CI. The VM diagnostic helper creates a separate temporary XML file and never edits the production input; its dedicated regression test covers libvirt's single-quoted `dumpxml` output. The VM XML path test and installer rollback test are offline regression harnesses. The `scripts/test-manual-vm-bootstrap.sh` and `scripts/test-installer-invariants.sh` paths are CI-only mock regression harnesses; they do not run host mutations or alter the NixOS system closure. NixOS modules/flake outputs/inputs and machine storage configuration (including `nixos/hosts/nixos/configuration.nix`, `nixos/flake.nix`, `nixos/flake.lock`, `nixos/hosts/nixos/hardware-configuration.nix`, and `nixos/mako-renderer.nix`), `vm-xml/win10.xml`, `install.sh`, runtime hooks, and other system-closure-affecting paths remain gated by a new full-system build.

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
