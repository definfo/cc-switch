{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-compat = {
      url = "github:roberth/flake-compat?rev=9680a5107f974df5a01d7fcd77a1ebe90cf5a8ee";
      flake = false;
    };
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-compat,
      flake-parts,
      rust-overlay,
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      perSystem =
        {
          config,
          pkgs,
          lib,
          system,
          ...
        }:
        let
          inherit (pkgs)
            lib
            stdenv
            rustPlatform
            fetchPnpmDeps
            pnpmConfigHook
            pkg-config
            cargo-tauri
            wrapGAppsHook3
            openssl
            libsoup_3
            webkitgtk_4_1
            libayatana-appindicator
            jq
            moreutils
          ;
          nodejs = pkgs.nodejs;
          pnpm = pkgs.pnpm_10;

          metadata = lib.importJSON ./package.json;

          cc-switch = rustPlatform.buildRustPackage (finalAttrs: {
            pname = metadata.name;
            inherit (metadata) version;
  
            src = lib.fileset.toSource {
              root = ./.;
              fileset = lib.fileset.unions [
                ./assets
                ./cc-switch-main
                # ./scripts
                ./src
                ./src-tauri
                ./tests
                ./components.json
                ./deplink.html
                ./LICENSE
                ./package.json
                ./pnpm-lock.yaml
                ./pnpm-workspace.yaml
                ./postcss.config.cjs
                ./tailwind.config.cjs
                ./tsconfig.json
                ./tsconfig.node.json
                ./vite.config.ts
                ./vitest.config.ts
              ];
            };
            strictDeps = true;

            cargoLock.lockFile = ./src-tauri/Cargo.lock;

            pnpmDeps = fetchPnpmDeps {
              inherit (finalAttrs)
                pname
                version
                src
                patches
                ;
              inherit pnpm;
              fetcherVersion = 3;
              hash = "sha256-kEobCKS7If66ViSClqpU9xQFjH9YYhj4yvI7+/8SFPg=";
            };

            postPatch = ''
              substituteInPlace $cargoDepsCopy/libappindicator-sys-*/src/lib.rs \
                --replace-fail "libayatana-appindicator3.so.1" "${libayatana-appindicator}/lib/libayatana-appindicator3.so.1"

              ${lib.getExe jq} '
                .bundle = (.bundle // {}) |
                .bundle.createUpdaterArtifacts = false |
                del(.plugins.updater)
              ' src-tauri/tauri.conf.json \
                | ${lib.getExe' moreutils "sponge"} src-tauri/tauri.conf.json
            '';

            nativeBuildInputs = [
              cargo-tauri.hook
              pkg-config
              pnpmConfigHook
              rustPlatform.bindgenHook
              nodejs
              pnpm
            ] ++ lib.optionals stdenv.hostPlatform.isLinux [ wrapGAppsHook3 ];

            buildInputs = [
              openssl
              libsoup_3
              webkitgtk_4_1
              libayatana-appindicator
            ];

            cargoRoot = "src-tauri";
            buildAndTestSubdir = finalAttrs.cargoRoot;

            meta = {
              license = lib.licenses.mit;
              platforms = lib.platforms.linux ++ lib.platforms.darwin;
              maintainers = with lib.maintainers; [ definfo ];
            };
          });
        in
        {
          _module.args.pkgs = import nixpkgs {
            inherit system;
            overlays = [
              rust-overlay.overlays.default
              (_final: prev: {
                rustToolchain =
                  let
                    rust = prev.rust-bin;
                  in
                  if builtins.pathExists ./rust-toolchain.toml then
                    rust.fromRustupToolchainFile ./rust-toolchain.toml
                  else if builtins.pathExists ./rust-toolchain then
                    rust.fromRustupToolchainFile ./rust-toolchain
                  else
                    rust.stable.latest.default.override {
                      extensions = [
                        "rust-src"
                        "rust-analyzer"
                      ];
                      # targets = [ "arm-unknown-linux-gnueabihf" ];
                    };
              })
            ];
          };


          devShells.default = pkgs.mkShell {
            shellHook = ''
              echo 1>&2 "Welcome to the development shell!"
            '';

            packages =
              with pkgs;
              [
                ### Rust toolchain ###
                rustToolchain
                openssl
                pkg-config
                # rustPlatform.bindgenHook
                cargo-tauri

                ### Node.js ###
                nodejs
                pnpm_10
                

                ### Deps ###
                glib
                gdk-pixbuf
                at-spi2-atk
                pango
                gtk3
                libsoup_3
                webkitgtk_4_1
                libayatana-appindicator

                ### Miscellaneous ###
                # cargo-audit
                # cargo-bloat
                # cargo-license
                # cargo-nextest
                # cargo-outdated
                # cargo-show-asm
                # samply
                # watchexec
                # bacon
              ]
              ++ lib.optionals (!pkgs.stdenv.isDarwin) [
                # cargo-llvm-cov
                # valgrind
              ];
          };

          packages.default = config.packages.cc-switch;
          packages.cc-switch = cc-switch;
        };
    };
}
