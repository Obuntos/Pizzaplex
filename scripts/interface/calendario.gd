class_name UICalendarioPlex
extends Control

const T = preload("res://scripts/interface/tema_hud.gd")
var jogo: Node
var janela := PanelContainer.new()
var corpo := VBoxContainer.new()
var mes_base := 0
var escolhido := 0
var palco := -1

func configurar(cena: Node) -> void:
	jogo = cena
	theme = T.criar()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fundo := ColorRect.new()
	fundo.color = Color(.025,.04,.05,.84)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	add_child(janela)
	janela.add_child(corpo)
	janela.mouse_force_pass_scroll_events = false
	get_viewport().size_changed.connect(redimensionar)
	hide()

func redimensionar() -> void:
	var tela := get_viewport_rect().size
	janela.size = Vector2(minf(900,tela.x-32),minf(604,tela.y-28))
	janela.position = (tela-janela.size)*.5

func abrir() -> void:
	mes_base = -int(jogo.calendario.data().dia)+1
	escolhido = 0
	show()
	preencher()
	redimensionar()

func navegar(direcao: int) -> void:
	if direcao>0:
		var mes: int = jogo.calendario.data(mes_base).mes
		while jogo.calendario.data(mes_base).mes==mes: mes_base+=1
	else:
		mes_base-=1
		mes_base-=int(jogo.calendario.data(mes_base).dia)-1
	preencher()

func preencher() -> void:
	for filho in corpo.get_children():
		corpo.remove_child(filho)
		filho.queue_free()
	var topo := HBoxContainer.new()
	corpo.add_child(topo)
	T.botao(topo,"<",func(): navegar(-1),T.AZUL)
	var data: Dictionary = jogo.calendario.data(mes_base)
	var nome := T.texto(topo,"AGENDA / "+CalendarioPlex.MESES[int(data.mes)-1].to_upper()+" "+str(data.ano),22)
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	T.botao(topo,">",func(): navegar(1),T.AZUL)
	T.botao(topo,"Fechar",hide)
	var principal := HBoxContainer.new()
	principal.add_theme_constant_override("separation",18)
	corpo.add_child(principal)
	var grade := GridContainer.new()
	grade.columns = 7
	principal.add_child(grade)
	for dia in ["DOM","SEG","TER","QUA","QUI","SEX","SÁB"]: T.texto(grade,dia,14,T.SUAVE).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var inicio: int = mes_base-int(data.semana)
	for i in 42:
		var offset := inicio+i
		var d: Dictionary = jogo.calendario.data(offset)
		var celula := Button.new()
		celula.custom_minimum_size = Vector2(66,65)
		celula.disabled = d.mes!=data.mes
		if celula.disabled: celula.modulate=Color(.5,.55,.55)
		if offset==escolhido: celula.add_theme_stylebox_override("normal",T.caixa(T.AZUL,T.AMBAR,3))
		celula.tooltip_text = "%02d/%02d · %s · %d °C" % [d.dia,d.mes,jogo.calendario.previsao(offset),jogo.calendario.temperatura(offset)]
		celula.pressed.connect(func(): escolhido=offset; preencher())
		grade.add_child(celula)
		var numero := T.texto(celula,str(d.dia),16,T.AMBAR if offset==0 else T.PAPEL)
		numero.position = Vector2(6,3)
		var icone := IconeHudPlex.new(jogo.calendario.previsao(offset))
		icone.scale = Vector2(.7,.7)
		icone.position = Vector2(15,25)
		celula.add_child(icone)
	var detalhes := VBoxContainer.new()
	detalhes.custom_minimum_size.x = 260
	principal.add_child(detalhes)
	var d: Dictionary = jogo.calendario.data(escolhido)
	T.texto(detalhes,"%02d DE %s" % [d.dia,CalendarioPlex.MESES[int(d.mes)-1].to_upper()],18,T.AMBAR)
	T.texto(detalhes,jogo.calendario.previsao(escolhido)+" · "+str(jogo.calendario.temperatura(escolhido))+" °C",18)
	T.texto(detalhes,"PREVISÃO DO DIA",12,T.SUAVE)
	detalhes.add_child(HSeparator.new())
	jogo.animatronicos.palcos.atualizar()
	var ids: Array = []
	for id in jogo.animatronicos.palcos.grupos.values():
		if not ids.has(id): ids.append(id)
	ids.sort()
	if ids.is_empty():
		T.texto(detalhes,"Construa um palco para\nprogramar apresentações.",16)
		return
	if not ids.has(palco): palco = ids[0]
	var seletor := OptionButton.new()
	detalhes.add_child(seletor)
	for id in ids:
		var total: int = jogo.personagens.filter(func(a): return a.robo and jogo.animatronicos.palcos.da_pose(a.pose)==id).size()
		seletor.add_item("Palco %d · %d robô(s)" % [ids.find(id)+1,total])
		seletor.set_item_metadata(seletor.item_count-1,id)
	seletor.select(ids.find(palco))
	seletor.item_selected.connect(func(i): palco=int(seletor.get_item_metadata(i)); preencher())
	T.texto(detalhes,"ANIMATRÔNICOS",14,T.SUAVE)
	for a in jogo.personagens:
		if not a.robo or jogo.animatronicos.palcos.da_pose(a.pose)!=palco: continue
		var nome_robo:=IdentidadesPlex.completo(a)
		T.texto(detalhes,nome_robo+" · "+str(a.robotica.get("apresentacao","cantar")).capitalize(),16).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var regra := T.texto(detalhes,"O palco liga com a plateia. Clique com o botão direito em um animatrônico para escolher Cantar, Falar ou Dançar na ficha dele.",16,T.SUAVE)
	regra.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	regra.custom_minimum_size.x=250
