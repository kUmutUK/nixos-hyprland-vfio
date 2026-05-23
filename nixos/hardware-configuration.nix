{ config, lib, pkgs, modulesPath, ... }:

let
  rootDev    = "/dev/disk/by-uuid/4822b18c-2663-4aa2-9f73-cd026da4b6e6";
  commonOpts = [ "noatime" "compress=zstd:1" "ssd" "space_cache=v2" "discard=async" ];
in
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "nvme" "xhci_pci" "ahci" "usb_storage" "usbhid" "sd_mod"
    "btrfs"
  ];

  boot.initrd.luks.devices."cryptroot" = {
    device           = "/dev/disk/by-uuid/ec0388fd-9499-4df0-8966-5a1b45477473";
    allowDiscards    = true;
    bypassWorkqueues = true;
  };

  fileSystems."/" = {
    device  = rootDev;
    fsType  = "btrfs";
    options = commonOpts ++ [ "subvol=@" ];
  };

  fileSystems."/home" = {
    device  = rootDev;
    fsType  = "btrfs";
    options = commonOpts ++ [ "subvol=@home" ];
    neededForBoot = true;
  };

  fileSystems."/nix" = {
    device  = rootDev;
    fsType  = "btrfs";
    options = [ "noatime" "nodatacow" "ssd" "space_cache=v2" "discard=async" "subvol=@nix" ];
  };

  fileSystems."/var/log" = {
    device  = rootDev;
    fsType  = "btrfs";
    options = [ "noatime" "ssd" "space_cache=v2" "discard=async" "subvol=@log" ];
  };

  fileSystems."/.snapshots" = {
    device  = rootDev;
    fsType  = "btrfs";
    options = commonOpts ++ [ "subvol=@snapshots" ];
  };

  fileSystems."/boot" = {
    device  = "/dev/disk/by-uuid/0D62-0386";
    fsType  = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  swapDevices = [{
    device = "/dev/disk/by-uuid/f3f695b4-4e9d-4b28-9b76-4bca970270c8";
    priority = 10;
  }];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
