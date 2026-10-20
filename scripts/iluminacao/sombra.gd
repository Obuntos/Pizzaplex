class_name SombraLuminariaPlex
extends Node2D

var ator: PersonagemPlex
var iluminacao: IluminacaoPlex
var planos: Array[Sprite2D] = []
var chave: String = ""
var textura: Texture2D
var espera := 1.0
var melhor_luz := -1
var energia := 0.0
var revisao_luz := -1

func configurar(personagem: PersonagemPlex, luzes: IluminacaoPlex, composicao: CenaPlex) -> void:
	ator = personagem
	iluminacao = luzes
	for altura in [0.0, 6.0, 12.0, 18.0]:
		var sprite := Sprite2D.new()
		sprite.centered = false
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
	if ator.trabalho == "usar_vaso":
		hide()
		return
	var origem := ator.ponto_visual()
	var ponto := GradePlex.projetar(Vector2(origem.x,origem.y))
	espera += delta
	if espera>=.1 or revisao_luz!=iluminacao.revisao:
		espera = 0.0
		revisao_luz = iluminacao.revisao
		for i in iluminacao.quantidade:
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
	var vetor := Vector2(ponto.x - p.x, ponto.y * 2.0 - p.y) / maxf(90.0, p.z - origem.z)
	vetor = vetor.limit_length(1.25)
	var d: Dictionary = ator.animacao.definicao
	var extra := 20 if bool(d.layered) else 0
	var pivo := Vector2(d.pivot[0],d.pivot[1]+extra)
	var fontes: Array = []
	for f in ator.pintura.fontes:
		var camada: Sprite2D = f.sprite
		if camada in [ator.manuseio.objeto,ator.manuseio.objeto_extra,ator.carga]: continue
		var fonte: Texture2D = camada.texture
		var regiao := Rect2(Vector2.ZERO,fonte.get_size())
		if fonte is AtlasTexture:
			regiao = fonte.region
			fonte = fonte.atlas
		var relativo := ator.global_transform.affine_inverse()*camada.global_transform
		var posicao := (relativo.origin+Vector2(0,origem.z))/ator.animacao.scale+pivo
		fontes.append({"textura":fonte,"regiao":regiao,"posicao":posicao})
	if not fontes.is_empty(): textura = SilhuetasPlex.obter(fontes,Vector2i(int(d.width),int(d.height)+extra))

	for sprite in planos:
		sprite.texture = textura
		sprite.scale = ator.animacao.scale
		sprite.position = -pivo * sprite.scale - Vector2(0, origem.z)
		var mat := sprite.material as ShaderMaterial
		mat.set_shader_parameter("apoio", Vector3(ponto.x, ponto.y * 2.0, origem.z))
		mat.set_shader_parameter("direcao", vetor)
		mat.set_shader_parameter("altura_luz", p.z)
		mat.set_shader_parameter("indice_luz", melhor)
		mat.set_shader_parameter("sombra_solar",melhor==-2)
		mat.set_shader_parameter("opacidade", 0.22)

