class_name ObjetoVisualPlex
extends Node2D

var sprite := Sprite2D.new()
var energia_disponivel := false
var intensidade_luz:=-1.0
var destaque_exclusao:=false
func destacar_exclusao(valor:bool) -> void:
	if destaque_exclusao==valor:return
	destaque_exclusao=valor
	if material is ShaderMaterial:material.set_shader_parameter("destaque_exclusao",valor)
	queue_redraw()

func aplicar_energia(valor: float, ambiente: float) -> void:
	valor=roundf(clampf(valor,0.0,1.0)*24.0)/24.0
	var brilho:=lerpf(clampf(ambiente*.75,.12,.8),1.0,valor)
	modulate=Color(brilho,brilho,brilho,1.0)
	if is_equal_approx(valor,intensidade_luz) and energia_disponivel==(valor>.06): return
	intensidade_luz=valor
	energia_disponivel=valor>.06
	queue_redraw()
var registro: Dictionary = {}
var marca_visivel:=false
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
		position = GradePlex.projetar(EncaixesMobiliaPlex.ancora_luz(planta,objeto))
		elevacao = planta.altura(objeto.celula)
		rotacao_luz = LuminariasPlex.rotacao_parede(objeto, planta, salas) if LuminariasPlex.tipo(objeto.tipo) == "luz_parede" else objeto.rotacao
		montagem_luz = LuminariasPlex.montagem_parede(objeto, planta, salas) if LuminariasPlex.tipo(objeto.tipo) == "luz_parede" else {}
		var base := planta.em(objeto.celula)
		var nivel_local: int = niveis.get(base.get("id", -1), nivel)
		altura_parede = [6.0, 22.0, 52.0, 104.0][clampi(nivel_local - 1, 0, 3)]
		if material is ShaderMaterial:
			var mat := material as ShaderMaterial
			var horizontal: bool = LuminariasPlex.tipo(objeto.tipo) != "luz_parede" or altura_parede < 82.0
			var z := elevacao + (140.0 if LuminariasPlex.tipo(objeto.tipo) == "luz_teto" else .2)
			if LuminariasPlex.tipo(objeto.tipo) == "luz_parede": z = altura_parede + 1.2
			mat.set_shader_parameter("horizontal", horizontal)
			mat.set_shader_parameter("altura", z)
			if not horizontal:
				var ponto := GradePlex.projetar(Vector2(objeto.celula) + Vector2(montagem_luz.deslocamento))
				var frente := GradePlex.projetar_vetor(montagem_luz.frente)
				var inclinacao := clampf(-frente.x / (frente.y * 2.0), -1.0, 1.0) if absf(frente.y) > .001 else 0.0
				mat.set_shader_parameter("centro_fisico", Vector2(ponto.x, ponto.y * 2.0))
				mat.set_shader_parameter("inclinacao", inclinacao)
		z_index = -1 if objeto.tipo in ["pose", "pose_quebrado", "pose_montagem", "luz_chao", "luz_chao_economica"] else 0
		queue_redraw()
		return
	var dimensao := CatalogoPlex.dimensoes(objeto.tipo, objeto.rotacao)
	var centro := Vector2(objeto.celula) + Vector2(dimensao - Vector2i.ONE) * 0.5
	position = GradePlex.projetar(centro)
	var volume := GeometriaPlex.objeto(objeto, planta, nivel)
	sprite.texture = volume.textura
	sprite.position = Vector2(volume.origin[0], volume.origin[1])

func _process(_delta: float) -> void:
	if registro.get("tipo","") not in ["pose","pose_quebrado","pose_montagem"]: return
	var cena:=get_tree().current_scene
	var editor: EditorPlex=cena.get("editor") if cena!=null else null
	var mostrar:=editor!=null and editor.construindo()
	if editor!=null and editor.jogo!=null and editor.jogo.painel.hud!=null: mostrar=mostrar or editor.jogo.painel.hud.catalogo.painel.visible
	if mostrar!=marca_visivel: marca_visivel=mostrar;queue_redraw()
func _draw() -> void:
	if registro.get("tipo","") in ["pose","pose_quebrado","pose_montagem"] and not marca_visivel: return
	if registro.get("tipo", "") in ["pose", "pose_quebrado", "pose_montagem", "luz_teto", "luz_parede", "luz_chao", "luz_teto_economica", "luz_parede_economica", "luz_chao_economica"]:
		DesenhoLuzPlex.desenhar(self, registro.tipo, rotacao_luz, elevacao, Color(registro.get("cor_luz", "#fff0d5")), registro.get("ligada", true) and energia_disponivel, altura_parede, montagem_luz, Color(1,.025,.015) if destaque_exclusao else Color.WHITE)


