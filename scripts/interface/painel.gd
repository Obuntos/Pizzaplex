class_name PainelPlex
extends CanvasLayer

signal luz_ajustada(valor: Dictionary)
signal ferramenta_escolhida(valor: String)
signal recorte_escolhido(valor: bool)
var status := Label.new()
var ferramenta := Label.new()
var selecao := Label.new()
var paredes := Button.new()
var recorte := CheckButton.new()
var autonomia := CheckButton.new()
var cabelo := OptionButton.new()
var uniforme := OptionButton.new()
var expressao := OptionButton.new()
var retrato := TextureRect.new()
var cor_luz := ColorPickerButton.new()
var energia_luz := HSlider.new()
var ligar_luz := CheckButton.new()
var painel: PanelContainer
var rodape: PanelContainer
var abas := TabContainer.new()
var navegacao := OptionButton.new()
var hud: HudPlex

func _ready() -> void:
	var raiz:=Control.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(raiz)
	painel=PanelContainer.new()
	painel.hide()
	raiz.add_child(painel)
	for controle in [ferramenta,selecao,paredes,recorte,autonomia,cabelo,uniforme,expressao,retrato,cor_luz,energia_luz,ligar_luz,abas,navegacao]: painel.add_child(controle)
	rodape=PanelContainer.new()
	rodape.hide()
	raiz.add_child(rodape)
	rodape.add_child(status)
	recorte.toggled.connect(func(valor): recorte_escolhido.emit(valor))
	cor_luz.color_changed.connect(func(_valor): emitir_luz())
	energia_luz.value_changed.connect(func(_valor): emitir_luz())
	ligar_luz.toggled.connect(func(_valor): emitir_luz())

func emitir_luz() -> void:
	luz_ajustada.emit({"cor_luz":"#"+cor_luz.color.to_html(false),"energia":energia_luz.value,"ligada":ligar_luz.button_pressed})

func botao(lista: VBoxContainer, nome: String, valor: String) -> void:
	var item := Button.new()
	item.text = nome
	item.alignment = HORIZONTAL_ALIGNMENT_LEFT
	item.custom_minimum_size.y = 32
	if valor.begins_with("spawn:"): item.icon=RetratoEquipePlex.icone(valor.trim_prefix("spawn:"))
	item.pressed.connect(func(): ferramenta_escolhida.emit(valor))
	lista.add_child(item)

func mensagem(texto: String) -> void:
	status.text = texto
	status.tooltip_text=""

func bloqueia_mouse(ponto: Vector2) -> bool:
	if hud != null and hud.menu_aberto(): return true
	if not is_instance_valid(painel): return false
	if (painel.is_visible_in_tree() and painel.get_global_rect().has_point(ponto)) or (is_instance_valid(rodape) and rodape.visible and rodape.get_global_rect().has_point(ponto)):
		return true
	return get_viewport().gui_get_hovered_control() != null

func mostrar_luz(objeto: Dictionary) -> void:
	cor_luz.color = Color(objeto.get("cor_luz", "#fff0d5"))
	energia_luz.set_value_no_signal(objeto.get("energia", 1.2))
	ligar_luz.set_pressed_no_signal(objeto.get("ligada", true))
	mensagem("Editando " + CatalogoPlex.objetos[objeto.tipo].nome.to_lower() + ".")

func mostrar_aparencia(ator: PersonagemPlex) -> void:
	retrato.texture=RetratoEquipePlex.criar(ator)
	retrato.visible=retrato.texture!=null
	var permitido := AparenciaPlex.permitida(ator)
	cabelo.disabled = not permitido
	uniforme.disabled = not permitido
	for controle in [cabelo,uniforme]:
		var valor: String = ator.cabelo if controle == cabelo else ator.uniforme
		for i in controle.item_count:
			if controle.get_item_metadata(i) == valor: controle.select(i)
			if controle==cabelo: controle.set_item_disabled(i,not AdministradorPlex.eh(ator) and controle.get_item_metadata(i)==ator.get_meta("cabelo_reservado","nenhum") and controle.get_item_metadata(i)!="nenhum")


func configurar_hud(jogo: Node) -> void:
	hud = HudPlex.new()
	add_child(hud)
	hud.configurar(jogo)

