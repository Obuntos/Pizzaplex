class_name ComposicaoPersonagemPlex
extends Node2D

var sprites: Dictionary = {}
var fontes: Array[Dictionary] = []

func _init() -> void:
	use_parent_material = true

func adicionar(sprite: Sprite2D, ordem: int) -> void:
	if not is_instance_valid(sprite): return
	if sprite.visibility_layer!=0: sprite.visibility_layer = 0
	if not sprite.is_visible_in_tree() or sprite.texture==null: return
	fontes.append({"sprite":sprite,"ordem":ordem,"indice":fontes.size()})

func atualizar(ator: PersonagemPlex) -> void:
	fontes.clear()
	var camadas: Dictionary = ator.animacao.camadas
	if ator.animacao.definicao.layered:
		adicionar(camadas.corpo,0)
		adicionar(camadas.cabeca,10)
		for i in 2: adicionar(ator.personalizacao.camadas.get("rosto_"+str(i)),10)
		adicionar(camadas.olhos,11)
		adicionar(camadas.boca,12)
	else:
		adicionar(camadas.modelo,0)
		adicionar(camadas.get("cabelo_profissional"),12)
	var lado := GradePlex.direcao_visual(ator.direcao)
	var costas := lado in [3,4,5]
	adicionar(ator.personalizacao.camadas.tras,13 if costas else -2)
	adicionar(ator.personalizacao.camadas.frente,14)
	adicionar(ator.personalizacao.camadas.chapeu,15)
	adicionar(ator.manuseio.pernas,-1 if ator.manuseio.integrado else 0)
	if ator.poses_humanas.ativa:
		adicionar(ator.poses_humanas.pernas,1)
		adicionar(ator.poses_humanas.frente,ator.poses_humanas.ordem_frente)
		adicionar(ator.poses_humanas.maos,ator.poses_humanas.ordem_maos)
		adicionar(ator.poses_humanas.item,4)
	var ordem_carga := (6 if ator.manuseio.carga_apoiada else 4) if ator.manuseio.carga_na_frente else -1
	adicionar(ator.manuseio.objeto,int(ator.manuseio.objeto.get_meta("ordem_fantasia",ordem_carga)) if ator.modelo=="fantasia_coelho" else ordem_carga)
	adicionar(ator.manuseio.objeto_extra,int(ator.manuseio.objeto_extra.get_meta("ordem_fantasia",ordem_carga)) if ator.modelo=="fantasia_coelho" else ordem_carga)
	var separados: bool = ManuseioPlex.definicoes.get(ator.modelo,{}).get(ator.manuseio.movimento,{}).get("bracos_separados",false)
	adicionar(ator.manuseio.maos,7 if ator.modelo=="fantasia_coelho" else 5 if separados or ator.manuseio.carga_na_frente else -1)
	adicionar(ator.carga,-1 if costas else 4)
	adicionar(ator.postura.pernas,1)
	adicionar(ator.postura_manual.tras,-1)
	adicionar(ator.postura_manual.frente,3)
	adicionar(ator.postura_manual.dedos,-1 if costas else 5)
	var arma: Sprite2D=(ator.get_meta("arma_visual") if ator.has_meta("arma_visual") else null)
	if ator.visita.get("faca_equipada",false): adicionar(arma,-1 if ator.postura_manual.arma_atras else 4)
	var corpo: Sprite2D=(ator.get_meta("corpo_visual") if ator.has_meta("corpo_visual") else null)
	var corpo_tras: Sprite2D=(ator.get_meta("corpo_visual_tras") if ator.has_meta("corpo_visual_tras") else null)
	if int(ator.visita.get("corpo_carregado",-1))>0:
		adicionar(corpo_tras,-1)
		adicionar(corpo,4 if is_instance_valid(corpo_tras) else -1 if costas else 4)
	fontes.sort_custom(func(a,b): return a.ordem<b.ordem if a.ordem!=b.ordem else a.indice<b.indice)
	var presentes: Dictionary = {}
	var inversa:=global_transform.affine_inverse()
	for indice in fontes.size():
		var f: Dictionary=fontes[indice]
		var origem: Sprite2D = f.sprite
		var id := origem.get_instance_id()
		presentes[id] = true
		if not sprites.has(id):
			var s := Sprite2D.new()
			s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			add_child(s)
			sprites[id] = s
		var copia: Sprite2D = sprites[id]
		copia.texture = origem.texture
		copia.centered = origem.centered
		copia.offset = origem.offset
		copia.flip_h = origem.flip_h
		copia.flip_v = origem.flip_v
		copia.transform = inversa*origem.global_transform
		copia.material = origem.material
		copia.use_parent_material = origem.material==null
		copia.modulate = origem.modulate
		copia.self_modulate = origem.self_modulate
		if copia.get_index()!=indice: move_child(copia,indice)
	for id in sprites.keys():
		if not presentes.has(id):
			sprites[id].queue_free()
			sprites.erase(id)


