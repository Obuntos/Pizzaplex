class_name DesenhoLuzPlex
extends RefCounted

static func desenhar(node: Node2D, tipo: String, rotacao: int, elevacao: float, cor: Color, ligada: bool = true, altura_parede: float = 104.0, montagem: Dictionary = {}, tom:Color=Color.WHITE) -> void:
	var centro := Vector2(0, -elevacao)
	if tipo in ["pose","pose_quebrado","pose_montagem"]:
		var cor_seta := Color("c76962") if tipo=="pose_quebrado" else Color("82b7d8") if tipo=="pose_montagem" else Color("93b5a4")
		var vetor := GradePlex.projetar_vetor(Vector2(GradePlex.frente(rotacao))).normalized()
		var lateral := Vector2(-vetor.y, vetor.x)
		var fim := centro + vetor * 17.0
		node.draw_line(centro - vetor * 9.0, fim, cor_seta, 2.0)
		node.draw_colored_polygon(PackedVector2Array([fim, fim - vetor * 7.0 + lateral * 4.0, fim - vetor * 7.0 - lateral * 4.0]), cor_seta)
		return
	var base:=LuminariasPlex.tipo(tipo)
	var corte:=base=="luz_parede" and altura_parede<82.0
	if base=="luz_teto": centro.y-=140.0
	elif base=="luz_parede":
		if corte: centro=Vector2(0,-altura_parede-1.2)
		else:
			var frente: Vector2=montagem.get("frente",Vector2(GradePlex.frente(rotacao)))
			centro=GradePlex.projetar_vetor(montagem.get("deslocamento",frente*.56),72.0)
	var textura:=ModeloLuminariaPlex.textura(tipo,GradePlex.rotacao_visual(rotacao),ligada,corte,cor)
	node.draw_texture(textura,(centro-Vector2(24,24)).round(),tom)

static func apontada(node: ObjetoVisualPlex, mouse: Vector2) -> bool:
	var tipo:=str(node.registro.get("tipo",""))
	if not LuminariasPlex.eh(tipo): return false
	var base:=LuminariasPlex.tipo(tipo)
	var centro:=Vector2(0,-node.elevacao)
	var corte:=base=="luz_parede" and node.altura_parede<82.0
	if base=="luz_teto": centro.y-=140.0
	elif base=="luz_parede":
		if corte: centro=Vector2(0,-node.altura_parede-1.2)
		else: centro=GradePlex.projetar_vetor(node.montagem_luz.get("deslocamento",Vector2(GradePlex.frente(node.rotacao_luz))*.56),72.0)
	var textura:=ModeloLuminariaPlex.textura(tipo,GradePlex.rotacao_visual(node.rotacao_luz),false,corte,Color(node.registro.get("cor_luz","#fff0d5")))
	var pixel:=Vector2i((node.to_local(mouse)-centro+Vector2(24,24)).floor())
	return Rect2i(Vector2i.ZERO,textura.get_size()).has_point(pixel) and textura.get_image().get_pixelv(pixel).a>.1
