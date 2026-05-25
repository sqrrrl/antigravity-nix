{
  lib,
  stdenv,
  fetchurl,
  buildFHSEnv,
  autoPatchelfHook,
  makeWrapper,
  writeShellScript,
  zlib,
  useFHS ? true,
}: let
  pname = "google-antigravity-cli";
  version = "1.0.1-5826024320139264";

  finalSrc = fetchurl {
    url = "https://storage.googleapis.com/antigravity-public/antigravity-cli/${version}/linux-x64/cli_linux_x64.tar.gz";
    sha256 = "sha256-gfoD752FdtCLTMAEjdvtKdPUangB+LRDqTVHHdnAbb4=";
  };

  meta = with lib; {
    description = "Google Antigravity CLI";
    homepage = "https://antigravity.google";
    license = licenses.unfree;
    platforms = platforms.linux;
    maintainers = [];
    mainProgram = "agy";
  };

  # Extract the upstream tarball without modification
  cli-unwrapped = stdenv.mkDerivation {
    inherit pname version;
    src = finalSrc;

    dontBuild = true;
    dontConfigure = true;
    dontPatchELF = true;
    dontStrip = true;

    sourceRoot = ".";

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin
      cp antigravity $out/bin/agy
      chmod +x $out/bin/agy

      runHook postInstall
    '';

    inherit meta;
  };

  # FHS environment for running the CLI
  fhs = buildFHSEnv {
    name = "agy-fhs";
    targetPkgs = pkgs: [
      zlib
      stdenv.cc.cc.lib
    ];

    runScript = writeShellScript "agy-wrapper" ''
      exec ${cli-unwrapped}/bin/agy "$@"
    '';

    inherit meta;
  };

  fhs-package = stdenv.mkDerivation {
    inherit pname version meta;

    dontUnpack = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin
      ln -s ${fhs}/bin/agy-fhs $out/bin/agy

      runHook postInstall
    '';
  };

  no-fhs-package = stdenv.mkDerivation {
    inherit pname version meta;
    src = finalSrc;

    nativeBuildInputs = [
      autoPatchelfHook
      makeWrapper
    ];

    buildInputs = [
      zlib
      stdenv.cc.cc.lib
    ];

    dontBuild = true;
    dontConfigure = true;

    sourceRoot = ".";

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin
      cp antigravity $out/bin/agy
      chmod +x $out/bin/agy

      runHook postInstall
    '';
  };
in
  if useFHS
  then fhs-package
  else no-fhs-package
