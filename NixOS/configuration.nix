{ config, pkgs, inputs, pkgs-unstable, pkgs-vpn, pkgs-agents, pkgs-cli, lib, ... }:

let
  desktopUser = builtins.head (builtins.attrNames config.home-manager.users);

  # Кастомная тема SDDM Astronaut с фоном black_hole
  sddmAstronautHyprlandKathTheme = pkgs.stdenvNoCC.mkDerivation {
    pname = "sddm-astronaut-theme-hyprland-kath";
    version = "1";
    dontUnpack = true;

    installPhase = ''
      mkdir -p "$out/share/sddm/themes"
      cp -r "${pkgs.sddm-astronaut}/share/sddm/themes/sddm-astronaut-theme" "$out/share/sddm/themes/"
      mv "$out/share/sddm/themes/sddm-astronaut-theme" "$out/share/sddm/themes/sddm-astronaut-theme-hyprland-kath"
      chmod -R u+w "$out/share/sddm/themes/sddm-astronaut-theme-hyprland-kath"
      substituteInPlace "$out/share/sddm/themes/sddm-astronaut-theme-hyprland-kath/metadata.desktop" \
        --replace "ConfigFile=Themes/astronaut.conf" "ConfigFile=Themes/black_hole.conf"
    '';
  };
in
{
  imports = [
    ./hardware-configuration.nix
    ./modules/power.nix # Управление питанием, профили энергопотребления и сон
  ];

  # =========================================================================
  # 1. Загрузчик и ядро Linux
  # =========================================================================

  boot.loader = {
    efi.canTouchEfiVariables = true;
    efi.efiSysMountPoint = "/boot/efi";
    timeout = 5;
    systemd-boot = {
      enable = true;
      configurationLimit = 5; # Хранить не более 5 предыдущих поколений системы
      graceful = true;
      extraInstallCommands = ''
        bootctl set-timeout 5
      '';
    };
  };

  boot.kernelPackages = pkgs.linuxPackages;

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "thunderbolt"
    "nvme"
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];

  boot.kernelModules = [
    "kvm-intel"
    "uinput"
    "xpad"
  ];

  # Блэклист термодрайверов Intel DTT для ноутбука Huawei MateBook 14s (2022).
  # Исправляет постоянный гул вентиляторов (5400+ RPM), возвращая управление кулерами тихой логике BIOS.
  boot.blacklistedKernelModules = [
    "int3400_thermal"
    "int3403_thermal"
    "int340x_thermal_zone"
    "processor_thermal_device"
    "processor_thermal_device_pci"
    "processor_thermal_soc_slider"
  ];

  boot.extraModulePackages = [ ];
  boot.resumeDevice = "/dev/disk/by-uuid/c95c8d22-0de2-4e0d-a8f4-d0951c736c83";

  # Скрытие логов ядра и красивый экран загрузки Plymouth
  boot.plymouth = {
    enable = true;
    theme = "bgrt";
  };

  boot.kernelParams = [
    "quiet"
    "splash"
    "boot.shell_on_fail"
    "loglevel=3"
    "rd.systemd.show_status=false"
    "rd.udev.log_level=0"
    "udev.log_priority=0"
  ];
  boot.consoleLogLevel = 0;
  boot.initrd.verbose = false;

  # =========================================================================
  # 2. Сеть, файрвол и VPN
  # =========================================================================

  networking.networkmanager.enable = true;
  networking.networkmanager.wifi.powersave = false;
  networking.firewall.enable = true;
  networking.firewall.trustedInterfaces = [ "docker0" ];

  # Порты для передачи файлов через LocalSend
  networking.firewall.allowedTCPPorts = [ 53317 ];
  networking.firewall.allowedUDPPorts = [ 53317 ];

  services.resolved.enable = true;
  services.netbird.enable = true;

  # Фоновый сервис AmneziaVPN
  systemd.services.amnezia-vpn = {
    description = "Фоновый сервис AmneziaVPN";
    after = [ "network.target" "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs-vpn.amnezia-vpn}/bin/AmneziaVPN-service";
      Restart = "always";
      RestartSec = 5;
      User = "root";
      Group = "root";
    };
  };

  # Права сетевого администратора для клиента Throne VPN
  security.wrappers.Throne = {
    source = "${pkgs-vpn.throne}/bin/Throne";
    owner = "root";
    group = "root";
    capabilities = "cap_net_admin,cap_net_bind_service+ep";
  };

  # Разрешение Throne изменять маршруты DNS через systemd-resolved без постоянных парольных окон Polkit
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (
        subject.user == "${desktopUser}" &&
        action.id.indexOf("org.freedesktop.resolve1.") === 0
      ) {
        return polkit.Result.YES;
      }
    });
  '';

  # =========================================================================
  # 3. Локализация и учетные записи
  # =========================================================================

  time.timeZone = "Europe/Moscow";
  time.hardwareClockInLocalTime = false;
  services.timesyncd.enable = true;

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "ru_RU.UTF-8";
    LC_IDENTIFICATION = "ru_RU.UTF-8";
    LC_MEASUREMENT = "ru_RU.UTF-8";
    LC_MONETARY = "ru_RU.UTF-8";
    LC_NAME = "ru_RU.UTF-8";
    LC_NUMERIC = "ru_RU.UTF-8";
    LC_PAPER = "ru_RU.UTF-8";
    LC_TELEPHONE = "ru_RU.UTF-8";
    LC_TIME = "ru_RU.UTF-8";
  };

  services.xserver.xkb = {
    layout = "us,ru";
    variant = "";
  };
  console.keyMap = "us";

  # Основной пользователь системы
  users.users.${desktopUser} = {
    isNormalUser = true;
    description = "Alexander";
    extraGroups = [ "networkmanager" "wheel" "docker" "video" "input" "kvm" "adbusers" ];
    shell = pkgs.fish;
  };

  # Настройки интеграции Home Manager
  home-manager.useUserPackages = true;
  home-manager.useGlobalPkgs = true;
  home-manager.backupFileExtension = "backup";

  # =========================================================================
  # 4. Совместимость с бинарниками и подкачка
  # =========================================================================

  # Разрешение несвободных (проприетарных) пакетов
  nixpkgs.config.allowUnfree = true;

  # nix-ld: эмуляция стандартных путей к библиотекам для запуска сторонних ELF-бинарников
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc.lib # libstdc++.so, libgcc_s.so
      zlib
      glibc
      openssl
      icu
      libffi
      readline
      sqlite
      libGL
      libx11
      libxml2
      util-linux
    ];
  };

  # Сжатие оперативной памяти zram для плавности работы
  zramSwap.enable = true;

  # Автоматическое добавление ~/.local/bin в $PATH
  environment.localBinInPath = true;

  # =========================================================================
  # 5. Графическое окружение (Hyprland, SDDM, XDG Portals)
  # =========================================================================

  # Оконный менеджер Hyprland с интеграцией UWSM
  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    withUWSM = true;
  };

  programs.dconf.enable = true;
  programs.fish.enable = true;
  qt.enable = true;
  qt.platformTheme = "qt5ct";

  # Экранный менеджер входа SDDM
  services.displayManager.sddm = {
    enable = true;
    theme = "sddm-astronaut-theme-hyprland-kath";
    wayland.enable = true;
    settings = {
      General = {
        GreeterEnvironment = "QT_SCALE_FACTOR=1.2,QT_SCREEN_SCALE_FACTORS=1.2,QT_SCALE_FACTOR_ROUNDING_POLICY=PassThrough";
      };
    };
    extraPackages = with pkgs; [
      kdePackages.qtmultimedia
      kdePackages.qtsvg
      kdePackages.qtvirtualkeyboard
      kdePackages.qtbase
    ];
  };

  # XDG Desktop Portals (для файловых диалогов, шаринга экрана и открытия ссылок)
  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = false;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];
    config = {
      common = {
        default = [ "hyprland" "gtk" ];
      };
      hyprland = {
        default = [ "hyprland" "gtk" ];
      };
    };
  };

  services.gvfs.enable = true;

  # =========================================================================
  # 6. Звук и оборудование
  # =========================================================================

  # Звуковой сервер PipeWire с поддержкой низкой задержки через RTKit
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    wireplumber.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Bluetooth и геймпады
  hardware.bluetooth.enable = true;
  hardware.enableRedistributableFirmware = true;
  hardware.xpadneo.enable = true;
  hardware.opentabletdriver.enable = false;

  # Аппаратное ускорение графики Intel (VA-API / QuickSync)
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-vaapi-driver
      intel-media-driver
    ];
  };

  # =========================================================================
  # 7. Виртуализация, сервисы и игры
  # =========================================================================

  # Агент SSH
  programs.ssh.startAgent = true;

  # Среда исполнения Java 21
  programs.java = {
    enable = true;
    package = pkgs.jdk21;
  };

  # Контейнеризация Docker
  virtualisation.docker = {
    enable = true;
    daemon.settings = {
      "userland-proxy" = true;
      "iptables" = true;
    };
  };

  # Игровые платформы Steam и Gamescope
  programs.steam = {
    enable = true;
    gamescopeSession.enable = false;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };

  programs.gamescope = {
    enable = true;
    package = pkgs.gamescope;
  };

  # Служба печати CUPS
  services.printing.enable = true;

  # Правила Udev для SwayOSD и устройств
  services.udev.packages = with pkgs; [
    game-devices-udev-rules
    steam-devices-udev-rules
    swayosd
  ];

  # =========================================================================
  # 8. Системные пакеты
  # =========================================================================

  environment.systemPackages =
    # Пакеты VPN
    (with pkgs-vpn; [
      amnezia-vpn
      amneziawg-tools
      throne
    ])
    # Инструменты ИИ и агенты (фиксированные версии)
    ++ (with pkgs-agents; [
      codex
      antigravity-cli
    ])
    # Нестабильные пакеты
    ++ (with pkgs-unstable; [
      yandex-music
    ])
    # Кастомные деривации
    ++ [ (pkgs.callPackage ./pkgs/ktalk.nix { }) ]
    # Основные утилиты и окружение
    ++ (with pkgs; [
      # Утилиты темы и интерфейса
      inputs.matugen.packages.${config.nixpkgs.hostPlatform.system}.default
      alsa-plugins
      font-awesome
      libnotify
      libqalculate
      mission-center
      gnome-themes-extra
      sddm-astronaut
      sddmAstronautHyprlandKathTheme
      bluetui
      pulsemixer
      playerctl

      # Разработка и компиляция
      gcc
      gdb
      gnumake
      cmake
      ninja
      maven
      stdenv
      ruff
      tex-fmt
      texliveFull
      python3
      python3Packages.pip
      python3Packages.tkinter
      python3Packages.virtualenv
      uv

      # Терминальные CLI-утилиты
      age
      bat
      bluez
      btop
      bubblewrap
      cloc
      curl
      duf
      ffmpeg
      fzf
      htop
      jq
      pkgs-cli.lazydocker
      pkgs-cli.lazygit
      micro
      neo
      nixfmt
      ntfs3g
      p7zip
      powertop
      rar
      tldr
      tmux
      tree
      unzip
      unrar
      vim
      wget
      xclip
      xsel
      zip
      yt-dlp

      # GUI-приложения и графика
      aseprite
      discord
      docker
      docker-compose
      dragon-drop
      freerdp
      gimp3
      kdePackages.qt6ct
      krita
      libsForQt5.qt5ct
      netbird-ui
      pinta
      postman
      qgis
      transmission_4-gtk
      vscode
      vscodium-fhs

      # Игры и эмуляция
      android-tools
      evtest
      mangohud
      protonplus
      r2modman
      scanmem
      scrcpy
      steam

      # Мультимедиа и загрузчики
      tenacity
      (instaloader.overrideAttrs (old: {
        propagatedBuildInputs = (old.propagatedBuildInputs or [ ]) ++ [ python3Packages.browser-cookie3 ];
      }))
    ]);

  # =========================================================================
  # 9. Шрифты
  # =========================================================================

  fonts.packages =
    (builtins.filter lib.attrsets.isDerivation (builtins.attrValues pkgs.nerd-fonts))
    ++ [
      pkgs.adwaita-fonts
      pkgs.noto-fonts
      pkgs.noto-fonts-cjk-sans
      pkgs.noto-fonts-color-emoji
    ];

  # =========================================================================
  # 10. Правила Udev для оборудования
  # =========================================================================

  services.udev.extraRules = ''
    # Доступ к uinput для эмуляции контроллеров и оверлеев в Steam
    KERNEL=="uinput", MODE="0660", GROUP="input", OPTIONS+="static_node=uinput", TAG+="uaccess"

    # Клавиатура Teevolution Terra
    SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3554", ATTRS{idProduct}=="f523", MODE="0666", TAG+="uaccess"
    SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3554", ATTRS{idProduct}=="f522", MODE="0666", TAG+="uaccess"

    # Клавиатура Wooting One Legacy
    SUBSYSTEM=="hidraw", ATTRS{idVendor}=="03eb", ATTRS{idProduct}=="ff01", MODE="0666", TAG+="uaccess"
    SUBSYSTEM=="usb", ATTRS{idVendor}=="03eb", ATTRS{idProduct}=="ff01", MODE="0666", TAG+="uaccess"

    # Режим обновления прошивки Wooting One
    SUBSYSTEM=="hidraw", ATTRS{idVendor}=="03eb", ATTRS{idProduct}=="2402", MODE="0666", TAG+="uaccess"

    # Клавиатура Wooting Two Legacy
    SUBSYSTEM=="hidraw", ATTRS{idVendor}=="03eb", ATTRS{idProduct}=="ff02", MODE="0666", TAG+="uaccess"
    SUBSYSTEM=="usb", ATTRS{idVendor}=="03eb", ATTRS{idProduct}=="ff02", MODE="0666", TAG+="uaccess"

    # Режим обновления прошивки Wooting Two
    SUBSYSTEM=="hidraw", ATTRS{idVendor}=="03eb", ATTRS{idProduct}=="2403", MODE="0666", TAG+="uaccess"

    # Универсальные правила для устройств Wooting
    SUBSYSTEM=="hidraw", ATTRS{idVendor}=="31e3", MODE="0666", TAG+="uaccess"
    SUBSYSTEM=="usb", ATTRS{idVendor}=="31e3", MODE="0666", TAG+="uaccess"
  '';

  # =========================================================================
  # 11. Настройки менеджера пакетов Nix
  # =========================================================================

  # Еженедельная сборка мусора и удаление поколений старше 14 дней
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # Оптимизация хранилища (дедупликация жестких ссылок)
  nix.settings.auto-optimise-store = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "26.05";
}
