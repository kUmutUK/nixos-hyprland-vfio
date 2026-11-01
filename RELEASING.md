# Releasing

This repository uses **git-cliff** for semantic version suggestions and release
notes. Publishing is tag-driven; ordinary pushes and pull requests do not create
releases.

## Before creating a release

1. Merge the intended stable code into `main` and make sure the worktree is
   clean.
2. Confirm that the **Nix Flake Check** workflow passed for the exact commit.
3. Run **Full NixOS System Build (manual)** against that same `main` commit.
   The run must complete successfully for the exact commit that will be tagged.
4. Review the version suggested by git-cliff; do not accept it blindly.

The full-system build is a separate, manually dispatched workflow on purpose.
A successful evaluation-only CI run is not a substitute for building the full
NixOS system and the selected RT-Bore-LTO kernel. A release still does not claim
that every machine has passed a physical VFIO/VM lifecycle test.

## Calculate and publish a version

Install/run git-cliff without adding it to the NixOS system:

```bash
nix run nixpkgs#git-cliff -- --config .git-cliff.toml --bumped-version
```

Review the printed SemVer value. Then create and push an annotated tag for the
commit whose CI and full-system build both passed:

```bash
VERSION="$(nix run nixpkgs#git-cliff -- --config .git-cliff.toml --bumped-version)"
git status --short
git tag -a "$VERSION" -m "Release $VERSION"
git push origin "$VERSION"
```

The tag must point to a commit reachable from `main`. The release workflow
checks that the normal CI and manual full-system build both succeeded for that
exact commit on `main`; it stops rather than publishing when either result is
missing or unsuccessful.

## What the release workflow publishes

When a valid `vMAJOR.MINOR.PATCH` tag is pushed, GitHub Actions:

- generates release notes with git-cliff;
- builds and validates the canonical source ZIP using
  `scripts/package-source-zip.sh` (no `.git/` directory; tracked executable
  modes retained);
- creates a SHA-256 checksum file;
- publishes a GitHub Release with the source ZIP, checksum, and generated notes.

The existing hand-maintained `CHANGELOG.md` is not overwritten by automation.
For the first tagged release, because this repository's historical `1.3.8`
entry is not itself a Git tag, the workflow uses the curated
`CHANGELOG.md` `[Unreleased]` section rather than dumping the entire Git
history. After a first version tag exists, git-cliff generates notes from the
commits since the previous matching version tag.

## Version rules

- `feat:` → minor version.
- `fix:` and other changes not excluded by the bump rules → patch version.
- Conventional breaking changes (for example, `feat!:`) → major version.
- Documentation, style, test, chore, CI, and build-only commits do not bump the
  version by themselves.

The parser includes an `Other Changes` group so non-Conventional commits are
not silently omitted from release notes. Prefer Conventional Commit messages
for future commits to keep both grouping and version suggestions predictable.
