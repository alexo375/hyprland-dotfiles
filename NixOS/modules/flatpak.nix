{ pkgs, lib, ... }:

{
  # Декларативное управление Flatpak через модуль nix-flatpak
  services.flatpak = {
    enable = true;

    # Автоматическая установка и обновление пакетов при выполнении nixos-rebuild switch
    update.onActivation = true;

    # Репозиторий Flathub для базовых рантаймов (org.freedesktop.Platform)
    remotes = lib.mkOptionDefault [
      {
        name = "flathub";
        location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
      }
    ];

    # Декларативный список установленных Flatpak-приложений
    packages = [
      # Общий лаунчер экосистемы ArtCraft
      {
        appId = "ai.storyteller.artcraft-launcher";
        sha256 = "sha256-qHUYKqh0KoZhL06u0paPFm44JT0O0k4aytXo1wGkR1M=";
        bundle = "${pkgs.fetchurl {
          url = "https://github.com/storytold/craft-launcher/releases/download/v0.4.1/artcraft-launcher-0.4.1-linux-x86_64.flatpak";
          hash = "sha256-qHUYKqh0KoZhL06u0paPFm44JT0O0k4aytXo1wGkR1M=";
        }}";
      }

      # PhotoCraft — растровый графический редактор (альтернатива Photoshop)
      {
        appId = "ai.storyteller.photocraft";
        sha256 = "sha256-PTps3ehL850ZBUUig0Th3DNAgJSc2jLVPee66184cXU=";
        bundle = "${pkgs.fetchurl {
          url = "https://github.com/storytold/photocraft/releases/download/v0.9.0/photocraft-0.9.0-linux-x86_64.flatpak";
          hash = "sha256-PTps3ehL850ZBUUig0Th3DNAgJSc2jLVPee66184cXU=";
        }}";
      }

      # WordCraft — текстовый процессор (альтернатива MS Word)
      {
        appId = "ai.storyteller.wordcraft";
        sha256 = "sha256-OpV6fF8lYjyjtkRHX4B44uBelcBmdtrRhhPmx9XAwPc=";
        bundle = "${pkgs.fetchurl {
          url = "https://github.com/storytold/wordcraft/releases/download/v0.7.0/wordcraft-0.7.0-linux-x86_64.flatpak";
          hash = "sha256-OpV6fF8lYjyjtkRHX4B44uBelcBmdtrRhhPmx9XAwPc=";
        }}";
      }

      # GridCraft — редактор электронных таблиц (альтернатива MS Excel)
      {
        appId = "ai.storyteller.gridcraft";
        sha256 = "sha256-I7I6ZiCtc0+0ScESVk8+wAKK28S8No2HKOSrYb61OxQ=";
        bundle = "${pkgs.fetchurl {
          url = "https://github.com/storytold/gridcraft/releases/download/v0.7.0/gridcraft-0.7.0-linux-x86_64.flatpak";
          hash = "sha256-I7I6ZiCtc0+0ScESVk8+wAKK28S8No2HKOSrYb61OxQ=";
        }}";
      }

      # DeckCraft — редактор презентаций (альтернатива MS PowerPoint)
      {
        appId = "ai.storyteller.deckcraft";
        sha256 = "sha256-0rKD43Tg8WVRho/riIqYAY2hBn1S2q3GPH2dUArWs7U=";
        bundle = "${pkgs.fetchurl {
          url = "https://github.com/storytold/deckcraft/releases/download/v0.7.0/deckcraft-0.7.0-linux-x86_64.flatpak";
          hash = "sha256-0rKD43Tg8WVRho/riIqYAY2hBn1S2q3GPH2dUArWs7U=";
        }}";
      }

      # FilmCraft — видеоредактор (альтернатива Adobe Premiere)
      {
        appId = "ai.storyteller.filmcraft";
        sha256 = "sha256-XyhBLwCgSbq/SUEaY+BlvbV9eofso+UO5u6OYGHWIDk=";
        bundle = "${pkgs.fetchurl {
          url = "https://github.com/storytold/filmcraft/releases/download/v0.8.0/filmcraft-0.8.0-linux-x86_64.flatpak";
          hash = "sha256-XyhBLwCgSbq/SUEaY+BlvbV9eofso+UO5u6OYGHWIDk=";
        }}";
      }
    ];
  };
}
