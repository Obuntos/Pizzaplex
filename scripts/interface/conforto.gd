class_name UIConfortoPlex
extends RefCounted

const T = preload("res://scripts/interface/tema_hud.gd")
var jogo: Node
var painel := PanelContainer.new()
var titulo := Label.new()
var detalhes := Label.new()
var botao: Button
var espera := 0.0
var sala_anterior := -2

func configurar(cena: Node, raiz: Control, linha: Node) -> void:
	jogo=cena
	botao=BotaoHudPlex.new("res://assets/interface/hud/conforto.png","","Conforto das salas")
	botao.alternavel()
	linha.add_child(botao)
	botao.pressed.connect(func():
		jogo.mapa_conforto.alternar()
		if jogo.mapa_conforto.ativo and jogo.painel.hud.ar_ui.mapa.ativo:jogo.painel.hud.ar_ui.fechar()
		botao.set_pressed_no_signal(jogo.mapa_conforto.ativo)
		if not jogo.mapa_conforto.ativo: painel.hide())
	raiz.add_child(painel)
	painel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	painel.custom_minimum_size.x=292
	painel.add_theme_stylebox_override("panel",KitPlex.moldura("hud_ativo",12))
	var coluna := VBoxContainer.new()
	coluna.mouse_filter=Control.MOUSE_FILTER_IGNORE
	painel.add_child(coluna)
	titulo.add_theme_font_size_override("font_size",19)
	detalhes.add_theme_font_size_override("font_size",16)
	detalhes.custom_minimum_size.x=264
	coluna.add_child(titulo)
	coluna.add_child(detalhes)
	painel.hide()

func atualizar(delta: float) -> void:
	if not jogo.mapa_conforto.ativo or jogo.painel.hud.menu_aberto() or jogo.painel.bloqueia_mouse(jogo.get_viewport().get_mouse_position()) or jogo.carteira.aberto() or jogo.terminal_ui.aberto():
		painel.hide()
		return
	var celula: Vector2i=jogo.apontada()
	var sala: Dictionary=jogo.ambientes.em(celula)
	if sala.is_empty():
		for direcao in GradePlex.VIZINHOS:
			var vizinha: Dictionary=jogo.ambientes.em(celula+direcao)
			if vizinha.get("fechada",false): sala=vizinha; celula+=direcao; break
	if sala.is_empty(): painel.hide(); return
	espera+=delta
	if not painel.visible or sala_anterior!=int(sala.id) or espera>=.5:
		espera=0.0
		sala_anterior=int(sala.id)
		var info: Dictionary=jogo.conforto.em(celula)
		var tinta:=MapaConfortoPlex.cor(float(info.nota))
		titulo.text="Conforto %.1f / 10 · %s" % [info.nota,info.titulo]
		titulo.add_theme_color_override("font_color",tinta)
		var nome: String=str(jogo.ambientes.definicoes.get(sala.tipo,{}).get("nome","")) if sala.tipo!="livre" else ""
		detalhes.text=("Sala: "+nome+"\n\n" if not nome.is_empty() else "")+"Itens: %d\nAnimatrônicos: %d\nSujeira e entulho: %d\n\nVermelho: ruim · Verde: confortável" % [info.itens,info.robos,info.sujeira]
		painel.reset_size()
	var mouse: Vector2=jogo.get_viewport().get_mouse_position()+Vector2(22,24)
	var tela: Vector2=jogo.get_viewport_rect().size
	painel.position=Vector2(clampf(mouse.x,12,tela.x-painel.size.x-12),clampf(mouse.y,12,tela.y-painel.size.y-12))
	painel.show()

func fechar() -> void:
	if jogo.mapa_conforto.ativo: jogo.mapa_conforto.alternar()
	botao.set_pressed_no_signal(false)
	painel.hide()
