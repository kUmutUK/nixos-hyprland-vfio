# 🤝 Contributing

Thank you for contributing to this project.

---

# 🚀 Workflow

1. Fork the repository  
2. Create a feature branch  
   ```bash
   git checkout -b feature/my-change
   ```
3. Make changes  
4. Test locally  
5. Open a Pull Request  

---

# 🧪 Validation

Before submitting changes:

```bash
nix flake check
sudo nixos-rebuild dry-activate --flake .#nixos
```

---

# 🎨 Style Guidelines

## Nix

- 2-space indentation
- Use `nixpkgs-fmt`

```bash
nixpkgs-fmt .
```

## Shell

- Prefer POSIX compliance
- Validate with shellcheck

```bash
shellcheck install.sh
```

---

# 🧠 Philosophy

This project is **declarative-first**.

Avoid:

- manual system changes
- imperative package installs
- runtime patching

Everything should be reproducible via Nix flakes.

---

# 📦 Pull Requests

Include:

- Clear description
- What changed & why
- Logs (if needed)
- Screenshots (if UI related)
- Reproduction steps (if bug fix)

---

# 🐞 Bug Reports

Include:

- NixOS version
- kernel version
- GPU model
- relevant logs

---

# 🙌 Thanks

All contributions are welcome.
