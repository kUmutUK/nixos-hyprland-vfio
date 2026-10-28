# Follow-up audit: source ZIP, deployed VM XML, and VFIO driver recovery

**Audit date:** 2026-10-28  
**Starting `main` revision reviewed:** [`59482f313b2229381fea2620fcc826158dbc2e2e`](https://github.com/kUmutUK/nixos-hyprland-vfio/commit/59482f313b2229381fea2620fcc826158dbc2e2e)  
**Scope:** verify the four findings supplied for `nixos-hyprland-vfio(6).zip`, patch confirmed code issues, and add regression coverage.  
**Archive limitation:** the exact ZIP bytes were not attached to this turn. Its SHA-256, entry list, embedded metadata, and extracted permission bits cannot be independently measured in this audit.

## Executive result

| Finding | Audit disposition | Change |
|---|---|---|
| 1. ZIP executable modes missing | Existing canonical packager is already designed to preserve/check modes. Specific submitted ZIP is not independently verifiable without its bytes. | No redundant source-code change; continue using canonical packager/CI artifact. |
| 2. ZIP includes `.git/` and placeholder revision | `$Format:%H$` is intentional in the Git checkout because `.gitattributes` enables `export-subst`. Canonical packaging substitutes the real commit SHA and excludes `.git/`. The reported ZIP may still be noncanonical, but its bytes were unavailable. | Keep the canonical packaging guard and document its scope accurately. |
| 3. VM XML test only reads repository files | Confirmed test-coverage gap. | Add `--xml-path`, `--hook-path`, and a deployed-XML option for local USB IDs; add path-override regression tests and usage documentation. |
| 4. VFIO release may accept `pci-stub` as host driver | Confirmed logic defect: the recovery predicate previously accepted any driver except `vfio-pci`. | Require `amdgpu` for the configured GPU function and `snd_hda_intel` for the configured GPU-audio function; reject other drivers in release and rollback checks. Add mocked regression cases. |

## Evidence and reasoning

### 1–2. ZIP content, executable permissions, and source revision

Files reviewed:

- [`.gitattributes`](https://github.com/kUmutUK/nixos-hyprland-vfio/blob/main/.gitattributes)
- [`scripts/package-source-zip.sh`](https://github.com/kUmutUK/nixos-hyprland-vfio/blob/main/scripts/package-source-zip.sh)
- [`.github/workflows/check.yml`](https://github.com/kUmutUK/nixos-hyprland-vfio/blob/main/.github/workflows/check.yml)
- [`SOURCE_REVISION`](https://github.com/kUmutUK/nixos-hyprland-vfio/blob/main/SOURCE_REVISION)

Verified source behavior:

1. `.gitattributes` contains `SOURCE_REVISION export-subst`. Therefore `$Format:%H$` is expected in the checkout; `git archive` substitutes the packaged commit SHA.
2. `scripts/package-source-zip.sh` packages a committed Git revision using `git archive`, rather than compressing the working directory.
3. The helper checks ZIP integrity, requires `SOURCE_REVISION` to equal the packaged full commit SHA, rejects any `.git` path, compares archived files to the Git tree, and verifies Unix execute metadata for every tracked `100755` file.
4. The CI workflow checks that `install.sh` is tracked as `100755`, runs the canonical packager, and publishes the archive only after required checks pass.

Consequently, the placeholder in the source file is not itself an error, and the source code does not support a claim that the canonical packager loses executable bits. An archive produced by a file manager or other ad-hoc process can nevertheless include `.git/`, retain the placeholder literally, or lose Unix modes.

**Evidence boundary:** because `nixos-hyprland-vfio(6).zip` was not attached here, the particular archive's entries, hash, mode metadata, and embedded revision were not re-calculated. The ZIP report remains a delivery-specific allegation, not an independently reproduced measurement. The safe remediation is to create a new artifact with `scripts/package-source-zip.sh` or download the CI artifact for the exact commit.

### 3. Test the installed XML and hook inputs

Reviewed [`scripts/test-vm-xml.py`](https://github.com/kUmutUK/nixos-hyprland-vfio/blob/main/scripts/test-vm-xml.py) and the PCI-address instructions in [`INSTALLATION.md`](https://github.com/kUmutUK/nixos-hyprland-vfio/blob/main/INSTALLATION.md).

Before this patch the test defined fixed paths to `vm-xml/win10.xml` and `nixos/hooks/qemu`. A successful result could not establish that the separately deployed files matched.

Changes:

- `--xml-path PATH` selects the XML file to parse.
- `--hook-path PATH` selects the hook whose `GPU_PCI` and `GPU_AUDIO` values are compared.
- `--allow-custom-usb-ids` keeps numeric/entry-count checks but allows a deployed machine to have different USB IDs from the repository template. Without this option the original exact template-ID assertion remains.
- `scripts/test-vm-xml-paths.py` copies files to temporary paths, confirms the arguments are honored, checks the custom-USB mode, and verifies that a mismatched hook is rejected.

Documented deployed-source check:

```bash
python3 scripts/test-vm-xml.py \
  --xml-path /var/lib/libvirt/win10.xml \
  --hook-path /etc/nixos/nixos/hooks/qemu \
  --allow-custom-usb-ids
```

Important distinction: `/etc/nixos/nixos/hooks/qemu` is the deployed *source* hook. The active libvirt hook is generated by NixOS activation. The installation guide also documents how to obtain the generated hook output and pass it as `--hook-path` when checking the active generated file.

The validator checks XML invariants and source-address agreement. It cannot prove that a BDF belongs to the intended physical GPU, that libvirt accepts all host resources, or that a VM boots successfully.

### 4. Validate expected host-driver identity during VFIO recovery

Reviewed [`nixos/hooks/qemu`](https://github.com/kUmutUK/nixos-hyprland-vfio/blob/main/nixos/hooks/qemu) and [`scripts/test-vfio-hook-driver-state.sh`](https://github.com/kUmutUK/nixos-hyprland-vfio/blob/main/scripts/test-vfio-hook-driver-state.sh).

The previous predicate accepted any resolvable driver name other than `vfio-pci`. The release path used that predicate to decide whether to attempt the opt-in remove/suspend/rescan fallback and which recovery warnings to emit. Consequently, a function bound to `pci-stub` or another unexpected driver could be mistaken for a restored host function.

The patch now checks the expected driver by PCI function:

- configured GPU function: `amdgpu`
- configured HDMI/DisplayPort audio function: `snd_hda_intel`

Unexpected, unknown, unbound, and VFIO-bound states are not treated as successful recovery. The preparation rollback path uses the same expected-driver predicate before deciding that no further probe is needed. The mocked regression test exercises the expected GPU/audio drivers plus `vfio-pci`, `pci-stub`, an unknown driver, and an incorrect driver bound to the audio function.

This mapping matches the repository's documented AMD RX 6700 XT target. It is not a claim that all GPUs or customized kernels use the same driver names; changing the supported hardware scope would require adapting this expectation and its tests.

## Regression and validation record

The code patch adds these checks to the standard GitHub Actions workflow:

- `python3 scripts/test-vm-xml.py`
- `python3 scripts/test-vm-xml-paths.py`
- `python3 scripts/test-vm-xml-sync.py`
- `bash scripts/test-vfio-hook-driver-state.sh`
- the existing canonical ZIP validation, executable-mode check, ShellCheck, Nix flake evaluation, generated-hook ShellCheck, and remaining repository regression gates.

**Workflow-result status:** awaiting the GitHub Actions run for the merged revision. No passing result is claimed until the run for the exact revision is inspected.

## Explicitly unverified

- The bytes of the specifically named `nixos-hyprland-vfio(6).zip` and its hash/metadata.
- Physical GPU binding/rebinding, GPU reset recovery, the active host display, and the Windows VM start/shutdown cycle.
- Whether the configured PCI BDFs identify the intended GPU/audio functions on a particular machine.
- A full-system NixOS build for this patch. Standard CI's `nix flake check --no-build` evaluates the flake; it is not a full system build or a hardware test.
