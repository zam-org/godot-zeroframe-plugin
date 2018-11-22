tool
extends EditorPlugin

func _enter_tree():
	add_custom_type("ZeroNet", "Node", load("res://addons/ZeroNet/ZeroNet.gd"), load("res://addons/ZeroNet/icon.png"))

func _exit_tree():
	pass