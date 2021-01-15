tool
extends EditorPlugin

var _scene = null
var _instance = null

var _restore_enabled = false # Used to restore enabled setting after env has been edited

var _button = MenuButton.new()
var _file_dialog = EditorFileDialog.new()
var _msg_dialog = AcceptDialog.new()

enum MenuOption {
	MENU_LOAD_SCENE,
	MENU_LOAD_PRESET
	MENU_EDIT_SCENE,
	MENU_ENABLE,
}

func _enter_tree():
	connect("scene_changed", self, "_on_scene_changed")
	get_tree().connect("node_added", self, "_on_node_added")
	
	_file_dialog.add_filter("*.tscn, *.scn; Scenes")
	_file_dialog.mode = _file_dialog.MODE_OPEN_FILE
	_file_dialog.connect("file_selected", self, "_on_file_selected")

	var editor_interface = get_editor_interface()
	var base_control = editor_interface.get_base_control()
	base_control.add_child(_file_dialog)
	base_control.add_child(_msg_dialog)

	_button.get_popup().connect("id_pressed", self, "_on_popup_id_pressed")

	_button.text = "Editor Environment"
	_button.get_popup().add_item("Load Environment Scene...", MenuOption.MENU_LOAD_SCENE)
	_button.get_popup().add_item("Load Preset", MenuOption.MENU_LOAD_PRESET)
	_button.get_popup().add_item("Edit Environment Scene", MenuOption.MENU_EDIT_SCENE)
	_button.get_popup().add_check_item("Enabled", MenuOption.MENU_ENABLE)

	_button.get_popup().set_item_disabled(_button.get_popup().get_item_index(MenuOption.MENU_EDIT_SCENE), true)
	_button.get_popup().set_item_disabled(_button.get_popup().get_item_index(MenuOption.MENU_ENABLE), true)

	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, _button)

	if _scene_is_empty():
		_disable_menu()

func _exit_tree():
	remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, _button)

func _on_popup_id_pressed(id):
	match id:
		MenuOption.MENU_LOAD_SCENE:
			_on_load_scene_pressed()
		MenuOption.MENU_LOAD_PRESET:
			_on_load_preset_pressed()
		MenuOption.MENU_EDIT_SCENE:
			_on_edit_scene_pressed()
		MenuOption.MENU_ENABLE:
			_on_enabled_pressed()

func _on_load_scene_pressed():
	_file_dialog.popup_centered_ratio(0.8)

func _on_load_preset_pressed():
	_load_environment("res://addons/quickenv/PresetEnv.tscn")

func _on_edit_scene_pressed():
	if _scene.resource_path == "res://addons/quickenv/PresetEnv.tscn":
		_scene = _scene.duplicate(true)
		ResourceSaver.save("res://PresetEnv.tscn", _scene)
		_scene.resource_path = "res://PresetEnv.tscn"
		_msg_dialog.dialog_text = "Editable scene created at " + _scene.resource_path + "."
		_msg_dialog.window_title = "File created."
		_msg_dialog.popup_centered()

	get_editor_interface().open_scene_from_path(_scene.resource_path)

func _on_enabled_pressed():
	_toggle_environment()

func _on_file_selected(path):
	_load_environment(path)

func _toggle_environment():
	if _has_environment():
		_remove_environment()
	else:
		_add_environment()
	_button.get_popup().set_item_checked(_button.get_popup().get_item_index(MenuOption.MENU_ENABLE), _has_environment())

func _load_environment(path):
	if _has_environment():
		_remove_environment()

	var resource = load(path)
	if not resource is PackedScene:
		_msg_dialog.dialog_text = "You must select a scene file!"
		_msg_dialog.window_title = "Cannot load scene."
		_msg_dialog.popup_centered()
		return

	_scene = resource
	_instance = _scene.instance()

	if _scene_is_environment() or _scene_is_empty():
		_disable_menu()
	else:
		_enable_menu()
		_button.get_popup().set_item_disabled(_button.get_popup().get_item_index(MenuOption.MENU_EDIT_SCENE), false)
		_button.get_popup().set_item_disabled(_button.get_popup().get_item_index(MenuOption.MENU_ENABLE), false)
		_add_environment()

func _on_scene_changed(_scene_root):
	if _scene_is_environment() or _scene_is_empty():
		_disable_menu()
		if _has_environment():
			_restore_enabled = true
			_remove_environment()
	else:
		_enable_menu()
		if _has_scene_loaded():
			if _has_environment():
				_remove_environment()
				_reload_resource()
				_add_environment()
			else:
				_reload_resource()
				if _restore_enabled:
					_restore_enabled = false
					_add_environment()


func _remove_environment():
	_instance.get_parent().remove_child(_instance)
	_button.get_popup().set_item_checked(_button.get_popup().get_item_index(MenuOption.MENU_ENABLE), false)

func _add_environment():
	get_editor_interface().get_edited_scene_root().add_child(_instance)
	_button.get_popup().set_item_checked(_button.get_popup().get_item_index(MenuOption.MENU_ENABLE), true)

func _reload_resource():
	_instance = _scene.instance()

func _has_environment():
	if _instance and _instance.get_parent():
		return true
	else:
		return false

func _has_scene_loaded():
	if _scene:
		return true
	else:
		return false

func _scene_is_environment():
	var scene_root = get_editor_interface().get_edited_scene_root()
	return _has_scene_loaded() and scene_root != null and scene_root.filename == _scene.resource_path

func _scene_is_empty():
	return get_editor_interface().get_edited_scene_root() == null

func _disable_menu():
	_button.disabled = true

func _enable_menu():
	_button.disabled = false

func _on_node_added(node):
	if node == get_editor_interface().get_edited_scene_root():
		_enable_menu()
		if _restore_enabled:
			_restore_enabled = false
			_add_environment()