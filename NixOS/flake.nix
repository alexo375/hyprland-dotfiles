{
  description = "NixOS with home-manager btw";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    nixpkgs-vpn.url = "github:nixos/nixpkgs/nixos-unstable";

    # Agent/AI CLI packages are intentionally pinned and updated separately.
    nixpkgs-agents.url = "github:nixos/nixpkgs/nixos-unstable";

    # General CLI tools (like yazi, eza, lazygit)
    nixpkgs-cli.url = "github:nixos/nixpkgs/nixos-unstable";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    matugen = {
      url = "github:InioX/Matugen?ref=refs/tags/v3.1.0";
    };

    # antigravity-nix = {
    #   url = "github:jacopone/antigravity-nix";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };

    # Hyprland updated to latest version (v0.55+ with Lua configuration)
    hyprland.url = "github:hyprwm/Hyprland";

    quickshell-overview = {
      url = "github:Shanu-Kumawat/quickshell-overview";
      flake = false;
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak";
  };

  outputs =
    inputs@{
      nixpkgs,
      home-manager,
      nixpkgs-unstable,
      nixpkgs-vpn,
      nixpkgs-agents,
      nixpkgs-cli,
      nixos-hardware,
      # antigravity-nix,
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
        # overlays = [ antigravity-nix.overlays.default ];
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
          nixos-hardware.nixosModules.common-cpu-intel
          nixos-hardware.nixosModules.common-gpu-intel
          nixos-hardware.nixosModules.common-pc-laptop
          nixos-hardware.nixosModules.common-pc-ssd
          ./configuration.nix
          inputs.nix-flatpak.nixosModules.nix-flatpak
          ./modules/flatpak.nix
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
