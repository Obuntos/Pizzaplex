class_name BotaoHudPlex
extends Button
## Botão da barra de ferramentas: ícone ilustrado de 48 px em escala inteira,
## rótulo opcional e um estado ligado com cor, friso, lâmpada e legenda.

const FACE=Color("3b2a25")
const FACE_LIGADA=Color("4f6a3f")
var conteudo:=HBoxContainer.new()
var imagem:=TextureRect.new()
var rotulo:Label
var legenda:Label
var lampada:ColorRect
var icone_normal:Texture2D
var icone_ligado:Texture2D
var ligado:=false

func _init(icone:String, texto:String="", dica:String="", cor:Color=FACE) -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	focus_mode=Control.FOCUS_NONE
	tooltip_text=dica
	KitPlex.preparar_botao(self,cor,false,4)
	custom_minimum_size=Vector2(56,56)
	add_child(conteudo)
	conteudo.mouse_filter=Control.MOUSE_FILTER_IGNORE
	conteudo.add_theme_constant_override("separation",6)
	icone_normal=load(icone)
	imagem.texture=icone_normal
	imagem.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	imagem.stretch_mode=TextureRect.STRETCH_KEEP_CENTERED
	imagem.custom_minimum_size=Vector2(48,48)
	imagem.mouse_filter=Control.MOUSE_FILTER_IGNORE
	conteudo.add_child(imagem)
	if not texto.is_empty():
		var coluna:=VBoxContainer.new()
		coluna.mouse_filter=Control.MOUSE_FILTER_IGNORE
		coluna.alignment=BoxContainer.ALIGNMENT_CENTER
		coluna.add_theme_constant_override("separation",-2)
		conteudo.add_child(coluna)
		rotulo=KitPlex.texto(coluna,texto,15,KitPlex.CREME,"botao")
		rotulo.uppercase=true
		legenda=KitPlex.texto(coluna,"",10,KitPlex.AREIA,"forte")
		legenda.hide()
		custom_minimum_size.x=48+14+ceilf(VintagePlex.fonte("botao").get_string_size(tr(texto).to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,15).x)+14

## Liga o modo alternável: pressionado fica afundado, com friso dourado.
func alternavel(cor:Color=Color("806139")) -> void:
	toggle_mode=true
	for estado in ["pressed","hover_pressed"]:
		add_theme_stylebox_override(estado,KitPlex.quadro([KitPlex.TINTA,Color("f0c060")],cor if estado=="pressed" else cor.lightened(.1),1,4,2,cor.darkened(.45),true))

## Estado com lâmpada e legenda, para modos que ficam ligados (corte).
func definir_estado(valor:bool, texto_ligado:String, texto_desligado:String, icone_ativo:String="") -> void:
	if lampada==null:
		lampada=ColorRect.new()
		lampada.mouse_filter=Control.MOUSE_FILTER_IGNORE
		lampada.size=Vector2(6,6)
		add_child(lampada)
		if not icone_ativo.is_empty():icone_ligado=load(icone_ativo)
		custom_minimum_size.x+=18
	ligado=valor
	KitPlex.preparar_botao(self,FACE_LIGADA if valor else FACE,false,4)
	if valor:
		for estado in ["normal","hover"]:
			add_theme_stylebox_override(estado,KitPlex.quadro([KitPlex.TINTA,Color("f0c060")],FACE_LIGADA if estado=="normal" else FACE_LIGADA.lightened(.1),1,4,2,FACE_LIGADA.darkened(.45),true))
	lampada.color=Color("c9f08a") if valor else Color("1d0e08")
	imagem.texture=icone_ligado if valor and icone_ligado!=null else icone_normal
	if legenda!=null:
		legenda.text=texto_ligado if valor else texto_desligado
		legenda.add_theme_color_override("font_color",KitPlex.VERDE_LUZ if valor else KitPlex.AREIA)
		legenda.show()
	queue_redraw()

func afundado() -> bool:
	return ligado or button_pressed or get_draw_mode() in [DRAW_PRESSED,DRAW_HOVER_PRESSED]

func _draw() -> void:
	var desce:=4.0 if afundado() else 0.0
	conteudo.position=Vector2(4,2+desce)
	conteudo.size=Vector2(size.x-8,48)
	imagem.modulate=Color(.62,.6,.58,.75) if disabled else Color.WHITE
	if lampada!=null:lampada.position=Vector2(size.x-14,8+desce)
