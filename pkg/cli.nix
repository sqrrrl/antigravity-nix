{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  autoPatchelfHook,
  zlib
}:

stdenv.mkDerivation rec {
  pname = "google-antigravity-cli";
  version = "1.0.1-5826024320139264";

  src = fetchurl {
    url = "https://storage.googleapis.com/antigravity-public/antigravity-cli/${version}/linux-x64/cli_linux_x64.tar.gz";
    sha256 = "sha256-gfoD752FdtCLTMAEjdvtKdPUangB+LRDqTVHHdnAbb4=";
  };

  nativeBuildInputs = [ makeWrapper autoPatchelfHook ];
  buildInputs = [ zlib stdenv.cc.cc.lib ];

  sourceRoot = ".";

  installPhase = ''
    mkdir -p $out/bin
    cp antigravity $out/bin/agy
    chmod +x $out/bin/agy
  '';

  meta = with lib; {
    description = "Google Antigravity CLI";
    homepage = "https://antigravity.google";
    license = licenses.unfree;
    platforms = platforms.linux;
    maintainers = [];
    mainProgram = "agy";
  };
}
