class_name CriacaoPartidaPlex
extends Control

signal confirmada(dados: Dictionary, modo_debug: bool)
signal cancelada
const T = preload("res://scripts/interface/tema_hud.gd")
var janela := PanelContainer.new()
var restaurante := LineEdit.new()
var nome := LineEdit.new()
var modelo := OptionButton.new()
var uniforme := OptionButton.new()
var cabelo := OptionButton.new()
var erro := Label.new()
var quadro := Control.new()
var ator: PersonagemPlex
var debug := false
var direcao := 0
var tempo := 0.0
var pronto := false
var posicao_previa := Vector2.ZERO

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme=T.criar()
	var fundo := ColorRect.new()
	fundo.color=Color("17252b")
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	add_child(janela)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	janela.add_child(scroll)
	var coluna := VBoxContainer.new()
	coluna.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	coluna.add_theme_constant_override("separation",14)
	scroll.add_child(coluna)
	T.texto(coluna,"UM NOVO COMEÇO",28,T.AMBAR)
	T.texto(coluna,"Dê um nome ao restaurante e crie seu administrador.",17,T.SUAVE)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation",28)
	coluna.add_child(linha)
	var formulario := VBoxContainer.new()
	formulario.custom_minimum_size.x=340
	formulario.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	linha.add_child(formulario)
	for spec in [["Nome do restaurante",restaurante],["Nome do administrador",nome]]:
		T.texto(formulario,spec[0],16,T.SUAVE)
		var campo: LineEdit=spec[1]
		campo.custom_minimum_size.y=42
		campo.max_length=40
		formulario.add_child(campo)
	restaurante.text="Pizzaplex"
	nome.text="Alex"
	T.texto(formulario,"Personagem",16,T.SUAVE)
	modelo.add_item("Homem")
	modelo.add_item("Mulher")
	formulario.add_child(modelo)
	T.texto(formulario,"Uniforme de administrador",16,T.SUAVE)
	formulario.add_child(uniforme)
	T.texto(formulario,"Cabelo exclusivo",16,T.SUAVE)
	AparenciaPlex.carregar()
	cabelo.add_item("Sem cabelo")
	cabelo.set_item_metadata(0,"nenhum")
	for item in AparenciaPlex.dados.cabelos:
		cabelo.add_item(item.nome)
		cabelo.set_item_metadata(cabelo.item_count-1,item.id)
		if item.id=="curto": cabelo.select(cabelo.item_count-1)
	formulario.add_child(cabelo)
	var regra := T.texto(formulario,"Seu administrador ajuda nas áreas sem funcionários. O cabelo escolhido não será usado pelos outros NPCs.",15,T.SUAVE)
	regra.custom_minimum_size.x=330
	regra.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var previa := VBoxContainer.new()
	previa.custom_minimum_size.x=260
	linha.add_child(previa)
	quadro.custom_minimum_size=Vector2(260,310)
	quadro.mouse_filter=Control.MOUSE_FILTER_IGNORE
	previa.add_child(quadro)
	var giros := HBoxContainer.new()
	giros.alignment=BoxContainer.ALIGNMENT_CENTER
	giros.add_theme_constant_override("separation",24)
	previa.add_child(giros)
	T.botao(giros,"←",func(): direcao=posmod(direcao+1,8); atualizar_previa()).custom_minimum_size=Vector2(54,38)
	T.botao(giros,"→",func(): direcao=posmod(direcao-1,8); atualizar_previa()).custom_minimum_size=Vector2(54,38)
	var acoes := HBoxContainer.new()
	coluna.add_child(acoes)
	T.botao(acoes,"Voltar",func(): hide(); cancelada.emit())
	T.botao(acoes,"Criar partida",confirmar,T.VERDE).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	coluna.add_child(erro)
	erro.add_theme_color_override("font_color",Color("f1a890"))
	modelo.item_selected.connect(func(_i): atualizar_uniformes(); atualizar_previa())
	uniforme.item_selected.connect(func(_i): atualizar_previa())
	cabelo.item_selected.connect(func(_i): atualizar_previa())
	get_viewport().size_changed.connect(redimensionar)
	pronto=true
	atualizar_uniformes()
	redimensionar()
	hide()

func redimensionar() -> void:
	var tela:=get_viewport_rect().size
	janela.size=Vector2(minf(820,tela.x-32),minf(640,tela.y-28))
	janela.position=(tela-janela.size)*.5

func atualizar_uniformes() -> void:
	uniforme.clear()
	var sexo := "masculino" if modelo.selected==0 else "feminino"
	for i in [1,2]:
		uniforme.add_item("Administrador · Modelo "+str(i))
		uniforme.set_item_metadata(uniforme.item_count-1,"administrador_"+sexo+"_"+str(i))

func dados() -> Dictionary:
	return {"restaurante":restaurante.text.strip_edges(),"nome":nome.text.strip_edges(),"modelo":"humano" if modelo.selected==0 else "humana","uniforme":str(uniforme.get_selected_metadata()),"cabelo":str(cabelo.get_selected_metadata())}

func abrir(modo_debug: bool) -> void:
	debug=modo_debug
	erro.text="Modo debug: construção, compras e recursos gratuitos." if debug else ""
	show()
	redimensionar()
	atualizar_previa()

func atualizar_previa() -> void:
	if not pronto or not visible: return
	if is_instance_valid(ator):
		quadro.remove_child(ator)
		ator.queue_free()
	ator=load("res://cenas/personagens/personagem.tscn").instantiate()
	ator.configurar(-1,str(dados().modelo),Vector2i.ZERO,false)
	ator.funcao="administrador"
	ator.visita.administrador=true
	ator.uniforme=dados().uniforme
	ator.cabelo=dados().cabelo
	ator.planta_visual=PlantaPlex.new()
	ator.scale=Vector2.ONE*3.0
	ator.direcao=direcao
	quadro.add_child(ator)
	ator.atualizar_visual(false)
	centralizar()
	ator.identificacao.hide()

func centralizar() -> void:
	if not is_instance_valid(ator): return
	var limites := Rect2()
	var iniciou := false
	for fonte in ator.pintura.fontes:
		var sprite: Sprite2D=fonte.sprite
		if sprite.texture==null: continue
		var usados := sprite.texture.get_image().get_used_rect()
		if not usados.has_area(): continue
		var transformacao := ator.global_transform.affine_inverse()*sprite.global_transform
		var retangulo := transformacao*Rect2(usados)
		limites=limites.merge(retangulo) if iniciou else retangulo
		iniciou=true
	if iniciou: posicao_previa=(quadro.size*.5-limites.get_center()*ator.scale).round()
	ator.position=posicao_previa

func confirmar() -> void:
	var valor:=dados()
	if valor.restaurante.is_empty() or valor.nome.is_empty():
		erro.text="Preencha o nome do restaurante e o nome do administrador."
		return
	hide()
	confirmada.emit(valor,debug)

func _process(delta: float) -> void:
	if not visible or not is_instance_valid(ator): return
	tempo+=delta
	if tempo<.08: return
	ator.relogio+=tempo
	tempo=0.0
	ator.atualizar_visual(false)
	ator.position=posicao_previa
	ator.identificacao.hide()
