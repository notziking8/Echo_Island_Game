extends SceneTree
## Optional rendered smoke check. Run without --headless, with --rendering-method gl_compatibility.


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	root.size = Vector2i(1280, 800)
	var sandbox: Node = load("res://systems/echo/demo/echo_sandbox.tscn").instantiate()
	root.add_child(sandbox)
	if "--wheel" in OS.get_cmdline_user_args():
		sandbox.wheel.open()
		sandbox.wheel.select_direction(Vector2.RIGHT)
	for frame in range(10):
		await process_frame
	await RenderingServer.frame_post_draw
	var output := "user://echo_wheel_preview.png" if "--wheel" in OS.get_cmdline_user_args() else "user://echo_sandbox_preview.png"
	var result := root.get_texture().get_image().save_png(output)
	print("Preview: ", ProjectSettings.globalize_path(output), " (", error_string(result), ")")
	quit(0 if result == OK else 1)
