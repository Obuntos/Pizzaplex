class_name VisorPlex
extends RefCounted

var jogo: Node2D
var automatico := true

func configurar(cena: Node2D) -> void:
	jogo = cena
	var janela := jogo.get_window()
	janela.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	janela.content_scale_size = Vector2i.ZERO
	janela.min_size = Vector2i(960, 600)
	janela.size_changed.connect(redimensionar)
	Callable(self, "enquadrar").call_deferred()

func redimensionar() -> void:
	if automatico: Callable(self, "enquadrar").call_deferred()

func enquadrar() -> void:
	if not is_instance_valid(jogo) or not jogo.is_inside_tree(): return
	automatico = true
	var tamanho := jogo.get_viewport_rect().size
	var esquerda: float = jogo.painel.painel.get_global_rect().end.x + 24.0
	var area := Rect2(Vector2(esquerda, 28), tamanho - Vector2(esquerda + 24.0, 110.0))
	if area.size.x < 100.0 or area.size.y < 100.0: return
	var pontos := PackedVector2Array()
	for x in [-0.5, GradePlex.TAMANHO.x - 0.5]:
		for y in [-0.5, GradePlex.TAMANHO.y - 0.5]: pontos.append(GradePlex.projetar(Vector2(x, y)))
	var limites := Rect2(pontos[0], Vector2.ZERO)
	for ponto in pontos: limites = limites.expand(ponto)
	limites.position.y -= 112.0
	limites.size.y += 128.0
	var zoom := clampf(minf(area.size.x / limites.size.x, area.size.y / limites.size.y), 0.30, 2.5)
	jogo.camera.zoom = Vector2.ONE * zoom
	jogo.camera.position = limites.get_center() - (area.get_center() - tamanho * 0.5) / zoom
	jogo.camera.force_update_scroll()

func alternar_tela_cheia() -> void:
	var janela := jogo.get_window()
	janela.mode = Window.MODE_MAXIMIZED if janela.mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN] else Window.MODE_FULLSCREEN
