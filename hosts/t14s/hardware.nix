# hosts/t14s/hardware.nix
#
# Disko owns all fileSystems/swap entries, so this stays minimal.
# After the first boot, compare against the output of
# `nixos-generate-config --show-hardware-config` and merge anything
# extra it detects for your exact unit.
{ config, lib, pkgs, ... }:

{
  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "thunderbolt"
    "usb_storage"
    "sd_mod"
  ];
  boot.kernelModules = [ "kvm-intel" ];

  hardware.cpu.intel.updateMicrocode = true;

  # Hardware video decode on the Arc iGPU (Arrow Lake uses the modern
  # intel-media-driver, not the legacy vaapi-intel one)
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      vpl-gpu-rt # Quick Sync / oneVPL runtime
    ];
  };

  # Kernel: stick with the NixOS default (LTS). On 26.05 it is recent
  # enough for Arrow Lake-U (Core Ultra 200 series needs >= 6.11 for
  # solid graphics/power support), and OpenZFS frequently lags behind
  # pkgs.linuxPackages_latest — chasing the newest kernel on a ZFS-root
  # machine is how you end up with a system that won't rebuild. If you
  # ever need a newer kernel, pin a specific version and check it builds
  # before rebooting.

  nixpkgs.hostPlatform = "x86_64-linux";
}
