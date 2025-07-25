extends Installer
class_name NixOsInstaller

# References:
# - https://nixos.org/manual/nixos/stable/#sec-installation-manual
# - https://nixos.wiki/wiki/NixOS_Installation_Guide


func get_configuration() -> Configuration:
	var config := Configuration.new()
	config.logo = load("res://assets/images/ogui-logo.svg")
	config.theme = load("res://assets/themes/darksoul_theme.tres")
	config.requires_internet = true

	return config


func install(options: Options, dry_run: bool = false) -> void:
	var to_disk := options.target_disk
	set_stage("Formatting disk")
	write_log("Formatting disk: " + to_disk.path)

	var result := await execute("sudo", ["parted", "--script", to_disk.path, "mklabel", "gpt"])
	if result.code != OK:
		finish(STATUS.FAILED, "Failed to format disk")
		return

	set_stage("Partitioning disk")
	set_progress(1)
	result = await execute("sudo", ["parted", "--script", to_disk.path, "mkpart", "root", "ext4", "512MB", "100%"])
	if result.code != OK:
		finish(STATUS.FAILED, "Failed to partition disk")
		return
	result = await execute("sudo", ["parted", "--script", to_disk.path, "mkpart", "ESP", "fat32", "1MB", "512MB"])
	if result.code != OK:
		finish(STATUS.FAILED, "Failed to partition disk")
		return
	result = await execute("sudo", ["parted", "--script", to_disk.path, "set", "2", "esp", "on"])
	if result.code != OK:
		finish(STATUS.FAILED, "Failed to partition disk")
		return

	set_stage("Formatting filesystems")
	set_progress(2)
	var partitions := get_partitions(to_disk)
	if partitions.size() != 2:
		finish(STATUS.FAILED, "Failed to get partitions")
		return
	var root_part := partitions[0]
	var boot_part := partitions[1]
	result = await execute("sudo", ["mkfs.ext4", "-L", "nixos", root_part])
	if result.code != OK:
		finish(STATUS.FAILED, "Failed to format root partition")
		return

	set_progress(3)
	result = await execute("sudo", ["mkfs.fat", "-F", "32", "-n", "boot", boot_part])
	if result.code != OK:
		finish(STATUS.FAILED, "Failed to format EFI partition")
		return

	set_stage("Mounting target drive")
	set_progress(4)
	result = await execute("sudo", ["mount", root_part, "/mnt"])
	if result.code != OK:
		finish(STATUS.FAILED, "Failed to mount root partition")
		return
	set_progress(5)
	result = await execute("sudo", ["mkdir", "-p", "/mnt/boot"])
	if result.code != OK:
		finish(STATUS.FAILED, "Failed to create boot directory")
		return
	result = await execute("sudo", ["mount", "-o", "umask=077", boot_part, "/mnt/boot"])
	if result.code != OK:
		finish(STATUS.FAILED, "Failed to mount boot directory")
		return
	set_progress(6)
	result = await execute("sudo", ["nixos-generate-config", "--root", "/mnt"])
	if result.code != OK:
		finish(STATUS.FAILED, "Failed to generate configuration.nix")
		return

	# Use nixos-facter to gather hardware-specific information about the system.
	# This can be used to create device-specific configs.
	set_stage("Generating hardware configuration")
	set_progress(7)
	result = await execute("sudo", ["nixos-facter", "-o", "/mnt/etc/nixos/facter.json"])
	if result.code != OK:
		finish(STATUS.FAILED, "Failed to run nixos-facter to gather system information")
		return

	# Append the facter path to configuration.nix
	result = await execute("sudo", ["sed", "-i", "s|^}$|  # Path to the output of `nixos-facter` with hardware details\\n  facter.reportPath = ./facter.json;\\n}|g", "/mnt/etc/nixos/configuration.nix"])
	if result.code != OK:
		finish(STATUS.FAILED, "Failed to append facter report to configuration")
		return

	var flake := FileAccess.open("/tmp/flake.nix", FileAccess.WRITE)
	flake.store_string(FLAKE_TEMPLATE)
	flake.close()
	result = await execute("sudo", ["cp", "/tmp/flake.nix", "/mnt/etc/nixos"])
	if result.code != OK:
		finish(STATUS.FAILED, "Failed to copy flake configuration")
		return

	var os_config := FileAccess.open("/tmp/opengamepadui-configuration.nix", FileAccess.WRITE)
	os_config.store_string(CUSTOM_CONFIG_TEMPLATE)
	os_config.close()
	result = await execute("sudo", ["cp", "/tmp/opengamepadui-configuration.nix", "/mnt/etc/nixos"])
	if result.code != OK:
		finish(STATUS.FAILED, "Failed to copy OS configuration")
		return

	set_stage("Configuring Boot")
	result = await execute("sudo", ["sbctl", "create-keys"])
	if result.code != OK:
		write_log("Failed to generate secure boot keys.")
	if result.code == OK:
		result = await execute("sudo", ["mkdir", "-p", "/mnt/var/lib"])
		if result.code != OK:
			write_log("Failed to create target directory for key enrollment")
	if result.code == OK:
		result = await execute("sudo", ["cp", "-rp", "/var/lib/sbctl", "/mnt/var/lib/sbctl"])
		if result.code != OK:
			write_log("Failed to copy generated enrollment keys to target")

	var secure_boot_state := get_secureboot_state()
	if secure_boot_state and secure_boot_state.setup_mode and result.code == OK:
		write_log("Secure boot setup is enabled. Enrolling keys.")
		result = await execute("sudo", ["sbctl", "enroll-keys", "--microsoft"])
		if result.code != OK:
			write_log("Failed to enroll keys")

	set_stage("Installing system")
	progress = 10
	var on_pty_line_written := func(line: String) -> PackedByteArray:
		if line.contains("copying path") and progress < 50:
			progress += 0.07
		elif line.contains("building") and progress < 90:
			progress += 0.1
		elif line.contains("New password:"):
			return "gamer\n".to_utf8_buffer()
		elif line.contains("Retype new password:"):
			return "gamer\n".to_utf8_buffer()
		return PackedByteArray()
	var code := await execute_with_follow("sudo", ["nixos-install", "--root", "/mnt", "--flake", "/mnt/etc/nixos/#nixos"], on_pty_line_written)
	if code != OK:
		finish(STATUS.FAILED, "Failed to run nixos-install")
		return

	set_progress(99)
	if await copy_network_config() != OK:
		write_log("Unable to copy network configuration to target install")

	result = await execute("sudo", ["umount", "/mnt/boot"])
	if result.code != OK:
		write_log("Failed to unmount boot directory")
		return

	result = await execute("sudo", ["umount", "/mnt"])
	if result.code != OK:
		write_log("Failed to unmount boot directory")
		return

	finish(STATUS.OK)


const FLAKE_TEMPLATE: String = """
{
  description = "OS Flake";

  inputs = {
	shadowblip.url = "gitlab:shadowapex/os-flake?ref=stable";
  };

  outputs =
	inputs@{
	  self,
	  shadowblip,
	}:
	{

	  # You can replace "nixos" with your hostname
	  nixosConfigurations.nixos = shadowblip.inputs.nixpkgs.lib.nixosSystem {
		system = "x86_64-linux";
		# Allows `inputs` to be used in configuration
		specialArgs = { inherit inputs; };
		modules = [
		  shadowblip.nixosModules.default
		  ./configuration.nix
		  ./opengamepadui-configuration.nix
		];
	  };

	};
}
"""

const CUSTOM_CONFIG_TEMPLATE: String = """
# Do not modify this file!  It was generated by OpenGamepadUI
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{
  pkgs,
  lib,
  inputs,
  ...
}:

{

}
"""
