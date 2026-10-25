{ config, lib, modulesPath, ... }:

let
  rootDev    = "/dev/disk/by-uuid/14d6b717-2c6d-42fb-9794-f3bb4ad729a9";
  commonOpts = [ "noatime" "compress=zstd:1" "ssd" "discard=async" ];
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
    options = [ "noatime" "nodatacow" "ssd" "discard=async" "subvol=@nix" ];
  };

  fileSystems."/var/log" = {
    device  = rootDev;
    fsType  = "btrfs";
    options = [ "noatime" "ssd" "discard=async" "subvol=@log" ];
  };

  fileSystems."/.snapshots" = {
    device  = rootDev;
    fsType  = "btrfs";
    options = commonOpts ++ [ "subvol=@snapshots" ];
  };

  # Required by `services.snapper.configs.home` for the `/home` subvolume: the NixOS
  # Snapper module expects a `.snapshots` subvolume inside each configured subvolume.
  # Create `/home/.snapshots` on the target host before activation, or `neededForBoot`
  # may send the system to emergency mode. Do not mount the root `@snapshots` subvolume
  # at `/home/.snapshots`, because that would collide with the root Snapper config; this
  # configuration uses a separate `@home/.snapshots` subvolume.
  fileSystems."/home/.snapshots" = {
    device  = rootDev;
    fsType  = "btrfs";
    options = commonOpts ++ [ "subvol=@home/.snapshots" ];
    neededForBoot = true;
  };

  fileSystems."/boot" = {
    device  = "/dev/disk/by-uuid/FB17-7687";
    fsType  = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  swapDevices = [{
  device = "/dev/disk/by-partuuid/efe099dd-2630-4f9c-802a-25e758815777";
  randomEncryption.enable = true;
  priority = 10;
}];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
