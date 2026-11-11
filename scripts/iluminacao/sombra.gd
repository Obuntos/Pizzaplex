class_name SombraLuminariaPlex
extends Node2D

var ator: PersonagemPlex
var iluminacao: IluminacaoPlex
var planos: Array[MeshInstance2D] = []
static var malhas:Dictionary={}
var chave: String = ""
var textura: Texture2D
var espera := 1.0
var melhor_luz := -1
var energia := 0.0
var revisao_luz := -1

func configurar(personagem: PersonagemPlex, luzes: IluminacaoPlex, composicao: CenaPlex) -> void:
	ator = personagem
	iluminacao = luzes
	for altura in [0.0, 6.0, 12.0, 18.0, 29.0, 31.0]:
		var sprite := MeshInstance2D.new()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/sombra_luminaria.gdshader")
		mat.set_shader_parameter("profundidade", composicao.profundidade)
		mat.set_shader_parameter("superficies", composicao.superficies)
		mat.set_shader_parameter("origem", Vector2(composicao.ORIGEM))
		mat.set_shader_parameter("tamanho", Vector2(composicao.TAMANHO))
		mat.set_shader_parameter("altura_destino", altura)
		iluminacao.vincular(mat)
		sprite.material = mat
		planos.append(sprite)
		add_child(sprite)

func atualizar(delta: float = .1) -> void:
	if not is_instance_valid(ator):
		queue_free()
		return
	var melhor: int = -1
	var nota: float = 0.0
	if not ator.get_meta("visivel_cena",true) or ator.visita.get("morto",false) or ator.visita.get("fora_turno",false) or ator.trabalho == "usar_vaso":
		hide()
		return
	var origem := ator.ponto_visual()
	var ponto := GradePlex.projetar(Vector2(origem.x,origem.y))
	espera += delta
	if espera>=.18 or revisao_luz!=iluminacao.revisao:
		espera = 0.0
		revisao_luz = iluminacao.revisao
		for i in candidatas(iluminacao,Vector3(ponto.x,ponto.y*2.0,origem.z+20.0)):
			var p_local: Vector4 = iluminacao.posicoes[i]
			if p_local.z <= origem.z + 25.0 or iluminacao.direcoes[i].z > 0.2:
				continue
			var atual := iluminacao.energia_recebida(i, Vector3(ponto.x, ponto.y * 2.0, origem.z + 20.0))
			if atual > nota:
				nota = atual
				melhor = i
		var solar := iluminacao.sol_recebido(Vector3(ponto.x,ponto.y*2.0,origem.z+20.0))
		if solar>nota:
			nota=solar
			melhor=-2
		melhor_luz = melhor
		energia = nota
	else:
		melhor = melhor_luz
		nota = energia
	visible = melhor != -1 and nota > 0.015
	if not visible:
		return
	position = ponto
	var p: Vector4 = iluminacao.posicao_sol(Vector3(ponto.x,ponto.y*2.0,origem.z)) if melhor==-2 else iluminacao.posicoes[melhor]
	var vetor := Vector2(ponto.x - p.x, ponto.y * 2.0 - p.y) / maxf(12.0, p.z - origem.z)
	vetor = vetor.limit_length(6.0)
	var d: Dictionary = ator.animacao.definicao
	if d.is_empty():
		hide()
		return
	var extra := 20 if bool(d.get("layered",false)) else 0
	var pivo := Vector2(d.pivot[0],d.pivot[1]+extra)
	var fontes: Array = []
	for f in ator.pintura.fontes:
		var camada: Sprite2D = f.sprite
		if not is_instance_valid(camada) or not camada.is_visible_in_tree() or not SilhuetasPlex.valida(camada.texture): continue
		if camada in [ator.manuseio.objeto,ator.manuseio.objeto_extra,ator.carga,ator.poses_humanas.item]: continue
		if camada.get_parent() not in [ator.visual,ator.animacao,ator.manuseio,ator.postura,ator.poses_humanas]: continue
		var fonte: Texture2D = camada.texture
		var regiao := Rect2(Vector2.ZERO,fonte.get_size())
		if fonte is AtlasTexture:
			regiao = fonte.region
			fonte = fonte.atlas
		var relativo := ator.global_transform.affine_inverse()*camada.global_transform
		var posicao := (relativo.origin+Vector2(0,origem.z))/ator.animacao.scale+pivo
		fontes.append({"textura":fonte,"regiao":regiao,"posicao":posicao})
	if fontes.is_empty():
		textura=null
		hide()
		return
	if textura==null or espera<.001: textura = SilhuetasPlex.obter(fontes,Vector2i(int(d.width),int(d.height)+extra))
	if textura==null:
		hide()
		return

	for sprite in planos:
		sprite.texture = textura
		sprite.mesh = malha(Vector2i(textura.get_size()))
		sprite.scale = ator.animacao.scale
		sprite.position = -pivo * sprite.scale - Vector2(0, origem.z)
		var mat := sprite.material as ShaderMaterial
		mat.set_shader_parameter("apoio", Vector3(ponto.x, ponto.y * 2.0, origem.z))
		mat.set_shader_parameter("direcao", vetor)
		mat.set_shader_parameter("altura_luz", p.z)
		mat.set_shader_parameter("posicao_luz",Vector3(p.x,p.y,p.z))
		mat.set_shader_parameter("indice_luz", melhor)
		mat.set_shader_parameter("sombra_solar",melhor==-2)
		mat.set_shader_parameter("opacidade", 0.42)
		mat.set_shader_parameter("peso_sombra",clampf(energia/(energia+iluminacao.ambiente_diurno*.45+.04),.15,1.0))



static func malha(tamanho:Vector2i) -> ArrayMesh:
	if malhas.has(tamanho):return malhas[tamanho]
	var pontos:=PackedVector3Array();var uvs:=PackedVector2Array();var indices:=PackedInt32Array()
	for y in 25:
		for x in 3:
			var uv:=Vector2(x/2.0,y/24.0);uvs.append(uv);pontos.append(Vector3(uv.x*tamanho.x,uv.y*tamanho.y,0))
	for y in 24:
		for x in 2:
			var i:=y*3+x;indices.append_array(PackedInt32Array([i,i+1,i+3,i+1,i+4,i+3]))
	var dados:=[];dados.resize(Mesh.ARRAY_MAX);dados[Mesh.ARRAY_VERTEX]=pontos;dados[Mesh.ARRAY_TEX_UV]=uvs;dados[Mesh.ARRAY_INDEX]=indices
	var resultado:=ArrayMesh.new();resultado.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,dados);malhas[tamanho]=resultado;return resultado

static func candidatas(luz:IluminacaoPlex,origem:Vector3) -> Array[int]:
	var lista:Array[int]=[]
	for i in luz.quantidade:
		if luz.posicoes[i].z>origem.z+5 and luz.direcoes[i].z<=.2:lista.append(i)
	lista.sort_custom(func(a,b):return Vector3(luz.posicoes[a].x,luz.posicoes[a].y,luz.posicoes[a].z).distance_squared_to(origem)<Vector3(luz.posicoes[b].x,luz.posicoes[b].y,luz.posicoes[b].z).distance_squared_to(origem))
	var resultado:Array[int]=[]
	resultado.assign(lista.slice(0,3));return resultado
