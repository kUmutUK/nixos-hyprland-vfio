{ config, lib, pkgs, modulesPath, ... }:

let
  rootDev    = "/dev/disk/by-uuid/14d6b717-2c6d-42fb-9794-f3bb4ad729a9";
  commonOpts = [ "noatime" "compress=zstd:1" "ssd" "space_cache=v2" "discard=async" ];
in
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "nvme" "xhci_pci" "ahci" "usb_storage" "usbhid" "sd_mod"
    "btrfs"
  ];

  boot.initrd.luks.devices."cryptroot" = {
    device           = "/dev/disk/by-uuid/334805fa-4601-4410-8bf5-299fbbd5aba7";
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
    device  = "/dev/disk/by-uuid/FB17-7687";
    fsType  = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  swapDevices = [{
    device = "/dev/disk/by-uuid/9c308abc-19d2-436e-b283-51256ac32600";
    priority = 10;
  }];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
