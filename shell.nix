{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    nixpkgs-fmt
    statix
    shellcheck
    nodePackages.prettier
  ];

  shellHook = ''
    echo "🔧 NixOS configuration development shell"
    echo "   Format Nix files:    nixpkgs-fmt *.nix"
    echo "   Lint Nix files:      statix check"
    echo "   Check shell scripts: shellcheck install.sh"
  '';
}
