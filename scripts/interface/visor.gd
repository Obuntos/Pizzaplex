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
	var minimo := Vector2(-.5,-.5)
	var maximo := Vector2(GradePlex.TAMANHO)-Vector2(.5,.5)
	if not jogo.planta.objetos.is_empty():
		minimo=Vector2(GradePlex.TAMANHO)
		maximo=Vector2.ZERO
		for o in jogo.planta.objetos.values():
			if o.get("carregada_por",0)>0: continue
			var posicao := Vector2(o.celula)
			var fim := posicao+Vector2(CatalogoPlex.dimensoes(o.tipo,o.rotacao))-Vector2.ONE
			minimo=minimo.min(posicao-Vector2(.5,.5))
			maximo=maximo.max(fim+Vector2(.5,.5))
	for x in [minimo.x,maximo.x]:
		for y in [minimo.y,maximo.y]: pontos.append(GradePlex.projetar(Vector2(x,y)))
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

