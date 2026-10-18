Disclaimer

Use at Your Own Risk

Recommended installation method and installer-specific risk

Manual installation is the recommended default. `install.sh` is an optional, higher-risk migration helper for an already-installed NixOS host; it is not a fresh-install or disk-partitioning tool. It has no dry-run mode. After the user acknowledges the warning, it may replace source files under `/etc/nixos/nixos` (including `/etc/nixos/nixos/hooks/qemu`) and write `/var/lib/libvirt/win10.xml`. It does not directly replace the currently active libvirt hook or automatically define the updated VM XML: the active hook is generated from `nixos/configuration.nix` and is refreshed only after a successful NixOS rebuild/activation. Incorrect host-specific values can prevent boot, interrupt graphical access, or make an existing VM unavailable. The script creates selected-file backups and attempts rollback, but this is best-effort and is not equivalent to a full system or VM backup. The script does not automatically rebuild/activate the machine, run `virsh define`, or reboot it. Existing backups are not deleted automatically.

A manual procedure is not risk-free either: commands in `KURULUM.md` include irreversible disk partitioning, encryption, and filesystem creation. Read each command, verify the target disk identity, and retain an independent backup before running any destructive step.

---

This project is provided for educational and informational purposes. By using, modifying, or executing any part of this project, you acknowledge and accept the risks associated with system-level configuration changes.

1. No Warranty

This project is provided "AS IS" and "AS AVAILABLE", without warranties of any kind, express or implied, including but not limited to fitness for a particular purpose, reliability, compatibility, or freedom from defects.

The maintainers do not guarantee that this project will work correctly on every hardware configuration, NixOS release, kernel version, or software environment.

2. Potential Risks

Using this project may result in, but is not limited to:

- Data loss or filesystem corruption.
- An unbootable or unstable operating system.
- Loss of graphical output or failure to restore the desktop session after GPU passthrough.
- Kernel crashes, driver conflicts, or hardware incompatibilities.
- Virtual machine startup failures or corrupted virtual machine disk images.
- Security vulnerabilities caused by incorrect configuration or third-party components.
- Unexpected behavior following system, kernel, or dependency updates.

3. User Responsibility

You are responsible for evaluating the suitability of this project for your system before using it.

You should:

- Back up important data before making system-level changes.
- Review scripts and configuration files before executing them, especially with elevated privileges.
- Verify hardware compatibility and understand the recovery procedure before enabling VFIO or GPU passthrough.
- Maintain a reliable recovery method, such as a working NixOS generation or bootable recovery media.
- Test changes in a controlled environment whenever possible.

4. Third-Party Software

This project may depend on third-party software, repositories, kernels, drivers, and other external components. Those components are subject to their respective licenses, terms, and maintenance policies.

The project maintainers do not control third-party changes, availability, or compatibility.

5. Limitation of Liability

To the maximum extent permitted by applicable law, the project maintainers shall not be liable for any damages arising from the use, inability to use, modification, or distribution of this project, including data loss, system failure, hardware or software incompatibility, or other consequential losses.

Nothing in this disclaimer excludes or limits liability where such exclusion or limitation is prohibited by applicable law.

6. Updates and Compatibility

This project may change without notice. Future NixOS releases, kernel updates, dependency changes, or hardware revisions may introduce regressions or require configuration adjustments.

A previously working configuration does not guarantee that future versions will work correctly.

7. Acceptance of Risk

By using this project, you acknowledge that system-level modifications carry inherent risks and that you are responsible for deciding whether to proceed.

If you do not understand or accept these risks, do not use this project.

---

This disclaimer is not legal advice and does not replace applicable license terms or legal obligations.
