# Contributing

Thank you for contributing to the project.

---

# Development Guidelines

## Workflow

1. Fork the repository
2. Create a feature branch
3. Make changes
4. Test locally
5. Open a Pull Request

---

# Validation

Run before submitting changes:

```bash
nix flake check
sudo nixos-rebuild dry-activate --flake .#nixos
```

---

# Style Guidelines

## Nix

- Use 2-space indentation
- Format with `nixpkgs-fmt`

```bash
nixpkgs-fmt .
```

## Shell

- Keep scripts POSIX-compliant where possible
- Run shellcheck

```bash
shellcheck install.sh
```

---

# Project Philosophy

This project follows a declarative-first approach.

All system configuration should be managed through Nix whenever possible.

Avoid:

- manual state mutation
- imperative package installs
- runtime patching

---

# Pull Requests

Please include:

- clear description
- screenshots if UI-related
- logs if bugfix-related
- reproduction steps

---

# Bug Reports

Include:

- NixOS version
- kernel version
- GPU model
- relevant logs

## Useful Logs

```bash
journalctl -u libvirtd
```

```bash
cat /var/log/libvirt/vfio.log
```

---

# Thank You

All contributions are welcome.
