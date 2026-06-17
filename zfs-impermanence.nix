# zfs-impermanence.nix
#
# Companion module to disko.nix. Import this (plus the disko config and the
# impermanence module) from your configuration.nix / flake:
#
#   inputs.impermanence.url = "github:nix-community/impermanence";
#   ...
#   imports = [
#     inputs.disko.nixosModules.disko
#     inputs.impermanence.nixosModules.impermanence
#     ./disko.nix
#     ./zfs-impermanence.nix
#   ];

{ config, lib, pkgs, ... }:

{
  # ---------------------------------------------------------------- boot/zfs
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.forceImportRoot = false;

  # Required by ZFS — must be a unique 8-char hex string per machine.
  # Generate with: head -c4 /dev/urandom | od -A none -t x4 | tr -d ' '
  networking.hostId = "CHANGE-ME";

  # ------------------------------------------------- rollback root on boot
  # systemd-stage-1 service that resets / to the blank snapshot after the
  # pool is imported (and unlocked) but before it is mounted.
  boot.initrd.systemd.enable = true;
  boot.initrd.systemd.services.rollback = {
    description = "Rollback root filesystem to blank snapshot";
    wantedBy = [ "initrd.target" ];
    after = [ "zfs-import-rpool.service" ];
    before = [ "sysroot.mount" ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    script = ''
      zfs rollback -r rpool/local/root@blank
    '';
  };

  # HIBERNATION SAFETY: the pool must never be imported (let alone rolled
  # back) before the resume-from-hibernation attempt. If resume succeeds,
  # the initrd hands control to the hibernated kernel and neither the
  # import nor the rollback ever runs — which is exactly what we want.
  boot.initrd.systemd.services."zfs-import-rpool".after =
    [ "systemd-hibernate-resume.service" ];

  # ----------------------------------------------------------- persistence
  # /persist must be mounted in the initrd so persisted files (ssh host
  # keys, machine-id, ...) are available early.
  fileSystems."/persist".neededForBoot = true;

  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/var/log"
      "/var/lib/nixos"               # uid/gid mappings — do not omit
      "/var/lib/systemd"             # timers, coredumps, journal state
      "/etc/NetworkManager/system-connections"
      # add as needed: "/var/lib/docker", "/var/lib/libvirt", ...
    ];
    files = [
      "/etc/machine-id"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];
  };

  # sops-nix / agenix users: point your host key at the persisted path,
  # since /etc/ssh is recreated from /persist via bind mounts.

  # ----------------------------------------------------------- maintenance
  services.zfs.autoScrub.enable = true;       # monthly scrub
  services.zfs.trim.enable = true;            # periodic TRIM

  # Automatic snapshots of the "safe" datasets (opt-in per dataset)
  services.sanoid = {
    enable = true;
    datasets."rpool/safe" = {
      recursive = true;
      autosnap = true;
      autoprune = true;
      hourly = 24;
      daily = 14;
      monthly = 3;
    };
  };

  # Don't let nix-daemon eat all RAM and force swapping during big builds
  zramSwap.enable = false; # redundant alongside a real 32G swap partition
}
