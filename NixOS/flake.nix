{
  description = "Конфигурация NixOS с Home Manager и Hyprland";

  inputs = {
    # Основной стабильный/текущий канал nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Нестабильный канал для свежих версий приложений
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # Канал для инструментов VPN
    nixpkgs-vpn.url = "github:nixos/nixpkgs/nixos-unstable";

    # ИИ-агенты и CLI-инструменты
    nixpkgs-agents.url = "github:nixos/nixpkgs/nixos-unstable";

    # Репозиторий со свежими ИИ агентами
    nixpkgs-llm-agents.url = "github:numtide/llm-agents.nix";

    # Основные CLI утилиты
    nixpkgs-cli.url = "github:nixos/nixpkgs/nixos-unstable";

    # Аппаратные профили оборудования под ноутбуки и Intel
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    # Пользовательский менеджер конфигураций Home Manager
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Генератор цветовых палитр Material You из обоев
    matugen = {
      url = "github:InioX/Matugen?ref=refs/tags/v3.1.0";
    };

    # Оконный менеджер Hyprland последней версии
    hyprland.url = "github:hyprwm/Hyprland";

    # Обзорщик рабочих столов Quickshell Overview
    quickshell-overview = {
      url = "github:Shanu-Kumawat/quickshell-overview";
      flake = false;
    };

    # Декларативное управление пакетами Flatpak
    nix-flatpak.url = "github:gmodena/nix-flatpak";
  };

  outputs =
    inputs@{
      nixpkgs,
      home-manager,
      nixpkgs-unstable,
      nixpkgs-vpn,
      nixpkgs-agents,
      nixpkgs-llm-agents,
      nixpkgs-cli,
      nixos-hardware,
      hyprland,
      ...
    }:
    let
      system = "x86_64-linux";
      unstablePkgs = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
      vpnPkgs = import nixpkgs-vpn {
        inherit system;
        config.allowUnfree = true;
      };
      agentPkgs = import nixpkgs-agents {
        inherit system;
        config.allowUnfree = true;
        # Мердж сюда же репозитория со свежими LLM агентами
        overlays = [
          (final: prev: nixpkgs-llm-agents.packages.${system})
        ];
      };
      cliPkgs = import nixpkgs-cli {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs system hyprland;
          pkgs-unstable = unstablePkgs;
          pkgs-vpn = vpnPkgs;
          pkgs-agents = agentPkgs;
          pkgs-cli = cliPkgs;
        };

        modules = [
          # Аппаратные модули под процессор Intel, графику и ноутбук
          nixos-hardware.nixosModules.common-cpu-intel
          nixos-hardware.nixosModules.common-gpu-intel
          nixos-hardware.nixosModules.common-pc-laptop
          nixos-hardware.nixosModules.common-pc-ssd

          # Системная конфигурация хоста
          ./configuration.nix

          # Модули Flatpak
          inputs.nix-flatpak.nixosModules.nix-flatpak
          ./modules/flatpak.nix

          # Пользовательская конфигурация Home Manager
          home-manager.nixosModules.home-manager
          {
            networking.hostName = "nixos";
            home-manager.extraSpecialArgs = {
              inherit inputs hyprland;
              pkgs-unstable = unstablePkgs;
              pkgs-vpn = vpnPkgs;
              pkgs-agents = agentPkgs;
              pkgs-cli = cliPkgs;
            };
            home-manager.users.alex = import ./home.nix;
          }
        ];
      };
    };
}
