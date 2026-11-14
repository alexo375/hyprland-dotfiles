{ lib
, appimageTools
, fetchurl
, gtk3
, webkitgtk_4_1
, libsoup_3
, libayatana-appindicator
, xdotool
, glib
, nss
, nspr
, libdrm
, libgbm
, libxkbcommon
, libGL
, udev
}:

let
  pname = "donut-browser";
  version = "0.36.0";

  src = fetchurl {
    url = "https://github.com/donutbrowser/donutbrowser/releases/download/v${version}/Donut_${version}_amd64.AppImage";
    hash = "sha256-hGi8rGAIryTIqLpj6QfuW0NQQ4D70pHZIciUmteEo6c=";
  };

  appimageContents = appimageTools.extractType2 {
    inherit pname version src;
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraPkgs = pkgs: with pkgs; [
    gtk3
    webkitgtk_4_1
    libsoup_3
    libayatana-appindicator
    xdotool
    glib
    nss
    nspr
    libdrm
    libgbm
    libxkbcommon
    libGL
    udev
  ];

  extraInstallCommands = ''
    install -m 444 -D ${appimageContents}/Donut.desktop $out/share/applications/donutbrowser.desktop
    sed -i 's|Exec=donutbrowser|Exec=${pname}|' $out/share/applications/donutbrowser.desktop

    mkdir -p $out/share/icons
    cp -r ${appimageContents}/usr/share/icons/* $out/share/icons/ 2>/dev/null || true
    install -m 444 -D ${appimageContents}/donutbrowser.png $out/share/pixmaps/donutbrowser.png

    ln -s $out/bin/${pname} $out/bin/donutbrowser
  '';

  meta = with lib; {
    description = "The Most Private Anti-Detect Browser";
    homepage = "https://donutbrowser.com";
    license = licenses.agpl3Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = pname;
  };
}
