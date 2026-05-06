{ config, lib, pkgs, modulesPath, ... }:

let
  rootDev    = "/dev/disk/by-uuid/2b423ef5-f0e7-4113-a094-8fbb3fd929b4";
  commonOpts = [ "noatime" "compress=zstd:1" "ssd" "space_cache=v2" "discard=async" ];
in
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "nvme" "xhci_pci" "ahci" "usb_storage" "usbhid" "sd_mod"
    "btrfs"
  ];

  boot.initrd.luks.devices."cryptroot" = {
    device           = "/dev/disk/by-uuid/b81da1b3-56a6-427a-ad1e-ccb2e2fb8fb2";
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
    device  = "/dev/disk/by-uuid/83A7-EE0C";
    fsType  = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  swapDevices = [{
    device = "/dev/disk/by-uuid/5e349735-5d50-4d95-a8ba-7b833ea0ad9b";
    priority = 10;
  }];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
