class_name FundoInicioPlex
extends Control

signal acao_escolhida(acao: String)
var palco:=Control.new()
var imagem:=TextureRect.new()
var atlas:=CatalogoPlex.atlas_vazio()
var botoes: Dictionary={}
var relogio:=0.0
var indice:=-1
var reduzido:=false
var nuvens: Array[Dictionary]=[]
const NUVENS=[Vector4(185,48,5.5,0),Vector4(427,30,4.3,1),Vector4(594,71,6.2,2),Vector4(88,97,3.2,3),Vector4(344,105,2.4,4)]

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(palco);palco.size=Vector2(800,450);palco.mouse_filter=Control.MOUSE_FILTER_IGNORE;palco.clip_contents=true
	var ceu:=TextureRect.new();ceu.texture=load("res://assets/interface/inicio/revisao_2/ceu.png");ceu.size=Vector2(800,450);ceu.mouse_filter=Control.MOUSE_FILTER_IGNORE;palco.add_child(ceu)
	for dados in NUVENS:
		for copia in [-1,0,1]:
			var nuvem:=TextureRect.new();nuvem.texture=load("res://assets/interface/inicio/revisao_2/nuvem_"+str(int(dados.w))+".png");nuvem.size=Vector2(232,112);nuvem.mouse_filter=Control.MOUSE_FILTER_IGNORE;palco.add_child(nuvem)
			nuvens.append({"node":nuvem,"inicio":dados.x,"y":dados.y-20.0,"velocidade":dados.z,"copia":copia})
	atlas.atlas=load("res://assets/interface/inicio/revisao_2/cenario.png")
	atlas.region=Rect2(0,0,800,450)
	imagem.texture=atlas;imagem.size=Vector2(800,450);imagem.mouse_filter=Control.MOUSE_FILTER_IGNORE
	palco.add_child(imagem)
	var fonte:=SystemFont.new();fonte.font_names=PackedStringArray(["Trebuchet MS","Arial","DejaVu Sans"])
	var lista=[["novo","Novo jogo"],["carregar","Carregar"],["opcoes","Opções"],["creditos","Créditos"],["sair","Sair"]]
	for i in lista.size():
		var acao: String=lista[i][0]
		var b:=Button.new();b.name=acao;b.text="◆   "+str(lista[i][1]);b.alignment=HORIZONTAL_ALIGNMENT_LEFT
		b.position=Vector2(46,99+i*35.8);b.size=Vector2(192,30.15)
		b.add_theme_font_override("font",fonte);b.add_theme_font_size_override("font_size",11)
		b.add_theme_color_override("font_color",Color("d9ba92"));b.add_theme_color_override("font_hover_color",Color("ffe0ad"));b.add_theme_color_override("font_focus_color",Color("ffe0ad"));b.add_theme_color_override("font_disabled_color",Color("6e5a4c"))
		var normal:=StyleBoxEmpty.new();normal.content_margin_left=9;b.add_theme_stylebox_override("normal",normal);b.add_theme_stylebox_override("disabled",normal)
		var escolhido:=StyleBoxTexture.new();escolhido.texture=load("res://assets/interface/inicio/selecionado.png");escolhido.content_margin_left=11
		var sobre:=escolhido.duplicate() as StyleBoxTexture;sobre.texture=load("res://assets/interface/inicio/sobre.png")
		b.add_theme_stylebox_override("hover",sobre);b.add_theme_stylebox_override("pressed",escolhido);b.add_theme_stylebox_override("focus",escolhido)
		b.pressed.connect(func(): acao_escolhida.emit(acao))
		b.mouse_entered.connect(func(): if not b.disabled: b.grab_focus())
		palco.add_child(b);botoes[acao]=b
	botoes.novo.grab_focus()
	resized.connect(organizar);organizar();atualizar_nuvens()

func organizar() -> void:
	var fator:=maxf(size.x/800.0,size.y/450.0)
	palco.scale=Vector2.ONE*fator
	palco.position=((size-Vector2(800,450)*fator)*.5).round()
	queue_redraw()

func _process(delta: float) -> void:
	if reduzido: return
	relogio+=delta
	atualizar_nuvens()
	var atual:=posmod(floori(relogio*4),32)
	if atual==indice: return
	indice=atual
	atlas.region=Rect2((indice%8)*800,floori(float(indice)/8)*450,800,450)

func atualizar_nuvens() -> void:
	for nuvem in nuvens:
		var x:=fposmod(float(nuvem.inicio)-relogio*float(nuvem.velocidade)+160.0,1040.0)-160.0
		nuvem.node.position=Vector2(roundf(x-28.0+float(nuvem.copia)*1040.0),float(nuvem.y))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("100a09"))
