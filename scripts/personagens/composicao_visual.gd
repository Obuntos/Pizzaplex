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
		adicionar(camadas.olhos,11)
		adicionar(camadas.boca,12)
	else: adicionar(camadas.modelo,0)
	var lado := GradePlex.direcao_visual(ator.direcao)
	var costas := lado in [3,4,5]
	adicionar(ator.personalizacao.camadas.tras,13 if costas else -2)
	adicionar(ator.personalizacao.camadas.frente,14)
	adicionar(ator.personalizacao.camadas.chapeu,15)
	adicionar(ator.manuseio.pernas,-1 if ator.manuseio.integrado else 0)
	var ordem_carga := (6 if ator.manuseio.carga_apoiada else 4) if ator.manuseio.carga_na_frente else -1
	adicionar(ator.manuseio.objeto,ordem_carga)
	adicionar(ator.manuseio.objeto_extra,ordem_carga)
	var separados: bool = ManuseioPlex.definicoes.get(ator.modelo,{}).get(ator.manuseio.movimento,{}).get("bracos_separados",false)
	adicionar(ator.manuseio.maos,5 if separados or ator.manuseio.carga_na_frente else -1)
	adicionar(ator.carga,-1 if costas else 4)
	adicionar(ator.postura.pernas,1)
	fontes.sort_custom(func(a,b): return a.ordem<b.ordem if a.ordem!=b.ordem else a.indice<b.indice)
	var presentes: Dictionary = {}
	for f in fontes:
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
		copia.transform = global_transform.affine_inverse()*origem.global_transform
		copia.material = origem.material
		copia.use_parent_material = origem.material==null
		copia.modulate = origem.modulate
		copia.self_modulate = origem.self_modulate
		if copia.get_index()!=fontes.find(f): move_child(copia,fontes.find(f))
	for id in sprites.keys():
		if not presentes.has(id):
			sprites[id].queue_free()
			sprites.erase(id)
