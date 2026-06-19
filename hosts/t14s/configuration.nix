# hosts/t14s/configuration.nix
{
  config,
  lib,
  pkgs,
  inputs,
  username,
  ...
}: {
  # --------------------------------------------------------------- identity
  networking.hostName = "t14s";
  # networking.hostId is set in zfs-impermanence.nix — don't forget it!

  time.timeZone = "Europe/Zurich";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings.LC_TIME = "fr_CH.UTF-8"; # adjust to taste

  networking.networkmanager.enable = true;

  # ------------------------------------------------------------------ users
  # With impermanence, declarative users are strongly recommended:
  # /etc/shadow lives on the wiped root, so imperative `passwd` changes
  # would not survive a reboot.
  users.mutableUsers = false;
  users.users.${username} = {
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager" "video"];
    # Generate with: mkpasswd -m yescrypt
    hashedPassword = "$y$j9T$z5UbqEIYx.3cZfrJRHCaH1$b/y2F2V3uc0KJYZ4CBY0OfUS11svfDuw/2x0rJ93An3";
    shell = pkgs.bash; # or pkgs.zsh / pkgs.fish
  };

  # -------------------------------------------------------------------- nix
  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    auto-optimise-store = true;
    # Pre-built noctalia binaries
    extra-substituters = ["https://noctalia.cachix.org"];
    extra-trusted-public-keys = [
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    ];
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # ---------------------------------------------------------------- desktop
  # niri: scrollable-tiling Wayland compositor (nixpkgs module sets up
  # the session, portals, gnome-keyring, etc.)
  programs.niri.enable = true;

  # Login manager: greetd + tuigreet starting the niri session
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd niri-session";
      user = "greeter";
    };
  };

  # Audio
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };
  security.rtkit.enable = true;

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  security.polkit.enable = true;

  # -------------------------------------------------------------- firefox
  # System-wide Firefox with uBlock Origin force-installed via policy —
  # fully declarative, no NUR needed, applies to every profile.
  programs.firefox = {
    enable = true;
    policies = {
      DisableTelemetry = true;
      DisablePocket = true;
      ExtensionSettings = {
        "uBlock0@raymondhill.net" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
          installation_mode = "force_installed";
        };
      };
    };
  };

  # ----------------------------------------------------------------- fonts
  fonts.packages = with pkgs; [
    jetbrains-mono
    nerd-fonts.jetbrains-mono # icon-patched variant, used by noctalia widgets
    noto-fonts
    noto-fonts-color-emoji
  ];

  # -------------------------------------------------------------- packages
  environment.systemPackages = with pkgs; [
    # Desktop shell (bar, launcher, notifications, lock screen, OSD)
    inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default

    xwayland-satellite # X11 app support; recent niri autostarts it
    wl-clipboard
    git
    vim
  ];

  # ------------------------------------------------------- host persistence
  # Extends the base list in zfs-impermanence.nix
  environment.persistence."/persist".directories = [
    "/var/lib/bluetooth"
    "/var/lib/fwupd"
  ];

  # ------------------------------------------------------------ laptop bits
  services.fwupd.enable = true; # LVFS firmware updates
  services.power-profiles-daemon.enable = true; # pairs well with intel_pstate
  services.fstrim.enable = true;
  hardware.enableRedistributableFirmware = true;

  system.stateVersion = "26.05"; # never change after install
}
