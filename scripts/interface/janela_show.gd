class_name JanelaShowPlex
extends PanelContainer
## Janela de palco: tábuas de madeira, cortina na boca de cena, o título
## numa placa pendurada e uma fileira de lâmpadas correndo no trilho.
## O conteúdo entra em `corpo`.

const MARGEM:=18
var corpo:=VBoxContainer.new()
var cabeca:Cabeca

static func criar(pai:Node, titulo:String, ao_fechar:Callable=Callable(), cortina:Color=ShowPlex.VINHO, madeira:Color=Color("4f281a")) -> JanelaShowPlex:
	var j:=JanelaShowPlex.new()
	j.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	j.add_theme_stylebox_override("panel",ShowPlex.estilo("tabuas",MARGEM,madeira,{"tabua":44}))
	pai.add_child(j)
	j.corpo.add_theme_constant_override("separation",12)
	j.add_child(j.corpo)
	j.cabeca=Cabeca.new(titulo,cortina)
	j.corpo.add_child(j.cabeca)
	if ao_fechar.is_valid():
		var x:=KitPlex.fechar(j.cabeca,ao_fechar)
		x.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		x.offset_left=-40;x.offset_right=0;x.offset_top=6;x.offset_bottom=46
	return j

func definir_titulo(valor:String) -> void:
	cabeca.titulo=valor;cabeca.queue_redraw()

class Cabeca extends Control:
	var titulo:=""
	var cor:=ShowPlex.VINHO
	var luzes:=LuzesShowPlex.new(true,22.0)
	func _init(valor:String, cortina:Color) -> void:
		titulo=valor;cor=cortina
		custom_minimum_size=Vector2(280,58)
		mouse_filter=Control.MOUSE_FILTER_IGNORE
		texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(luzes)
		resized.connect(arrumar);arrumar()
	func arrumar() -> void:
		luzes.position=Vector2(-JanelaShowPlex.MARGEM+16,-JanelaShowPlex.MARGEM+6)
		luzes.size=Vector2(size.x+JanelaShowPlex.MARGEM*2-32,10)
	func _draw() -> void:
		var ci:=get_canvas_item()
		var m:=float(JanelaShowPlex.MARGEM)
		ShowPlex.cortina(ci,Rect2(-m+2,-m+2,size.x+m*2-4,44),cor,14.0)
		var fonte:=VintagePlex.fonte("titulo")
		var texto_titulo:=tr(titulo).to_upper()
		var largura:=ceilf(fonte.get_string_size(texto_titulo,HORIZONTAL_ALIGNMENT_LEFT,-1,20).x*.5)*2.0+44.0
		var placa:=Rect2(roundf((size.x-largura)*.25)*2.0,14,largura,40)
		for x in [placa.position.x+18,placa.end.x-18]:ShowPlex.corrente(ci,x,-m+8,placa.position.y+2)
		ShowPlex.ret(ci,placa.position.x+2,placa.end.y,placa.size.x-4,4,Color(0.07,0.03,0.02,.4))
		ShowPlex.placa(ci,placa,ShowPlex.MADEIRA,ShowPlex.CREME,5)
		draw_string(fonte,Vector2(placa.position.x,placa.position.y+27),texto_titulo,HORIZONTAL_ALIGNMENT_CENTER,placa.size.x,20,ShowPlex.NANQUIM)
