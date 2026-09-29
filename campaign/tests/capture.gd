extends SceneTree
## Run with a real renderer, -- --output=C:/absolute/folder (not --headless).
func _initialize() -> void:
	capture.call_deferred()

func capture() -> void:
	root.size = Vector2i(1280, 720)
	var output := OS.get_environment("TEMP")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	var game := preload("res://campaign/main.tscn").instantiate()
	root.add_child(game)
	await frames(15)
	await save(output.path_join("echo-title.png"))
	await game.load_stage(0)
	await frames(30)
	await save(output.path_join("echo-arrival.png"))
	await game.load_stage(1)
	game.stage.player.position = Vector3(0, 0.1, 5)
	await frames(15)
	await save(output.path_join("echo-earth-ruins.png"))
	# Cosmetic review view, not a simulated playthrough or production shortcut.
	game.echo.collect_stone("earth")
	game.echo.begin_generation(2)
	game.echo.collect_stone("wind")
	game.echo.begin_generation(3)
	game.echo.collect_stone("water")
	game.echo.begin_generation(4)
	game.echo.collect_stone("time")
	await game.load_stage(8)
	game.stage.player.position = Vector3(0, 0.1, -16)
	await frames(15)
	await save(output.path_join("echo-core.png"))
	game.free()
	quit()

func frames(count: int) -> void:
	for i in count:
		await process_frame

func save(path: String) -> void:
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(path)
	print("CAPTURE ", path, " result=", result)
