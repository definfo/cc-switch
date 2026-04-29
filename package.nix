{
  lib,
  stdenv,
  rustPlatform,
  fetchPnpmDeps,
  pnpmConfigHook,
  pnpm_10,
  pkg-config,
  cargo-tauri,
  wrapGAppsHook3,
  nodejs,
  openssl,
  libsoup_3,
  webkitgtk_4_1,
  libayatana-appindicator,
  jq,
  moreutils,
  nix-update-script,
}:
let
  pnpm = pnpm_10.override { inherit nodejs; };
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "cc-switch";
  version = "3.14.0";

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

  checkFlags = map (t: "--skip ${t}") [
    # need network connection
  ];

  # Set our Tauri source directory
  cargoRoot = "src-tauri";
  # And make sure we build there too
  buildAndTestSubdir = finalAttrs.cargoRoot;

  passthru.updateScript = nix-update-script { extraArgs = [ "--version-regex=v(.*)" ]; };

  meta = {
    description = "An assistant tool for SJTU Canvas online course platform";
    homepage = "https://github.com/Okabe-Rintarou-0/SJTU-Canvas-Helper";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
    maintainers = with lib.maintainers; [ definfo ];
  };
})
