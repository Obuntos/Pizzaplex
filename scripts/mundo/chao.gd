class_name ChaoPlex
extends Node2D

var planta: PlantaPlex
const CORES = ["original", "creme", "grafite", "vinho"]

func _draw() -> void:
	if planta == null:
		return
	var tiles: Array[Vector2i] = []
	for y in GradePlex.TAMANHO.y:
		for x in GradePlex.TAMANHO.x:
			tiles.append(Vector2i(x, y))
	tiles.sort_custom(func(a, b):
		var primeiro := GradePlex.projetar(Vector2(a))
		var segundo := GradePlex.projetar(Vector2(b))
		if not is_equal_approx(primeiro.y, segundo.y): return primeiro.y < segundo.y
		return primeiro.x < segundo.x)
	for celula in tiles:
		if planta.pisos.has(celula):
			var tipo: String = planta.pisos[celula]
			draw_texture(CatalogoPlex.sprite(tipo,GradePlex.visao),GradePlex.projetar(Vector2(celula))-Vector2(96,144))
			continue
		var cor: int = planta.cores.get(celula, 0)
		var caminho := "res://assets/objetos/chao/sprites/frente.png"
		if cor > 0:
			caminho = "res://assets/objetos/chao/sprites/cores/" + CORES[cor] + ".png"
		draw_texture(CatalogoPlex.textura(caminho), GradePlex.projetar(Vector2(celula)) - Vector2(96, 144))

