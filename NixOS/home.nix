{ config, pkgs, pkgs-unstable, pkgs-cli, hyprland, inputs, ... }:

let
  # Пропатченный обзорщик окон Quickshell Overview
  quickshellOverview = pkgs.runCommand "quickshell-overview-patched" { } ''
    cp -R ${inputs.quickshell-overview}/. "$out"
    substituteInPlace "$out/common/functions/ColorUtils.qml" \
      --replace-fail \
      'function applyAlpha(color, alpha) {' \
      'function applyAlpha(color, alpha) { if (!color) return "transparent";'
    substituteInPlace "$out/modules/overview/OverviewWindow.qml" \
      --replace-fail \
      'property var iconPath: Quickshell.iconPath(iconName, "image-missing")' \
      'property var iconPath: entry?.icon ? Quickshell.iconPath(iconName) : ""'
  '';
in
{
  imports = [
  ];

  home.stateVersion = "26.05";
  home.username = "alex";
  home.homeDirectory = "/home/alex";

  # =========================================================================
  # 1. Quickshell Overview (экран обзора рабочих столов по Win+Tab)
  # =========================================================================

  home.file.".config/quickshell/overview" = {
    source = quickshellOverview;
    recursive = true;
  };

  # Конфигурация сетки и внешнего вида Quickshell
  home.file.".config/quickshell/overview/config.json".text = builtins.toJSON {
    appearance = {
      colorSource = "matugen";
      font.family = {
        main = "JetBrains Mono Nerd Font";
        title = "JetBrains Mono Nerd Font";
        expressive = "JetBrains Mono Nerd Font";
      };
    };
    overview = {
      rows = 2;
      columns = 5;
      hideEmptyRows = true;
      previewsEnabled = true;
      previewMode = "live";
      includeInactiveMonitorPreviews = true;
      showSpecialWorkspaces = true;
      specialWorkspaces = [ "magic" ];
    };
  };

  # =========================================================================
  # 2. Интеграция Flatpak в пользовательские каталоги данных XDG
  # =========================================================================

  xdg.systemDirs.data = [
    "/var/lib/flatpak/exports/share"
    "/home/alex/.local/share/flatpak/exports/share"
  ];

  # =========================================================================
  # 3. Ассоциации типов файлов (MIME) по умолчанию
  # =========================================================================

  xdg.mimeApps.enable = true;
  xdg.configFile."mimeapps.list".force = true;

  xdg.mimeApps.defaultApplications = {
    # Изображения
    "image/jpeg" = [ "imv.desktop" ];
    "image/png"  = [ "imv.desktop" ];
    "image/gif"  = [ "firefox.desktop" ];
    "image/webp" = [ "imv.desktop" ];
    "image/heif" = [ "imv.desktop" ];

    # Текст и исходный код
    "text/plain" = [ "code.desktop" ];
    "text/css" = [ "code.desktop" ];
    "application/x-shellscript" = [ "code.desktop" ];
    "application/x-zerosize" = [ "code.desktop" ];
    "text/html" = [ "firefox.desktop" ];

    # Браузер и протоколы ссылок
    "x-scheme-handler/http"  = [ "firefox.desktop" ];
    "x-scheme-handler/https" = [ "firefox.desktop" ];
    "x-scheme-handler/ktalk" = [ "ktalk.desktop" ];
    "application/pdf" = [ "firefox.desktop" ];
    "application/x-pdf" = [ "firefox.desktop" ];
    "application/acrobat" = [ "firefox.desktop" ];
    "application/vnd.pdf" = [ "firefox.desktop" ];
    "application/vnd.adobe.pdf" = [ "firefox.desktop" ];
    "text/pdf" = [ "firefox.desktop" ];

    # Документы Microsoft Word
    "application/msword" = [ "msword.desktop" ];
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document" = [ "msword.desktop" ];
    "application/vnd.openxmlformats-officedocument.wordprocessingml.template" = [ "msword.desktop" ];
    "application/vnd.ms-word.document.macroEnabled.12" = [ "msword.desktop" ];
    "application/rtf" = [ "msword.desktop" ];

    # Таблицы Microsoft Excel
    "application/vnd.ms-excel" = [ "msexcel.desktop" ];
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" = [ "msexcel.desktop" ];
    "application/vnd.openxmlformats-officedocument.spreadsheetml.template" = [ "msexcel.desktop" ];
    "application/vnd.ms-excel.sheet.macroEnabled.12" = [ "msexcel.desktop" ];
    "text/csv" = [ "msexcel.desktop" ];

    # Презентации Microsoft PowerPoint
    "application/vnd.ms-powerpoint" = [ "mspowerpoint.desktop" ];
    "application/vnd.openxmlformats-officedocument.presentationml.presentation" = [ "mspowerpoint.desktop" ];
    "application/vnd.openxmlformats-officedocument.presentationml.template" = [ "mspowerpoint.desktop" ];
    "application/vnd.openxmlformats-officedocument.presentationml.slideshow" = [ "mspowerpoint.desktop" ];
    "application/vnd.ms-powerpoint.presentation.macroEnabled.12" = [ "mspowerpoint.desktop" ];

    # Аудиофайлы
    "audio/mpeg" = [ "org.gnome.Decibels.desktop" ];

    # Файловый менеджер
    "inode/directory" = [ "org.gnome.Nautilus.desktop" ];

    # Видеофайлы
    "video/mp4" = [ "mpv.desktop" ];
    "video/x-matroska" = [ "mpv.desktop" ];
    "video/webm" = [ "mpv.desktop" ];
    "video/ogg" = [ "mpv.desktop" ];
    "video/quicktime" = [ "mpv.desktop" ];
    "video/x-flv" = [ "mpv.desktop" ];
    "video/x-msvideo" = [ "mpv.desktop" ];
    "video/x-ms-wmv" = [ "mpv.desktop" ];
    "video/mpeg" = [ "mpv.desktop" ];
  };

  # Кастомный ярлык Steam с масштабированием под HiDPI экраны
  xdg.desktopEntries.steam = {
    name = "Steam";
    exec = "env STEAM_FORCE_DESKTOPUI_SCALING=1.5 GDK_SCALE=2 GDK_DPI_SCALE=0.75 steam -forcedesktopscaling 1.5 %U";
    terminal = false;
    type = "Application";
    icon = "steam";
    categories = [ "Game" "Network" ];
    mimeType = [ "x-scheme-handler/steam" "x-scheme-handler/steamlink" ];
  };

  # =========================================================================
  # 4. Браузеры и переменные сессии
  # =========================================================================

  # Браузер Firefox с интеграцией темы Pywalfox
  programs.firefox = {
    enable = true;
    nativeMessagingHosts = [ pkgs.pywalfox-native ];
    languagePacks= [ "ru" ];
  };

  # Браузер Chromium
  programs.chromium.enable = true;

  # Переменные сессии пользователя
  home.sessionVariables = {
    BROWSER = "firefox";
    EDITOR = "code";
    VISUAL = "code";
    JAVA_HOME = "${pkgs.jdk21}/lib/openjdk";
  };

  # =========================================================================
  # 5. Командная оболочка Fish и приглашение Starship
  # =========================================================================

  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set -g fish_color_autosuggestion brblack
      set -U fish_greeting ""
    '';
    functions = {
      # Применение сгенерированной Matugen палитры ко всем запущенным окнам Kitty
      kitty-theme = ''
          kitty @ --to unix:/tmp/kitty set-colors /home/alex/.config/kitty/themes/Matugen.conf
          for socket in /tmp/kitty-*
            test -S "$socket"; or continue
            kitty @ --to unix:$socket set-colors /home/alex/.config/kitty/themes/Matugen.conf
          end
      '';
    };
    shellAliases = {
      # NixOS команды
      nrs = "sudo nixos-rebuild switch --flake /home/alex/hyprland-dotfiles/NixOS#nixos";
      nrb = "sudo nixos-rebuild boot --flake /home/alex/hyprland-dotfiles/NixOS#nixos";
      nfu = "nix flake update --flake /home/alex/hyprland-dotfiles/NixOS";
      nce = "vim /home/alex/hyprland-dotfiles/NixOS/configuration.nix";
      nhe = "vim /home/alex/hyprland-dotfiles/NixOS/home.nix";
      nfe = "vim /home/alex/hyprland-dotfiles/NixOS/flake.nix";
      try = "nix-shell -p";
      ncg = "sudo nix-collect-garbage -d";

      # Утилиты и терминал
      neo = "neo --colormode=32 -C /home/alex/.config/neo/colors-matugen.neo";
      ls = "eza -la";
      dnd = "dragon-drop -x -A";
      g = "lazygit";
      d = "lazydocker";

      # Docker
      dcuw = "docker compose -f /home/alex/.config/windows-docker/compose.yaml up -d";
      dcdw = "docker compose -f /home/alex/.config/windows-docker/compose.yaml down";

      # Загрузка аудио/видео через yt-dlp
      dwa = "yt-dlp -x --audio-format mp3 --cookies-from-browser firefox -N 50";
      dla = "yt-dlp -x --audio-format mp3 --enable-file-urls";

      # Яндекс Музыка TUI
      ymtui = "yandex-music-tui";
    };
  };

  # Информативная строка приглашения Starship
  programs.starship = {
    enable = true;
    enableFishIntegration = true;
  };

  # =========================================================================
  # 6. Git, терминал Kitty и медиаплеер
  # =========================================================================

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Alexander";
        email = "alexo375@yandex.ru";
      };
    };
  };

  # Экранный регулятор громкости и яркости SwayOSD
  services.swayosd.enable = true;

  # Эквалайзер и обработка звука EasyEffects
  services.easyeffects.enable = true;

  # Видеоплеер MPV
  programs.mpv = {
    enable = true;
  };

  # Эмулятор терминала Kitty
  programs.kitty = {
    enable = true;
    package = pkgs.kitty;
    settings = {
      include = "current-theme.conf";
      font_size = 14;
      cursor_trail = 5;
      scrollback_indicator_opacity = 0;
      window_padding_width = 20;
      placement_strategy = "top-left";
      hide_window_decorations = "yes";
      resize_debounce_time = "0 0";
      confirm_os_window_close = 0;
      background_opacity = 0.8;
      background_blur = 0;
      allow_remote_control = "yes";
      listen_on = "unix:/tmp/kitty";
      "map shift+cmd+plus" = "change_font_size all +2.0";
      "map shift+cmd+minus" = "change_font_size all -2.0";
      "map shift+cmd+backspace" = "change_font_size all 14";
    };
    font = {
      size = 14;
      name = "FiraCode Nerd Font";
      package = pkgs.nerd-fonts.fira-code;
    };
  };

  # Меню запуска Rofi с плагином калькулятора
  programs.rofi = {
    enable = true;
    plugins = [ pkgs.rofi-calc ];
    package = pkgs.rofi;
    configPath = ".config/rofi/.hm-config.rasi";
  };

  programs.home-manager.enable = true;

  # Пользовательские скрипты из misc/bin в ~/.local/bin
  home.file.".local/bin" = {
    source = ../misc/bin;
    recursive = true;
  };

  # =========================================================================
  # 7. Пользовательские пакеты Home Manager
  # =========================================================================

  home.packages = with pkgs; [
    # Оформление и темы
    adw-gtk3
    nwg-look
    pywalfox-native
    dconf-editor
    pkgs-unstable.qt6Packages.qt6ct
    qt6.qtwayland

    # Терминальные утилиты и заставки
    ani-cli
    asciiquarium-transparent
    cbonsai
    cava
    playerctl
    clock-rs
    nitch
    unimatrix
    pkgs-cli.eza
    pkgs-cli.yazi
    git
    jq
    socat
    stow

    # Скриншоты, запись экрана и буфер обмена
    cliphist
    wl-clip-persist
    wl-clipboard
    grim
    slurp
    hyprpicker
    hyprshot
    wf-recorder
    tesseract

    # Управление Hyprland и рабочим столом
    brightnessctl
    hypridle
    hyprlock
    hyprpolkitagent
    hyprsunset
    awww
    pamixer
    pavucontrol
    quickshell
    waybar
    swaynotificationcenter
    zenity
    rofimoji

    # Документы и медиа
    decibels
    exiftool
    file-roller
    gimp
    gnome-clocks
    gthumb
    imv
    libreoffice
    localsend
    mediainfo
    nautilus
    obsidian
    telegram-desktop
    vscode

    # Python окружение
    python3
    python3Packages.pip
    python3Packages.virtualenv
  ];
}
