class_name ConfetePlex
extends Control
## Estouro de confete em pixels. Cada pedaço é um quadradinho que sobe,
## gira (alterna largura e altura) e cai. Some sozinho ao terminar.

var pedacos:Array[Dictionary]=[]
var vida:=0.0
const DURACAO:=1.5

## Estoura confete num ponto da tela (coordenadas do viewport).
static func estourar(origem:Node, ponto:Vector2, quantidade:int=26, cores:Array=ShowPlex.FESTA, forca:float=260.0) -> void:
	if not is_instance_valid(origem) or not origem.is_inside_tree():return
	var camada:=CanvasLayer.new();camada.layer=126
	origem.get_tree().root.add_child(camada)
	var c:=ConfetePlex.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter=Control.MOUSE_FILTER_IGNORE
	camada.add_child(c)
	for i in quantidade:
		var angulo:=randf_range(-PI*.95,-PI*.05)
		var impulso:=randf_range(.35,1.0)*forca
		c.pedacos.append({"p":ponto,"v":Vector2(cos(angulo),sin(angulo))*impulso,"cor":cores[i%cores.size()],"giro":randf()*TAU,"vel":randf_range(8.0,16.0),"lado":4 if i%3 else 6})
	c.tree_exited.connect(camada.queue_free)

## Estoura no centro de um controle.
static func sobre(alvo:Control, quantidade:int=26, cores:Array=ShowPlex.FESTA) -> void:
	if not is_instance_valid(alvo) or not alvo.is_inside_tree():return
	estourar(alvo,alvo.get_global_transform_with_canvas()*(alvo.size*.5),quantidade,cores)

func _process(delta:float) -> void:
	vida+=delta
	if vida>=DURACAO:queue_free();return
	for p in pedacos:
		p.v.y+=620.0*delta
		p.v*=1.0-1.6*delta
		p.p+=p.v*delta
		p.giro+=float(p.vel)*delta
	queue_redraw()

func _draw() -> void:
	var some:=clampf((DURACAO-vida)/.35,0.0,1.0)
	for p in pedacos:
		var lado:=float(p.lado)
		var largura:=maxf(2.0,roundf(absf(cos(float(p.giro)))*lado*.5)*2.0)
		var cor:Color=p.cor
		cor.a=some
		draw_rect(Rect2((Vector2(p.p)*.5).round()*2.0-Vector2(largura,lado)*.5,Vector2(largura,lado)),cor)
