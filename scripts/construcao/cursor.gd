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
	var alvo:Dictionary=editor.alvo_remocao(celula) if editor.ferramenta=="remover" else {}
	if editor.ferramenta=="remover":cor=Color(1.0,.12,.08,.95)
	var rotacao_previa:=PortasPlex.rotacao_para(editor.planta,editor.ferramenta,celula,editor.rotacao) if PortasPlex.ajusta(str(editor.ferramenta)) else editor.rotacao
	var ocupadas: Array[Vector2i]=[celula]
	if CatalogoPlex.objetos.has(editor.ferramenta): ocupadas=editor.planta.celulas(editor.ferramenta,celula,rotacao_previa)
	if not alvo.is_empty():ocupadas=editor.planta.celulas(alvo.tipo,alvo.celula,alvo.rotacao)
	for c in ocupadas:
		var poligono:=GradePlex.poligono(GradePlex.projetar(Vector2(c),altura))
		draw_colored_polygon(poligono,Color(cor,.12))
		draw_polyline(poligono+PackedVector2Array([poligono[0]]),cor,1.5)
	if not alvo.is_empty():
		var p:=ApoiosPlex.posicao(editor.planta,alvo)
		if alvo.tipo in ["luz_teto","luz_parede","luz_chao","luz_teto_economica","luz_parede_economica","luz_chao_economica","pose","pose_quebrado","pose_montagem"]:
			draw_set_transform(GradePlex.projetar(Vector2(p.x,p.y)))
			var r:=LuminariasPlex.rotacao_parede(alvo,editor.planta,salas) if LuminariasPlex.tipo(alvo.tipo)=="luz_parede" else int(alvo.rotacao)
			var nivel:int=niveis.get(editor.planta.em(alvo.celula).get("id",-1),4)
			var montagem:=LuminariasPlex.montagem_parede(alvo,editor.planta,salas) if LuminariasPlex.tipo(alvo.tipo)=="luz_parede" else {}
			DesenhoLuzPlex.desenhar(self,alvo.tipo,r,p.z,cor,true,[6.0,22.0,52.0,104.0][nivel-1],montagem,Color(1,.08,.04,.95))
			draw_set_transform(Vector2.ZERO)
		elif not MobiliaPlex.dados(alvo).get("bairro",false) and not ManchasPlex.eh(alvo.tipo):
			var volume:=GeometriaPlex.objeto(alvo,editor.planta,4)
			draw_texture(volume.textura,GradePlex.projetar(Vector2(p.x,p.y),p.z)+Vector2(volume.origin[0],volume.origin[1]),Color(1.0,.1,.06,.75))
		return
	if CatalogoPlex.objetos.has(editor.ferramenta): AcessosConstrucaoPlex.desenhar(self,editor.acessos.avaliar(editor,celula))
	if CatalogoPlex.objetos.has(editor.ferramenta):PoluicaoArPlex.desenhar_alcance(self,editor.ferramenta,celula,rotacao_previa)
	if editor.item_movendo>=0 and not LuminariasPlex.eh(editor.ferramenta):
		PreviaConstrucaoPlex.desenhar(self,.55)
		return
	if editor.ferramenta in ["luz_teto", "luz_parede", "luz_chao", "luz_teto_economica", "luz_parede_economica", "luz_chao_economica", "pose", "pose_quebrado", "pose_montagem"]:
		draw_set_transform(GradePlex.projetar(EncaixesMobiliaPlex.ancora_luz(editor.planta,{"tipo":editor.ferramenta,"celula":celula})))
		var objeto := {"celula": celula, "rotacao": editor.rotacao}
		var rotacao_luz := LuminariasPlex.rotacao_parede(objeto, editor.planta, salas) if LuminariasPlex.tipo(editor.ferramenta) == "luz_parede" else editor.rotacao
		var nivel: int = niveis.get(editor.planta.em(celula).get("id", -1), 4)
		var montagem := LuminariasPlex.montagem_parede(objeto, editor.planta, salas) if LuminariasPlex.tipo(editor.ferramenta) == "luz_parede" else {}
		DesenhoLuzPlex.desenhar(self, editor.ferramenta, rotacao_luz, altura, Color(editor.luz_padrao.cor_luz), true, [6.0, 22.0, 52.0, 104.0][nivel - 1], montagem)
		draw_set_transform(Vector2.ZERO)
	elif CatalogoPlex.objetos.has(editor.ferramenta) and editor.ferramenta!="chao":
		if CatalogoPlex.objetos[editor.ferramenta].has("pacote"):
			for c in MobiliaPlex.modulos(editor.ferramenta,celula,rotacao_previa):
				draw_texture(CatalogoPlex.sprite(editor.ferramenta,GradePlex.rotacao_visual(rotacao_previa),editor.estado_visual),GradePlex.projetar(Vector2(c))-Vector2(96,144),Color(1,1,1,.45))
		else:PreviaConstrucaoPlex.desenhar(self,.45)
