{
  description = "Description for the project";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    cairo-nix.url = "github:0xmugen/cairo-nix";
    devshell.url = "github:numtide/devshell";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = inputs @ { flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.devshell.flakeModule ];

      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];

      perSystem = { system, inputs', ... }:
      let
        pkgs = import inputs.nixpkgs {
          inherit system;
          overlays = [ inputs.rust-overlay.overlays.default ];
        };
        rust = pkgs.rust-bin.nightly."2025-04-05".default.override {
          extensions = [ "rust-src" "rustfmt" "clippy" ];
          targets    = [ "wasm32-unknown-unknown" ];
        };
      in {
        devshells.default = {
          packages = [
            # Scarb bundle from cairo-nix (includes Cairo CLI + corelib)
            inputs'.cairo-nix.packages.scarb
            inputs'.cairo-nix.packages.starkli

            # Pinned Rust toolchain (includes rustc + cargo)
            rust
            pkgs.bun
          ];

          env = [
            {
              name = "PATH";
              eval = "$PWD/stwo-cairo/cairo-prove/target/release:$PWD/.starknet-foundry/target/release:$PATH";
            }
          ];
        };
      };
      flake = { };
    };
}
