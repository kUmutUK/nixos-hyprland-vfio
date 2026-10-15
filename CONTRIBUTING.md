# Contributing

Thank you for helping improve this project. Because this is a hardware-specific NixOS configuration, changes should be reproducible, clearly scoped, and explicit about what was and was not tested.

## Workflow

1. Fork the repository.
2. Create a focused feature branch:
   ```bash
   git checkout -b feature/my-change
   ```
3. Make the smallest change that addresses the issue.
4. Run the relevant checks below and include their results in the pull request.
5. Open a pull request with a clear explanation and reproduction steps.

## Validation

Run these commands from the repository root:

```bash
bash -n install.sh nixos/hooks/qemu scripts/test-vfio-hook-driver-state.sh
shellcheck -S warning install.sh nixos/hooks/qemu scripts/test-vfio-hook-driver-state.sh
python3 scripts/test-vm-xml.py
bash scripts/test-vfio-hook-driver-state.sh
python3 scripts/extract-embedded-scripts.py /tmp/embedded-scripts \
  | xargs -0 -r -n1 -- shellcheck -S warning
(cd nixos && nix flake check --no-build)
```

For changes to NixOS options or kernel inputs, also evaluate the relevant output and, where feasible, run a real `nixos-rebuild dry-activate`. Do not claim that the full kernel or system builds unless the build was actually completed. The `--no-build` CI step only evaluates the flake.

For VM XML changes, keep the project-specific invariant test up to date and validate the definition with the target host's libvirt/QEMU. A well-formed XML document can still reference an unsupported machine type or unavailable host resources.

For VFIO hook changes, run the mock driver-state regression test and document which branches it covers. It is not a substitute for testing the real GPU lifecycle on hardware. Single-GPU passthrough can terminate the host graphical session; arrange a recovery TTY or SSH path before running it.

## Style

- Use two-space indentation in Nix files and format them with `nixfmt`.
- Keep shell scripts compatible with the Bash runtime they declare and check them with ShellCheck.
- Prefer declarative NixOS configuration over manual runtime changes.
- Keep comments and documentation accurate; remove stale explanations rather than appending contradictory notes.
- Never commit host-specific secrets, password hashes, personal SSH keys, or test data.

## Pull requests

Include the motivation, a summary of changed files, test output, known limitations, and screenshots only when a UI change needs them. If a change is host-specific, state the required hardware and firmware assumptions.

## Bug reports

Include the NixOS release, `uname -r`, CPU/GPU model, relevant logs, the exact command that failed, and whether the failure occurred during evaluation, derivation building, activation, or runtime. Redact secrets and personal identifiers.
