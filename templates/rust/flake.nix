{
  description = "Rust (cargo, clippy, rust-analyzer, sccache)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs =
    {
      nixpkgs,
      rust-overlay,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ rust-overlay.overlays.default ];
      };
      # Single source of truth for the Rust version: rust-toolchain.toml.
      # Set channel there ("stable", "1.85.0", "nightly") to pin it.
      rustToolchain = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = [
          rustToolchain
          pkgs.sccache
        ];

        # Shared compilation cache across builds/projects (~/.cache/sccache).
        # Incremental must be off for sccache to cache.
        RUSTC_WRAPPER = "${pkgs.sccache}/bin/sccache";
        CARGO_INCREMENTAL = "0";
      };
    };
}
