# OptiScaler Manager

The repository includes an optional, independent **third-party/nonofficial** Python helper for checking, downloading, verifying, installing, updating, rolling back, and removing OptiScaler in a **single explicitly selected game directory**. It is maintained by this repository and is not developed, affiliated with, or endorsed by OptiScaler upstream; the manual installation path remains available.

It is not a NixOS package, Home Manager module, Vulkan layer, or background service. It does not edit Steam launch options, global environment variables, the flake, or the system configuration. The helper uses Python's standard library; 7-Zip is required only for archive extraction.

## Safety model

- Checks only the official OptiScaler GitHub stable-release endpoint. Nightly, rolling, draft, and prerelease builds are ignored.
- Verifies the downloaded archive's byte count and SHA-256 before extraction. Each concurrent download writes to its own uniquely named temporary file in the versioned cache directory; only that verified file is atomically moved into the shared cache. This prevents another game's install/download command from unlinking or replacing an in-progress download. v0.9.4 uses the digest pinned in `docs/OPTISCALER.md`. A later release must expose a SHA-256 digest through GitHub release metadata or the operator must provide a checksum independently verified from the official release page. If neither is available, the helper fails closed.
- Parses each 7-Zip member record before extraction, rejects absolute/traversal paths, symbolic links, hard links, reparse points, and Unix special files, and requires a complete per-member uncompressed-size listing under the 4 GiB limit. A second post-extraction scan still rejects any symlink that appears in the staged tree.
- Requires the exact game executable directory (`--game-dir`) and verifies that it contains a Windows `.exe`.
- Requires an explicit offline/single-player confirmation and the interactive word `INSTALL`. Do not use OptiScaler with online or anti-cheat-protected games; upstream warns this can trigger anti-cheat and account penalties.
- Refuses file conflicts by default. `--replace-existing` is an explicit opt-in and backs up pre-existing files before replacing them.
- Validates the state JSON root, schema, proxy name, relative paths, SHA-256 values, backup mappings, and rollback flag before trusting the record. Malformed state is reported as a controlled manager error rather than an uncaught attribute/type error.
- Records managed-file hashes and backs up original files under `$XDG_STATE_HOME/optiscaler-manager` (default `~/.local/state/optiscaler-manager`). Modified managed files are not silently deleted during rollback or removal.
- When a later release drops a previously managed path, the update restores that path's pre-install original from its backup and removes the obsolete mapping from manager state. If the required backup is missing or unsafe, the update stops before changing the game files or replacing the existing one-step rollback. Previously managed files that had no original are removed when the new payload no longer includes them.
- Before rotating an existing one-step rollback, an update atomically copies every newly encountered pre-existing game file into its original-file backup. If any copy fails, the update stops before changing the game folder, manager state, or previous rollback.
- Install/update, status, rollback, and removal acquire a private per-game `flock` lock under `$XDG_STATE_HOME/optiscaler-manager/locks`. Download cache writes use separate per-download temporary files because downloads may be initiated for different game directories and therefore do not share a per-game lock. A second operation for the same game fails immediately with an actionable message instead of racing over its files or state; different game directories use independent locks. Lock files are mode `0600`, and the lock is released when the command exits.
- `rollback` preflights every required backup and validates the complete rollback manifest before changing the game folder; existing targets are replaced atomically rather than deleted before their backup is read. It also keeps a persistent pre-rollback snapshot of the game files and manager state until the rollback is fully committed. If rollback fails, it restores the previously installed state and leaves the one-step rollback available; if that recovery also fails, the exact recovery directory is reported and retained.
- `remove` validates every original-file backup and destination before mutating any managed file. It snapshots the pre-remove state in a persistent recovery directory and attempts to restore it if a later removal/restore operation fails. The snapshot is removed only after successful removal or successful recovery; a second failure leaves the snapshot on disk and reports its path.
- The final manager-state JSON write is part of the install/update transaction. If it fails after payload copying, the helper runs the rollback path instead of leaving untracked files in the game directory. If automatic restoration itself fails, the error names the backup directory to preserve for manual recovery.

The helper copies the payload found beside `OptiScaler.dll` in the verified archive and renames that DLL to the selected proxy name. The default is `dxgi.dll`; use another supported proxy only when the game's upstream compatibility notes require it.

## Commands

Run from the repository root. The following uses a temporary Nix shell for 7-Zip; it does not add a package to the system profile or flake:

```bash
# Check the latest official stable release and whether a trusted digest is available.
nix shell nixpkgs#p7zip -c python3 scripts/optiscaler_manager.py check

# Download the official archive and verify it before caching.
nix shell nixpkgs#p7zip -c python3 scripts/optiscaler_manager.py download

# Install/update only in the directory containing that game's main Windows executable.
nix shell nixpkgs#p7zip -c python3 scripts/optiscaler_manager.py install \\
  --game-dir "$HOME/path/to/Game/Binaries/Win64" \\
  --confirm-offline-singleplayer

# Check the files managed in that game directory.
python3 scripts/optiscaler_manager.py status \\
  --game-dir "$HOME/path/to/Game/Binaries/Win64"

# Restore the exact game-folder state from before the most recent install/update.
python3 scripts/optiscaler_manager.py rollback \\
  --game-dir "$HOME/path/to/Game/Binaries/Win64"

# Remove OptiScaler and restore any files backed up before its first manager install.
python3 scripts/optiscaler_manager.py remove \\
  --game-dir "$HOME/path/to/Game/Binaries/Win64"
```

The `install` command asks for the word `INSTALL` after showing the exact target directory. It does not guess a game folder or install into every Steam library.

### Existing DLL conflicts

If the selected directory already contains a proxy such as `dxgi.dll`, the default behavior is to stop. Inspect the file and its owner first. Only when replacement is intentional, repeat the install command with `--replace-existing`; the original is backed up so `remove` can restore it.

### Future releases without a published digest

Run `check` first. If the official stable release has no SHA-256 digest in GitHub metadata and is not covered by a repository-pinned digest, the helper will refuse to download/install it. Verify the SHA-256 independently from the official OptiScaler release information, then pass it explicitly:

```bash
python3 scripts/optiscaler_manager.py download --sha256 THE_VERIFIED_64_CHARACTER_SHA256
```

The same `--sha256` option is available to `install`. The supplied digest is checked against the GitHub digest or repository pin whenever one exists; a conflicting value is rejected.

## Proton launch option

After installation, the helper prints the matching per-game Wine DLL override. For the default DXGI proxy, add this in **that game's** Steam Properties → General → Launch Options:

```text
WINEDLLOVERRIDES="dxgi=n,b" %command%
```

Preserve existing launch options. The helper deliberately does not edit Steam's configuration or apply this override globally. Remove the per-game override after `remove`.

## RX 6700 XT and LSFG-VK

See [OptiScaler on NixOS with Steam/Proton](OPTISCALER.md) for the pinned v0.9.4 asset, RX 6700 XT/RDNA2 FSR 4.1.1 limitations, RADV notes, and the frame-generation warning. Do not run OptiScaler Frame Generation and LSFG-VK simultaneously in the same game.

## Validation

Run the offline regression tests:

```bash
python3 scripts/test-optiscaler-manager.py
```

The tests cover digest selection and fail-closed behavior, unsafe paths, pre-extraction link/special-file and size checks, incomplete listing rejection, malformed state documents, explicit replacement, missing-backup preflight, restoration of original files omitted by a newer payload, preservation of the prior rollback when an obsolete-file backup is missing, state-write rollback, partial-remove recovery, update rollback, and executable-directory validation. They do not download or execute OptiScaler.
