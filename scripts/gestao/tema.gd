class_name TemaTerminalPlex
extends RefCounted

const FUNDO = Color("d5bc91")
const PAPEL = Color("f1dfb9")
const TINTA = Color("3b291e")
const SUAVE = Color("80694f")
const LINHA = Color("ab8053")
const VERDE = Color("52603d")
const FOSFORO = Color("ead1a3")
const AMBAR = Color("dfb16a")
const MADEIRA = Color("37231b")
const VINHO = Color("69392f")
const AZUL = Color("706146")

static func caixa(cor: Color, borda: Color = Color.TRANSPARENT, _raio: int = 0, margem: int = 16) -> StyleBoxFlat:
	return TemaHudPlex.caixa(cor,LINHA if borda.a==0 else borda,margem)

static func criar() -> Theme:
	var t:=TemaHudPlex.criar()
	t.default_font_size=15
	t.set_color("font_color","Label",TINTA)
	for tipo in ["Button","OptionButton","CheckButton","CheckBox"]:
		for nome in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: t.set_color(nome,tipo,TINTA)
		for estado in ["normal","hover","pressed","hover_pressed","disabled"]: t.set_stylebox(estado,tipo,caixa(Color("f8e8bb") if estado=="hover" else Color("c9af83") if estado=="disabled" else PAPEL,LINHA,0,10))
		for nome in ["checked","radio_checked","checked_disabled","radio_checked_disabled"]: t.set_icon(nome,tipo,VintagePlex.icone("marcado",TINTA))
		for nome in ["unchecked","radio_unchecked","unchecked_disabled","radio_unchecked_disabled"]: t.set_icon(nome,tipo,VintagePlex.icone("desmarcado",TINTA))
	t.set_icon("arrow","OptionButton",VintagePlex.icone("baixo",TINTA))
	t.set_stylebox("panel","PanelContainer",caixa(PAPEL,LINHA))
	t.set_constant("separation","VBoxContainer",12)
	t.set_constant("separation","HBoxContainer",12)
	return t

static func texto(pai: Node, valor: String, tamanho: int = 14, cor: Color = TINTA, mono: bool = false) -> Label:
	var l := Label.new()
	l.text = valor
	l.add_theme_font_size_override("font_size",tamanho)
	l.add_theme_color_override("font_color",cor)
	l.add_theme_font_override("font",VintagePlex.fonte("forte" if mono else "titulo" if tamanho>=22 else "corpo"))
	pai.add_child(l)
	return l

static func botao(pai: Node, valor: String, acao: Callable, primario: bool = false) -> Button:
	return VintagePlex.botao(pai,valor,acao,Color("e8a237") if primario else PAPEL,true)

static func imagem(pai: Node, tipo: String, altura: int = 110, visual: String="", estado: String="") -> TextureRect:
	var r := TextureRect.new()
	var caminho: String="res://assets/objetos/gestao/"+tipo+"/icone.png"
	var fonte: Texture2D=CatalogoPlex.sprite(visual,0,estado) if not visual.is_empty() else load(caminho) if ResourceLoader.exists(caminho) else CatalogoPlex.sprite(tipo,0)
	if fonte!=null:
		var recorte:=CatalogoPlex.atlas_vazio()
		recorte.atlas=fonte
		recorte.region=Rect2(fonte.get_image().get_used_rect())
		r.texture=recorte
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(90,altura)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pai.add_child(r)
	return r



static func cabecalho(pai: Node, titulo: String, _simbolo: String, cor: Color=TINTA) -> HBoxContainer:
	var linha:=HBoxContainer.new()
	linha.add_theme_constant_override("separation",10)
	pai.add_child(linha)
	if not titulo.is_empty(): texto(linha,titulo,20,cor).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	return linha
