{
  config,
  lib,
  modulesPath,
  ...
}:

let
  rootDev = "/dev/disk/by-uuid/c3632154-4368-4184-ba51-8b051da21c84";
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
    device = "/dev/disk/by-uuid/33021fb9-00fd-4be1-a8ee-ab45ce0bbfc2";
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
    device = "/dev/disk/by-uuid/D7B9-C532";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  swapDevices = [
    {
      device = "/dev/disk/by-partuuid/c97e681b-5732-4b6b-b4e7-6a9fc4e3d128";
      randomEncryption.enable = true;
      priority = 10;
    }
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
