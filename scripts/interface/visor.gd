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
	ativar_camera()
	Callable(self, "enquadrar").call_deferred()

func redimensionar() -> void:
	if automatico: Callable(self, "enquadrar").call_deferred()

func enquadrar() -> void:
	if not is_instance_valid(jogo) or not jogo.is_inside_tree(): return
	automatico = true
	ativar_camera()
	var tamanho := jogo.get_viewport_rect().size
	var esquerda: float = jogo.painel.painel.get_global_rect().end.x + 24.0 if jogo.painel.painel.visible else 24.0
	var baixo := 330.0 if jogo.painel.hud != null and jogo.painel.hud.catalogo.painel.visible else 120.0
	var area := Rect2(Vector2(esquerda, 90), tamanho - Vector2(esquerda + 24.0, baixo+90.0))
	if area.size.x < 100.0 or area.size.y < 100.0: return
	var pontos := PackedVector2Array()
	var minimo := Vector2(-.5,-.5)
	var maximo := Vector2(GradePlex.TAMANHO)-Vector2(.5,.5)
	if not jogo.planta.objetos.is_empty():
		var quantidade:=0
		minimo=Vector2(GradePlex.TAMANHO)
		maximo=Vector2.ZERO
		for o in jogo.planta.objetos.values():
			if o.get("carregada_por",0)>0 or o.get("cidade",false) or MobiliaPlex.dados(o).get("bairro",false): continue
			quantidade+=1
			var posicao := Vector2(o.celula)
			var fim := posicao+Vector2(CatalogoPlex.dimensoes(o.tipo,o.rotacao))-Vector2.ONE
			minimo=minimo.min(posicao-Vector2(.5,.5))
			maximo=maximo.max(fim+Vector2(.5,.5))
		if quantidade==0:
			minimo=Vector2(-.5,-.5)
			maximo=Vector2(GradePlex.TAMANHO)-Vector2(.5,.5)
	for x in [minimo.x,maximo.x]:
		for y in [minimo.y,maximo.y]: pontos.append(GradePlex.projetar(Vector2(x,y)))
	var limites := Rect2(pontos[0], Vector2.ZERO)
	for ponto in pontos: limites = limites.expand(ponto)
	limites.position.y -= 112.0
	limites.size.y += 128.0
	var zoom := clampf(minf(area.size.x / limites.size.x, area.size.y / limites.size.y), 0.30, 2.5)
	jogo.camera.zoom = Vector2.ONE * zoom
	jogo.camera.global_position = limites.get_center() - (area.get_center() - tamanho * 0.5) / zoom
	jogo.camera.reset_smoothing()
	jogo.camera.force_update_scroll()

func alternar_tela_cheia() -> void:
	if Engine.is_embedded_in_editor():return
	var janela := jogo.get_window()
	janela.mode = Window.MODE_MAXIMIZED if janela.mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN] else Window.MODE_FULLSCREEN


func enquadrar_se_automatico() -> void:
	if automatico: enquadrar()


func ativar_camera() -> void:
	if not is_instance_valid(jogo) or not jogo.is_inside_tree(): return
	var camera: Camera2D=jogo.camera
	camera.enabled=true
	camera.anchor_mode=Camera2D.ANCHOR_MODE_DRAG_CENTER
	camera.offset=Vector2.ZERO
	camera.position_smoothing_enabled=false
	camera.rotation_smoothing_enabled=false
	camera.drag_horizontal_enabled=false
	camera.drag_vertical_enabled=false
	camera.make_current()
	camera.force_update_scroll()

func apresentar() -> void:
	if not is_instance_valid(jogo) or not jogo.is_inside_tree(): return
	jogo.show()
	jogo.mundo.show()
	jogo.chao.show()
	jogo.composicao.show()
	enquadrar()
	jogo.visibilidade.atualizar(jogo.camera,jogo.get_viewport())
	for ator in jogo.personagens:
		if ator.visita.get("morto",false) or ator.visita.get("fora_turno",false): continue
		ator.visible=jogo.visibilidade.personagem(ator)
	jogo.chao.queue_redraw()
	jogo.sincronizar()

