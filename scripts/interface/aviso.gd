class_name AvisoPlex
extends CanvasLayer
## Diálogo do jogo, no lugar das caixas cinza do sistema. Uma placa de
## título, o texto em uma folha de papel e, no rodapé, a ação principal em
## ouro. Com `cancelar`, vira uma pergunta de duas respostas.

signal confirmado
signal cancelado
var janela:=PanelContainer.new()
var respondido:=false

static func mostrar(jogo:Node, titulo:String, texto:String, confirmar:String="Fechar", cancelar:String="", largura:int=520) -> AvisoPlex:
	var aviso:=AvisoPlex.new()
	jogo.add_child(aviso)
	aviso.montar(titulo,texto,confirmar,cancelar,largura)
	return aviso

func montar(titulo:String, texto:String, confirmar:String, cancelar:String, largura:int) -> void:
	layer=122
	var raiz:=Control.new();raiz.theme=TemaHudPlex.criar();raiz.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(raiz)
	var sombra:=ColorRect.new();sombra.color=Color(.05,.025,.015,.65);sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);raiz.add_child(sombra)
	raiz.add_child(janela);janela.add_theme_stylebox_override("panel",KitPlex.moldura("janela",18))
	janela.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	janela.grow_horizontal=Control.GROW_DIRECTION_BOTH;janela.grow_vertical=Control.GROW_DIRECTION_BOTH
	var coluna:=VBoxContainer.new();coluna.add_theme_constant_override("separation",12);coluna.custom_minimum_size.x=largura;janela.add_child(coluna)
	KitPlex.placa(coluna,titulo,18)
	var folha:=KitPlex.painel(coluna,"papel",16)
	var rolagem:=ScrollContainer.new();rolagem.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;folha.add_child(rolagem)
	var corpo:=KitPlex.texto(rolagem,texto,15,Color("2a1408"))
	corpo.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;corpo.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	corpo.custom_minimum_size.x=largura-48
	var linhas:=texto.count("\n")+1+texto.length()/56
	rolagem.custom_minimum_size.y=clampf(linhas*20.0+8.0,48.0,300.0)
	var rodape:=HBoxContainer.new();rodape.alignment=BoxContainer.ALIGNMENT_END;rodape.add_theme_constant_override("separation",8);coluna.add_child(rodape)
	if not cancelar.is_empty():KitPlex.botao(rodape,cancelar,func():responder(false),"noite").custom_minimum_size.x=120
	var principal:=KitPlex.botao(rodape,confirmar,func():responder(true),"ouro");principal.custom_minimum_size.x=140
	principal.grab_focus.call_deferred()

func responder(aceito:bool) -> void:
	if respondido:return
	respondido=true
	if aceito:confirmado.emit()
	else:cancelado.emit()
	queue_free()

func _unhandled_input(e:InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode==KEY_ESCAPE:
		get_viewport().set_input_as_handled();responder(false)
