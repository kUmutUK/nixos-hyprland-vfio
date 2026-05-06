# Contributing

Thank you for considering a contribution to this project!

## How to contribute

1. Fork the repository.
2. Create a new branch for your feature or bugfix.
3. Make your changes, ensure they follow the existing structure.
4. Test your changes locally:
   ```bash
   nix flake check
   nixos-rebuild dry-activate --flake .#nixos
