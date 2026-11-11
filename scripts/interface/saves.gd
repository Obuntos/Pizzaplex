class_name UISavesPlex
extends Control

signal escolhido(caminho: String)
signal excluido(caminho: String)
signal salvar_escolhido(slot:int)
const T=preload("res://scripts/interface/tema_hud.gd")

class Linha extends Control:
	signal selecionada(caminho:String)
	signal carregar_pedido
	var caminho:=""
	var superficie:=SuperficieVintagePlex.new("linha",22)
	var apagar:Button
	var deslocamento:=0.0
	var sobre:=false
	var saindo:=false
	var escolhida:=false
	var flutuante:TextureRect
	func _ready() -> void:
		custom_minimum_size.y=106
		focus_mode=Control.FOCUS_ALL
		add_child(superficie)
		superficie.pontilhado=true
		superficie.mouse_filter=Control.MOUSE_FILTER_IGNORE
		mouse_entered.connect(func(): sobre=true)
		mouse_exited.connect(func(): sobre=false)
		resized.connect(organizar)
		organizar()
	func organizar() -> void:
		superficie.position=Vector2(deslocamento,0)
		superficie.size=Vector2(maxf(0,size.x-absf(deslocamento)),106)
	func marcar(valor:bool) -> void:
		escolhida=valor
		superficie.selecionado=valor
		superficie.queue_redraw()
	func _gui_input(e:InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_LEFT and e.pressed and not saindo:
			selecionada.emit(caminho)
			grab_focus()
			if e.double_click: carregar_pedido.emit()
			accept_event()
	func _process(delta:float) -> void:
		sobre=get_global_rect().has_point(get_global_mouse_position())
		if not saindo: deslocamento=move_toward(deslocamento,4.0 if sobre else 0.0,delta*50.0)
		if superficie.sobre!=sobre: superficie.sobre=sobre;superficie.queue_redraw()
		if is_instance_valid(flutuante): flutuante.position.y=move_toward(flutuante.position.y,-3.0 if sobre else 0.0,delta*40.0)
		organizar()

var modo_salvar:=false
var sobrescrever:=""
var titulo_label:Label
var instrucao_label:Label
var janela:=SuperficieVintagePlex.new("moldura",18)
var lista:=VBoxContainer.new()
var carregar:Button
var selecionado:=""
var botoes:Dictionary={}
var cartoes:Dictionary={}
var registros:Array[Dictionary]=[]
var excluir_caminho:=""
var tempo_exclusao:=0.0
var ocupado:=false
var erro:=Label.new()
var rolagem:=ScrollContainer.new()
var vazio:=Label.new()
var fechar_botao:Button

func _ready() -> void:
	theme=T.criar()
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	z_index=300
	focus_mode=Control.FOCUS_ALL
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fundo:=TextureRect.new()
	fundo.texture=load("res://assets/interface/vintage/madeira.png")
	fundo.stretch_mode=TextureRect.STRETCH_TILE
	fundo.modulate=Color(.25,.24,.23)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	add_child(janela)
	var madeira:=SuperficieVintagePlex.new("madeira",44)
	var espaco:=madeira.get_theme_stylebox("panel").duplicate() as StyleBoxEmpty
	espaco.content_margin_top=40;espaco.content_margin_bottom=46
	madeira.add_theme_stylebox_override("panel",espaco)
	janela.add_child(madeira)
	var coluna:=VBoxContainer.new()
	coluna.add_theme_constant_override("separation",32)
	madeira.add_child(coluna)
	var topo:=CenterContainer.new()
	topo.draw.connect(func():
		var y0:=floorf((topo.size.y-42)*.5)
		for y in 3:
			for x in range(-44,int(topo.size.x)+44,7):
				topo.draw_rect(Rect2(x,y0+y*14,7,14),Color("6b3f26") if (int(float(x)/7.0)+y)%2==0 else Color("44210f")))
	coluna.add_child(topo)
	var faixa:=SuperficieVintagePlex.new("faixa",14)
	topo.add_child(faixa)
	var faixa_margem:=faixa.get_theme_stylebox("panel").duplicate() as StyleBoxEmpty
	faixa_margem.content_margin_left=38;faixa_margem.content_margin_right=38
	faixa.add_theme_stylebox_override("panel",faixa_margem)
	var titulo_linha:=HBoxContainer.new();titulo_linha.add_theme_constant_override("separation",22);faixa.add_child(titulo_linha)
	for lado in 3:
		if lado==1:
			var titulo:=T.texto(titulo_linha,"CARREGAR PARTIDA",32,VintagePlex.OURO);titulo_label=titulo
			var fonte:=FontVariation.new();fonte.base_font=VintagePlex.fonte("titulo");fonte.spacing_glyph=2;titulo.add_theme_font_override("font",fonte)
			titulo.add_theme_color_override("font_shadow_color",VintagePlex.SOMBRA);titulo.add_theme_constant_override("shadow_offset_x",3);titulo.add_theme_constant_override("shadow_offset_y",3)
		else:
			var quadrado:=ColorRect.new();quadrado.color=VintagePlex.OURO;quadrado.custom_minimum_size=Vector2(8,8);quadrado.size_flags_vertical=Control.SIZE_SHRINK_CENTER;titulo_linha.add_child(quadrado)
	var papel:=SuperficieVintagePlex.new("papel",36)
	var margens:=papel.get_theme_stylebox("panel").duplicate() as StyleBoxEmpty
	margens.content_margin_top=30;margens.content_margin_bottom=22
	papel.add_theme_stylebox_override("panel",margens)
	coluna.add_child(papel)
	var corpo:=VBoxContainer.new()
	corpo.add_theme_constant_override("separation",0)
	papel.add_child(corpo)
	var sub:=HBoxContainer.new()
	sub.add_theme_constant_override("separation",16)
	corpo.add_child(sub)
	for parte in 5:
		if parte in [0,4]:
			var traco:=HSeparator.new();traco.size_flags_horizontal=Control.SIZE_EXPAND_FILL;traco.add_theme_stylebox_override("separator",VintagePlex.caixa(Color("7a5a3a"),Color("7a5a3a"),1));sub.add_child(traco)
		elif parte in [1,3]:
			var dm:=Control.new();dm.custom_minimum_size=Vector2(9,9);dm.size_flags_vertical=Control.SIZE_SHRINK_CENTER
			dm.draw.connect(func(): dm.draw_colored_polygon(PackedVector2Array([Vector2(4.5,0),Vector2(9,4.5),Vector2(4.5,9),Vector2(0,4.5)]),Color("5a3a22")))
			sub.add_child(dm)
		else:
			var texto:=Label.new();instrucao_label=texto;texto.text="Escolha uma partida para continuar.";texto.add_theme_font_override("font",VintagePlex.fonte("forte"));texto.add_theme_font_size_override("font_size",17);texto.add_theme_color_override("font_color",VintagePlex.ESCURO);sub.add_child(texto)
	var intervalo:=Control.new();intervalo.custom_minimum_size.y=28;corpo.add_child(intervalo)
	rolagem.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	rolagem.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	corpo.add_child(rolagem)
	var margem_lista:=MarginContainer.new()
	margem_lista.add_theme_constant_override("margin_left",8);margem_lista.add_theme_constant_override("margin_right",8);margem_lista.add_theme_constant_override("margin_top",8);margem_lista.add_theme_constant_override("margin_bottom",8)
	margem_lista.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	rolagem.add_child(margem_lista)
	lista.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation",24)
	margem_lista.add_child(lista)
	vazio.text="Nenhuma partida salva."
	vazio.add_theme_font_override("font",VintagePlex.fonte("forte"));vazio.add_theme_color_override("font_color",Color("7a5a3a"));vazio.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;vazio.custom_minimum_size.y=200
	corpo.add_child(vazio)
	var espaco_fim:=Control.new();espaco_fim.custom_minimum_size.y=24;corpo.add_child(espaco_fim)
	var ornamento:=Control.new();ornamento.custom_minimum_size.y=48
	ornamento.draw.connect(func():
		for y in 2:
			for x in range(0,floori(ornamento.size.x/10.0)):
				if (x+y)%2==0: ornamento.draw_rect(Rect2(x*10,y*10,10,10),Color("b8925866"))
		var centro:=ornamento.size.x*.5
		ornamento.draw_line(Vector2(0,40),Vector2(centro-18,40),Color("7a5a3a"),2)
		ornamento.draw_line(Vector2(centro+18,40),Vector2(ornamento.size.x,40),Color("7a5a3a"),2)
		ornamento.draw_colored_polygon(PackedVector2Array([Vector2(centro,35.5),Vector2(centro+4.5,40),Vector2(centro,44.5),Vector2(centro-4.5,40)]),Color("5a3a22")))
	corpo.add_child(ornamento)
	erro.add_theme_color_override("font_color",Color("812b24"));erro.add_theme_font_size_override("font_size",15);erro.hide();corpo.add_child(erro)
	var rodape:=HBoxContainer.new()
	rodape.add_theme_constant_override("separation",24)
	coluna.add_child(rodape)
	var voltar:=VintagePlex.botao(rodape,"VOLTAR",fechar,Color("5a2d1c"));voltar.custom_minimum_size=Vector2(200,52);voltar.icon=VintagePlex.icone("seta_esquerda")
	VintagePlex.preparar_pixel(voltar,Color("5a2d1c"),Color("1d0e08"),Color("7a4a2c"))
	var linha:=Control.new();linha.size_flags_horizontal=Control.SIZE_EXPAND_FILL;linha.mouse_filter=Control.MOUSE_FILTER_IGNORE;rodape.add_child(linha)
	linha.draw.connect(func(): linha.draw_rect(Rect2(0,linha.size.y*.5,linha.size.x,4),Color("1d0e08")))
	carregar=VintagePlex.botao(rodape,"CONTINUAR",confirmar,Color("e8a237"),true)
	VintagePlex.preparar_pixel(carregar,Color("e8a237"),Color("7a3d0c"),Color("2a140c"),true)
	carregar.icon=VintagePlex.icone("seta_direita",VintagePlex.ESCURO);carregar.icon_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	carregar.custom_minimum_size=Vector2(200,52)
	carregar.add_theme_font_size_override("font_size",20)
	fechar_botao=VintagePlex.botao(self,"",fechar,VintagePlex.VERMELHO)
	fechar_botao.icon=VintagePlex.icone("x")
	fechar_botao.expand_icon=true
	fechar_botao.add_theme_constant_override("icon_max_width",12)
	VintagePlex.preparar_pixel(fechar_botao,VintagePlex.VERMELHO,Color("3a0b10"),Color("2a140c"))
	for estado in ["normal","hover","pressed","hover_pressed","disabled"]:
		var estilo:=fechar_botao.get_theme_stylebox(estado).duplicate() as StyleBoxTexture
		for lado in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]: estilo.set_content_margin(lado,4)
		fechar_botao.add_theme_stylebox_override(estado,estilo)
	fechar_botao.custom_minimum_size=Vector2(32,32)
	fechar_botao.size=Vector2(32,32)
	get_viewport().size_changed.connect(redimensionar)
	hide()

func redimensionar() -> void:
	if not is_inside_tree(): return
	var tela:=get_viewport_rect().size
	janela.scale=Vector2.ONE
	janela.size=Vector2(760,janela.get_combined_minimum_size().y)
	var escala:=minf(1.0,minf(tela.x/(janela.size.x+48.0),tela.y/(janela.size.y+48.0)))
	janela.scale=Vector2.ONE*escala
	if janela.get_meta("movida_pelo_player",false):
		janela.position=Vector2(clampf(janela.position.x,16,maxf(16,tela.x-janela.size.x*escala-16)),clampf(janela.position.y,16,maxf(16,tela.y-janela.size.y*escala-16))).round()
	else: janela.position=((tela-janela.size*escala)*.5).round()
	fechar_botao.scale=Vector2.ONE*escala
	fechar_botao.position=janela.position+Vector2(janela.size.x-64,32)*escala

func abrir_salvar() -> void:
	modo_salvar=true;abrir_janela()
func abrir() -> void:
	modo_salvar=false;abrir_janela()
func abrir_janela() -> void:
	sobrescrever=""
	titulo_label.text="SALVAR PARTIDA" if modo_salvar else "CARREGAR PARTIDA"
	instrucao_label.text="Escolha um slot." if modo_salvar else "Escolha uma partida para continuar."
	carregar.text="SALVAR" if modo_salvar else "CONTINUAR"
	cancelar_apagar()
	ocupado=false
	erro.hide()
	preencher()
	show()
	grab_focus()
	redimensionar()

func preencher() -> void:
	botoes.clear();cartoes.clear()
	for filho in lista.get_children(): lista.remove_child(filho);filho.queue_free()
	registros=ArquivoPlex.listar_slots()
	rolagem.visible=not registros.is_empty()
	vazio.visible=registros.is_empty()
	rolagem.custom_minimum_size.y=mini(4,registros.size())*106+maxi(0,mini(4,registros.size())-1)*24+16
	for registro in registros:
		var caminho:=str(registro.caminho)
		var item:=Linha.new();item.caminho=caminho;item.size_flags_horizontal=Control.SIZE_EXPAND_FILL;lista.add_child(item)
		cartoes[caminho]=item
		item.selecionada.connect(selecionar);item.carregar_pedido.connect(confirmar)
		var conteudo:=HBoxContainer.new();conteudo.add_theme_constant_override("separation",24);conteudo.mouse_filter=Control.MOUSE_FILTER_IGNORE;item.superficie.add_child(conteudo)
		var suporte:=Control.new();suporte.custom_minimum_size=Vector2(52,52);suporte.size_flags_vertical=Control.SIZE_SHRINK_CENTER;suporte.mouse_filter=Control.MOUSE_FILTER_IGNORE;conteudo.add_child(suporte)
		var disquete:=TextureRect.new();disquete.texture=VintagePlex.icone("salvar",Color("2b1a12"));disquete.custom_minimum_size=Vector2(52,52);disquete.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;disquete.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;disquete.mouse_filter=Control.MOUSE_FILTER_IGNORE;disquete.size_flags_vertical=Control.SIZE_SHRINK_CENTER;disquete.size=Vector2(52,52);suporte.add_child(disquete);item.flutuante=disquete
		var info:=VBoxContainer.new();info.add_theme_constant_override("separation",12);info.size_flags_horizontal=Control.SIZE_EXPAND_FILL;info.mouse_filter=Control.MOUSE_FILTER_IGNORE;conteudo.add_child(info)
		var nome_linha:=HBoxContainer.new();nome_linha.size_flags_horizontal=Control.SIZE_EXPAND_FILL;nome_linha.add_theme_constant_override("separation",12);nome_linha.mouse_filter=Control.MOUSE_FILTER_IGNORE;info.add_child(nome_linha)
		var nome:=Label.new();nome.text=str(registro.nome);nome.add_theme_font_override("font",VintagePlex.fonte("forte"));nome.add_theme_font_size_override("font_size",22);nome.add_theme_color_override("font_color",VintagePlex.ESCURO);nome.mouse_filter=Control.MOUSE_FILTER_IGNORE;nome.clip_text=true;nome.size_flags_horizontal=Control.SIZE_EXPAND_FILL;nome.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;nome_linha.add_child(nome)
		var tag:=PanelContainer.new();tag.add_theme_stylebox_override("panel",VintagePlex.caixa(Color("5a3a22"),Color("5a3a22"),4));tag.mouse_filter=Control.MOUSE_FILTER_IGNORE;tag.size_flags_vertical=Control.SIZE_SHRINK_CENTER;nome_linha.add_child(tag);tag.visible=not registro.vazio
		var modo:=Label.new();modo.text="NORMAL";modo.add_theme_font_override("font",VintagePlex.fonte("botao"));modo.add_theme_font_size_override("font_size",12);modo.add_theme_color_override("font_color",VintagePlex.CREME);modo.mouse_filter=Control.MOUSE_FILTER_IGNORE;tag.add_child(modo)
		var data:=Label.new();data.text=("Dia %d · %s · US$ %.2f"%[registro.dia,registro.hora,registro.saldo]) if not registro.vazio else "";data.add_theme_font_size_override("font_size",17);data.add_theme_color_override("font_color",Color("4a2e18"));data.mouse_filter=Control.MOUSE_FILTER_IGNORE;data.clip_text=true;data.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;info.add_child(data)
		var apagar:=VintagePlex.botao(conteudo,"APAGAR",pedir_exclusao.bind(caminho),Color("8c1c20"));apagar.custom_minimum_size=Vector2(124,52);apagar.size_flags_vertical=Control.SIZE_SHRINK_CENTER;apagar.icon=VintagePlex.icone("lixeira");apagar.add_theme_font_size_override("font_size",20)
		apagar.mouse_entered.connect(func(): apagar.icon=VintagePlex.icone("lixeira_aberta"));apagar.mouse_exited.connect(func(): apagar.icon=VintagePlex.icone("lixeira"))
		VintagePlex.preparar_pixel(apagar,Color("8c1c20"),Color("3d0a0c"),Color("2a140c"));item.apagar=apagar;botoes[caminho]=apagar;apagar.visible=not registro.vazio
	if not cartoes.has(selecionado): selecionado=""
	if selecionado.is_empty():
		for registro in registros:
			if modo_salvar or registro.carregavel: selecionado=str(registro.caminho);break
	selecionar(selecionado)
	redimensionar()

func selecionar(caminho:String) -> void:
	if ocupado: return
	var valido:bool=registros.any(func(r):return str(r.caminho)==caminho and (modo_salvar or r.carregavel))
	if selecionado!=caminho:sobrescrever=""
	selecionado=caminho if valido else ""
	carregar.text="SALVAR" if modo_salvar else "CONTINUAR"
	for id in cartoes: cartoes[id].marcar(id==selecionado)
	carregar.disabled=selecionado.is_empty()

func pedir_exclusao(caminho:String) -> void:
	if ocupado or not botoes.has(caminho): return
	if excluir_caminho==caminho:
		confirmar_apagar()
		return
	cancelar_apagar()
	excluir_caminho=caminho;tempo_exclusao=2.5
	botoes[caminho].text="CERTEZA?"
	VintagePlex.preparar_pixel(botoes[caminho],Color("c42a2a"),Color("3d0a0c"),Color("2a140c"))

func cancelar_apagar() -> void:
	if botoes.has(excluir_caminho):
		botoes[excluir_caminho].text="APAGAR"
		VintagePlex.preparar_pixel(botoes[excluir_caminho],Color("8c1c20"),Color("3d0a0c"),Color("2a140c"))
	excluir_caminho="";tempo_exclusao=0.0

func confirmar_apagar() -> void:
	if ocupado or excluir_caminho.is_empty(): return
	var caminho:=excluir_caminho
	if not ArquivoPlex.apagar(caminho): erro.text="Não foi possível apagar a partida.";erro.show();return
	cancelar_apagar()
	ocupado=true;carregar.disabled=true
	for b in botoes.values(): b.disabled=true
	var item:Linha=cartoes[caminho]
	item.saindo=true
	var transicao:=create_tween()
	transicao.set_parallel(true)
	transicao.tween_property(item,"modulate:a",0.0,.18)
	transicao.tween_property(item,"deslocamento",56.0,.2)
	transicao.chain().tween_property(item,"custom_minimum_size:y",0.0,.18)
	transicao.tween_callback(func(): ocupado=false;preencher();excluido.emit(caminho))

func confirmar() -> void:
	if selecionado.is_empty() or ocupado: return
	if modo_salvar:
		var r:Dictionary=registros.filter(func(v):return str(v.caminho)==selecionado)[0]
		if not r.vazio and sobrescrever!=selecionado:sobrescrever=selecionado;carregar.text="SUBSTITUIR?";return
		fechar();salvar_escolhido.emit(int(r.slot));return
	if ArquivoPlex.ler(selecionado).is_empty(): erro.text="Não foi possível carregar esta partida.";erro.show();return
	var caminho:=selecionado
	fechar();escolhido.emit(caminho)

func fechar() -> void:
	cancelar_apagar()
	hide()

func _process(delta:float) -> void:
	if not visible: return
	redimensionar()
	if tempo_exclusao>0:
		tempo_exclusao-=delta
		if tempo_exclusao<=0: cancelar_apagar()

func _input(e:InputEvent) -> void:
	if not visible or not e is InputEventKey or not e.pressed or e.echo: return
	if e.keycode==KEY_ESCAPE: fechar();get_viewport().set_input_as_handled();return
	if ocupado: return
	if e.keycode in [KEY_UP,KEY_DOWN] and not registros.is_empty():
		var indice:=-1
		for i in registros.size():
			if str(registros[i].caminho)==selecionado: indice=i
		indice=clampi(indice+(-1 if e.keycode==KEY_UP else 1),0,registros.size()-1)
		selecionar(str(registros[indice].caminho));get_viewport().set_input_as_handled()
	elif e.keycode==KEY_ENTER and not get_viewport().gui_get_focus_owner() is BaseButton: confirmar();get_viewport().set_input_as_handled()
