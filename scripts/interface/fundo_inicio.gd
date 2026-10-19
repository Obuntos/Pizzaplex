class_name FundoInicioPlex
extends Control

var figuras: Array[AnimacaoPlex] = []
var tempo := 0.0
var espera := 0.0

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	for modelo in ["ovelha","coelho","raposa"]:
		var figura:=AnimacaoPlex.new()
		figura.configurar(modelo)
		add_child(figura)
		figuras.append(figura)
		figura.atualizar("parado",0,0,0)
	resized.connect(organizar)
	organizar()

func moldura() -> Rect2:
	return Rect2(size.x*.36,64,size.x*.60,size.y-128)

func organizar() -> void:
	var area:=moldura()
	var fator:=clampf(floorf(minf(area.size.x/240.0,area.size.y/170.0)),1.0,4.0)
	for i in figuras.size():
		figuras[i].scale=Vector2.ONE*(fator+1 if i==1 else fator)
		figuras[i].position=Vector2(area.position.x+area.size.x*[.21,.5,.79][i],area.end.y-48).round()
	queue_redraw()

func _process(delta: float) -> void:
	tempo+=delta
	espera+=delta
	if espera<.15: return
	espera=0
	for i in figuras.size(): figuras[i].atualizar("parado",0,0,tempo+i*.47)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("121e25"))
	var area:=moldura()
	draw_rect(Rect2(area.position+Vector2(6,8),area.size),Color("0b141a"))
	draw_rect(area,Color("4c3037"))
	var interior:=area.grow(-10)
	draw_rect(interior,Color("2d252e"))
	var margem:=interior.size.x*.13
	for lado in [0,1]:
		for i in 7:
			var x:=interior.position.x+i*margem/7 if lado==0 else interior.end.x-margem+i*margem/7
			draw_rect(Rect2(x,interior.position.y,margem/7+1,interior.size.y),Color("793d48") if i%2==0 else Color("62333e"))
	for i in 8:
		var x:=interior.position.x+i*interior.size.x/8
		draw_rect(Rect2(x,interior.position.y,interior.size.x/8+1,26+(12 if i%2==0 else 0)),Color("874750") if i%2==0 else Color("713942"))
	var piso:=Rect2(interior.position.x,interior.end.y-52,interior.size.x,52)
	draw_rect(piso,Color("6c5143"))
	draw_rect(Rect2(piso.position+Vector2(0,8),Vector2(piso.size.x,3)),Color("a08055"))
	draw_rect(Rect2(piso.position+Vector2(0,43),Vector2(piso.size.x,9)),Color("433742"))
	for i in 3:
		var centro:=Vector2(area.position.x+area.size.x*[.21,.5,.79][i],area.end.y-46)
		oval(centro,Vector2(42,10),Color("1e2028"))
	for x in range(4):
		var p:=Vector2(interior.position.x+interior.size.x*(.25+x*.17),interior.position.y+60)
		draw_rect(Rect2(p,Vector2(5,5)),Color("c4a46d"))
	draw_rect(Rect2(32,38,4,size.y-76),Color("916d49"))

func oval(centro: Vector2, raio: Vector2, cor: Color) -> void:
	var pontos:=PackedVector2Array()
	for i in 24:
		var angulo:=float(i)/24*TAU
		pontos.append(centro+Vector2(cos(angulo),sin(angulo))*raio)
	draw_colored_polygon(pontos,cor)
