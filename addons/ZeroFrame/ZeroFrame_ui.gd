tool
extends Node

var ZeroFrame = preload("res://addons/ZeroFrame/ZeroFrame.gd")

func update():
	$"../VBoxContainer/HBoxContainer/max_in".text = str(ProjectSettings.get_setting("network/limits/websocket_client/max_in_buffer_kb"))
	$"../VBoxContainer/HBoxContainer/max_out".text = str(ProjectSettings.get_setting("network/limits/websocket_client/max_out_buffer_kb"))
	$"../VBoxContainer/buffer_explanation".visible = false
	
func _on_site_address_edit_text_changed(address):
	zf_settings._site_address = address

func _on_zeronet_address_edit_text_changed(address):
	zf_settings._daemon_address = address

func _on_zeronet_port_edit_text_changed(port):
	zf_settings._daemon_port = int(port)

func _on_check_button_pressed():
	update()
	# Connect to site
	# TODO: Timeout and complain if timeout reached
	yield(ZeroFrame.use_site(ZeroFrame._site_address), "site_connected")
	
func _on_buffer_kb_button_button_down():
	$"../VBoxContainer/buffer_explanation".visible = !$"../VBoxContainer/buffer_explanation".visible

func _on_automatic_limit_toggled(button_pressed):
	if button_pressed:
		#do what needs to be done to automatically set the limits
		pass
	else:
		# do what needs to be done to not automatically set the limits
		pass

func _on_max_in_text_changed(new_in_limit):
	ProjectSettings.set_setting("network/limits/websocket_client/max_in_buffer_kb", new_in_limit)


func _on_max_out_text_changed(new_out_limit):
	ProjectSettings.set_setting("network/limits/websocket_client/max_out_buffer_kb", new_out_limit)
