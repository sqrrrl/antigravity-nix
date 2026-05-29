{
  lib,
  stdenv,
  fetchurl,
  buildFHSEnv,
  autoPatchelfHook,
  makeDesktopItem,
  copyDesktopItems,
  makeWrapper,
  writeShellScript,
  bash,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  chromium,
  cups,
  dbus,
  expat,
  glib,
  gtk3,
  libdrm,
  libgbm,
  libglvnd,
  libnotify,
  libsecret,
  libuuid,
  libxkbcommon,
  nspr,
  nss,
  pango,
  systemdLibs,
  vulkan-loader,
  libx11,
  libxscrnsaver,
  libxcomposite,
  libxcursor,
  libxdamage,
  libxext,
  libxfixes,
  libxi,
  libxrandr,
  libxrender,
  libxtst,
  libxcb,
  libxshmfence,
  libxkbfile,
  zlib,
  useFHS ? true,
  useSystemChromeProfile ? true,
  google-chrome ? null,
  extraBwrapArgs ? [],
  srcOverride ? null,
}: let
  pname = "google-antigravity-hub";
  version = "2.0.10-5119448496078848";

  isAarch64 = stdenv.hostPlatform.system == "aarch64-linux";

  browserPkg =
    if isAarch64
    then chromium
    else if google-chrome != null
    then google-chrome
    else
      throw ''
        google-chrome is required on ${stdenv.hostPlatform.system} builds.
        Make sure you have allowUnfree = true or pass a google-chrome package.
      '';

  browserCommand =
    if isAarch64
    then "chromium"
    else "google-chrome-stable";

  browserProfileDir =
    if isAarch64
    then "$HOME/.config/chromium"
    else "$HOME/.config/google-chrome";

  finalSrc =
    if srcOverride != null
    then srcOverride
    else
      fetchurl {
        url = "https://storage.googleapis.com/antigravity-public/antigravity-hub/${version}/linux-x64/Antigravity.tar.gz";
        sha256 = "sha256-EtpgukOuoxKItexk2JqrcPYf2yogwMtbYQwg6DtkbjI=";
      };

  # Create a browser wrapper
  chrome-wrapper = writeShellScript "${browserCommand}-with-profile" ''
    set -euo pipefail

    system_browser="/run/current-system/sw/bin/${browserCommand}"
    browser_cmd="$system_browser"

    if [ ! -x "$system_browser" ]; then
      browser_cmd=${browserPkg}/bin/${browserCommand}
    fi

    exec "$browser_cmd" \
      ${lib.optionalString useSystemChromeProfile ''--user-data-dir="${browserProfileDir}" --profile-directory=Default''} \
      "$@"
  '';

  dlopenLibs = [
    libglvnd
    vulkan-loader
    systemdLibs
    libnotify
    libsecret
  ];

  linkedLibs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    glib
    gtk3
    libdrm
    libgbm
    libuuid
    libxkbcommon
    nspr
    nss
    pango
    stdenv.cc.cc.lib
    libx11
    libxscrnsaver
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxrandr
    libxrender
    libxtst
    libxcb
    libxshmfence
    libxkbfile
    zlib
  ];

  runtimeLibs = linkedLibs ++ dlopenLibs;

  desktopItem = makeDesktopItem {
    name = "antigravity";
    desktopName = "Google Antigravity Hub";
    comment = "Next-generation agentic Hub";
    exec = "antigravity --enable-features=UseOzonePlatform,WaylandWindowDecorations --ozone-platform-hint=auto --enable-wayland-ime=true --wayland-text-input-version=3 %U";
    icon = "antigravity";
    categories = ["Development"];
    startupNotify = true;
    startupWMClass = "Antigravity";
    mimeTypes = [
      "x-scheme-handler/antigravity"
    ];
  };

  meta = with lib; {
    description = "Google Antigravity Hub";
    homepage = "https://antigravity.google";
    license = licenses.unfree;
    platforms = platforms.linux;
    maintainers = [];
    mainProgram = "antigravity";
  };

  antigravity-unwrapped = stdenv.mkDerivation {
    inherit pname version;
    src = finalSrc;

    dontBuild = true;
    dontConfigure = true;
    dontPatchELF = true;
    dontStrip = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/antigravity
      cp -r ./* $out/lib/antigravity/

      runHook postInstall
    '';

    inherit meta;
  };

  fhs = buildFHSEnv {
    name = "antigravity-hub-fhs";
    targetPkgs = pkgs:
      runtimeLibs
      ++ [
        pkgs.udev
        pkgs.libudev0-shim
      ]
      ++ lib.optional (browserPkg != null) browserPkg;

    extraBwrapArgs = [
      "--bind-try /etc/nixos/ /etc/nixos/"
      "--ro-bind-try /etc/xdg/ /etc/xdg/"
      "--ro-bind-try /etc/nixpkgs/ /etc/nixpkgs/"
    ] ++ extraBwrapArgs;

    runScript = writeShellScript "antigravity-wrapper" ''
      export CHROME_BIN=${chrome-wrapper}
      export CHROME_PATH=${chrome-wrapper}

      exec ${antigravity-unwrapped}/lib/antigravity/antigravity "$@"
    '';

    inherit meta;
  };

  fhs-package = stdenv.mkDerivation {
    inherit pname version meta;

    dontUnpack = true;
    dontBuild = true;

    nativeBuildInputs = [copyDesktopItems];

    desktopItems = [desktopItem];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin
      ln -s ${fhs}/bin/antigravity-hub-fhs $out/bin/antigravity

      runHook postInstall
    '';
  };

  no-fhs-package = stdenv.mkDerivation {
    inherit pname version meta;
    src = finalSrc;

    nativeBuildInputs = [
      autoPatchelfHook
      makeWrapper
      copyDesktopItems
    ];

    buildInputs = runtimeLibs;

    runtimeDependencies = dlopenLibs;

    autoPatchelfIgnoreMissingDeps = [
      "libwebkit2gtk-4.1.so.0"
      "libsoup-3.0.so.0"
      "libcurl.so.4"
      "libcrypto.so.3"
    ];

    dontBuild = true;
    dontConfigure = true;

    desktopItems = [desktopItem];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/antigravity
      cp -r ./* $out/lib/antigravity/

      mkdir -p $out/bin
      makeWrapper $out/lib/antigravity/antigravity $out/bin/antigravity \
        --set CHROME_BIN ${chrome-wrapper} \
        --set CHROME_PATH ${chrome-wrapper}

      runHook postInstall
    '';
  };
in
  if useFHS
  then fhs-package
  else no-fhs-package
