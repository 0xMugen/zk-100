{
  description = "S-Two Cairo Prover Development Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, rust-overlay, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };

        # Define Rust toolchain based on cairo-prove requirements
        rustToolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = [ "rust-src" "rust-analyzer" ];
        };

        # Scarb package definition
        scarb = pkgs.stdenv.mkDerivation rec {
          pname = "scarb";
          version = "2.10.0";
          
          src = pkgs.fetchurl {
            url = "https://github.com/software-mansion/scarb/releases/download/v${version}/scarb-v${version}-${pkgs.stdenv.hostPlatform.system}.tar.gz";
            sha256 = ""; # Will need to be filled with actual hash
          };

          installPhase = ''
            mkdir -p $out/bin
            cp scarb $out/bin/
            chmod +x $out/bin/scarb
          '';
        };

      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Rust toolchain
            rustToolchain
            pkg-config
            openssl
            
            # Build tools
            gcc
            gnumake
            cmake
            
            # Cairo and S-Two dependencies
            scarb
            
            # Version control
            git
            
            # Development utilities
            ripgrep
            fd
            jq
            
            # Python (for any scripts)
            python3
            python3Packages.pip
            
            # ASDF for Scarb management (optional)
            asdf-vm
          ];

          shellHook = ''
            echo "S-Two Cairo Prover Development Environment"
            echo "==========================================="
            echo ""
            echo "Rust version: $(rustc --version)"
            echo "Cargo version: $(cargo --version)"
            echo ""
            echo "To get started:"
            echo "  1. Clone the S-Two Cairo repository:"
            echo "     git clone https://github.com/starkware-libs/stwo-cairo.git"
            echo "  2. Navigate to cairo-prove directory:"
            echo "     cd stwo-cairo/cairo-prove"
            echo "  3. Build the project:"
            echo "     ./build.sh"
            echo "  4. Install cairo-prove to PATH (optional):"
            echo "     sudo cp target/release/cairo-prove /usr/local/bin/"
            echo ""
            echo "For the latest Scarb nightly:"
            echo "  asdf plugin add scarb"
            echo "  asdf install scarb latest:nightly"
            echo "  asdf set -u scarb latest:nightly"
            echo ""
            
            # Set up environment variables
            export RUST_SRC_PATH="${rustToolchain}/lib/rustlib/src/rust/library"
          '';

          # Environment variables
          OPENSSL_NO_VENDOR = 1;
          RUST_BACKTRACE = 1;
        };
      });
}