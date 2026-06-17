# flake.nix
#
# Repo layout:
#   flake.nix
#   disko.nix                  <- generated earlier
#   zfs-impermanence.nix       <- generated earlier
#   hosts/t14s/configuration.nix
#   hosts/t14s/hardware.nix
#   home/main-user.nix
#
# Install (from the NixOS installer, after cloning this repo):
#   sudo nix --experimental-features "nix-command flakes" run \
#     github:nix-community/disko -- --mode destroy,format,mount ./disko.nix
#   sudo nixos-install --flake .#t14s
#
# Day-to-day:
#   sudo nixos-rebuild switch --flake .#t14s
#   nix flake update          # then rebuild

{
  description = "ThinkPad T14s Gen 6 Intel — niri + noctalia, ZFS, impermanence";

  inputs = {
    # Latest stable release (May 2026)
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence.url = "github:nix-community/impermanence";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Desktop shell for niri (quickshell-based).
    # If it ever fails to build against stable nixpkgs, remove the
    # `follows` line so it uses its own pinned nixpkgs instead.
    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, disko, impermanence, nixos-hardware
                   , home-manager, noctalia, ... }:
    let
      username = "yourname"; # <- CHANGE ME (used for the user account + home-manager)
    in
    {
      nixosConfigurations.t14s = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs username; };
        modules = [
          disko.nixosModules.disko
          impermanence.nixosModules.impermanence

          # Generic Intel laptop profiles — no dedicated T14s Gen 6 Intel
          # profile exists in nixos-hardware yet. (common-cpu-intel also
          # pulls in the Intel GPU profile: media drivers, VA-API.)
          nixos-hardware.nixosModules.common-cpu-intel
          nixos-hardware.nixosModules.common-pc-laptop
          nixos-hardware.nixosModules.common-pc-laptop-ssd

          ./disko.nix
          ./zfs-impermanence.nix
          ./hosts/t14s/configuration.nix
          ./hosts/t14s/hardware.nix

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs username; };
            home-manager.users.${username} = import ./home/main-user.nix;
          }
        ];
      };
    };
}
