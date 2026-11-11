class_name DesenhoSalasPlex
extends Node2D

var salas: AmbientesPlex
var mostrar := false
var selecionada := Vector2i(-1,-1)

func _draw() -> void:
	if salas == null or not mostrar: return
	for ambiente in salas.ambientes:
		if ambiente.tipo == "livre": continue
		var cor := Color(salas.definicoes[ambiente.tipo].cor)
		cor.a = .65
		for celula in ambiente.celulas:
			var centro := GradePlex.projetar(Vector2(celula),salas.planta.altura(celula)+.2)
			var poli := GradePlex.poligono(centro)
			for i in 4:
				var vizinha: Vector2i = celula + [Vector2i(0,-1),Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0)][i]
				if not ambiente.celulas.has(vizinha): draw_line(poli[i],poli[(i+1)%4],cor,1.0)
		if ambiente.celulas.has(selecionada):
			var ponto := GradePlex.projetar(Vector2(selecionada),salas.planta.altura(selecionada)+.3)
			draw_polyline(GradePlex.poligono(ponto)+PackedVector2Array([ponto+Vector2(0,-16)]),cor,1.5)
