class_name LuzesShowPlex
extends Control
## Fileira de lâmpadas de letreiro em volta de um retângulo. Fica por cima
## do controle pai, sem pegar o mouse, e as lâmpadas correm em sequência.

enum Modo {CORRER, PISCAR, FIXO}
var modo:=Modo.CORRER
var passo:=20.0
var ritmo:=.28
var cor:=Color("ffe9a8")
var so_topo:=false
var folga:=0.0
var ativo:=true:
	set(v):
		if v==ativo:return
		ativo=v;queue_redraw()
var fase:=0
var relogio:=0.0

func _init(apenas_topo:bool=false, distancia:float=20.0) -> void:
	so_topo=apenas_topo;passo=distancia
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST

## Cobre o controle pai inteiro, com as lâmpadas sobre a borda.
static func em_volta(pai:Control, distancia:float=20.0, margem:float=0.0) -> LuzesShowPlex:
	var l:=LuzesShowPlex.new(false,distancia)
	l.folga=margem
	pai.add_child(l)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return l

func _process(delta:float) -> void:
	if not is_visible_in_tree() or modo==Modo.FIXO:return
	relogio+=delta
	if relogio<ritmo:return
	relogio=0.0;fase+=1;queue_redraw()

func pontos() -> PackedVector2Array:
	var r:=Rect2(Vector2(folga,folga),size-Vector2(folga,folga)*2.0)
	var lista:=PackedVector2Array()
	var nx:=maxi(2,roundi(r.size.x/passo))
	for i in nx+1:lista.append(Vector2(r.position.x+r.size.x*i/nx,r.position.y))
	if so_topo:return lista
	var ny:=maxi(1,roundi(r.size.y/passo))
	for i in range(1,ny):lista.append(Vector2(r.end.x,r.position.y+r.size.y*i/ny))
	for i in nx+1:lista.append(Vector2(r.end.x-r.size.x*i/nx,r.end.y))
	for i in range(1,ny):lista.append(Vector2(r.position.x,r.end.y-r.size.y*i/ny))
	return lista

func _draw() -> void:
	var ci:=get_canvas_item()
	var lista:=pontos()
	for i in lista.size():
		var acesa:=ativo and (modo==Modo.FIXO or (posmod(i+fase,3)!=0 if modo==Modo.CORRER else (i+fase)%2==0))
		ShowPlex.lampada(ci,lista[i],acesa,cor)
