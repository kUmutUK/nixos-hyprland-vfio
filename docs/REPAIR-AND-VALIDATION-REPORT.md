# Repair and validation report — updated 2026-10-30

> **Delivery-scope note:** This report is part of the tracked source tree. The dated “patch-only ZIP” notes below are historical. For a canonical full-source ZIP, use `scripts/package-source-zip.sh` or the CI-uploaded `nixos-hyprland-vfio-source` artifact for the exact commit. The helper verifies tracked-file completeness, excludes `.git/`, preserves executable bits, and makes the finished artifact readable from shared output directories.
## Supplied ZIP provenance and canonical packaging — 2026-10-30

The measurements below were transcribed from supplied audit text. The ZIP bytes were not attached to this repository-editing session, so the byte count, SHA-256, entry count, `.git` contents, and ZIP metadata have not been independently remeasured here. This is a provenance record for the reported archives, **not** a current canonical-artifact index. The dated sections are grouped by subject and source snapshot rather than strict chronological order. The described archives are reported as noncanonical and must not be used as installation sources. For a canonical archive of a particular commit, run `scripts/package-source-zip.sh` from a clean checkout or download the CI artifact built for that exact commit and verify its accompanying `.sha256` manifest.

| Archive | Recorded metadata from supplied audit | Disposition |
|---|---|---|
| ZIP described in the supplied sixth audit (claimed HEAD `e309173582763d152d8ab6552f16a277ed297f6e`) | 572,689 bytes; SHA-256 `f11b4cac497055bd5bfdadc93ad0bece1593f68f4af9481e26419cec80ed1ef1`; 116 entries (91 files and 25 directories: 62 project files plus 29 `.git` files); 45 `.git` entries including directories; the embedded Git HEAD reportedly points to `e309173582763d152d8ab6552f16a277ed297f6e` on `refs/heads/main`; SOURCE_REVISION reportedly contains the unexpanded Git export-substitution placeholder; all 116 entries reportedly have no Unix mode metadata (`external_attr=0x00000000`); single timestamp 2026-10-30 14:10:24. The supplied audit says tracked content matches HEAD and only permission metadata differs. | Sixth-audit measurements transcribed from supplied text only. The ZIP bytes were not attached; SHA, entry list, permission metadata, timestamp and claimed content equality were not independently remeasured. Reported noncanonical; not an approved installation artifact. |
| ZIP described in the supplied fifth audit (claimed HEAD `8b8cf29a1d21f2100234814b80fc4f5671e2b74a`) | 570,101 bytes; SHA-256 `dee424e555ca173773388101d407a6699d668eda6fe348a5aa75962ebae4c2be`; 116 entries (91 files and 25 directories: 62 project files plus 29 `.git` files); 45 `.git` entries including directories; `SOURCE_REVISION` contains the unexpanded Git export-substitution marker; all 116 entries reportedly have `external_attr=0x00000000`; single timestamp 2026-10-30 12:13:00. | Supplied fifth-audit measurements only; ZIP bytes not attached and not independently remeasured. Reported noncanonical; not an approved installation artifact. |
| ZIP described in the supplied third audit (embedded HEAD `b413e6df50f64ab16d1694d9b19dae97a078f56c`) | 565,429 bytes; SHA-256 `89fab35d7ecd18bb2b39bb74cbf7b799f8d76bc4c9d59970e7e94060f82dc374`; 116 entries (62 project files, 29 `.git` files, 25 directory entries); 45 `.git` entries including directories; `.git/HEAD` contains `ref: refs/heads/main`, with `refs/heads/main` pointing to commit `b413e6df50f64ab16d1694d9b19dae97a078f56c`; `SOURCE_REVISION` contains the unexpanded Git export-substitution placeholder; the `install.sh` entry reports `create_system=0` and `external_attr=0x00000000`. | Supplied measurements only; not independently remeasured because the ZIP bytes were not attached; reported noncanonical. Do not use this archive for installation. |
| ZIP described in the supplied 2026-10-30 audit | 561,513 bytes; SHA-256 `c905b5036d04bf1ec6c0b2929cba7bce4eb5405df9a6c4886ef677e65c829b8`; 116 entries (62 project files, 29 `.git` files, 25 directory entries); 45 `.git` entries including directories; `.git/HEAD` contains `ref: refs/heads/main`, with `refs/heads/main` pointing to commit `92ca0121917d63f4c9f87bf2a4adcacfd5c8bb56`; `SOURCE_REVISION` remains the literal `$Format:%H$`; the `install.sh` entry reports `create_system=0` and `external_attr=0x00000000`. | Supplied measurements only; reported noncanonical; not independently remeasured in this session. Do not use this archive for installation. |
| Earlier ZIP from the 2026-10-28 audit | 494,995 bytes; SHA-256 prefix `00805455…`; 105 entries including 45 `.git` entries; embedded commit `cdfd3d8d5008e4b7405ce2433e29b8a0e34ffebe`. | Historical, distinct from the 561,513-byte archive above. |
| Historical ZIP(2) | 490,249 bytes; SHA-256 `505ab8bcadc4f7ad0459194e561d27e2d8f65627e859df35a8af7c385707046f`; 105 entries including 45 `.git` entries; embedded commit `8487ea4cd82e75ede71bcad7eaada6438c40adb0`. | Historical submitted archive. |
| Historical ZIP(10) | 475,881 bytes; SHA-256 `9b107f6a3579224944211349d46377e96ff48e26eb4bfa548c30276a86efbe6c`. | Historical; remaining metadata are recorded in its dated section below. |
| Historical ZIP(9) | 475,483 bytes; SHA-256 `931c5d75f8af22e9de5ebfa64341a4d1777a47e2a0e6ad882ba65f1b4bd13f6c`; 102 entries including 45 `.git` entries. | Historical submitted archive. |
| Historical ZIP(1) | 456,770 bytes; SHA-256 `69168ea0d90285a879baf08dfb7be0425db2cedb6539344d4ab603caf1f36094`; 101 entries including 45 `.git` entries; embedded commit `8c6cf467038bacbc8cba46a0c9dcfe54e13c467d`. | Historical; distinct from ZIP(9) and ZIP(10). |
| Earlier archive from the 2026-10-27 audit | 436,212 bytes; SHA-256 prefix `3f0f0ed5`; 96 entries; embedded commit `a631d195891ff6da74ae727ac3c531ffc77c50ed`. | Historical; separate attachment. |
| Another older archive | 493,030 bytes; SHA-256 prefix `45e3edaa…`; embedded revision prefix `c395611f…`. | Historical; not the 494,995-byte archive above. |

The repository's `scripts/package-source-zip.sh` remains the canonical packager. It packages committed `HEAD`, checks archive integrity, tracked-file completeness, the embedded 40-character revision, absence of `.git/`, and the exact expected executable-mode set. CI uploads the validated ZIP and a relative-path `.sha256` manifest after required checks pass. Do not hard-code a digest for a future artifact in this report; use the manifest generated alongside that exact commit.

## Follow-up verification — 2026-10-30

- **K-1 scope clarification:** `install.sh` resolves the source revision from `git rev-parse HEAD` and checks `git status` whenever `.git` is present; it reads `SOURCE_REVISION` only outside a Git work tree. Therefore, if the fifth audit's ZIP measurements are correct, the unmodified extraction is noncanonical and the lost executable modes make the Git work tree dirty. Restoring the nine tracked executable modes could make the Git-based provenance gate pass, because the included Git metadata supplies `HEAD`; removing Git metadata instead exposes the unexpanded export-substitution marker, which fails the 40-character check. The statement that the installer cannot run by any route is too absolute. This recovery possibility does not make the archive canonical or suitable for distribution; use the validated CI artifact.

- **Y-1 reassessment:** The GitHub record for commit `b413e6df50f64ab16d1694d9b19dae97a078f56c` lists `scripts/test-installer-invariants.sh` as a changed path without a textual patch, while that commit's CHANGELOG says its executable bit was restored. This is consistent with a mode-only change in `b413e6df`; the nine-file `100755` inventory recorded for that tree can therefore be post-restoration. The supplied fifth audit does not establish a contradiction between those records. Calling the `b413e6df` tree “pre-correction” is unsupported without a separate measurement of its parent tree's file modes. The earlier eight-file count refers to a distinct, older snapshot.

## Follow-up audit — source ZIP handling and partition-count verification — 2026-10-28

**GitHub `main` immediately before this follow-up:** [`0d748ed82244a51ce49f53e9fc458df16eca4a38`](https://github.com/kUmutUK/nixos-hyprland-vfio/commit/0d748ed82244a51ce49f53e9fc458df16eca4a38). The recursive tree has 55 tracked file blobs and eight executable-mode files (`100755`); the executable list remains `install.sh`, `nixos/hooks/qemu`, and the six packaging/test/verifier scripts named in the prior snapshot below.

### Findings confirmed against source

- **The canonical source-archive helper is already defensive.** `.gitattributes` marks `SOURCE_REVISION` as `export-subst`; `git archive` expands the checkout placeholder to the packaged commit, omits `.git/`, and preserves Git executable modes. `scripts/package-source-zip.sh` verifies the 40-character revision, exact tracked-file inventory, ZIP integrity, and executable bits. CI invokes this helper and uploads its validated ZIP only after required checks pass.
- **The source-tree value `$Format:%H$` is intentional, not a bad committed revision.** It is the expected placeholder in a normal Git checkout. It is invalid only when a distributor bypasses canonical packaging and ships a manually compressed working directory.
- **The exact ZIP described in the submitted audit was not attached to this turn.** Its reported size, SHA-256, `.git/` entries, and extracted permissions therefore could not be recalculated independently here. The source code proves how the canonical helper behaves, but not the metadata of an unavailable ZIP. Use the helper or the CI artifact associated with the exact commit; do not distribute the manually compressed archive.
- **A real documentation/verification gap was found in `INSTALLATION.md`.** The text claimed that exactly three partitions are verified, while the snippet only checked the three expected device nodes and their parent-disk identity. The guide now counts `lsblk` partition entries and fails closed unless the total is exactly three. The existing installer-invariant test suite now exercises the guard for three, two, and four partitions.
- **The report cannot safely pin the ZIP's digest inside itself.** Since the tracked report is included in the source ZIP, changing a digest recorded here would change the ZIP being hashed. CI now generates `nixos-hyprland-vfio-source.zip.sha256` using the relative archive filename and uploads the manifest beside the ZIP, so each artifact carries a digest for its exact bytes.
- **Hardware-specific configuration remains a deployment condition, not a proven source defect.** The committed UUID/PARTUUID, LUKS, EFI, swap, and Btrfs settings must be adapted for a different target machine as the guide states. This review did not run a physical VFIO transfer/recovery test or a full-system build for the new commit; neither is claimed as verified.

The remediation changes the install guide, its regression coverage, README packaging instructions, CI artifact metadata, and this report. GitHub Actions is the validation gate for the pushed commit; results must be read from that exact commit's run rather than inferred from earlier runs.


## Prior source-tree measurement — superseded audit snapshot — 2026-10-28

The pre-update GitHub `main` HEAD was [`1b652cb663feb7a60c62086b51f97a7d7611b804`](https://github.com/kUmutUK/nixos-hyprland-vfio/commit/1b652cb663feb7a60c62086b51f97a7d7611b804). Its recursive Git tree contains **55 tracked file blobs** and **8 files stored with mode `100755`**: `install.sh`, `nixos/hooks/qemu`, `scripts/package-source-zip.sh`, `scripts/test-installer-invariants.sh`, `scripts/test-manual-vm-bootstrap.sh`, `scripts/test-source-revision.sh`, `scripts/test-vfio-hook-driver-state.sh`, and `scripts/verify-source-revision.sh`. This count is from the Git tree rather than from a ZIP extraction.

`SOURCE_REVISION` containing `$Format:%H$` in the checked-out Git source is intentional: `.gitattributes` declares `SOURCE_REVISION export-subst`, so `git archive` substitutes the packaged commit SHA into the ZIP. `scripts/package-source-zip.sh` packages committed `HEAD`, excludes `.git/`, compares the archive contents to the tracked tree, checks all executable bits, verifies ZIP integrity, and requires the embedded revision to equal the commit being packaged. Therefore, the reported `.git/` and lost-permissions issue is a defect in the manually created ZIP, not in the current canonical packaging script. The submitted ZIP bytes were not attached to this update, so its exact checksum and extracted metadata could not be independently recalculated here. Use the canonical script or a successful CI artifact for the exact commit; do not distribute the manually compressed archive.

That earlier update affected documentation and a CI comment only, so the 55/8 source-tree counts remained unchanged at that point.

## Earlier main/source baseline recorded during prior remediation — 2026-10-28

**GitHub `main` at the start of this remediation:** [`cdfd3d8d5008e4b7405ce2433e29b8a0e34ffebe`](https://github.com/kUmutUK/nixos-hyprland-vfio/commit/cdfd3d8d5008e4b7405ce2433e29b8a0e34ffebe).

**Last source HEAD with an explicitly cited successful standard CI run:** [`b3cd4b5924ebf85a5818b23e0f4cf8b9d479b336`](https://github.com/kUmutUK/nixos-hyprland-vfio/commit/b3cd4b5924ebf85a5818b23e0f4cf8b9d479b336). This is historical CI evidence for that exact SHA, not a validation result for the source revision at the start of this remediation or its descendant commits.

- The standard [Nix Flake Check run #983](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/40673243300) passed for the exact CI-validated source HEAD `b3cd4b5924ebf85a5818b23e0f4cf8b9d479b336`. Required checks include canonical ZIP validation, Bash/Python and VM regressions, ShellCheck, Nix flake evaluation, generated Hyprland Lua syntax, the selected LSFG-VK v1 package build, Statix, Deadnix, and a clean `flake.lock`. This result must not be presented as a run against the starting commit `cdfd3d8d` or this remediation commit.
- The complete NixOS toplevel including RT-Bore-LTO built successfully in [manual run #40571665471](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/40571665471) at commit `6e831df6dc26b08802da0fe69fc661d9780de082`. Later documentation-only commits did not change the `nixos/**` tree in that historical interval. This is not a claim that a full-system build ran for the current remediation.
- **User-supplied measurements for the ZIP under review before this remediation:** size **494,995 bytes**; SHA-256 prefix **`00805455…`**; **105 ZIP entries**, including **45 entries under `.git/`**; embedded Git `HEAD` **`cdfd3d8d5008e4b7405ce2433e29b8a0e34ffebe`**. The ZIP bytes were not attached to this editing session, so its size, digest, entries, and extracted permissions were not independently recalculated here; these values are recorded from the supplied audit.
- The previously documented **493,030-byte / `45e3edaa…` / `c395611f…`** archive describes a different, older ZIP and must not be confused with the file above.
- The packaging source itself already uses `git archive`, excludes `.git/`, compares archived files with the committed tree, validates tracked executable bits, and checks ZIP integrity. The reported executable-mode defect is a delivery defect in the manually compressed ZIP, not a defect in Git's tracked `100755` modes or the canonical helper. This remediation additionally validates that a canonical ZIP embeds the exact commit it packages, so the same commit can be checked after a no-`.git` archive is extracted.
- Rechecked the PCI slot-boundary guard: `scripts/pci-address.sh` and `scripts/sync-vm-xml.py` restrict slot addresses to `00`–`1f`; tests accept `1f` and reject `20`/ `ff`. SSH/local-password-hash behavior remains consistent with configuration and tests.



### Repository ruleset status

On 2026-10-28, the default-branch ruleset named `gpt` (`25819380`) was updated and its `rules` array is now empty. Therefore, this ruleset currently enforces no branch restrictions. The legacy branch-protection status-check enforcement also reports `off` with no required contexts. This matches the current repository settings; no request to re-enable a required-status-check rule is implied here.

**Scope boundary:** successful CI and a full-system build do not prove physical VFIO GPU handoff, Windows VM lifecycle, or Hyprland display recovery. Those remain target-hardware tests.

## Audit remediation — 2026-10-28

- Source revision is now pinned across clean install, README Path B, and `install.sh`. All routes record `/etc/nixos/.source-revision`; post-reboot VM preparation stops if the marker is missing or malformed, the checkout is at another commit, or the checkout is dirty. Canonical source ZIPs embed the exact commit via `SOURCE_REVISION`/Git `export-subst`, and the package helper validates it.
- Closed the VFIO service-state race: a unit captured inactive is queried again before allowing GPU handoff. If it became active/transitional, the hook attempts to stop it and confirms it is inactive; query failures and unknown states abort handoff. Mocked regression coverage exercises this race.
- The manual VM-bootstrap regression fixture now initializes a real clean temporary Git repository and writes a matching source-revision marker, so its existing missing-ISO, partial-disk, concurrent-XML, and successful-bootstrap cases run through the mandatory source verifier.
- Hardware UUID/PARTUUID, PCI BDF, and USB IDs remain machine-specific template values as documented. They are not changed to generic guesses; validating these values on the target machine remains a deployment prerequisite.
- Corrected `install.sh` and its regression test so `/etc/nixos/hashedPassword` is described as the local `localhost` account password hash. The current SSH configuration remains public-key-only; this hash does not enable SSH password authentication.
- The source ZIP helper now sets the published ZIP to mode `0644`. README and CONTRIBUTING validation instructions include the package helper and installer-lock checks, and the README tree lists both lock scripts.
- Current-state notes in `DEGISIKLIK_GECMISI.md` now describe the key-only SSH policy and the canonical ZIP helper. The 2026-10-16 section below is historical and must not be treated as current configuration guidance.
- Historical validation recorded for extracted source snapshot `8487ea4cd82e75ede71bcad7eaada6438c40adb0`: Bash syntax checks passed; the installer-lock, installer-invariants, installer-rollback, and VFIO driver-state tests passed; Python compilation, embedded-script extraction, LSFG-VK config, VM ISO-path tests (8 tests), VM XML invariants, JSON lock parsing, and XML parsing passed. For that older snapshot, the canonical package helper produced 51 tracked source files with `.git/` excluded, two tracked executable files encoded as `0755`, and the final ZIP file mode set to `0644`. Those are historical snapshot counts, not measurements of current `main` (55 tracked files and 8 executable files).
- Historical isolated validation of source snapshot `8487ea4cd82e75ede71bcad7eaada6438c40adb0` (2026-10-28; not the `c395611f` archive baseline): `python3 scripts/test-vm-xml-sync.py` passed independently (about 12 seconds); `bash scripts/test-manual-vm-bootstrap.sh` passed independently and also passed with stdout redirected (about 10 seconds). A separate aggregate invocation exceeded its outer command time limit, but no assertion failure was reproduced and the cause was not established; record that aggregate run as inconclusive rather than a confirmed test failure. Nix, ShellCheck, Statix, and Deadnix were unavailable in the local runner, so no full NixOS/RT-Bore-LTO build or physical VFIO/VM lifecycle validation is claimed.

### Historical submitted archive audit: `nixos-hyprland-vfio(2).zip` — 2026-10-28

This section preserves the exact measurements of a separate earlier ZIP inspected by a previous 2026-10-28 audit. It is not the latest archive described in the report opening. The older ZIP(1), ZIP(9), and ZIP(10) notes below are also historical; none of these measurements should be substituted for the latest archive metadata.

- Archive size: **490,249 bytes**; SHA-256: `505ab8bcadc4f7ad0459194e561d27e2d8f65627e859df35a8af7c385707046f`.
- The ZIP has **105 entries** (80 files and 25 directories), including **45 `.git/` entries** (29 files and 16 directories). The embedded Git `HEAD` and `origin/main` point to commit `8487ea4cd82e75ede71bcad7eaada6438c40adb0`.
- Its 51 tracked project files match that source snapshot. The discrepancy is packaging metadata: the ZIP entries do not carry Unix permission bits, and the extracted `install.sh` and `scripts/package-source-zip.sh` are mode `0644` although Git tracks both as `100755`. This can make the documented `./install.sh` invocation fail with a permission error after extraction.
- **Do not distribute this manually compressed archive.** This is not a tracked source-code defect: `scripts/package-source-zip.sh` and the CI workflow already create and validate the canonical archive using `git archive`, exclude `.git/`, and verify executable bits. For this audit, the canonical helper generated and validated a replacement with **51 tracked files**, no `.git/` entries, both executable files encoded as `0755`, and the ZIP file itself mode `0644`. There is no reason to change the installer content or Git modes for this packaging-only issue.
- The independent reruns listed in the audit remediation section above supersede the earlier timeout-only note for these two tests. The aggregate-run timing observation remains inconclusive, not a confirmed test failure.

## Historical repository validation — 2026-10-27

**Historical snapshot checked before the prior report-only update:** GitHub `main` pointed to [`2fac8309345355f2fac5c54591c5c8fe2972787f`](https://github.com/kUmutUK/nixos-hyprland-vfio/commit/2fac8309345355f2fac5c54591c5c8fe2972787f). The tracked `install.sh` mode is `100755`.

**Standard CI:** [GitHub Actions run #40566306710](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/40566306710) completed successfully for that exact SHA. The run passed canonical source ZIP creation/validation, XML and VM invariant tests, ShellCheck, the Nix flake evaluation step, the selected LSFG-VK package build, Statix, Deadnix, and upload of the validated archive.

**Verified canonical artifact for that snapshot:** the workflow uploaded `nixos-hyprland-vfio-source` (223,842 bytes; artifact digest `sha256:e4a367a1f00152ccb3569d672d9839921632c4b271f78b97f3800ef447e3ed78`). GitHub listed its expiration as **2026-11-10 19:09:51 UTC**. It was generated from the exact SHA above; it is not the same file as any manually compressed ZIP discussed below. The artifact is temporary, so use a new successful CI artifact for the exact commit being distributed.

**Verification boundaries:** the standard workflow runs `nix flake check --no-build`; that evaluates the flake but does not build the complete NixOS system. The separate full-system build workflow is manually dispatched. A successful full-system build for the snapshot above was not established by the standard CI result. Physical GPU passthrough and VM/Hyprland lifecycle behavior must likewise not be inferred from CI.

### Historical submitted archive audit: `nixos-hyprland-vfio(10).zip`

The previously submitted ZIP(10) audit reported:

- File size: **475,881 bytes**.
- SHA-256: `9b107f6a3579224944211349d46377e96ff48e26eb4bfa548c30276a86efbe6c`.
- Embedded commit: `19c87b8f22b92e47d9489be6994808be74eeefdc`.
- Entries under `nixos-hyprland-vfio/.git/`: **45**.
- Extracted `install.sh` mode: `0644`, although the tracked Git mode is `100755`.
- The submitted audit says all **48 tracked files** match the embedded commit.

**Verification boundary:** the ZIP(10) bytes were not attached to this workspace, so its byte count, hash, entry list, extracted mode, and 48-file content comparison were not independently recomputed here. The measurements above are retained as a record of the submitted audit, not as fresh measurements of the current repository.

**Delivery finding:** accepting the submitted measurements as accurate, ZIP(10) is a noncanonical delivery archive. Do not distribute that archive. The repository workflow already creates a canonical ZIP with `git archive`, rejects `.git/` entries, checks that the archive preserves `install.sh`'s Unix executable bit, and uploads the validated ZIP. This packaging defect does not justify changing the tracked installer content or its Git mode.

### Historical delivery audit: `nixos-hyprland-vfio(9).zip`

The earlier ZIP(9) audit reported the following measurements for `nixos-hyprland-vfio(9).zip`; these remain historical and do not describe ZIP(10):

- File size: **475,483 bytes**.
- SHA-256: `931c5d75f8af22e9de5ebfa64341a4d1777a47e2a0e6ad882ba65f1b4bd13f6c`.
- ZIP central-directory entry count: **102**.
- Entries under `nixos-hyprland-vfio/.git/`: **45** (29 file entries and 16 directory entries).
- Embedded commit reported by the audit: `d1e6c979aa25e8908b40dab12e5055a5d87900c7`.
- Extracted `install.sh` mode reported by the audit: `0644`; the Git tree at that commit records `install.sh` as `100755`.

**Verification boundary:** the ZIP(9) bytes were not available in this workspace, so the size, SHA-256, entry count, embedded metadata and extracted mode above are transcribed from the submitted audit rather than independently recomputed in this update. I independently checked the corresponding GitHub branch, tracked file mode, README instructions, workflow, and CI result.

**Delivery finding (based on the submitted ZIP audit):** the ZIP reportedly includes `.git/` metadata and does not preserve `install.sh`'s executable mode. Do not distribute that ad-hoc archive. This is a packaging/delivery defect, not a defect in the tracked installer file: the Git tree records mode `100755`, and `README.md` documents creating the source ZIP with `git archive`.

**Independent source/CI cross-check:** GitHub `main` was at `d1e6c979aa25e8908b40dab12e5055a5d87900c7` during this check. The current `.github/workflows/check.yml` creates a ZIP with `git archive`, rejects `.git/` entries, checks that the ZIP retains the Unix executable bit on `install.sh`, and uploads the validated file as the `nixos-hyprland-vfio-source` workflow artifact. GitHub Actions run [#969](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/40559643957) for that exact source commit completed successfully, including the archive validation and upload steps. This validates the repository's canonical packaging path for that commit; it does **not** validate the separate ZIP(9) bytes themselves.

**Historical report correction:** when the ZIP(9) section was written, older ZIP(1) measurements had been incorrectly presented as current. That earlier correction remains part of the history; ZIP(9) is now also a historical record and must not be attributed to ZIP(10).

### Cross-checks for the ZIP(9) audit

The submitted audit reports that Bash syntax checks, Python compilation, JSON/TOML/XML parsing, VM XML synchronization, installer invariants, and rollback tests passed. Its statement that the VM XML synchronization test passed with a longer timeout is recorded as a supplied result; the ZIP and per-test logs were not available here to repeat those exact checks against the extracted ZIP(9) snapshot.

Separately, the independently inspected GitHub Actions run #969 for source commit `d1e6c979aa25e8908b40dab12e5055a5d87900c7` succeeded. Its successful steps include XML and VM invariants, the manual VM bootstrap retry test, installer invariants and rollback, ShellCheck, VFIO hook regression tests, embedded-script checks, `nix flake check` (evaluation only), the selected LSFG-VK v1 package build, Statix, Deadnix, the lock-file guard, and canonical ZIP creation/validation/upload. This workflow does not perform a full NixOS system build or a physical GPU passthrough / VM shutdown-and-display-recovery test.

### Historical regression checks for the earlier ZIP(1) snapshot

The following repository regression tests were recorded for the earlier ZIP(1) snapshot, with `install.sh` restored to its tracked executable mode for source-level testing. They are historical results and are not claimed as reruns against ZIP(9):

- `scripts/test-installer-invariants.sh`
- `scripts/test-installer-rollback.sh`
- `scripts/test-vfio-hook-driver-state.sh`
- `scripts/test-vm-xml.py`
- `scripts/test-vm-xml-sync.py`
- `scripts/test-vm-diagnostic.py`
- `scripts/test-lsfg-v1-config.py`
- `scripts/test-extract-embedded-scripts.py`
- `scripts/test-vm-iso-paths.py`

Follow-up checks also passed: `bash -n` for `install.sh`, the QEMU hook and shell regression scripts; `python3 -m compileall -q scripts`; JSON parsing of `nixos/flake.lock`; and XML parsing of `vm-xml/win10.xml`.

An earlier combined test invocation exceeded its outer command time limit after the VM diagnostic test printed its success message. The diagnostic test was rerun alone and exited successfully; the remaining tests and follow-up checks were then run separately. The original aggregate command, per-test timestamps and complete exit-status trace were not preserved. This is a historical run and must not be conflated with the separate `test-installer-invariants.sh` timeout note below; there is no evidence that both notes describe the same invocation.

In the local environment used for that earlier ZIP(1) snapshot test run, Nix, ShellCheck, Statix, Deadnix, `xmllint`, and `virt-xml-validate` were not available; those historical local checks therefore did not claim a Nix evaluation/build or libvirt/QEMU semantic validation. Physical GPU passthrough and VM shutdown/display-recovery testing remain unverified. The SSH password-authentication setting remains a documented, network-dependent security risk; it was not changed automatically because doing so without verifying a working alternate access path could lock out a deployed host.

The tracked source already has the correct `install.sh` mode, and `.github/workflows/check.yml` already builds a canonical ZIP with `git archive` and rejects archives that include `.git/` or lose the executable mode. The source/workflow logic was not altered for a defect confined to this ad-hoc ZIP.

### Historical audit notes for earlier ZIP attachments (not the file measured above)

- Exact-byte record for the earlier `nixos-hyprland-vfio(1).zip` audit (not ZIP(9)): **456,770 bytes**, **101** ZIP entries, SHA-256 `69168ea0d90285a879baf08dfb7be0425db2cedb6539344d4ab603caf1f36094`, embedded `.git/shallow` commit `8c6cf467038bacbc8cba46a0c9dcfe54e13c467d`, and **45** `.git/` entries (29 files plus 16 directories). Its installer ZIP entry had `create_system=0` and `external_attr=0x00000000`, so no Unix permission bits were encoded. These are historical ZIP(1) measurements, not measurements of ZIP(9).
- A still earlier audit also recorded **436,212 bytes**, **96** entries, a SHA-256 beginning `3f0f0ed5`, and embedded commit `a631d195`. Those figures describe a separate earlier ZIP and must not be applied to ZIP(1) or ZIP(9).


An earlier review used baseline `e5d491b60f48a35a3cb0b4288c02a7e789a31e4d` and examined a different ZIP whose embedded shallow checkout pointed to `a631d195891ff6da74ae727ac3c531ffc77c50ed`. The following older measurements and CI references are retained as historical records only; they do not describe the 456,770-byte attachment measured at the top of this report.

- The supplied `nixos-hyprland-vfio.zip` contains 96 ZIP entries. There are 45 entries under `nixos-hyprland-vfio/.git/`, including 29 actual files plus directory entries, so the internal Git metadata is definitely included.
- The `nixos-hyprland-vfio/install.sh` ZIP entry uses DOS/FAT creator metadata (`create_system=0`) and carries no Unix permission bits (`external_attr` mode `0000`). Extracting this archive therefore does not preserve the executable bit required by the documented `./install.sh` command and may cause `Permission denied` on Unix. The embedded Git index records `install.sh` as `100755`; the tracked script content and Git mode are not the defect.
- The current source workflow `.github/workflows/check.yml` already has the correct defense: it generates the source archive using `git archive`, rejects `.git/` entries, and validates the Unix executable mode on `install.sh`. The README already documents the same canonical command. This audit does not justify changing the installer or weakening/replacing those checks; the problem is the supplied noncanonical ZIP.
- GitHub Actions run [#928](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/40478786307) succeeded for SHA `a631d195891ff6da74ae727ac3c531ffc77c50ed` and produced the canonical source artifact. That artifact cannot be the supplied ZIP because the run's archive validation excludes `.git/`, while this ZIP contains it. Run #928 is historical evidence for its exact SHA only, not for the later main revision.
- Remediation: after the desired source changes are committed, generate the ZIP from that exact commit with the README's `git archive` command, or use the CI artifact produced for that exact commit. Do not distribute a manually compressed checkout containing `.git/`.

- **Historical re-verification from an earlier review — 2026-10-27 (different ZIP):** At parent revision `5959a79dcba3a0b8c7db4743c9a4a57a1025e36b`, a separate attachment was measured as 96 entries with embedded Git HEAD `a631d195891ff6da74ae727ac3c531ffc77c50ed`. These figures were correct only for that older attachment and must not be applied to the current 456,770-byte ZIP described at the top of this report.
- GitHub Actions run [#953](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/40518482880) succeeded for parent SHA `5959a79dcba3a0b8c7db4743c9a4a57a1025e36b` and uploaded the validated `nixos-hyprland-vfio-source` artifact (artifact ID `12739669466`, SHA-256 `df7db0982c1ebeb7f65d0279368cb85946eef2de2eb5a3f373e4d1c59492125b`). This run applies only to that exact parent SHA. The documentation-only update below must receive its own CI run before its resulting artifact is considered validated.

## Manual validation parity and installer-test timeout follow-up — 2026-10-27

- Updated the README and CONTRIBUTING validation commands to ShellCheck `scripts/pci-address.sh`, and to run `statix check .` plus `deadnix .`, matching the required CI gates. The README repository map now also lists the shared PCI helper.
- Extended `scripts/test-installer-invariants.sh` so documentation drift for these commands and their CI counterparts fails the regression test.
- A separate supplied audit note reports that `test-installer-invariants.sh` passed independently but timed out once during a combined audit. Its exact command wrapper, elapsed time and exit/timeout trace were not preserved, so it cannot be equated with the earlier aggregate timeout described above. This remains a test-stability question rather than a confirmed test assertion failure; do not add arbitrary delays or relax timeouts without reproducing and recording the exact run.
- Use only the exact measurements in the opening `ZIP audit confirmation` section for the `nixos-hyprland-vfio(1).zip` attachment. The 96-entry / `a631d195…` figures belong to a separate historical ZIP and are not current attachment facts. CI already enforces canonical archive packaging; the ZIP-only permission defect does not justify changing the installer's tracked executable mode.
- This change records and guards the manual-validation parity correction. It does not claim that Nix evaluation, Statix, Deadnix, a complete system build, QEMU/libvirt startup, or physical GPU passthrough was executed in this workspace.

## Audit follow-up — 2026-10-27

- The reviewed ad-hoc full-source ZIP included `.git/` metadata and did not preserve `install.sh`’s Unix executable bit. These are packaging defects: the existing GitHub Actions workflow already creates the canonical archive with `git archive`, checks that `.git/` is absent and `install.sh` retains mode `100755`, then uploads that exact validated ZIP. Distribution should use the CI artifact rather than manually compressing a checkout.
- Fixed `INSTALLATION.md` to query `sudo virsh list --all --name` before classifying the VM. A registered `win10` is now treated as existing even when `/var/lib/libvirt/win10.xml` is missing; a failed libvirt query aborts rather than entering the new-VM path. An existing on-disk XML also remains classified as existing.
- Extended `scripts/test-installer-invariants.sh` to require the registered-domain check in both `README.md` and `INSTALLATION.md`, alongside the existing `--domain win10` synchronizer checks.
- Static regression tests were run against the correction bundle and passed, including installer invariants/rollback, VM XML/sync/diagnostic, VFIO handoff, LSFG-VK, embedded-script extraction, Bash syntax, and Python compilation. Nix evaluation, ShellCheck, libvirt/QEMU semantic checks, and physical GPU/VM lifecycle testing remain separate and are not claimed here.

## Current follow-up correction — 2026-10-27

- Closed the VM-definition source-of-truth gap found in the October 24 audit. The XML synchronizer accepts an optional `--domain win10`, checks libvirt's registered domain list, and, when the domain exists, uses a validated `virsh dumpxml --inactive win10` result instead of trusting a stale or missing `/var/lib/libvirt/win10.xml`.
- The synchronizer now fails closed if the libvirt query/export fails or returns an unexpected domain. It creates a mode-`0600` recovery copy of the registered XML and backs up any existing on-disk XML before writing the PCI-address-synchronized result.
- Restored the embedded-script extractor's Nix-attribute boundary guard, made unterminated indented strings fail closed, and added `scripts/test-extract-embedded-scripts.py`. CI and contributor validation now run this focused regression test before ShellCheck extracts the seven real scripts.
- Both `install.sh` and the manual README flow pass `--domain win10`. The VM XML regression suite uses a fake `virsh` executable to cover registered-domain vs stale XML, registered-domain with missing on-disk XML, and list/dump failures with no mutation.

### Cross-conversation recheck on 2026-10-27

- The earlier report had not covered two fault paths deeply enough: a service stop may return success while systemd still reports an active unit, and `stateVersion` discovery could silently prefer one existing file when other existing candidates conflicted. The VFIO hook now checks the post-stop `ActiveState` and aborts before unbinding unless it is `inactive`/`failed`; mocked tests now cover stop failures, restoration failures, and retained retry state. Installer discovery now rejects duplicate or mixed literal/non-literal assignments and prompts when existing candidate values conflict; regression tests cover these cases.
- Status update — 2026-10-29: the previously documented v1 scope decision has been superseded by a coordinated LSFG-VK v2 migration. The active flake builds the hash-pinned `.#lsfg-vk-v2` package; Home Manager emits `version = 2` / `[[profile]]` TOML; the installer backs up, deploys, and rolls back `nixos/lsfg-vk-v2.nix`; and CI now validates the v2 schema and builds the package. This does not itself prove that a target host has rebuilt or that frame generation works at runtime.
- Cross-checked the manual `INSTALLATION.md` VM synchronization example against the README and `install.sh`. It previously omitted `--domain win10`; it now uses the same persistent `virsh dumpxml --inactive win10` source-of-truth path and documents fail-closed behavior.
- The report's historical audit is still not a reproducible 927-commit-per-finding manifest: imported conversation summaries and prior reports do not provide exact source/destination SHA coverage for every review turn. Findings are therefore mapped by report and current code state below rather than pretending every historical commit has been individually re-audited in this single pass.
- Historical CI note (not current HEAD): commit `a631d195891ff6da74ae727ac3c531ffc77c50ed` was the `main` revision used by GitHub Actions run [#928](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/40478786307), which succeeded on 2026-10-27. Before this documentation correction, `main` had advanced to `e5d491b60f48a35a3cb0b4288c02a7e789a31e4d`. Run #928 validates only its exact SHA, not later commits or physical hardware behavior.
- No live libvirt guest, physical GPU passthrough/release cycle, full RT-Bore-LTO kernel build, or target-host lifecycle run was performed as part of this follow-up audit. The CI result does not replace those target-machine checks.

## Post-audit documentation and delivery corrections — 2026-10-27

- Added `scripts/test-extract-embedded-scripts.py` to the README's manual validation sequence so it matches CONTRIBUTING and CI.
- Renamed the older 2026-10-23 changelog subsection to `Follow-up fixes — 2026-10-23`, leaving one current `Unreleased` heading and making the dated history clearer.
- Historical CI reference: run #928 passed for SHA `a631d195891ff6da74ae727ac3c531ffc77c50ed`; it should not be described as CI status for the later `main` revision.
- The inspected ad-hoc full-source ZIP was not a valid distribution archive because it included `.git/` and did not preserve `install.sh`'s executable mode. The tracked Git mode remains `100755`. Recreate the distributable bundle with the canonical `git archive` command in README, or use the CI artifact for the exact source commit being distributed; do not infer that an artifact from an earlier commit validates the current tree.

## Follow-up corrections — 2026-10-23

- Preserved the executable bit for `install.sh` in the correction bundle (`100755`) and clarified that its monitor-output prompt controls both the Hyprland monitor rule and mpvpaper wallpaper. The supplied full-source archive's `.git/` packaging issue is avoided here because this is a patch-only ZIP containing only the corrected paths.
- Corrected the cache description in `nixos/flake.nix` and `README.md`: the active configuration lists the Nix Community cache, not the upstream CachyOS Attic cache. No new third-party substituter was added. The upstream cache does not publish the RT-Bore-LTO ThinLTO variant; the project owner reports that the currently locked revision has built successfully on the target machine, while each newly selected upstream revision still requires a local build.
- Updated the current changelog and configuration index to match the actual CachyOS revision in `nixos/flake.lock` (`02ba4db52e62e1fbece80402d369127ae77cbbeb`). Updated current validation wording to record the project owner's report of a successful rebuild, RT-Bore-LTO compile, VM start/shutdown, and return to Hyprland. Older date-stamped entries below remain historical records of what was known at those dates.
- Fixed the six Hyprlock label text colors in `nixos/home.nix`: label widgets now use the documented `color` option, while `input-field.font_color` remains unchanged. Replaced the network label's `xargs`/`||` fallback with an `awk` empty-input check so it reliably displays `Disconnected` when no active connection name is available.
- Validation for this follow-up patch: all six repository regression suites, Bash syntax checks, Python compilation, JSON/XML/YAML parsing, embedded-script extraction/syntax checks, and Markdown relative-link checks were rerun. Nix evaluation/build, ShellCheck, libvirt semantic validation, and independent physical GPU/VM lifecycle testing remain unverified in this environment.

## Historical correction record — 2026-10-21

The patch-only ZIP created for the 2026-10-21 correction set contained `CHANGELOG.md`, this report, `install.sh` (content unchanged, ZIP Unix mode `100755`), `scripts/sync-vm-xml.py`, and `scripts/test-vm-xml-sync.py`. It excluded `.git/` and all unchanged project files. It was an overlay for the matching project tree, not a full-source archive or replacement for the original project ZIP.

- Corrected the changelog's language-policy description: the root `KURULUM.md` and `DEGISIKLIK_GECMISI.md` are English compatibility/current-state pointers, while the original Turkish release-by-release history is in `docs/archive/DEGISIKLIK_GECMISI.md`.
- Corrected VM XML GPU/audio role identification. The helper now matches each PCI hostdev's guest-side PCI target against the reviewed template's role map, so reordering the two XML blocks no longer swaps GPU/audio source addresses. Unknown target addresses fail closed before a destination or backup is modified.
- Added regression tests for reordered PCI hostdev blocks and unrecognized guest-side target addresses, in addition to the existing preservation/backup/unsupported-layout tests.
- Preserved `install.sh`'s tracked executable mode (`100755`) in this patch ZIP. Its contents are unchanged. The full-source ZIP supplied for review had dropped that mode and included `.git/`; this patch-only ZIP intentionally excludes `.git/` and is not a repackaged full source bundle.

Validation for this patch: all six regression suites passed (`test-vm-xml.py`, `test-vm-xml-sync.py`, `test-vm-diagnostic.py`, installer invariants, installer rollback, and VFIO driver/service-state tests). Bash syntax checks, Python source compilation, `flake.lock` JSON parsing, template XML parsing, extraction and `bash -n` checks for all seven embedded scripts, and all 38 Markdown relative-link checks also passed. Nix evaluation/build, ShellCheck, and libvirt semantic validation were not run in this environment; no real GPU/VM lifecycle behavior is claimed.


## Delivery-scope clarification — 2026-10-19

This report contains historical notes about earlier correction bundles; those dated notes must not be read as a description of the original full-project archive currently under review. The original uploaded archive (`nixos-hyprland-vfio(5).zip`) included the full project tree and `.git/`, and its `install.sh` ZIP entry did not preserve the Unix executable bit. The English `README.md` also contained one Turkish error message.

The corrective ZIP produced from this review is a **patch-only bundle** containing only the three files corrected for these findings: `README.md`, `install.sh` (stored with Unix mode `100755`), and this report. It excludes `.git/` and unchanged project files. Applying it overlays those paths onto the matching project tree; it is not a replacement for the full source archive. This bundle addresses the confirmed packaging/documentation findings only and does not claim Nix evaluation, libvirt validation, or real hardware/VM lifecycle verification.

## Follow-up corrections — 2026-10-19

This follow-up patch-only bundle contains only the files modified in this correction set: `README.md`, `scripts/test-installer-invariants.sh`, `.github/workflows/check.yml`, `CHANGELOG.md`, this report, and `install.sh` (mode correction only). It excludes `.git/` and does not duplicate the full source tree. The user-supplied full-project ZIP included `.git/` and did not preserve executable permission for `install.sh`; this patch ZIP explicitly stores that entry as Unix mode `100755`.

- The README snippet for preserving machine-specific hardware configuration was already correct in the supplied source archive: when the destination is missing, it checks the generated source at `/etc/nixos/hardware-configuration.nix` before copying. The earlier audit's quoted “current example” incorrectly showed the destination path twice. No logic change was needed; `scripts/test-installer-invariants.sh` now executes the documented block against temporary paths and checks copy, preserve-existing-target, and missing-source failure cases.
- CI creates the canonical source ZIP with `git archive`, validates that ZIP for `.git` exclusion and Unix executable mode, and uploads the exact validated ZIP as the `nixos-hyprland-vfio-source` workflow artifact after the required checks pass. This narrows the distribution gap between a tested archive and a separately repackaged download.
- The installer source code is unchanged in this correction set. Its executable bit is restored in the patch archive so applying/extracting that file does not repeat the original ZIP's mode-loss problem.

Validation for this correction set: Bash syntax checks, the installer invariants/rollback tests, VFIO driver-state tests, VM XML and diagnostic tests, Python compilation, workflow YAML parsing, canonical ZIP metadata checks, and patch ZIP metadata checks. This remains static validation only; Nix evaluation/build, ShellCheck if unavailable, libvirt semantic validation, and physical VM/GPU lifecycle testing remain separate checks that must not be inferred from static results.


## Follow-up status — 2026-10-17: packaging and documentation audit corrections

The 2026-10-17 audit of `nixos-hyprland-vfio(6).zip` found that the uploaded full-project archive included its internal `.git/` directory and extracted `install.sh` as mode `0644`, despite the Git index recording mode `100755`. This is an input-archive packaging defect, not a content-level installer bug. The fix-only ZIP for this correction set contains only the changed documentation/workflow files plus `install.sh` with Unix mode `100755`; it does not include `.git/` or duplicate the full project. To publish a canonical full-source ZIP from a Git checkout, commit the intended revision and use the `git archive` command documented in `README.md`. The CI check validates both exclusion of `.git/` and preservation of the executable bit.

The documentation and validation workflow were updated to close the other findings from that audit:

- `KURULUM.md` now distinguishes manual Btrfs `/home/.snapshots` setup from the installer's existing create-and-verify behavior, warns against running `btrfs subvolume create` on an already-existing subvolume, and keeps the boot-critical mount requirement explicit.
- `README.md` lists `scripts/test-installer-rollback.sh` in the repository map and local validation steps; `CONTRIBUTING.md` includes the same test and ShellCheck/syntax coverage.
- The embedded Bash validation in README, CONTRIBUTING, and CI now uses a fresh temporary directory, captures and checks the extractor's exit status directly, verifies exactly seven scripts before invoking ShellCheck, and removes the temporary files. An extraction failure or missing marker can no longer be masked by a downstream `xargs` success.
- `README.md` now names the default Windows and VirtIO ISO files and their expected `/var/lib/libvirt/images/` location, matching `vm-xml/win10.xml` and `KURULUM.md`.

Validation completed in this environment: installer invariants, rollback, VFIO driver-state, and VM XML tests passed; Bash syntax checks passed for the installer, QEMU hook, regression scripts, and all seven extracted embedded scripts; Python compilation, XML parsing, `flake.lock` JSON parsing, and workflow YAML parsing passed. The embedded-script extractor returned exactly seven scripts. ShellCheck and Nix flake evaluation were not run because those executables are unavailable here; libvirt semantic validation and real GPU/VM lifecycle behavior still require validation on the target host.

## Scope

Reviewed the uploaded source archive and modified source files, configuration, VM XML, installer, CI, scripts, and documentation. This is a static maintenance pass, not a claim that the configuration was activated on the target PC.

## Follow-up status — 2026-10-17: installer and VFIO safety corrections

The RT-Bore-LTO ThinLTO kernel selection remains intentional and unchanged in `nixos/flake.nix`. The following code-level findings from the follow-up static audit have now been addressed:

- `install.sh` backs up `/var/lib/libvirt/win10.xml` together with the deployed NixOS files, tracks which targets existed before deployment, and installs an `EXIT` rollback handler. If deployment exits non-zero after the first target mutation, existing files are restored from the run's backup and newly created targets are removed. Rollback is best-effort; if it reports a restoration failure, inspect the backup directory before rebuilding.
- `nixos/hooks/qemu` writes the pre-VM active state of `greetd`, `ollama`, and `polkit.service` to a mode-0600 state file under `/run/libvirt/vfio-state`. The release hook and prepare rollback restore only services which were active before the handoff; inactive Ollama is no longer started just because its unit is enabled.
- The installer now stops before deploying configuration if either CPU or GPU is not positively identified as AMD, matching the supported configuration scope.
- `README.md` and `KURULUM.md` document the upstream `low_latency_layer` v0.2.0 CS2/Source 2 frame-pacing limitation, the `fps_max 0` workaround, and per-game opt-out.
- New mocked tests cover the rollback path and service active-state restoration. CI invokes the rollback test and includes it in ShellCheck.

Validation performed for this follow-up: `bash -n` on the installer, hook, and affected shell tests; `scripts/test-installer-rollback.sh`; `scripts/test-vfio-hook-driver-state.sh`; `scripts/test-installer-invariants.sh`; `scripts/test-vm-xml.py`; Python compilation of `scripts/*.py`; and XML well-formedness parsing all passed. This environment does not have Nix, ShellCheck, or libvirt/QEMU validation tools, and no actual GPU passthrough or RT-Bore-LTO boot was performed here. The selected kernel still requires local build and real target-system boot/VM lifecycle verification.

## Follow-up status — 2026-10-16: RT-Bore-LTO selected

The current `nixos/flake.nix` selects `pkgs.cachyosKernels.linuxPackages-cachyos-rt-bore-lto` from the upstream `master` input; no kernel version is hard-coded in the flake expression. The checked-in `flake.lock` records the resolved input revisions for reproducibility; run a targeted `nix flake update` to move to a newer upstream revision. In the current lock graph, the CachyOS kernel flake has its own `nixpkgs` input, separate from the root system flake's `nixpkgs` input. The `pinned` overlay selects the CachyOS package from that kernel-flake package set; it does not align the system's nixpkgs revision with the kernel flake's revision. Upstream does not publish the RT-Bore-LTO LTO variant in its binary cache, so expect a local kernel build; the overlay cannot create a missing cache artifact. The earlier user-provided linker log named standard BORE-LTO, a different package derivation, and does not prove or disprove the RT-Bore-LTO build. This audit environment has no Nix CLI, so package evaluation and compilation were not run here.

The previously reported successful target-machine build and VM display recovery were performed with the standard (non-RT) BORE-LTO kernel. They do not validate the selected RT-Bore-LTO kernel. After a successful build, boot it and test VM start, normal shutdown, host display/Hyprland recovery, and a second VM start before treating the migration as validated. Upstream package reference: https://github.com/xddxdd/nix-cachyos-kernel/blob/master/README.md

## Corrections applied for the 2026-10-16 audit

- `KURULUM.md` now states the 810 GiB minimum (about 870 GB decimal) and explicitly documents that the `G` suffix accepted by `sgdisk` represents GiB. The reference partitions total 809 GiB.
- Before `sgdisk -Z` can run, the guide checks that the target exists, is a whole-disk block device, has no mounted descendants, and is at least 810 GiB. These checks reduce common mistakes but do not replace the operator's final model/serial-number verification; `sgdisk -Z` remains destructive.
- `KURULUM.md` and `README.md` now identify RX 6700 XT/Navi 22 as the reference GPU and do not imply universal support for RX 6000/7000 cards.
- The original uploaded full-project ZIP's missing Unix executable bit is distinguished from the new patch-only ZIP, which stores `install.sh` as mode `100755`. This patch archive contains only the corrected paths, not a duplicate full project or `.git` metadata.

## Changes made

### CachyOS kernel build/cache path

- Historical note (the tree at the time of that earlier audit): the CachyOS flake input was changed from `master` to `github:xddxdd/nix-cachyos-kernel/release`. The current tree has since returned to `master`. [Upstream documentation](https://github.com/xddxdd/nix-cachyos-kernel/blob/release/README.md) says this branch contains a kernel built by its Hydra CI and published to its binary cache.
- Changed `cachyos-kernel.overlays.default` to `cachyos-kernel.overlays.pinned`, which selects packages from the kernel flake's pinned nixpkgs revision. See the [upstream overlay definition](https://github.com/xddxdd/nix-cachyos-kernel/blob/release/flake.nix). For variants that upstream actually caches, this can avoid a local ThinLTO build when a matching derivation exists. RT-Bore-LTO's LTO variant is not cached, as noted in the follow-up status above.
- Replaced the previous CachyOS cache entry with the Attic substituter and public key documented by upstream in both the flake `nixConfig` and system Nix settings. [Upstream cache configuration](https://github.com/xddxdd/nix-cachyos-kernel/blob/release/flake.nix).
- The previous archive's CachyOS lock referred to an older upstream `release` snapshot. This correction refreshed the CachyOS input and its matching nested nixpkgs revision at the time of that audit. At the time of that earlier audit, the flake expression followed the upstream `release` branch rather than hard-coding a kernel version; the current tree follows `master`. The `flake.lock` records the selected source snapshot so rebuilds remain reproducible until the CachyOS input is intentionally updated. RT-Bore-LTO LTO is not in the upstream binary cache, so local build failures such as linker regressions still need their own investigation.

### Windows VM XML

- Changed the Q35 machine alias from `pc-q35` to `q35`. A versioned alias such as `pc-q35-X.Y` may also be used if that exact version is supported by the installed QEMU/libvirt.
- Reordered CD-ROM boot priorities so the Windows installation ISO is attempted before the VirtIO driver ISO. The disk remains boot priority 1.
- Added `scripts/test-vm-xml.py`, which parses the XML and checks the machine alias, disk/CD-ROM priority, SATA CD-ROM bus, and complete PCI hostdev addresses. CI runs this test.

### Ollama translation fallback

- Changed the API call to fail on HTTP error responses and display transport errors.
- Added validation that the response includes a non-empty string `response` property.
- Removed use of `xargs` as a generic whitespace trimmer, so quotes/backslashes are not reinterpreted. Empty/error responses now fail and are not appended to the translation cache.

### Documentation and language consistency (current state, 2026-10-23)

- `README.md`, `CONTRIBUTING.md`, and `CHANGELOG.md` are maintained in English. The root `KURULUM.md` is an English compatibility pointer to `INSTALLATION.md`; it is not the canonical Turkish installation guide.
- The root `DEGISIKLIK_GECMISI.md` is an English current-state/compatibility summary. The full historical Turkish change log is preserved at `docs/archive/DEGISIKLIK_GECMISI.md`.
- Installer prompts, warnings, desktop labels, status messages, notifications, service descriptions, and VFIO hook comments are maintained in English. The OCR/game-translation utility intentionally translates recognized English game text into Turkish.
- Older statements in this report that described the root `KURULUM.md` as Turkish or the root `DEGISIKLIK_GECMISI.md` as the full Turkish history were true only of an earlier project state and were superseded by the documentation migration recorded on 2026-10-19. They should not be treated as descriptions of the current tree.

## Checks performed in this environment

| Check | Result |
|---|---|
| Individual `bash -n` syntax checks for `install.sh`, `nixos/hooks/qemu`, and both regression shell scripts | Passed |
| `bash scripts/test-installer-invariants.sh` | Passed |
| `python3 -m py_compile` for repository Python scripts | Passed |
| `python3 scripts/test-vm-xml.py` | Passed |
| `bash scripts/test-vfio-hook-driver-state.sh` | Passed |
| ZIP/tree and JSON/YAML/XML parsing | Passed where relevant tooling was available |
| GitHub Actions CI | The project owner reports that CI is green for the updated repository; this status was not independently re-run from the audit container. |
| Nix evaluation / `nixos-rebuild dry-activate` | Not run by this reviewer: `nix` is unavailable in the audit environment. The project owner separately reports a successful target-system rebuild; whether the exact `dry-activate` command was run was not specified. |
| `shellcheck`, `xmllint`, `virt-xml-validate` | Not run: tools are unavailable in this environment |
| Real VM/GPU lifecycle | Not independently run by this reviewer. The project owner now reports that the RT-Bore-LTO kernel built successfully and that the Windows VM started, shut down normally, and returned the host to Hyprland. This is target-machine owner-reported validation, not an independent test or a guarantee for other hardware. |

The checked-in `nixos/flake.lock` records the CachyOS `master` revision `02ba4db52e62e1fbece80402d369127ae77cbbeb` for reproducibility; `nixos/flake.nix` does not hard-code a kernel version. To move the system to a newer upstream revision, update only the CachyOS input, inspect the lock diff, then evaluate and build the candidate. Nix is unavailable in the review environment, so this reviewer did not independently run flake evaluation or a kernel build. The project owner reports that the target system rebuilt successfully, compiled RT-Bore-LTO locally, started and shut down the Windows VM normally, and restored the Hyprland host session. This is owner-reported evidence rather than a result independently reproduced in this container, and it does not guarantee compatibility on other hardware.

## Required checks on the target NixOS host

From `/etc/nixos/nixos/`:

```bash
nix flake check --no-build --show-trace --no-update-lock-file --option warn-dirty false
sudo nixos-rebuild dry-activate --flake .#nixos -L
```

Watch whether the kernel is substituted from cache or built locally. If the same `tools/bpf/resolve_btfids` `ld.lld: undefined symbol` error recurs, capture the full derivation log with `nix log /nix/store/<kernel-derivation>.drv`; a lock/cache change does not itself fix a linker bug in source. Keep the currently working system generation until the candidate generation succeeds.

The project owner has confirmed a successful RT-Bore-LTO build and rebuild, VM start, normal shutdown, and host Hyprland recovery on the target machine; this closes the previously reported VM recovery issue for that setup. After future kernel, firmware, PCI-layout, VM XML, or hook changes, repeat the lifecycle check and inspect GPU/audio driver restoration. XML parsing is not a substitute for libvirt/QEMU validation or a real boot.


## Follow-up fixes in the reviewed archive

- Defined `PATCHED_XML=/var/lib/libvirt/win10.xml` before its first use in `install.sh` and translated the remaining installer prompt/help strings. The originally uploaded full-project ZIP did not encode Unix permission bits for `install.sh`, so extraction produced mode `0644` even though the Git index records `100755`. The fix-only patch ZIP for the 2026-10-16 corrections stores `install.sh` as mode `100755`; this statement is verified against the patch archive, not inferred from the Git index.
- The installer backs up an existing deployed VM XML, then regenerates it from the repository template while preserving the existing UUID and MAC and synchronizing GPU/audio PCI addresses; arbitrary custom XML edits are not merged into the regenerated file. Manual-copy instructions warn that host-specific PCI addresses must be checked.
- Documented a manual migration prerequisite check for `/etc/nixos/hashedPassword` in `README.md`, including non-empty content, root ownership, and mode `0600`, before rebuild commands. The installer now performs the same presence/metadata check during preflight and warns without aborting, because the manual checklist may still need to create or repair the file. Its example creates a hash only when the file is missing or empty, preserving an existing valid hash. Added a regression assertion that rejects the former undeclared `iommu_dir` spelling; the checked-in installer already uses the declared `gpu_iommu_dir`.
- Retracted the false OVMF template-architecture finding, corrected historical HEAD wording, and removed stale advice to refresh the CachyOS lock during routine installation.
- Set all configured locale categories and the supported generated locale to `en_US.UTF-8`. The Turkish Q keyboard mapping remains intentionally configured as a physical keyboard-layout choice, not as the system language.
- Translated remaining Waybar/Hyprlock labels, notifications, service descriptions, runtime errors, hook comments, and the commented USB-input XML notes into English. Translation output from the OCR/game translation feature remains Turkish intentionally.
- Added `scripts/test-installer-invariants.sh` and connected it to CI to guard the XML destination, preservation of deployed XML, English locale, and known user-visible strings.
- Added a Windows 10 lifecycle warning to the README; standard Home/Pro support ended on October 14, 2025.
- Corrected the installer preflight summary to disclose the actual changes: replacing the NixOS VFIO hook source under `/etc/nixos/nixos/hooks`, writing `/var/lib/libvirt/win10.xml`, and retaining backups without automatic pruning. The active NixOS-generated libvirt hook is refreshed only after a successful rebuild/activation; the installer does not run `virsh define` for the written VM XML. The README and disclaimer state these timing and activation limits explicitly.
- Replaced the ambiguous `nixfmt ./nixos` README command with a `find`/`xargs` pipeline that invokes `nixfmt` separately on each `.nix` file.
- Hardened `scripts/test-vm-xml.py`: the checked-in template must contain exactly two PCI `hostdev` elements, their source addresses must be unique, and they must match the two distinct hook defaults.
- Clarified the VFIO release log so it distinguishes restoration of the GPU display function from restoration of the HDMI/DP audio function; a restored display GPU no longer implies that both functions recovered.
- Made the installer checklist non-destructive for `hashedPassword`, translated the final remaining Turkish source comment, and moved the `nixos-enter ... passwd root` instruction to after successful `nixos-install` in `KURULUM.md`.

## Follow-up validation of this fix bundle

- The fix-only patch ZIP produced for the 2026-10-16 corrections stores `install.sh` with Unix mode `100755`. The original full-project ZIP is intentionally not included or repackaged in this patch-only delivery; apply these files over the project tree and create a fresh full-project archive from the corrected tree when needed. ZIP mode was read back from the produced patch archive, not inferred from the Git index.
- The pre-existing validation suite passed again for the 2026-10-16 correction set: `bash -n` for the installer, QEMU hook, and regression tests; `scripts/test-installer-invariants.sh`; `scripts/test-vfio-hook-driver-state.sh`; `scripts/test-vm-xml.py`; Python compilation for repository scripts; JSON parsing for `flake.lock`; and XML parsing for `win10.xml`. The newly added disk preflight code block in `KURULUM.md` was also extracted and Bash-syntax-checked. These checks do not simulate a real disk operation or VM lifecycle. Negative tests in the existing suite also confirm that duplicate PCI addresses and a third PCI `hostdev` are rejected.
- `shellcheck`, Nix evaluation/build, and libvirt validation were not run by this reviewer because the required tools are unavailable in the preparation environment. Real hardware tests were also not run independently by this reviewer. The project owner confirms the VM problem is resolved on the target system: rebuild and BORE-LTO kernel build succeeded, the VM started and shut down normally, and the display/Hyprland session recovered. The report records this as owner-verified real-system validation, not independent reproduction or a general guarantee for other hardware.

- The privileged XML updater uses the already-resolved Python interpreter. XML parsing errors, an incomplete/extra PCI `hostdev` pair, or a PCI node whose source-address structure cannot be synchronized now abort before a VM XML backup/write. Added a preflight guard against running the checkout from `/etc/nixos` (which would overlap source and destination), trimmed monitor-name input before generating Hyprland defaults, and expanded the installer regression tests. Source ZIPs should be built with `scripts/package-source-zip.sh` so tracked executable modes remain intact and `.git/` is excluded; patch ZIP delivery independently stores executable modes in archive metadata.


## Historical configuration snapshot — 2026-10-16 (superseded; not current guidance)

> This dated snapshot records an earlier configuration and contains statements that became outdated. In particular, the OpenSSH password-authentication claim in the next bullet is false for the current `nixos/configuration.nix`: password and keyboard-interactive SSH authentication are disabled; public-key authentication is required.

- The current RT-Bore-LTO package follows `github:xddxdd/nix-cachyos-kernel/master`; the package version is not hard-coded in `flake.nix`. The lock file records the resolved upstream source revision for reproducibility, and a newer revision is selected by running `sudo nix flake update --flake /etc/nixos/nixos cachyos-kernel` followed by a review of the lock diff. Do not use `--accept-flake-config` simply to bypass the cache-trust prompt. The `nup` Fish alias targets only this CachyOS input and works from any directory.
- `LOW_LATENCY_LAYER=1` and `LOW_LATENCY_LAYER_REFLEX=1` are set through `environment.sessionVariables` so PAM-launched desktop sessions receive the system-wide Reflex setting. Affected applications may opt out with `DISABLE_LOW_LATENCY_LAYER=1`.
- Historical note only: this snapshot claimed OpenSSH password authentication was enabled. That claim is superseded: the current configuration disables password and keyboard-interactive SSH authentication, requires public keys, and uses `/etc/nixos/hashedPassword` only for the local `localhost` account password. The QEMU hook terminates only `seat0` rather than all sessions for the desktop user, preserving a remote SSH session. The existing GPU-node check still aborts and rolls back if a process retains the device.
- This environment did not run Nix evaluation or build the RT-Bore-LTO kernel. Test the lock update, full rebuild, SSH persistence during VM startup, and complete VM stop/host-GPU recovery sequence on the target system before relying on these changes.

## 2026-10-19 follow-up — VM XML preservation and Vulkan capture compatibility

- Extracted the privileged VM XML synchronization code into `scripts/sync-vm-xml.py` so it can be tested independently and called by `install.sh`. When `/var/lib/libvirt/win10.xml` already exists, the existing XML is now the source of truth; the helper backs it up and updates only the four BDF attributes for the two PCI hostdev source addresses. It retains the current UUID/MAC, disk path, firmware/NVRAM, CPU/device settings, USB passthrough entries, comments, and additional PCI-address attributes. Malformed XML, a different domain, unsupported primary-disk layout, extra/missing PCI hostdevs, or unsupported source-address shapes abort before the destination is changed. New VM XML continues to start from the checked-in template and receives a new UUID/MAC.
- Added `scripts/test-vm-xml-sync.py` and made CI run it. Tests cover new VM identity, existing VM customization/identity/disk path/USB retention, exact backup contents, PCI address updates, and fail-closed behavior when a deployed XML has an unexpected extra PCI hostdev.
- Added the upstream `low_latency_layer` v0.2.0 `obs_vkcapture` compatibility caveat and per-game opt-out to the English project guides.
- Validation run after these changes: Bash syntax checks for all shell entry points; Python compilation for `scripts/*.py`; `scripts/test-vm-xml.py`, `scripts/test-vm-xml-sync.py`, `scripts/test-vm-diagnostic.py`; `scripts/test-installer-invariants.sh`, `scripts/test-installer-rollback.sh`, and `scripts/test-vfio-hook-driver-state.sh` all passed. `nix`, ShellCheck, and libvirt/QEMU validation tools are not installed in the review environment; no Nix evaluation/build or real hardware lifecycle test is claimed.
- Made `INSTALLATION.md` the canonical English installation guide. The root `KURULUM.md` filename remains only as an English compatibility pointer; automated checks now validate the canonical guide. Replaced the root `DEGISIKLIK_GECMISI.md` with an English current-state summary and preserved the full original Turkish history unchanged at `docs/archive/DEGISIKLIK_GECMISI.md`.


## Follow-up corrections — 2026-10-20

- The installer now records whether the NixOS deployment directory existed before the run. The transaction is marked active before the first `mkdir -p`, so a failed or partial directory-creation operation is covered by rollback. After managed targets are restored/removed, rollback uses `rmdir` only for a directory created by this run. It never recursively deletes the directory itself; if unrelated content remains or removal fails, the directory is retained and rollback is reported as incomplete.
- `scripts/test-installer-rollback.sh` now covers both new-directory outcomes: an empty directory created by the failed installation is removed, while unrelated content is preserved and the directory remains. Existing-file and symlink rollback tests remain in place.
- The patch-only ZIP stores `install.sh` with Unix mode `100755`; the archive contains only files changed in this correction set and excludes `.git/`.
- Historical validation for this correction set: the recorded command `bash -n install.sh scripts/test-installer-rollback.sh` syntax-checked only `install.sh`; Bash treats the second path as an argument to the first script, not as another file to parse. The separately recorded `bash scripts/test-installer-rollback.sh` test passed, which also establishes that the test script parsed and ran under Bash. Future multi-file syntax checks use one `bash -n` invocation per path, as shown in the README. Nix evaluation/build, ShellCheck, libvirt semantic validation, and real hardware/VM lifecycle checks were not performed here unless separately available in the target CI/host environment.

## Follow-up verification and fixes — parent `8e063bd3ddcf5774dba10553fe06be2cbcb15fdc` — 2026-10-27

### Findings rechecked against the uploaded archive and current source

- **VM XML/new-disk integration — confirmed by static control-flow inspection.** `install.sh` previously invoked `sync-vm-xml.py` even when no `win10` domain was registered and no deployed XML existed. The helper then created a fresh on-disk XML; both manual VM setup blocks treated any existing XML as an existing VM and disabled the new-disk branch if its disk was missing. The migration helper now synchronizes only a registered domain or an already deployed XML. When neither exists, it defers fresh XML creation to the documented VM-preparation flow, which classifies the VM before calling the helper. Existing disks remain protected; no disk is recreated, overwritten, re-owned or re-permissioned by this change.
- **Post-reboot repository path — confirmed from clean-install instructions.** The fresh-install flow cloned to `/tmp/repo` in the Live ISO, but the later VM-preparation block expected `~/nixos-hyprland-vfio` without creating it. The README and installation guide now clone to the persistent home-directory path if absent, reject a conflicting non-Git path, and use that same checkout for the rest of the block.
- **Archive measurement history — corrected.** The exact size/hash/entry-count/embedded-HEAD tuple for the supplied `nixos-hyprland-vfio(1).zip` remains in the opening section. The 436,212-byte / 96-entry / `a631d195…` data and older v7 figures are historical measurements from different ZIPs, not facts about the current attachment.
- **Machine-specific `hardware-configuration.nix` and deployment-specific SSH/IOMMU/libvirt ownership risks — not changed here.** The existing documentation already warns that hardware UUIDs must be regenerated for the target host and describes the SSH, IOMMU group and libvirt file-ownership risks. Replacing device UUIDs or changing access policy without the target machine could break boot or remote access; these were not treated as verified runtime defects.

### Proposed-tree validation record

The code changes were first tested in the extracted source snapshot. The core installer, guide and regression-test file contents matched the corresponding blobs on `main` at parent `8e063bd3ddcf5774dba10553fe06be2cbcb15fdc`; the current report and changelog were fetched from that parent before edits. Statuses below are from this proposed tree, not from a live target host.

| Command | Exit status | Elapsed time | Result |
| --- | ---: | ---: | --- |
| `bash scripts/test-installer-invariants.sh` | 0 | 16.518 s | Passed |
| `bash scripts/test-installer-rollback.sh` | 0 | 0.193 s | Passed |
| `bash scripts/test-vfio-hook-driver-state.sh` | 0 | 0.968 s | Passed |
| `python3 scripts/test-vm-xml.py` | 0 | 0.987 s | Passed |
| `python3 scripts/test-vm-xml-sync.py` (isolated; `timeout 45s`) | 0 | 21.66 s | Passed in isolated run; see aggregate-run note below |
| `python3 scripts/test-vm-diagnostic.py` | 0 | 7 s (shell `SECONDS` resolution) | Passed |
| `python3 scripts/test-lsfg-v1-config.py` | 0 | 1 s (shell `SECONDS` resolution) | Passed |
| `python3 scripts/test-extract-embedded-scripts.py` | 0 | 2 s (shell `SECONDS` resolution) | Passed |
| `python3 scripts/test-vm-iso-paths.py` | 0 | 7 s wall clock; 5.744 s for six unit tests | Passed |
| `bash -n install.sh`, `bash -n nixos/hooks/qemu`, and Bash regression-script syntax checks | 0 | Combined | Passed |
| `python3 -m compileall -q scripts` | 0 | Combined validation block | Passed |
| Parse `nixos/flake.lock` as JSON and `vm-xml/win10.xml` as XML | 0 | Combined validation block | Passed |

One aggregate test command exceeded the container's 300-second outer limit while waiting in `scripts/test-vm-xml-sync.py`, after the installer-invariants, rollback, VFIO driver-state and VM XML tests had printed success. The XML-sync test then passed in an isolated retry, measured at 21.66 seconds, and also passed on another isolated attempt. This reproduces variable aggregate behavior but does **not** identify the cause; it is not presented as a failed assertion or a proven product defect. Preserve the full runner trace and use an external per-test timeout on the next reproduction.

Nix evaluation/system build, ShellCheck, Statix, Deadnix, libvirt/QEMU semantic validation, and physical GPU/VM lifecycle testing were not run in this environment. No claim of a successful real-host VM or GPU handoff is made.
