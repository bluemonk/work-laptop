# disko.nix
#
# Layout:
#   GPT
#   ├── 1G   ESP (vfat, /boot)             <- unencrypted by necessity
#   ├── 32G  LUKS2 "cryptswap" -> swap     <- robust swap + hibernation support
#   └── rest ZFS pool "rpool"              <- native ZFS encryption (aes-256-gcm)
#       ├── local/root   -> /        (rolled back to @blank on every boot)
#       ├── local/nix    -> /nix     (rebuildable, excluded from backups)
#       ├── safe/persist -> /persist (survives reboots, back this up)
#       └── safe/home    -> /home
#
# The local/safe split is the conventional impermanence layout:
# everything under "local" is disposable, everything under "safe" matters.
#
# Apply with:
#   sudo nix run github:nix-community/disko -- --mode destroy,format,mount ./disko.nix
#
# !! Adjust `device` below to your actual disk. Prefer /dev/disk/by-id/... paths.

{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/disk/by-id/CHANGE-ME"; # e.g. nvme-Samsung_SSD_990_PRO_2TB_S6...
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              priority = 1;
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ]; # keep kernels/initrds non-world-readable
              };
            };
            swap = {
              priority = 2;
              size = "32G";
              content = {
                type = "luks";
                name = "cryptswap";
                # A persistent passphrase-protected volume (not a random
                # per-boot key) is required for hibernation to survive reboot.
                settings.allowDiscards = true;
                content = {
                  type = "swap";
                  resumeDevice = true; # sets boot.resumeDevice for hibernation
                };
              };
            };
            zfs = {
              priority = 3;
              size = "100%";
              content = {
                type = "zfs";
                pool = "rpool";
              };
            };
          };
        };
      };
    };

    zpool = {
      rpool = {
        type = "zpool";
        options = {
          ashift = "12";     # 4K sectors; correct for virtually all modern SSDs
          autotrim = "on";
        };
        # Properties on the pool root, inherited by all datasets
        rootFsOptions = {
          mountpoint = "none";
          canmount = "off";
          compression = "zstd";
          atime = "off";
          xattr = "sa";
          acltype = "posixacl";
          dnodesize = "auto";
          normalization = "formD";
          relatime = "on";
          "com.sun:auto-snapshot" = "false";

          # Native ZFS encryption — one passphrase prompt at boot, unlocks everything
          encryption = "aes-256-gcm";
          keyformat = "passphrase";
          keylocation = "prompt";
        };

        datasets = {
          # ---- disposable ------------------------------------------------
          "local" = {
            type = "zfs_fs";
            options.mountpoint = "none";
          };

          "local/root" = {
            type = "zfs_fs";
            mountpoint = "/";
            options.mountpoint = "legacy";
            # Blank snapshot taken right after creation; we roll back to it
            # on every boot (see the initrd service in configuration.nix)
            postCreateHook = "zfs snapshot rpool/local/root@blank";
          };

          "local/nix" = {
            type = "zfs_fs";
            mountpoint = "/nix";
            options = {
              mountpoint = "legacy";
              atime = "off";
            };
          };

          # ---- persistent ------------------------------------------------
          "safe" = {
            type = "zfs_fs";
            options.mountpoint = "none";
          };

          "safe/persist" = {
            type = "zfs_fs";
            mountpoint = "/persist";
            options.mountpoint = "legacy";
          };

          "safe/home" = {
            type = "zfs_fs";
            mountpoint = "/home";
            options.mountpoint = "legacy";
          };
        };
      };
    };
  };
}
