# Development shell for working on the NixOS config
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    nixpkgs-fmt   # Nix code formatter
    statix        # Lint and analyse Nix code
    shellcheck    # Shell script analysis
    nodePackages.prettier  # For formatting CSS / JSON
  ];

  shellHook = ''
    echo "🔧 NixOS configuration development shell"
    echo "   Format Nix files:    nixpkgs-fmt *.nix"
    echo "   Lint Nix files:      statix check"
    echo "   Check shell scripts: shellcheck install.sh"
  '';
}
