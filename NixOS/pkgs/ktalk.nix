{ pkgs, stdenv, dpkg, autoPatchelfHook, makeWrapper, ... }:

stdenv.mkDerivation rec {
  pname = "ktalk";

  # Инструкция по обновлению версии KTalk:
  # 1. Измените `version` (например, "3.8.0")
  # 2. Получите SRI-хэш новой версии командой в терминале:
  #    nix store prefetch-file https://st.ktalk.host/ktalk-app/linux/ktalk3.8.0amd64.deb
  # 3. Вставьте полученный хэш в параметр sha256 ниже.
  version = "3.7.0";

  src = pkgs.fetchurl {
    url = "https://st.ktalk.host/ktalk-app/linux/ktalk${version}amd64.deb";
    sha256 = "sha256-oZuSaSizg6F/phPaJ8Od6rR6Sb6TjyNq838e1g/ZkjA=";
  };

  # Инструменты сборки и патчинга
  nativeBuildInputs = with pkgs; [
    autoPatchelfHook # Автоматически переписывает пути к системным библиотекам в бинарниках
    dpkg             # Для распаковки deb-пакета
    makeWrapper      # Обертка над бинарником с переменными окружения и $PATH
  ];

  # Зависимости среды выполнения (GTK, графические и звуковые библиотеки)
  buildInputs = with pkgs; [
    gtk3
    nss
    alsa-lib
    at-spi2-atk
    mesa
    libdrm
    libxkbcommon
    expat
    pango
    cairo
    systemd
    pipewire
    libgbm
    libpng
    zlib
    avahi
    libx11
    libxtst
    libxcomposite
    libxdamage
    libxrandr
    libxext
    libxfixes
    libxrender
    libxi
    xdg-utils # Необходим для вызова xdg-open (открытие ссылок в браузере)
    glib
  ];

  # Фаза распаковки deb-пакета
  unpackPhase = "dpkg-deb -x $src .";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    mkdir -p $out/share/applications
    mkdir -p $out/share/pixmaps

    cp -r opt $out/ 2>/dev/null || true

    if [ -d "usr/share" ]; then
      cp -r usr/share/* $out/share/ 2>/dev/null || true
    fi

    TARGET_BIN=$(find $out/opt -maxdepth 2 -name "ktalk" -type f | head -n 1)
    if [ -n "$TARGET_BIN" ]; then
      ln -s "$TARGET_BIN" $out/bin/ktalk
    fi

    DESKTOP_FILE="$out/share/applications/ktalk.desktop"
    if [ ! -f "$DESKTOP_FILE" ]; then
      DESKTOP_FILE=$(find $out/share/applications -name "*.desktop" | head -n 1)
    fi

    if [ -f "$DESKTOP_FILE" ]; then
      # Добавляем %u, чтобы браузер мог передавать URL звонка в приложение
      sed -i "s|Exec=.*|Exec=$out/bin/ktalk %u|g" "$DESKTOP_FILE"

      # Гарантируем регистрацию схемы протокола x-scheme-handler/ktalk
      if ! grep -q "MimeType=" "$DESKTOP_FILE"; then
        echo "MimeType=x-scheme-handler/ktalk;" >> "$DESKTOP_FILE"
      elif ! grep -q "x-scheme-handler/ktalk" "$DESKTOP_FILE"; then
        sed -i "s|MimeType=|MimeType=x-scheme-handler/ktalk;|g" "$DESKTOP_FILE"
      fi

      ICON_SRC=$(find $out/share/icons -name "ktalk.png" | head -n 1)
      if [ -n "$ICON_SRC" ]; then
        cp "$ICON_SRC" $out/share/pixmaps/ktalk.png
        sed -i "s|Icon=.*|Icon=$out/share/pixmaps/ktalk.png|g" "$DESKTOP_FILE"
      fi
    fi

    runHook postInstall
  '';

  # Пост-обработка бинарника: проброс xdg-utils в PATH и включение поддержки Wayland/PipeWire
  postFixup = ''
    RESOURCES_DIR=$(dirname $(find $out/opt -name "icudtl.dat" | head -n 1))

    wrapProgram $out/bin/ktalk \
      --set CHROME_ICU_DIR "$RESOURCES_DIR" \
      --set NIXOS_OZONE_WL "1" \
      --set ELECTRON_OZONE_PLATFORM_HINT "auto" \
      --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.xdg-utils pkgs.glib ]} \
      --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath buildInputs} \
      --add-flags "--no-sandbox --ozone-platform-hint=auto --enable-features=UseOzonePlatform,WebRTCPipeWireCapturer"
  '';
}
