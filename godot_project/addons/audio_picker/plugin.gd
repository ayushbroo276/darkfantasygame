@tool
extends EditorPlugin

var export_plugin: AudioPickerExportPlugin


func _enter_tree() -> void:
	export_plugin = AudioPickerExportPlugin.new()
	add_export_plugin(export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(export_plugin)
	export_plugin = null


class AudioPickerExportPlugin extends EditorExportPlugin:
	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		return PackedStringArray(["audio_picker/audio_picker.aar"])

	func _get_name() -> String:
		return "AndroidAudioPicker"
