# Migration guide — hosts/ layout restructure (2026-11-19)

This guide documents the repository restructure prepared as a single working-tree
change, how to commit it in reviewable steps, how to migrate an already-deployed
host, and what to validate afterwards. The restructure applies the module/layout
recommendations from the repository analysis report (items 10.1, 10.3, 10.8,
10.9, and 10.10); Stylix (10.4), disko (10.5), and nix-flatpak (10.6) are
follow-up work and are intentionally not part of this change.

## What changed

**Layout (10.1).** The four host-owned NixOS sources moved:

| Old path | New path |
|---|---|
| `nixos/configuration.nix` | `nixos/hosts/nixos/configuration.nix` |
| `nixos/home.nix` | `nixos/hosts/nixos/home.nix` |
| `nixos/hardware-configuration.nix` | `nixos/hosts/nixos/hardware-configuration.nix` |
| `nixos/hooks/qemu` | `nixos/hosts/nixos/hooks/qemu` |

`nixos/flake.nix`, `nixos/flake.lock`, `nixos/lsfg-vk-v2.nix`, and
`nixos/mako-renderer.nix` stay at the flake root (they are flake-level, not
host-level). `nixos/flake.nix` now imports `./hosts/nixos/configuration.nix`.
The deployed tree under `/etc/nixos/nixos` keeps the same layout, so the
rebuild target remains `/etc/nixos/nixos#nixos`.

**Host-specific values (10.3).** The five desktop values (`monitorOutput`,
`monitorMode`, `wallpaperVideo`, `gitName`, `gitEmail`) moved from home.nix's
`let` block into a new options module, `nixos/hosts/nixos/host-settings.nix`
(`kumutuk.host.*`). `home.nix` reads them through `osConfig.kumutuk.host` and
keeps the same fallback literals, so standalone `home-manager switch` still
works. `install.sh` now rewrites the option defaults in `host-settings.nix`
instead of patching home.nix; its `apply_var` target and the required-file,
backup, transaction, and stateVersion paths were updated for the new layout.

**New files (10.8/10.9/10.10).**
- `nixos/hosts/.template/` — configuration.nix + host-settings.nix template for
  adding a second machine, with the AMD/VFIO review checklist.
- `.envrc` — `use flake ./nixos` for direnv users (`.direnv/` is git-ignored).
- `.github/workflows/cache.yml` — manual Cachix push of the system toplevel,
  kernel, and pinned packages (see the setup notes inside the file).
- `.github/workflows/flake-update.yml` — weekly automated flake.lock update PR;
  it never merges automatically.

**Documentation and tests.** README.md, INSTALLATION.md, CONTRIBUTING.md,
RELEASING.md, DISCLAIMER.md, DEGISIKLIK_GECMISI.md, CHANGELOG.md, and the
docs/ guides were updated to the new paths. The release allowlist in
`.github/workflows/release.yml` and RELEASING.md was first extended (53 → 56 exact
paths) with the two new workflows and this guide. Follow-up commit
`05aa2333b3c004dda7f2b8c6d8e992da9aea94bd` then added five more explicit paths
(56 → 61); **61 is the current matching count** enforced by
`scripts/test-documentation-integrity.py`. The 53 → 56 figure is an earlier
intermediate snapshot, not the current allowlist size. All offline regression
suites that reference repository paths were updated: installer invariants,
documentation integrity, LSFG-VK v2, MAKO, VM XML (three suites), VM
diagnostic, VM ISO paths, VFIO hook driver-state, embedded-script extraction,
Home Snapper layout, and the source packager's executable list.

**What did NOT change.** No NixOS runtime setting, kernel parameter, VM XML,
or VFIO hook behavior changed. `nixos/flake.lock` is untouched, so no new
flake inputs were added (this is why Stylix/disko/nix-flatpak/sops are
follow-up work: they need `nix flake lock` updates, which should be separate,
individually validated commits).

## Suggested commit split

The whole change can land as one commit, but if you prefer reviewable steps:

1. `git mv` only (four renames) + the one-line flake.nix import change +
   `nixfmt`-clean: the tree builds exactly as before.
2. `host-settings.nix` + home.nix `osConfig` reading + configuration.nix import
   + install.sh `apply_var`/path updates.
3. New workflows + `.envrc` + template + release allowlist extension.
4. Documentation and test path updates (this commit must land together with 1–3
   in the same push; the documentation-integrity test checks the tree as a whole).

## Migrating a deployed host

The deployed tree keeps the same structure, so only file locations change.

```bash
# 1. Back up the current deployed tree.
sudo cp -a /etc/nixos/nixos ~/nixos-deployed-backup-$(date +%Y%m%d-%H%M%S)

# 2. Create the new host directory and move the deployed files.
sudo mkdir -p /etc/nixos/nixos/hosts/nixos/hooks
sudo mv /etc/nixos/nixos/configuration.nix   /etc/nixos/nixos/hosts/nixos/
sudo mv /etc/nixos/nixos/home.nix            /etc/nixos/nixos/hosts/nixos/
sudo mv /etc/nixos/nixos/hardware-configuration.nix /etc/nixos/nixos/hosts/nixos/
sudo mv /etc/nixos/nixos/hooks/qemu          /etc/nixos/nixos/hosts/nixos/hooks/
sudo rmdir /etc/nixos/nixos/hooks 2>/dev/null || true

# 3. Copy the new host-settings.nix from the updated repository checkout.
sudo install -m 0644 "$REPO/nixos/hosts/nixos/host-settings.nix" /etc/nixos/nixos/hosts/nixos/

# 4. If your monitor/git/wallpaper values differ from the defaults, edit the
#    kumutuk.host option defaults in /etc/nixos/nixos/hosts/nixos/host-settings.nix.
```

If your deployed `home.nix` was edited locally (for example by a previous
`install.sh` run that wrote `monitorOutput = "DP-1"`), copy those five values
into `host-settings.nix` first; the `let` block in the new home.nix no longer
holds them. `lsfg-vk-v2.nix`, `mako-renderer.nix`, `flake.nix`, and
`flake.lock` stay at `/etc/nixos/nixos/` — do not move them.

Then rebuild and reboot:

```bash
sudo nixos-rebuild dry-activate --flake /etc/nixos/nixos#nixos
sudo nixos-rebuild switch     --flake /etc/nixos/nixos#nixos
sudo reboot
```

After reboot, verify the Hyprland Lua config still renders (it reads the host
values through `osConfig`): `hyprctl configversion`, `hyprctl monitors`, and
check that the mpvpaper wallpaper service started (or warned, if the video
path is intentionally absent).

## Post-merge validation sequence

1. Push to `main` and let **Normal CI** run on the exact merge commit. All 27
   workflow-defined steps must pass. The Nix evaluation steps
   (`nix flake check --no-build`, generated-Lua `luac -p`, LSFG-VK/MAKO builds,
   statix/deadnix, nixfmt) are the real gate for the moved files.
2. Trigger the **Full NixOS System Build** workflow on the merge commit. Every
   moved path is a pending-build path, so a release before this build requires
   the manual `target_host_validated` attestation; the normal path is to wait
   for the build.
3. Optional but recommended: set up the Cachix cache
   (`.github/workflows/cache.yml` header) so future full-system builds reuse
   the kernel.
4. On the physical host, run one complete VM start/shutdown cycle and confirm
   GPU handback, as with any system-affecting change.
5. Record the new verified baseline in `docs/REPAIR-AND-VALIDATION-REPORT.md`
   once the full-system build passes (the existing format: exact SHA + run ID).

## Known limitations

- The `nix develop`-based checks (nixfmt, statix, deadnix, Lua validation)
  could not run in the environment where this change was prepared (no Nix).
  All offline regression suites (the 19 `scripts/test-*` files run by normal
  CI) pass; the Nix-side gates run in CI.
- `install.sh` remains experimental and untried end-to-end; its path handling
  was updated and covered by the mocked suites, but no live migration was
  performed.
- The weekly flake-update workflow opens PRs from `auto/flake-update`; GitHub
  scheduled workflows are disabled by default on forks and can be noisy on
  long-lived branches — disable the schedule trigger if that becomes a problem.
