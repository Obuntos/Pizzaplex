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
	botao=T.botao(linha,"",func():
		jogo.mapa_conforto.alternar()
		botao.button_pressed=jogo.mapa_conforto.ativo
		if not jogo.mapa_conforto.ativo: painel.hide(),Color("4a465c"))
	botao.toggle_mode=true
	botao.custom_minimum_size=Vector2(48,48)
	botao.tooltip_text="Conforto das salas: ative e passe o mouse pelos tiles."
	var imagem := IconeHudPlex.new("conforto")
	botao.add_child(imagem)
	raiz.add_child(painel)
	painel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	painel.custom_minimum_size.x=292
	painel.add_theme_stylebox_override("panel",T.caixa(Color("152329"),Color("86aaa5"),14))
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
