class_name SuperficieVintagePlex
extends PanelContainer

var tipo:="madeira"
var cor:=Color("4f281a")
var selecionado:=false
var pontilhado:=false
var sobre:=false
var textura:Texture2D

func _init(modo:String="madeira", margem:int=16) -> void:
	tipo=modo
	var s:=StyleBoxEmpty.new()
	for lado in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]: s.set_content_margin(lado,margem)
	add_theme_stylebox_override("panel",s)
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	textura=load("res://assets/interface/vintage/"+("papel" if tipo=="papel" else "madeira")+".png") if tipo in ["madeira","papel","moldura"] else null

func contorno(r:Rect2, cor_a:Color, cor_b:Color) -> void:
	for q in [Rect2(r.position-Vector2(8,0),r.size+Vector2(16,0)),Rect2(r.position-Vector2(0,8),r.size+Vector2(0,16)),r.grow(4)]: draw_rect(q,cor_b)
	for q in [Rect2(r.position-Vector2(4,0),r.size+Vector2(8,0)),Rect2(r.position-Vector2(0,4),r.size+Vector2(0,8))]: draw_rect(q,cor_a)

func _draw() -> void:
	var r:=Rect2(Vector2.ZERO,size)
	var a:=Color("150803") if tipo=="moldura" else Color("6b3f26") if tipo=="papel" else Color("f0a92a") if selecionado else Color("8a5a38") if tipo=="linha" else Color("3a0b10") if tipo=="faixa" else Color("1d0e08")
	var b:=Color("0a0402") if tipo=="moldura" else Color("1d0e08") if tipo=="papel" else Color("7a4a10") if selecionado else Color("4a2a18") if tipo=="linha" else Color("2a140c") if tipo=="faixa" else Color("5a3320")
	contorno(r,a,b)
	if textura!=null:
		draw_texture_rect(textura,r,tipo!="papel",Color("705342") if tipo=="moldura" else Color.WHITE)
	else: draw_rect(r,Color("7d1d22") if tipo=="faixa" else Color("f8e8bb") if selecionado else Color("f7e6b8") if sobre else Color("f1dcaa"))
	if tipo=="faixa":
		draw_rect(r.grow(-7),Color("e8b56a55"),false,2)
		draw_rect(Rect2(0,0,size.x,4),Color("ffffff18"));draw_rect(Rect2(0,size.y-4,size.x,4),Color("00000033"))
	if pontilhado:
		var tinta:=Color("d9921a99") if selecionado else Color("b8955e88")
		for x in range(7,int(size.x)-7,10):
			draw_rect(Rect2(x,7,5,2),tinta);draw_rect(Rect2(x,size.y-9,5,2),tinta)
		for y in range(7,int(size.y)-7,10):
			draw_rect(Rect2(7,y,2,5),tinta);draw_rect(Rect2(size.x-9,y,2,5),tinta)
	if tipo=="moldura":
		for p in [Vector2(5,5),Vector2(size.x-13,5),Vector2(5,size.y-13),size-Vector2(13,13)]:
			draw_rect(Rect2(p,Vector2(8,8)),Color("1a0b06"));draw_rect(Rect2(p+Vector2.ONE,Vector2(2,2)),Color("6b3f26"))
