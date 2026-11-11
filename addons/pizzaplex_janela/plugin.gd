@tool
extends EditorPlugin

func _enter_tree() -> void:
	Callable(self, "ajustar").call_deferred()

func ajustar() -> void:
	if not is_inside_tree(): return
	var configuracoes := EditorInterface.get_editor_settings()
	if configuracoes == null: return
	if bool(configuracoes.get_project_metadata("pizzaplex", "janela_ajustada", false)): return
	configuracoes.set_project_metadata("game_view", "embed_size_mode", 2)
	configuracoes.set_project_metadata("pizzaplex", "janela_ajustada", true)
