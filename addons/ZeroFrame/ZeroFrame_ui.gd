tool
extends Node

onready var ZeroFrame_file = preload("res://addons/ZeroFrame/ZeroFrame.gd")
onready var ZeroFrame = ZeroFrame_file.new()
var config_file = "res://addons/ZeroFrame/config.cfg"

func refresh_values():
	$VBoxContainer/CenterContainer/HBoxContainer/version.text = str(load_setting("zeroframe", "version", "v 0.1"))
	#get the config's buffer sizes and apply them to project settings
	var new_in = load_setting("zeroframe", "max_in_buffer_kb", 64)
	var new_out = load_setting("zeroframe", "max_out_buffer_kb", 64)
	ProjectSettings.set_setting("network/limits/websocket_client/max_in_buffer_kb", new_in)
	ProjectSettings.set_setting("network/limits/websocket_client/max_out_buffer_kb", new_out)	
	
	#update text based on the config file's
	$VBoxContainer/center/HBoxContainer/max_in.text = str(ProjectSettings.get_setting("network/limits/websocket_client/max_in_buffer_kb"))
	$VBoxContainer/center/HBoxContainer/max_out.text = str(ProjectSettings.get_setting("network/limits/websocket_client/max_out_buffer_kb"))
	$VBoxContainer/site_address_edit.text = load_setting("zeroframe", "site_address", "1HeLLo4uzjaLetFx6NH3PMwFP3qbRbTf3D")
	$VBoxContainer/zeronet_address_edit.text = load_setting("zeroframe", "zeronet_address", "127.0.0.1")
	$VBoxContainer/zeronet_port_edit.text = str(load_setting("zeroframe", "zeronet_port", 43110))
	$VBoxContainer/center/HBoxContainer/max_in.text = str(ProjectSettings.get_setting("network/limits/websocket_client/max_in_buffer_kb"))
	$VBoxContainer/center/HBoxContainer/max_out.text = str(ProjectSettings.get_setting("network/limits/websocket_client/max_out_buffer_kb"))	
		
func _on_site_address_edit_text_changed(address):
	save_setting("zeroframe", "site_address", address)	

func _on_zeronet_address_edit_text_changed(address):
	save_setting("zeroframe", "zeronet_address", address)	

func _on_zeronet_port_edit_text_changed(port):
	save_setting("zeroframe", "zeronet_port", int(port))
	
func _on_check_button_pressed():
	# Set status
	$VBoxContainer2/CenterContainer2/connection_status.text = "Checking connection..."
	
	# Connect to site. Timeout and complain if timeout reached
	if yield(ZeroFrame.use_site($VBoxContainer/site_address_edit.text), "site_connected"):
		$VBoxContainer2/CenterContainer2/connection_status.text = "Connection successful!"
	else:
		$VBoxContainer2/CenterContainer2/connection_status.text = "Connection timed out"
	
func _on_buffer_kb_button_pressed():
	$VBoxContainer/buffer_explanation.visible = !$VBoxContainer/buffer_explanation.visible

func _on_automatic_limit_toggled(button_pressed):
	if button_pressed:
		$VBoxContainer/center/HBoxContainer/max_in.editable = false
		$VBoxContainer/center/HBoxContainer/max_out.editable = false
		save_setting("zeroframe", "automatic_buffer_kb", true)

	else:
		$VBoxContainer/center/HBoxContainer/max_in.editable = true
		$VBoxContainer/center/HBoxContainer/max_out.editable = true
		save_setting("zeroframe", "automatic_buffer_kb", false)		

func _on_max_in_text_changed(new_in_limit):
	ProjectSettings.set_setting("network/limits/websocket_client/max_in_buffer_kb", new_in_limit)
	save_setting("zeroframe", "max_in_buffer_kb", new_in_limit)

func _on_max_out_text_changed(new_out_limit):
	ProjectSettings.set_setting("network/limits/websocket_client/max_out_buffer_kb", new_out_limit)
	save_setting("zeroframe", "max_out_buffer_kb", new_out_limit)	

func save_setting(section, key, value):
	var file = ConfigFile.new()
	var err = file.load(config_file)
		
	file.set_value(section, key, value)
	file.save(config_file)
	
func load_setting(section, key, default):
	var file = ConfigFile.new()
	var err = file.load(config_file)
		
	var result = file.get_value(section, key, default)
	return result
	
func reset_to_defaults():
	save_setting("zeroframe", "site_address", "1HeLLo4uzjaLetFx6NH3PMwFP3qbRbTf3D")
	save_setting("zeroframe", "zeronet_address", "127.0.0.1")
	save_setting("zeroframe", "zeronet_port", 43110)
	save_setting("zeroframe", "max_in_buffer_kb", 16)
	save_setting("zeroframe", "max_out_buffer_kb", 16)
	refresh_values()

func _on_defaults_button_pressed():
	reset_to_defaults()