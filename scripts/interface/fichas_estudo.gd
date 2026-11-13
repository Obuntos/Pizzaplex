class_name FichasEstudoPlex
extends RefCounted
## Dados e peças desenhadas do cartaz de estudo e da ficha de animatrônico.
## Os textos ficam em dados/fichas_animatronicos.json para serem editados
## sem mexer no código.

const U:=2
static var dados:Dictionary={}

static func ficha(id:String) -> Dictionary:
	if dados.is_empty():
		var lido=JSON.parse_string(FileAccess.get_file_as_string("res://dados/fichas_animatronicos.json"))
		dados=lido if lido is Dictionary else {}
	var d:Dictionary=dados.get(id,{})
	if d.is_empty():
		var nome:=CatalogoMontagemPlex.nome(id)
		d={"nome":nome.split(" · ")[-1],"subtitulo":"","imagem":"","cor":"dfb16a","curta":"","longa":""}
	return d

static func imagem(id:String) -> Texture2D:
	var caminho:=str(ficha(id).get("imagem",""))
	if caminho.is_empty() or not ResourceLoader.exists(caminho):
		caminho=str(AtracoesCatalogoPlex.registro(id).get("rosto",""))
	return load(caminho) if not caminho.is_empty() and ResourceLoader.exists(caminho) else null

static func cor(id:String) -> Color:
	return Color(str(ficha(id).get("cor","dfb16a")))

## Retrato do animatrônico em escala inteira. Sem estudo, só a silhueta.
static func retrato(pai:Node, id:String, escala:int, silhueta:bool) -> TextureRect:
	var r:=TextureRect.new()
	r.texture=imagem(id)
	r.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode=TextureRect.STRETCH_KEEP_CENTERED
	r.mouse_filter=Control.MOUSE_FILTER_IGNORE
	if r.texture!=null:
		r.custom_minimum_size=Vector2(r.texture.get_width(),r.texture.get_height())*escala
		r.stretch_mode=TextureRect.STRETCH_SCALE
	if silhueta:r.self_modulate=Color("1d0e08")
	pai.add_child(r)
	return r


## Moldura em arco, como as dos cartazes de atração: topo arredondado em
## degraus de pixel, base reta. O retrato fica centralizado e apoiado no chão.
class Arco extends Container:
	var borda:=Color("e8b56a")
	var fundo:=Color("f6e3b8")
	var raio:=40
	func _init() -> void:
		mouse_filter=Control.MOUSE_FILTER_IGNORE
		texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	func _notification(o:int) -> void:
		if o==NOTIFICATION_SORT_CHILDREN:
			for filho in get_children():
				if filho is Control:
					var m:Vector2=filho.get_combined_minimum_size()
					fit_child_in_rect(filho,Rect2(Vector2(roundf((size.x-m.x)*.5),size.y-m.y-10),m))
	func pintar(folga:float, cor:Color) -> void:
		# Cada camada usa o mesmo centro de canto com raio menor: o arco
		# mantém a espessura e desce em degraus de 2 px.
		var r:=float(raio)-folga
		for y in range(int(folga),int(size.y-folga),2):
			var esquerda:=folga
			if y<raio:
				var dy:=float(raio)-y-1.0
				if dy>=r:continue
				esquerda=maxf(folga,snappedf(raio-sqrt(r*r-dy*dy),2.0))
			draw_rect(Rect2(esquerda,y,size.x-esquerda*2,2),cor)
	func _draw() -> void:
		pintar(0,Color("1d0e08"))
		pintar(2,borda)
		pintar(6,borda.darkened(.35))
		pintar(8,fundo)
		draw_rect(Rect2(8,size.y-22,size.x-16,14),fundo.darkened(.08))


## Estrela de 7 × 7 pixels, para os cantos do cartaz.
class Estrela extends Control:
	var cor:=Color("f3c46f")
	const FORMA=["...#...","...#...","#######",".#####.","..###..",".##.##.","##...##"]
	func _init(tinta:Color=Color("f3c46f")) -> void:
		cor=tinta;mouse_filter=Control.MOUSE_FILTER_IGNORE;custom_minimum_size=Vector2(7,7)*3
	func _draw() -> void:
		for y in FORMA.size():
			for x in FORMA[y].length():
				if FORMA[y][x]=="#":draw_rect(Rect2(x*3,y*3,3,3),cor)


## Faixa quadriculada das fichas impressas.
class Xadrez extends Control:
	var a:=Color("e2c49a")
	var b:=Color("cfa676")
	var lado:=20
	func _init() -> void:
		mouse_filter=Control.MOUSE_FILTER_IGNORE;custom_minimum_size.y=40
	func _draw() -> void:
		for y in range(0,int(size.y),lado):
			for x in range(0,int(size.x),lado):
				draw_rect(Rect2(x,y,lado,lado),a if (floori(float(x)/lado)+floori(float(y)/lado))%2==0 else b)


## Fundo de palco atrás do retrato da ficha: cortina e chão.
class Palco extends Container:
	var borda:=Color("e8b56a")
	func _init() -> void:
		mouse_filter=Control.MOUSE_FILTER_IGNORE;texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	func _notification(o:int) -> void:
		if o==NOTIFICATION_SORT_CHILDREN:
			for filho in get_children():
				if filho is Control:
					var m:Vector2=filho.get_combined_minimum_size()
					fit_child_in_rect(filho,Rect2(Vector2(roundf((size.x-m.x)*.5),size.y-m.y-30),m))
	func _draw() -> void:
		var r:=Rect2(Vector2.ZERO,size)
		draw_rect(r,Color("1d0e08"))
		draw_rect(r.grow(-2),borda)
		var dentro:=r.grow(-10)
		draw_rect(r.grow(-8),borda.darkened(.35))
		draw_rect(dentro,Color("2b2838"))
		# Pregas da cortina, em faixas verticais.
		for x in range(int(dentro.position.x),int(dentro.end.x),24):
			draw_rect(Rect2(x,dentro.position.y,10,dentro.size.y),Color("34303f"))
			draw_rect(Rect2(x+10,dentro.position.y,2,dentro.size.y),Color("3d384a"))
		# Chão do palco.
		var chao:=Rect2(dentro.position.x,dentro.end.y-56,dentro.size.x,56)
		draw_rect(chao,Color("252231"))
		draw_rect(Rect2(chao.position,Vector2(chao.size.x,2)),Color("3f3a50"))
		draw_rect(Rect2(dentro.position.x+20,chao.position.y+18,dentro.size.x-40,10),Color(0,0,0,.25))
