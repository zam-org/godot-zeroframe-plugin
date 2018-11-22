tool
extends EditorPlugin

func _enter_tree():
	add_custom_type("ZeroFrame", "Node", load("res://addons/ZeroFrame/ZeroFrame.gd"), load("res://addons/ZeroFrame/icon.png"))

func _exit_tree():
	pass