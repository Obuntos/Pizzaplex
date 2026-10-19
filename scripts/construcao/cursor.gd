class_name CursorPlex
extends Node2D

var editor: EditorPlex
var celula := Vector2i(-1, -1)
var altura: float = 0.0
var valido: bool = false
var niveis: Dictionary = {}
var salas: Dictionary = {}

func _draw() -> void:
	if editor == null or not GradePlex.dentro(celula):
		return
	var cor := Color(0.62, 0.78, 0.68, 0.8) if valido else Color(0.85, 0.45, 0.38, 0.8)
	var centro := GradePlex.projetar(Vector2(celula), altura)
	var poligono := GradePlex.poligono(centro)
	draw_colored_polygon(poligono, Color(cor, 0.12))
	draw_polyline(poligono + PackedVector2Array([poligono[0]]), cor, 1.5)
	if editor.ferramenta in ["luz_teto", "luz_parede", "luz_chao", "pose", "pose_quebrado"]:
		draw_set_transform(GradePlex.projetar(Vector2(celula)))
		var objeto := {"celula": celula, "rotacao": editor.rotacao}
		var rotacao_luz := LuminariasPlex.rotacao_parede(objeto, editor.planta, salas) if editor.ferramenta == "luz_parede" else editor.rotacao
		var nivel: int = niveis.get(editor.planta.em(celula).get("id", -1), 4)
		var montagem := LuminariasPlex.montagem_parede(objeto, editor.planta, salas) if editor.ferramenta == "luz_parede" else {}
		DesenhoLuzPlex.desenhar(self, editor.ferramenta, rotacao_luz, altura, Color(editor.luz_padrao.cor_luz), true, [6.0, 22.0, 52.0, 104.0][nivel - 1], montagem)
		draw_set_transform(Vector2.ZERO)
	elif CatalogoPlex.objetos.has(editor.ferramenta) and editor.ferramenta != "chao":
		var rotacao := PortasPlex.rotacao_para(editor.planta, editor.ferramenta, celula, editor.rotacao) if editor.ferramenta in CatalogoPlex.PORTAS else editor.rotacao
		var dimensao := CatalogoPlex.dimensoes(editor.ferramenta, rotacao)
		var ponto := GradePlex.projetar(Vector2(celula) + Vector2(dimensao - Vector2i.ONE) * 0.5)
		var apoio := ApoiosPlex.encontrar(editor.planta, celula, editor.ferramenta) if ApoiosPlex.superficie(editor.ferramenta) else {}
		if not apoio.is_empty():
			var base := ApoiosPlex.posicao(editor.planta, editor.planta.objetos[apoio.pai])
			var slot: Dictionary = ApoiosPlex.pontos(editor.planta.objetos[apoio.pai],editor.planta)[apoio.slot]
			ponto = GradePlex.projetar(Vector2(base.x + slot.u, base.y + slot.v), base.z + slot.z)
		draw_texture(CatalogoPlex.sprite(editor.ferramenta, GradePlex.rotacao_visual(rotacao)), ponto - Vector2(96, 144), Color(1, 1, 1, 0.45))

