{
  description = "Google Antigravity - Next-generation agentic IDE (Nix package)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      in {
        packages = {
          default = pkgs.callPackage ./pkg/hub.nix {};
          google-antigravity = pkgs.callPackage ./pkg/hub.nix {};
          google-antigravity-no-fhs = pkgs.callPackage ./pkg/hub.nix {useFHS = false;};

          google-antigravity-ide = pkgs.callPackage ./pkg/ide.nix {};
          google-antigravity-ide-no-fhs = pkgs.callPackage ./pkg/ide.nix {useFHS = false;};

          google-antigravity-cli = pkgs.callPackage ./pkg/cli.nix {};
          google-antigravity-cli-no-fhs = pkgs.callPackage ./pkg/cli.nix {useFHS = false;};
        };

        # Development shell for working on this flake
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nix
            git
            curl
            jq
            gh
            nodejs_20
          ];

          shellHook = ''
            echo "Antigravity development environment"
            echo "Available commands:"
            echo "  ./scripts/check-version.sh  - Check current vs latest version"
            echo "  ./scripts/update-version.sh - Update to latest version"
            echo ""
            echo "First time setup:"
            echo "  npm install  - Install playwright-chromium locally"
            echo ""
            echo "Note: Requires google-chrome-stable to be installed system-wide for browser automation"
          '';
        };
      }
    )
    // {
      # Version information for auto-update
      version = "2.0.6-5413878570549248";
      ide_version = "2.0.3-6242596486512640";
      cli_version = "1.0.3-6260531212976128";

      # Overlay for easy integration into NixOS configurations
      overlays.default = final: prev: {
        google-antigravity = final.callPackage ./pkg/hub.nix {};
        google-antigravity-no-fhs = final.callPackage ./pkg/hub.nix {useFHS = false;};
        google-antigravity-ide = final.callPackage ./pkg/ide.nix {};
        google-antigravity-ide-no-fhs = final.callPackage ./pkg/ide.nix {useFHS = false;};
        google-antigravity-cli = final.callPackage ./pkg/cli.nix {};
        google-antigravity-cli-no-fhs = final.callPackage ./pkg/cli.nix {useFHS = false;};
      };
    };
}
