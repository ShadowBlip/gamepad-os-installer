extends Resource
class_name Installer

signal install_progressed(percent: float)
signal install_stage_started(text: String)
signal install_completed(status: STATUS, error: String)
signal log_written(text: String)
signal child_added(node: Node)
signal child_removed(node: Node)

enum STATUS {
	OK = 0,
	FAILED,
}

## Whether or not this installer should do a dry-run
var dry_run: bool = false
## Progress of the installation as a percentage
var progress: float = 0.0:
	set(v):
		progress = v
		set_progress(v)
## Current stage of the installation
var stage: String = "":
	set(v):
		stage = v
		set_stage(v)


## Write the given message to the log
func write_log(msg: String) -> void:
	print("LOG: ", msg)
	if not msg.ends_with("\n"):
		msg += "\n"
	log_written.emit(msg)


## Notify the installer of the stage of installation
func set_stage(stage: String) -> void:
	write_log("Stage: " + stage)
	install_stage_started.emit(stage)


## Notify the installer of the percentage complete
func set_progress(percent: float) -> void:
	install_progressed.emit(percent)


## Notify the installer that the installation has completed
func finish(status: STATUS, error: String = "") -> void:
	if not error.is_empty():
		write_log("Installation failed with error: " + error)
	install_completed.emit(status, error)


## Executes the given command asyncronously. If [dry_run] is `true`, this will
## simply sleep instead of actually executing the command.
func execute(command: String, args: Array[String]) -> Command:
	write_log("Executing command: '" + command + " " + " ".join(args) + "'")
	var cmd := _create_command(command, args)
	cmd.execute()
	await cmd.finished as int
	if not cmd.stdout.is_empty():
		write_log(cmd.stdout)
	if not cmd.stderr.is_empty():
		write_log(cmd.stderr)

	return cmd


## Executes the given command asyncronously and execute the given callback whenever
## text is written to stdout by the program. Returns the exit code of the command
## when it has finished executing
func execute_with_follow(command: String, args: Array[String], callback: Callable) -> int:
	if dry_run:
		return OK
	var pty := Pty.new()
	var on_line_written := func(text: String):
		write_log(text)
		var to_send := callback.call(text) as PackedByteArray
		if to_send.size() > 0:
			pty.write(to_send)
	pty.line_written.connect(on_line_written)
	add_child(pty)
	pty.exec(command, PackedStringArray(args))
	var exit_code := await pty.finished as int
	remove_child(pty)
	return exit_code


func _create_command(command: String, args: Array[String]) -> Command:
	if dry_run:
		return Command.create("sleep", ["1"])
	else:
		return Command.create(command, args)


## Returns the installer configuration
func get_configuration() -> Configuration:
	return Configuration.new()


## Return the available disks
func get_available_disks() -> Array[Disk]:
	var disks: Array[Disk] = []
	var output := []
	if OS.execute("lsblk", ["--list", "-n", "-o", "name,type,size,model"], output) != OK:
		print("Unable to read devices: ", output[0])
		return disks
	var stdout := output[0] as String

	# Parse the output
	for line in stdout.split("\n"):
		if not line.contains("disk"):
			continue
		var parts := line.split(" ", false, 3)
		if parts.size() < 4:
			continue
		var disk := Disk.new()
		disk.name = parts[0]
		disk.path = "/dev/" + disk.name
		disk.size = parts[2]
		disk.model = parts[3]
		disk.install_found = has_existing_install(disk.name)
		disks.append(disk)
	
	return disks


## Returns the path to the partitions on the given disk.
## E.g. ["/dev/sda1", "/dev/sda2"]
func get_partitions(disk: Disk) -> PackedStringArray:
	var partitions := PackedStringArray()
	var output := []
	if OS.execute("lsblk", ["--list", "-n", "-o", "name,type", disk.path], output) != OK:
		push_error("Unable to read partitions on disk: ", output[0])
		return partitions
	var stdout := output[0] as String
	
	for line in stdout.split("\n"):
		if line.contains("disk") or not line.contains("part"):
			continue
		var parts := line.split(" ", false, 2)
		partitions.append("/dev/" + parts[0])
		
	return partitions


## Returns true if the block device at the given path has an existing install 
func has_existing_install(path: String) -> bool:
	return false


## Starts installing the OS to the given disk.
func install(to_disk: Disk, dry_run: bool = false) -> void:
	write_log("Installation started")
	finish(STATUS.FAILED, "Installer has not implemented install steps")


## Copy over all network configuration from the live session to the system
func copy_network_config(dest: String = "/mnt/etc/NetworkManager/system-connections", source: String = "/etc/NetworkManager") -> Error:
	var result := await execute("sudo", ["mkdir", "-p", "-m=700", dest])
	if result.code != OK:
		return FAILED
	result = await execute("sudo", ["cp", "-r", source, dest])
	if result.code != OK:
		return FAILED
	return OK


## Add a child to the scene tree
func add_child(node: Node) -> void:
	child_added.emit(node)


## Remove a child from the scene tree
func remove_child(node: Node) -> void:
	child_removed.emit(node)


## Installer configuration
class Configuration:
	var logo: Texture2D
	var theme: Theme
	var name: String
	var requires_internet: bool

	func _init() -> void:
		requires_internet = true


## Simple container for holding information about a disk
class Disk:
	var name: String
	var path: String
	var model: String
	var size: String
	var install_found: bool
