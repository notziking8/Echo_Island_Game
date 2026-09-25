extends SceneTree


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	root.size = Vector2i(1280, 800)
	var game: Node = load("res://integration/team_game.tscn").instantiate()
	root.add_child(game)
	for frame in 60:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "user://echo_team_integration.png"
	var result := root.get_texture().get_image().save_png(path)
	print("Integration preview: ", ProjectSettings.globalize_path(path))
	quit(0 if result == OK else 1)
