{
  lib,
  stdenv,
  darwin,
  rustPlatform,
  runCommand,
  zig_0_16,
  pkg-config,
  clang,
  libclang,
  makeWrapper,
  makeDesktopItem,
  copyDesktopItems,
  fontconfig,
  freetype,
  libxcb,
  libxkbcommon,
  wayland,
  vulkan-loader,
  mesa,
  xdg-utils,
  ghostty,
}:
let
  version = (lib.importTOML ../Cargo.toml).package.version;
  runtimeDependencies = [
    fontconfig
    freetype
    libxcb
    libxkbcommon
    wayland
    vulkan-loader
  ];
  zigDeps =
    if stdenv.hostPlatform.isDarwin then
      runCommand "herdr-ghostty-zig-deps"
        {
          nativeBuildInputs = [ zig_0_16 ];
          outputHashMode = "recursive";
          outputHash = "sha256-fELTGrVyRIAbXGClAz8+czPbgAfZYR3yP9Hsk/6UiIQ=";
        }
        ''
          export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-cache"
          mkdir -p "$ZIG_GLOBAL_CACHE_DIR/tmp"
          cp -R ${ghostty} ghostty
          chmod -R u+w ghostty
          cd ghostty
          # Preserve the pinned commit and package hash while avoiding Codeberg outages.
          substituteInPlace pkg/translate-c/build.zig.zon \
            --replace-fail 'https://codeberg.org/vancluever/translate-c/archive/' \
                           'https://github.com/moderatelyConfused/translate-c/archive/'
          zig build --fetch -Demit-lib-vt -Demit-xcframework=false -Doptimize=ReleaseFast
          mv "$ZIG_GLOBAL_CACHE_DIR/p" "$out"
        ''
    else
      zig_0_16.fetchDeps {
        pname = "herdr-ghostty";
        version = ghostty.shortRev;
        src = ghostty;
        fetchAll = true;
        hash = "sha256-G9xbZ/pyQTDIfzG0h++i70a45zpwyYpZMBZfAnoOQw0=";
      };
in
rustPlatform.buildRustPackage {
  pname = "herdr-app";
  inherit version;
  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../Cargo.toml
      ../Cargo.lock
      ../build.rs
      ../CHANGELOG.md
      ../LICENSE
      ../THIRD-PARTY-NOTICES
      ../scripts/fixtures
      ../assets
      ../crates
      ../defaults
      ../distribution/core-version
      ../src
      ../shell
      ../tests
      ../vendor
    ];
  };

  cargoLock = {
    lockFile = ../Cargo.lock;
    outputHashes = {
      "llrt_buffer-0.9.0-beta" = "sha256-Iu7AAEeCmfPSYPgkR3JXVUi7BYubaAhU5YDApo7LaMQ=";
      "quickjs-jit-core-0.12.11" = "sha256-4izRB3HxCd9r1ZV/Na6dVmVwEPtX3vFMM1JRp9zu8Go=";
      "quickjs-jit-stdlib-0.12.7" = "sha256-eJuDUwZvmnrlNsGD15ZwhOzz6O4wi9dtc/yUH0nIf0A=";
    };
  };

  nativeBuildInputs = [
    pkg-config
    clang
    rustPlatform.bindgenHook
    zig_0_16
    makeWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ copyDesktopItems ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [ darwin.cctools ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux runtimeDependencies;
  LIBCLANG_PATH = "${lib.getLib libclang}/lib";

  # Cargo invokes Zig through ghostty-sys, not through Nix's Zig phases.
  dontUseZigConfigure = true;
  dontUseZigBuild = true;
  dontUseZigCheck = true;
  dontUseZigInstall = true;

  postUnpack = ''
    mkdir -p "$sourceRoot/vendor/ghostty"
    cp -R ${ghostty}/. "$sourceRoot/vendor/ghostty/"
    chmod -R u+w "$sourceRoot/vendor/ghostty"
  '';

  preBuild = ''
    export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-cache"
    mkdir -p "$ZIG_GLOBAL_CACHE_DIR"
    ln -s ${zigDeps} "$ZIG_GLOBAL_CACHE_DIR/p"
  '';

  # Linux's headless pixel test uses Mesa's software Vulkan driver.
  doCheck = stdenv.hostPlatform.isLinux;
  # Unit tests need debug-only UI instrumentation and write to /var/tmp.
  # Run those with `nix develop --command just test`, outside the build sandbox.
  cargoTestFlags = [
    "--test"
    "commands"
    "--test"
    "skill"
    "--test"
    "shot_pixels"
  ];
  preCheck = lib.optionalString stdenv.hostPlatform.isLinux ''
    export VK_DRIVER_FILES=${mesa}/share/vulkan/icd.d/lvp_icd.${stdenv.hostPlatform.parsed.cpu.name}.json
    export LD_LIBRARY_PATH=${lib.makeLibraryPath runtimeDependencies}
    export XDG_RUNTIME_DIR="$TMPDIR/runtime"
    mkdir -p "$XDG_RUNTIME_DIR"
    chmod 700 "$XDG_RUNTIME_DIR"
  '';

  desktopItems = lib.optionals stdenv.hostPlatform.isLinux [
    (makeDesktopItem {
      name = "herdr-app";
      desktopName = "Herdr";
      comment = "Terminals and coding agents that keep running";
      exec = "herdr-app";
      icon = "herdr-app";
      terminal = false;
      categories = [ "Development" ];
      startupWMClass = "herdr-app";
    })
  ];

  postInstall = ''
    install -Dm644 shell/herdr.zsh "$out/share/herdr-app/shell/herdr.zsh"
  ''
  + lib.optionalString stdenv.hostPlatform.isLinux ''
    install -Dm644 assets/icons/herdr-ui-icon-clean.svg \
      "$out/share/icons/hicolor/scalable/apps/herdr-app.svg"
    wrapProgram "$out/bin/herdr-app" \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeDependencies} \
      --suffix PATH : ${lib.makeBinPath [ xdg-utils ]}
  ''
  + lib.optionalString stdenv.hostPlatform.isDarwin ''
    app="$out/Applications/Herdr.app"
    mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
    mv "$out/bin/herdr-app" "$app/Contents/MacOS/Herdr"
    cp ${./Info.plist} "$app/Contents/Info.plist"
    substituteInPlace "$app/Contents/Info.plist" --replace-fail '@version@' '${version}'
    cp assets/icons/Herdr.icns LICENSE THIRD-PARTY-NOTICES "$app/Contents/Resources/"
    ln -s "$app/Contents/MacOS/Herdr" "$out/bin/herdr-app"
  '';

  postFixup = lib.optionalString stdenv.hostPlatform.isDarwin ''
    /usr/bin/codesign --force --sign - "$out/Applications/Herdr.app"
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/herdr-app" --help > /dev/null
    "$out/bin/herdr-app" --skill > /dev/null
    ${lib.optionalString stdenv.hostPlatform.isDarwin ''
      test -x "$out/Applications/Herdr.app/Contents/MacOS/Herdr"
      /usr/bin/plutil -lint "$out/Applications/Herdr.app/Contents/Info.plist"
      /usr/bin/codesign --verify --deep --strict "$out/Applications/Herdr.app"
    ''}
    runHook postInstallCheck
  '';

  passthru = { inherit runtimeDependencies zigDeps; };
  meta = {
    description = "Desktop app for terminals and coding agents";
    homepage = "https://github.com/herdrdev/herdr-app";
    license = lib.licenses.asl20;
    mainProgram = "herdr-app";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];
  };
}
