class_name MapaArPlex
extends Node2D
var jogo:Node
var ativo:=false
var espera:=0.0
var revisao:=-1
var visao:=-1
var tiles:Dictionary={}
static func cor(q:float) -> Color:
	return Color("d54b40") if q<55 else Color("e39843") if q<85 else Color("6cb58b")
func alternar() -> void:ativo=not ativo;revisao=-1;queue_redraw()
func _process(delta:float) -> void:
	if not ativo:return
	espera+=delta
	if espera<.35:return
	espera=0
	var ar:AmbienciaRestaurantePlex=jogo.sistemas.ambiencia
	if revisao==ar.revisao_ar and visao==GradePlex.visao:return
	revisao=ar.revisao_ar;visao=GradePlex.visao;tiles.clear()
	for sala in jogo.ambientes.ambientes:
		if not sala.get("fechada",false):continue
		for c in sala.celulas:tiles[c]=ar.qualidade(c)
	queue_redraw()
func _draw() -> void:
	if not ativo:return
	for c in tiles:
		var p:=GradePlex.poligono(GradePlex.projetar(Vector2(c),jogo.planta.altura(c)+.6));var tinta:=cor(float(tiles[c]));draw_colored_polygon(p,Color(tinta,.48));draw_polyline(p+PackedVector2Array([p[0]]),Color(tinta,.7),1)
