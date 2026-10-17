class_name DesenhoLuzPlex
extends RefCounted

static func desenhar(node: Node2D, tipo: String, rotacao: int, elevacao: float, cor: Color, ligada: bool = true, altura_parede: float = 104.0, montagem: Dictionary = {}) -> void:
	var centro := Vector2(0, -elevacao)
	var aro := Color("59646a")
	var brilho := cor if ligada else Color("666b68")
	if tipo in ["pose","pose_quebrado"]:
		var cor_seta := Color("c76962") if tipo=="pose_quebrado" else Color("93b5a4")
		var vetor := GradePlex.projetar_vetor(Vector2(GradePlex.frente(rotacao))).normalized()
		var lateral := Vector2(-vetor.y, vetor.x)
		var fim := centro + vetor * 17.0
		node.draw_line(centro - vetor * 9.0, fim, cor_seta, 2.0)
		node.draw_colored_polygon(PackedVector2Array([fim, fim - vetor * 7.0 + lateral * 4.0, fim - vetor * 7.0 - lateral * 4.0]), cor_seta)
		return
	if tipo == "luz_teto":
		centro.y -= 140.0
		node.draw_set_transform(centro, 0.0, Vector2(1, .48))
		node.draw_circle(Vector2.ZERO, 12, aro)
		node.draw_circle(Vector2.ZERO, 9, Color("858e8d"))
		node.draw_circle(Vector2.ZERO, 7, brilho)
	elif tipo == "luz_parede":
		if altura_parede < 82.0:
			centro = Vector2(0, -altura_parede - 1.2)
			node.draw_set_transform(centro, 0, Vector2(1, .5))
			node.draw_circle(Vector2.ZERO, 5, aro)
			node.draw_circle(Vector2.ZERO, 3, brilho)
		else:
			var frente: Vector2 = montagem.get("frente", Vector2(GradePlex.frente(rotacao)))
			centro = GradePlex.projetar_vetor(montagem.get("deslocamento", frente * .56), 72.0)
			var lado := GradePlex.projetar_vetor(Vector2(frente.y, -frente.x) * .12)
			if absf(lado.x) < 1.0: lado = Vector2(3.8, 0)
			for painel in [0, 1]:
				var lateral := lado * (1.0 if painel == 0 else .53)
				var vertical := Vector2(0, 8 if painel == 0 else 5)
				node.draw_colored_polygon(PackedVector2Array([centro - lateral - vertical, centro + lateral - vertical, centro + lateral + vertical, centro - lateral + vertical]), aro if painel == 0 else brilho)
	else:
		node.draw_set_transform(centro, 0.0, Vector2(1, .5))
		node.draw_circle(Vector2.ZERO, 6, aro)
		node.draw_circle(Vector2.ZERO, 4, brilho)
		node.draw_circle(Vector2(-1, -1), 1, Color("fff4dd") if ligada else aro)
	node.draw_set_transform(Vector2.ZERO)
