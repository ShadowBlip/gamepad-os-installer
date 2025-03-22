extends RefCounted
class_name Hardware

## Returns the CPU data for the given system
static func get_cpu_info() -> CpuInfo:
	var info := CpuInfo.new()
	var output: Array[String] = []
	
	OS.execute("cat", ["/proc/cpuinfo"], output)
	if output.is_empty():
		return info
	var stdout := output[0] as String

	for line in stdout.split("\n"):
		if line.begins_with("vendor_id"):
			var parts := line.split(":")
			if parts.is_empty():
				continue
			info.vendor = parts[-1].strip_edges()
			continue
		if line.begins_with("model name"):
			var parts := line.split(":")
			if parts.is_empty():
				continue
			info.model = parts[-1].strip_edges()
			break

	return info


## Returns the DMI data for the given system
static func get_dmi_info() -> DmiInfo:
	var dmi := DmiInfo.new()
	var output: Array[String] = []

	dmi.bios_date = get_dmi_property("bios_date", output)
	dmi.bios_release = get_dmi_property("bios_release", output)
	dmi.bios_vendor = get_dmi_property("bios_vendor", output)
	dmi.bios_version = get_dmi_property("bios_version", output)
	dmi.board_name = get_dmi_property("board_name", output)
	dmi.board_vendor = get_dmi_property("board_vendor", output)
	dmi.board_version = get_dmi_property("board_version", output)
	dmi.chassis_type = get_dmi_property("chassis_type", output)
	dmi.chassis_vendor = get_dmi_property("chassis_vendor", output)
	dmi.chassis_version = get_dmi_property("chassis_version", output)
	dmi.product_family = get_dmi_property("product_family", output)
	dmi.product_name = get_dmi_property("product_name", output)
	dmi.product_sku = get_dmi_property("product_sku", output)
	dmi.product_uuid = get_dmi_property("product_uuid", output)
	dmi.product_version = get_dmi_property("product_version", output)
	dmi.vendor_name = get_dmi_property("sys_vendor", output)

	return dmi


## Returns the value of the given DMI property
static func get_dmi_property(name: String, output: Array[String] = []) -> String:
	OS.execute("cat", ["/sys/class/dmi/id/product_name"], output)
	if output.is_empty():
		return ""
	var stdout := output[0] as String
	var value := stdout.strip_edges()
	output.clear()

	return value


class DmiInfo:
	var bios_date: String
	var bios_release: String
	var bios_vendor: String
	var bios_version: String
	var board_name: String
	var board_vendor: String
	var board_version: String
	var chassis_type: String
	var chassis_vendor: String
	var chassis_version: String
	var product_family: String
	var product_name: String
	var product_sku: String
	var product_uuid: String
	var product_version: String
	var vendor_name: String


class CpuInfo:
	var vendor: String
	var model: String
