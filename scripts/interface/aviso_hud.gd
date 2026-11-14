class_name AvisoHudPlex
extends CanvasLayer
## Aviso de status do HUD: mostra, no alto da tela, as mensagens enviadas por
## PainelPlex.mensagem(). Fica entre o saldo e o relógio, acima das janelas,
## e some sozinho. Não captura o mouse, para não atrapalhar o mapa.

const LARGURA_MAXIMA:=600.0
var raiz:=Control.new()
var painel:=PanelContainer.new()
var rotulo:Label
var atual:=""
var restante:=0.0
var animacao:Tween

func _ready() -> void:
	layer=121
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter=Control.MOUSE_FILTER_IGNORE
	raiz.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(raiz)
	painel.add_theme_stylebox_override("panel",ShowPlex.estilo("painel",10,Color("5a3320"),{"tampas":true}))
	painel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	raiz.add_child(painel)
	var linha:=HBoxContainer.new();linha.add_theme_constant_override("separation",10);linha.mouse_filter=Control.MOUSE_FILTER_IGNORE;painel.add_child(linha)
	var marca:=ColorRect.new();marca.color=KitPlex.AMBAR;marca.custom_minimum_size=Vector2(4,4);marca.mouse_filter=Control.MOUSE_FILTER_IGNORE;linha.add_child(marca)
	rotulo=KitPlex.texto(linha,"",15,KitPlex.PAPEL)
	rotulo.mouse_filter=Control.MOUSE_FILTER_IGNORE
	painel.hide()

func mostrar(texto:String) -> void:
	var frase:=texto.strip_edges()
	if frase.is_empty():
		painel.hide();atual="";restante=0.0;return
	# Leitura confortável: 3 s de base e mais um pouco para frases longas.
	restante=clampf(3.0+frase.length()*.045,3.5,8.0)
	if frase==atual and painel.visible:
		painel.modulate.a=1.0;return
	atual=frase
	rotulo.autowrap_mode=TextServer.AUTOWRAP_OFF;rotulo.custom_minimum_size.x=0
	rotulo.text=frase
	var largura:=VintagePlex.fonte().get_string_size(tr(frase),HORIZONTAL_ALIGNMENT_LEFT,-1,15).x
	var limite:=minf(LARGURA_MAXIMA,raiz.size.x-560.0)
	if largura>limite:
		rotulo.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;rotulo.custom_minimum_size.x=maxf(240.0,limite)
	painel.show();painel.reset_size()
	posicionar.call_deferred(true)

func posicionar(entrada:bool=false) -> void:
	painel.reset_size()
	var destino:=Vector2(roundf((raiz.size.x-painel.size.x)*.5),14)
	if animacao!=null and animacao.is_valid():animacao.kill()
	if not entrada:
		painel.position=destino;return
	painel.position=destino-Vector2(0,8);painel.modulate.a=0.0
	animacao=create_tween().set_parallel(true)
	animacao.tween_property(painel,"position",destino,.14)
	animacao.tween_property(painel,"modulate:a",1.0,.14)

func _process(delta:float) -> void:
	if not painel.visible:return
	restante-=delta
	if restante<=0.0:
		painel.hide();atual=""
	elif restante<.4:painel.modulate.a=restante/.4
