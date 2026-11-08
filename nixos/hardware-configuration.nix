{
  config,
  lib,
  modulesPath,
  ...
}:

let
  rootDev = "/dev/disk/by-uuid/ac24eaab-e1d2-49fd-afba-05d23bd02da0";
  commonOpts = [
    "noatime"
    "compress=zstd:1"
    "ssd"
    "discard=async"
  ];
in
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "ahci"
    "usb_storage"
    "usbhid"
    "sd_mod"
    "btrfs"
  ];

  boot.initrd.luks.devices."cryptroot" = {
    device = "/dev/disk/by-uuid/8e911e30-4d8c-4844-bd7a-034691a3c3f0";
    allowDiscards = true;
    bypassWorkqueues = true;
  };

  fileSystems."/" = {
    device = rootDev;
    fsType = "btrfs";
    options = commonOpts ++ [ "subvol=@" ];
  };

  fileSystems."/home" = {
    device = rootDev;
    fsType = "btrfs";
    options = commonOpts ++ [ "subvol=@home" ];
    neededForBoot = true;
  };

  fileSystems."/nix" = {
    device = rootDev;
    fsType = "btrfs";
    options = [
      "noatime"
      "nodatacow"
      "ssd"
      "discard=async"
      "subvol=@nix"
    ];
  };

  fileSystems."/var/log" = {
    device = rootDev;
    fsType = "btrfs";
    options = [
      "noatime"
      "ssd"
      "discard=async"
      "subvol=@log"
    ];
  };

  fileSystems."/.snapshots" = {
    device = rootDev;
    fsType = "btrfs";
    options = commonOpts ++ [ "subvol=@snapshots" ];
  };

  # Required by `services.snapper.configs.home` for the `/home` subvolume: the NixOS
  # Snapper module expects a `.snapshots` subvolume inside each configured subvolume.
  # Create `/home/.snapshots` on the target host before activation, or `neededForBoot`
  # may send the system to emergency mode. Do not mount the root `@snapshots` subvolume
  # at `/home/.snapshots`, because that would collide with the root Snapper config; this
  # configuration uses a separate `@home/.snapshots` subvolume.
  fileSystems."/home/.snapshots" = {
    device = rootDev;
    fsType = "btrfs";
    options = commonOpts ++ [ "subvol=@home/.snapshots" ];
    neededForBoot = true;
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/803D-F784";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  swapDevices = [
    {
      device = "/dev/disk/by-partuuid/91db3839-6320-4ab7-a076-78f3d5766d24";
      randomEncryption.enable = true;
      priority = 10;
    }
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
