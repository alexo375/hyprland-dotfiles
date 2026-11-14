{ lib
, appimageTools
, fetchurl
, makeDesktopItem
}:

let
  pname = "snowhush";
  version = "0.12.0";
  src = fetchurl {
    url = "https://github.com/mbezruchko/Snowhush/releases/download/v${version}/Snowhush-x86_64.AppImage";
    hash = "sha256-K7vJ50gkUIBuW5Fc/46GFvR+N99BNIDD0dfHjIofvhk=";
  };
  appimageContents = appimageTools.extractType2 {
    inherit pname version src;
  };
  desktopItem = makeDesktopItem {
    name = pname;
    desktopName = "Snowhush";
    comment = "Snow, rain, leaves and petals on the desktop";
    exec = pname;
    icon = "weather-snow";
    categories = [ "Utility" ];
    terminal = false;
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    install -Dm644 ${desktopItem}/share/applications/snowhush.desktop \
      "$out/share/applications/snowhush.desktop"

    if [ -f "${appimageContents}/snowhush.png" ]; then
      install -Dm644 "${appimageContents}/snowhush.png" \
        "$out/share/pixmaps/snowhush.png"
    fi
  '';

  meta = {
    description = "Desktop weather effects for Wayland compositors";
    homepage = "https://github.com/mbezruchko/Snowhush";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = pname;
  };
}
