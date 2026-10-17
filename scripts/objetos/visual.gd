class_name ObjetoVisualPlex
extends Node2D

var sprite := Sprite2D.new()
var registro: Dictionary = {}
var elevacao: float = 0.0
var rotacao_luz: int = 0
var altura_parede: float = 104.0
var montagem_luz: Dictionary = {}

func configurar_profundidade(cena: CenaPlex) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/luminaria_visivel.gdshader")
	mat.set_shader_parameter("profundidade", cena.profundidade)
	mat.set_shader_parameter("origem", Vector2(cena.ORIGEM))
	mat.set_shader_parameter("tamanho", Vector2(cena.TAMANHO))
	material = mat

func _init() -> void:
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)

func atualizar(objeto: Dictionary, planta: PlantaPlex, nivel: int, niveis: Dictionary = {}, salas: Dictionary = {}) -> void:
	registro = objeto
	if planta.sobreposto(objeto.tipo):
		sprite.visible = false
		position = GradePlex.projetar(Vector2(objeto.celula))
		elevacao = planta.altura(objeto.celula)
		rotacao_luz = LuminariasPlex.rotacao_parede(objeto, planta, salas) if objeto.tipo == "luz_parede" else objeto.rotacao
		montagem_luz = LuminariasPlex.montagem_parede(objeto, planta, salas) if objeto.tipo == "luz_parede" else {}
		var base := planta.em(objeto.celula)
		var nivel_local: int = niveis.get(base.get("id", -1), nivel)
		altura_parede = [6.0, 22.0, 52.0, 104.0][clampi(nivel_local - 1, 0, 3)]
		if material is ShaderMaterial:
			var mat := material as ShaderMaterial
			var horizontal: bool = objeto.tipo != "luz_parede" or altura_parede < 82.0
			var z := elevacao + (140.0 if objeto.tipo == "luz_teto" else .2)
			if objeto.tipo == "luz_parede": z = altura_parede + 1.2
			mat.set_shader_parameter("horizontal", horizontal)
			mat.set_shader_parameter("altura", z)
			if not horizontal:
				var ponto := GradePlex.projetar(Vector2(objeto.celula) + Vector2(montagem_luz.deslocamento))
				var frente := GradePlex.projetar_vetor(montagem_luz.frente)
				var inclinacao := clampf(-frente.x / (frente.y * 2.0), -1.0, 1.0) if absf(frente.y) > .001 else 0.0
				mat.set_shader_parameter("centro_fisico", Vector2(ponto.x, ponto.y * 2.0))
				mat.set_shader_parameter("inclinacao", inclinacao)
		z_index = -1 if objeto.tipo in ["pose", "pose_quebrado", "luz_chao"] else 0
		queue_redraw()
		return
	var dimensao := CatalogoPlex.dimensoes(objeto.tipo, objeto.rotacao)
	var centro := Vector2(objeto.celula) + Vector2(dimensao - Vector2i.ONE) * 0.5
	position = GradePlex.projetar(centro)
	var volume := GeometriaPlex.objeto(objeto, planta, nivel)
	sprite.texture = volume.textura
	sprite.position = Vector2(volume.origin[0], volume.origin[1])

func _draw() -> void:
	if registro.get("tipo", "") in ["pose", "pose_quebrado", "luz_teto", "luz_parede", "luz_chao"]:
		DesenhoLuzPlex.desenhar(self, registro.tipo, rotacao_luz, elevacao, Color(registro.get("cor_luz", "#fff0d5")), registro.get("ligada", true), altura_parede, montagem_luz)
