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
# flake nixos/ altında — cd nixos'tan sonra yol ".#nixos" olur
cd nixos
nix eval .#nixosConfigurations.nixos.config.system.build.toplevel.drvPath
sudo nixos-rebuild dry-activate --flake .#nixos
```

**CI aynısını otomatik yapıyor.** `.github/workflows/check.yml` artık
`nix flake check --no-build` çalıştırıyor — yani bir option adı yanlış yazılırsa
(`xwaylan.enable`, `services.lsfg-vk`…) PR merge olmadan
kırılıyor. Bu adım 2026-10-05'te eklendi; o tarihten önce CI'de **hiç Nix
çalışmıyordu**, sadece shellcheck vardı.

---

# 🎨 Style Guidelines

## Nix

- 2-space indentation
- Use `nixfmt` (devShell'de `pkgs.nixfmt` olarak gelir)

```bash
nix develop ./nixos
nixfmt .
```

> `nixpkgs-fmt` **kullanmayın** — RFC-166 stiliyle biçimlendirir ve aynı dosyayı
> iki kişi farklı biçimde kaydedebilir. Kökteki `shell.nix` tam olarak bu
> belirsizliği yaratıyordu; 2026-10-05'te silindi.

## Shell

- Prefer POSIX compliance
- Validate with shellcheck

```bash
shellcheck -S warning install.sh nixos/hooks/qemu
```

> `home.nix` içine gömülü script'ler doğrudan taranamaz. Onları çıkarmak için:
>
> ```bash
> python3 scripts/extract-embedded-scripts.py /tmp/emb | xargs -0 -n1 -- shellcheck -S warning
> ```
>
> CI bunu otomatik yapıyor. Manuel değişiklikten sonra çalıştırmazsan
> CI yakalar — ama iki tur beklemek istemiyorsan elle de koş.

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
