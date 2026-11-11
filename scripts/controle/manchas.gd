class_name ManchasPlex
extends Node2D

var jogo: Node
var sprites: Dictionary = {}
var revisao := -1
var visao := -1
var passos: Dictionary = {}
var espera := 0.0

static func eh(tipo: String) -> bool:
	return tipo.begins_with("cenario_poca_") or tipo=="cenario_trilha_pegadas"

func apontada(ponto: Vector2) -> int:
	for id in sprites:
		var s: Sprite2D=sprites[id]
		if not s.visible: continue
		var p:=Vector2i((s.to_local(ponto)-s.offset).floor())
		var im:=SilhuetasPlex.imagem(s.texture)
		if im!=null and Rect2i(Vector2i.ZERO,im.get_size()).has_point(p) and im.get_pixelv(p).a>.1: return id
	return -1

func atualizar(delta: float) -> void:
	if revisao!=jogo.planta.revisao or visao!=GradePlex.visao:
		revisao=jogo.planta.revisao
		visao=GradePlex.visao
		var presentes: Dictionary={}
		for item in jogo.planta.objetos.values():
			if not eh(item.tipo): continue
			presentes[item.id]=true
			var s: Sprite2D=sprites.get(item.id)
			if not is_instance_valid(s):
				s=Sprite2D.new()
				s.centered=false
				s.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
				var mat:=ShaderMaterial.new()
				mat.shader=load("res://shaders/objeto_manual.gdshader")
				mat.set_shader_parameter("profundidade_cena",jogo.composicao.profundidade)
				mat.set_shader_parameter("origem",Vector2(CenaPlex.ORIGEM))
				mat.set_shader_parameter("tamanho",Vector2(CenaPlex.TAMANHO))
				jogo.iluminacao.vincular(mat)
				s.material=mat
				add_child(s)
				sprites[item.id]=s
			var info:=MobiliaPlex.dados(item)
			var r:=GradePlex.rotacao_visual(item.rotacao)
			var origem: Array=info.origens[CatalogoPlex.DIRECOES[r]]
			var altura: float=jogo.planta.altura(item.celula)+.18
			s.texture=CatalogoPlex.textura(info.pasta+"/sprites/"+str(item.estado)+"/"+str(r)+"_volume.png")
			s.offset=Vector2(origem[0],origem[1])
			if item.tipo=="cenario_trilha_pegadas":
				s.texture=PegadasPlex.textura(int(item.get("direcao_passos",item.rotacao*2)),str(item.estado).ends_with("seco"))
				s.offset=Vector2(-24,-16)
			s.position=GradePlex.projetar(Vector2(item.celula),altura)
			s.material.set_shader_parameter("altura",altura)
		for id in sprites.keys():
			if not presentes.has(id): sprites[id].queue_free(); sprites.erase(id)
	espera+=delta
	if espera<.12: return
	espera=0.0
	var mudou:=false
	for a in jogo.personagens:
		if a.visita.get("morto",false) or a.visita.get("fora_turno",false): continue
		var anterior: Vector2i=passos.get(a.identificador,a.celula)
		passos[a.identificador]=a.celula
		if anterior==a.celula: continue
		var sangue: bool=jogo.planta.sobre(a.celula).any(func(item): return GorePlex.fresco(item))
		if sangue: a.visita.passos_sangue=5
		elif int(a.visita.get("passos_sangue",0))>0 and jogo.planta.transitavel(a.celula):
			a.visita.passos_sangue=int(a.visita.passos_sangue)-1
			if not jogo.planta.sobre(a.celula,"cenario_trilha_pegadas").is_empty(): continue
			var id: int=jogo.servicos.inventario.criar("cenario_trilha_pegadas",a.celula)
			var vetor:=GradePlex.projetar_local(Vector2(a.celula-anterior))
			var direcao:=posmod(roundi(atan2(vetor.x,vetor.y*2.0)/(PI/4.0)),8)
			jogo.planta.objetos[id].direcao_passos=direcao
			jogo.planta.objetos[id].rotacao=posmod(roundi(float(direcao)/2.0),4)
			mudou=true
	if mudou: jogo.planta.alterada.emit()

