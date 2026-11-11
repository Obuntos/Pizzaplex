class_name MapaConfortoPlex
extends Node2D

var jogo: Node
var ativo := false
var espera := 0.0
var assinatura := -1
var areas: Array = []

static func cor(nota: float) -> Color:
	if nota<5.5: return Color("d66459").lerp(Color("d5b95c"),clampf((nota-1.0)/4.5,0.0,1.0))
	return Color("d5b95c").lerp(Color("65ba94"),clampf((nota-5.5)/4.5,0.0,1.0))

func alternar() -> void:
	ativo = not ativo
	assinatura = -1
	queue_redraw()

func _process(delta: float) -> void:
	if not ativo: return
	espera += delta
	if espera<.3: return
	espera = 0.0
	var nova := hash([jogo.planta.revisao,GradePlex.visao,jogo.conforto.notas])
	if nova==assinatura: return
	assinatura=nova
	areas.clear()
	for sala in jogo.ambientes.ambientes:
		if not sala.fechada: continue
		var nota: Dictionary = jogo.conforto.notas.get(sala.id,{})
		if nota.is_empty(): nota=jogo.conforto.calcular(sala)
		areas.append({"celulas":sala.celulas,"nota":nota.nota})
	queue_redraw()

func _draw() -> void:
	if not ativo: return
	for area in areas:
		var tinta := cor(float(area.nota))
		for c in area.celulas:
			var pontos := GradePlex.poligono(GradePlex.projetar(Vector2(c),jogo.planta.altura(c)+.4))
			draw_colored_polygon(pontos,Color(tinta,.3))
			draw_polyline(pontos+PackedVector2Array([pontos[0]]),Color(tinta,.42),1.0)
