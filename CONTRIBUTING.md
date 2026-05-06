# 🤝 Contributing

Thank you for considering a contribution to this project!

---

## 🚀 How to Contribute

1. **Fork** the repository
2. Create a new branch for your feature or bugfix
3. Make your changes and follow the existing structure
4. Test your changes locally:

```bash
nix flake check
sudo nixos-rebuild dry-activate --flake .#nixos
```

5. Commit using **descriptive messages**
6. Push to your fork and open a **Pull Request**

---

## 🧹 Code Style

* Use **2-space indentation** for Nix files
* Format Nix code with `nixpkgs-fmt`
* Keep shell scripts **POSIX-compliant** where possible
* Run `shellcheck` on scripts
* Maintain the **declarative approach** — all configs should be managed by Nix

---

## 🐞 Reporting Issues

Please include:

* NixOS version:

  ```bash
  nixos-version
  ```
* Kernel version:

  ```bash
  uname -r
  ```
* Relevant logs:

  ```bash
  journalctl -u libvirtd
  cat /var/log/libvirt/vfio.log
  ```

---

## ❤️ Final Notes

All contributions are welcome — whether it's a typo fix or a new feature!
