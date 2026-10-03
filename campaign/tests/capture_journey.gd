extends SceneTree
## Renderer-only review of every chapter. Never writes a player checkpoint.
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	root.size = Vector2i(1280, 720)
	var output := OS.get_environment("TEMP")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	var game := preload("res://campaign/main.tscn").instantiate()
	game.persistence_enabled = false
	root.add_child(game)
	for i in 9:
		await game.load_stage(i)
		for frame in 20:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := output.path_join("chapter-%02d.png" % (i + 1))
		print("CAPTURE ", path, " result=", root.get_texture().get_image().save_png(path))
		var stone: String = game.Catalog.STAGES[i].stone
		if not stone.is_empty():
			game.echo.collect_stone(stone)
	game.free()
	await create_timer(0.15).timeout
	quit()
