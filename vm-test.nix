# vm-test.nix
#
# Optional scaffolding for booting this config in a disko VM, to validate
# the partition / encrypt / mount / rollback path without real hardware.
#
# It is wired into the flake as a SEPARATE output (`t14s-vm`), so your real
# `t14s` config never sees any of this. Build and run with:
#
#   nix build -L '.#nixosConfigurations.t14s-vm.config.system.build.vmWithDisko'
#   ./result/bin/disko-vm
#
# Quit the VM from the serial console with:  Ctrl-a  then  x
{
  config,
  lib,
  pkgs,
  username,
  ...
}: let
  cfg = config.my.vmTest;
in {
  options.my.vmTest = {
    enable = lib.mkEnableOption "disko VM-test scaffolding";

    imageSize = lib.mkOption {
      type = lib.types.str;
      default = "24G";
      description = ''
        Backing size for the VM's virtual disk. Your real layout uses
        size = "100%" for the pool, which only resolves to a number once it
        lands on a disk, so the VM needs a concrete bound. Holds the 1G ESP,
        the (shrunk) swap partition below, and the ZFS pool.
      '';
    };

    memSize = lib.mkOption {
      type = lib.types.int;
      default = 4096;
      description = "VM RAM in MiB.";
    };

    swapSize = lib.mkOption {
      type = lib.types.str;
      default = "2G";
      description = ''
        VM-only override for the swap partition. Your real config uses 32G,
        which would blow past a sane VM image size — there's no point
        reserving 32G of swap just to watch the thing boot.
      '';
    };
  };

  # --------------------------------------------------------------------
  # The robust neededForBoot fix.
  #
  # vmWithDisko builds a SEPARATE nested NixOS config whose qemu-vm layer
  # rebuilds `fileSystems` and resets neededForBoot. That reset wins over
  # mkForce AND mkOverride — no priority number reaches it, because the VM
  # layer reconstructs the entries rather than merging into them.
  #
  # `apply` sidesteps the whole priority system: it post-processes the
  # FINAL resolved value of the option, after every merge and override has
  # happened. Here we OR neededForBoot with "is this an impermanence root"
  # (/ for the wiped ephemeral side, /persist for the persistent side), so
  # it is forced true no matter what the VM layer set. Gated on cfg.enable
  # so the option declaration is harmless when VM-test mode is off.
  options.fileSystems = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({config, ...}: {
      options.neededForBoot = lib.mkOption {
        apply = orig:
          orig
          || (cfg.enable
            && (config.mountPoint == "/" || config.mountPoint == "/persist"));
      };
    }));
  };

  config = lib.mkIf cfg.enable {
    # ---- VM disk + RAM -------------------------------------------------
    # These merge into the existing disko structure; nested attrs merge
    # recursively, so siblings in disko.nix are left intact.
    disko.devices.disk.main.imageSize = cfg.imageSize;
    disko.devices.disk.main.content.partitions.swap.size = lib.mkForce cfg.swapSize;

    disko.memSize = cfg.memSize;

    # ---- VM-only machine config ---------------------------------------
    # Applied only to the vmWithDisko runner, never to the installed system.
    virtualisation.vmVariantWithDisko = {
      virtualisation.cores = 4;
      # Headless serial console — easier to drive than a graphical window,
      # and you get to watch the early-boot ZFS import + rollback service.
      virtualisation.graphics = false;
    };

    # ---- credentials ---------------------------------------------------
    # Your real account uses hashedPassword; override it to a known plain
    # password so you can actually log into the VM. Login: <username> / "vm".
    users.users.${username} = {
      hashedPassword = lib.mkForce null;
      password = lib.mkForce "vm";
    };
    users.mutableUsers = lib.mkForce true;
  };
}
