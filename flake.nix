{
  description = "zk-100";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    cairo-nix.url = "github:knownasred/cairo-nix";
    devshell.url = "github:numtide/devshell";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        inputs.devshell.flakeModule
      ];

      systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin"];
      perSystem = {
        config,
        self',
        inputs',
        pkgs,
        system,
        ...
      }: let
        pkgs = import inputs.nixpkgs {
          inherit system;
          overlays = [ inputs.rust-overlay.overlays.default ];
        };
        
        # Download pre-built scarb 2.12.0 binary
        scarb-bin = pkgs.stdenv.mkDerivation rec {
          pname = "scarb";
          version = "2.12.0";
          
          src = pkgs.fetchurl {
            url = "https://github.com/software-mansion/scarb/releases/download/v${version}/scarb-v${version}-x86_64-unknown-linux-gnu.tar.gz";
            sha256 = "sha256-awd7Qz5f7wGdDdz4OkZSEtftLzkGQhmvMWrWtBEVhX8=";
          };
          
          nativeBuildInputs = [ pkgs.autoPatchelfHook ];
          
          buildInputs = [
            pkgs.stdenv.cc.cc.lib
            pkgs.zlib
          ];
          
          sourceRoot = ".";
          
          installPhase = ''
            mkdir -p $out/bin
            install -m755 scarb-v${version}-x86_64-unknown-linux-gnu/bin/scarb $out/bin/
          '';
        };
        
        # Wrap scarb for NixOS compatibility
        scarb-wrapped = pkgs.buildFHSEnv {
          name = "scarb";
          targetPkgs = pkgs: [ scarb-bin ];
          runScript = "scarb";
        };
      in {
        # Per-system attributes can be defined here. The self' and inputs'
        # module parameters provide easy access to attributes of the same
        # system.

        # Equivalent to  inputs'.nixpkgs.legacyPackages.hello;
        devshells.default = {
          packages = [
            # Use wrapped scarb 2.12.0
            scarb-wrapped
            inputs'.cairo-nix.packages.starkli

            # Use Rust nightly for stwo-cairo
            (pkgs.rust-bin.nightly."2025-04-06".default.override {
              extensions = [ "rust-src" ];
              targets = [ "wasm32-unknown-unknown" ];
            })
          ];

          env = [
            {
              name = "PATH";
              eval = "$PWD/stwo-cairo/cairo-prove/target/release:$PATH";
            }
          ];
        };
      };

      flake = {
        # The usual flake attributes can be defined here, including system-
        # agnostic ones like nixosModule and system-enumerating ones, although
        # those are more easily expressed in perSystem.
      };
    };
}