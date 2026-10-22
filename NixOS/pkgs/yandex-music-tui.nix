{ lib, buildGoModule, fetchFromGitHub, pkg-config, alsa-lib }:

buildGoModule rec {
  pname = "yandex-music-tui";
  version = "0.8.0";

  src = fetchFromGitHub {
    owner = "dece2183";
    repo = "yamusic-tui";
    rev = "v${version}";
    hash = "sha256-WlXTCtJt5FaCQiZ1YtsgDVO4IOsfnxF09M/BWPABP+E=";
  };

  vendorHash = "sha256-GI2xgj8ABKTJRuy405D5XUZDFLj5J5sh8QeWVJb33Xo=";

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ alsa-lib ];

  postPatch = ''
    substituteInPlace main.go \
      --replace-fail 'media.NewHandler(config.DirName,' 'media.NewHandler("yandex-music-tui",'
  '';

  postInstall = ''
    if [ -f "$out/bin/yamusic-tui" ]; then
      mv "$out/bin/yamusic-tui" "$out/bin/yandex-music-tui"
      ln -s yandex-music-tui "$out/bin/yamusic"
    elif [ -f "$out/bin/yamusic" ]; then
      ln -s yamusic "$out/bin/yandex-music-tui"
    fi
  '';

  meta = with lib; {
    description = "TUI client for Yandex Music with MPRIS support";
    homepage = "https://github.com/dece2183/yamusic-tui";
    license = licenses.mit;
    mainProgram = "yandex-music-tui";
  };
}
