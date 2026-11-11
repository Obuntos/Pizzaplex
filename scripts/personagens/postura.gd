class_name PosturaPlex
extends Node2D

var pernas := Sprite2D.new()
var atlas := CatalogoPlex.atlas_vazio()

func _init() -> void:
	pernas.centered = false
	pernas.texture = atlas
	pernas.use_parent_material = true
	pernas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	use_parent_material = true
	add_child(pernas)
	hide()

func atualizar(ator: PersonagemPlex) -> void:
	visible = ator.assento >= 0 and ator.trabalho == "usar_vaso" and ator.animacao.definicao.layered
	if not visible: return
	var corpo: AtlasTexture = ator.animacao.atlases.corpo
	var regiao := corpo.region
	atlas.atlas = corpo.atlas
	var margem := Vector2(16,12) if ator.poses_humanas.ativa and not ator.poses_humanas.nativa else Vector2.ZERO
	atlas.region = Rect2(regiao.position + margem + Vector2(0, 40), Vector2(48, 17))
	corpo.region = Rect2(regiao.position, Vector2(regiao.size.x, 40+margem.y))
	var angulo := GradePlex.direcao_visual(ator.direcao) * PI / 4.0
	pernas.position = (Vector2(-24, -15) + Vector2(sin(angulo) * 2.0, cos(angulo))) * ator.animacao.scale
	pernas.scale = ator.animacao.scale * Vector2(1.0, 0.55)

static func sentada(ator: PersonagemPlex) -> bool:
	return ator.assento >= 0 and ator.trabalho in ["sentar_mesa","sentar_banco","descansar","vigiar_ibm","aguardar_vestiario","caixa_sentado"] and not ator.ocupado()

static func ossos(ator: PersonagemPlex) -> PackedVector4Array:
	var resultado := PackedVector4Array()
	var origem := ator.ponto_visual()
	var angulo := ator.direcao * PI / 4.0
	var escala := ator.animacao.scale
	var jovem:=.86 if ator.modelo.begins_with("adolescente") else 1.0
	var abertura := 2.2 if ator.modelo == "crianca" else 2.45*(.9 if jovem<1.0 else 1.0)
	var quadril := 10.0 if ator.modelo == "crianca" else 15.0*jovem
	for lado in [-1,1]:
		for p in [Vector3(lado*abertura,0,quadril),Vector3(lado*abertura,6.5*jovem,quadril-.8*jovem),Vector3(lado*abertura,7*jovem,.4*jovem)]:
			var x: float = (cos(angulo)*p.x+sin(angulo)*p.y)*escala.x
			var y: float = (-sin(angulo)*p.x+cos(angulo)*p.y)*.5*escala.y
			var local := Vector2(origem.x,origem.y)+GradePlex.inverter_local(Vector2(x,y))
			var z: float = origem.z+(p.z+(1.0 if ator.modelo == "crianca" else 0.0))*escala.y
			var tela := GradePlex.projetar(local,z)
			resultado.append(Vector4(tela.x,tela.y,GradePlex.profundidade(local,z),0.0))
	return resultado

