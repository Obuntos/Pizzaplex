class_name SombraLuminariaPlex
extends Node2D

var ator: PersonagemPlex
var iluminacao: IluminacaoPlex
var planos: Array[Sprite2D] = []
var chave: String = ""
var textura: ImageTexture

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

func atualizar() -> void:
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
	for i in iluminacao.quantidade:
		var p: Vector4 = iluminacao.posicoes[i]
		if p.z <= origem.z + 25.0 or iluminacao.direcoes[i].z > 0.2:
			continue
		var atual := iluminacao.energia_recebida(i, Vector3(ponto.x, ponto.y * 2.0, origem.z + 20.0))
		if atual > nota:
			nota = atual
			melhor = i
	visible = melhor >= 0 and nota > 0.015
	if not visible:
		return
	position = ponto
	var p: Vector4 = iluminacao.posicoes[melhor]
	var vetor := Vector2(ponto.x - p.x, ponto.y * 2.0 - p.y) / maxf(90.0, p.z - origem.z)
	vetor = vetor.limit_length(1.25)
	var d: Dictionary = ator.animacao.definicao
	var extra := 20 if bool(d.layered) else 0
	var pivo := Vector2(d.pivot[0],d.pivot[1]+extra)
	var fontes: Array = []
	for f in ator.pintura.fontes:
		var camada: Sprite2D = f.sprite
		if camada in [ator.manuseio.objeto,ator.carga]: continue
		var fonte: Texture2D = camada.texture
		var regiao := Rect2(Vector2.ZERO,fonte.get_size())
		if fonte is AtlasTexture:
			regiao = fonte.region
			fonte = fonte.atlas
		var relativo := ator.global_transform.affine_inverse()*camada.global_transform
		var posicao := (relativo.origin+Vector2(0,origem.z))/ator.animacao.scale+pivo
		fontes.append({"textura":fonte,"regiao":regiao,"posicao":posicao})
	var quadro := str(fontes)
	if quadro != chave and not fontes.is_empty():
		chave = quadro
		var imagem := Image.create_empty(int(d.width),int(d.height)+extra,false,Image.FORMAT_RGBA8)
		for fonte in fontes:
			var textura_fonte: Texture2D = fonte.textura
			if textura_fonte is CanvasTexture: textura_fonte = textura_fonte.diffuse_texture
			imagem.blend_rect(textura_fonte.get_image(),Rect2i(fonte.regiao),Vector2i(fonte.posicao.round()))
		if textura == null or Vector2i(textura.get_size()) != imagem.get_size(): textura = ImageTexture.create_from_image(imagem)
		else: textura.update(imagem)

	for sprite in planos:
		sprite.texture = textura
		sprite.scale = ator.animacao.scale
		sprite.position = -pivo * sprite.scale - Vector2(0, origem.z)
		var mat := sprite.material as ShaderMaterial
		mat.set_shader_parameter("apoio", Vector3(ponto.x, ponto.y * 2.0, origem.z))
		mat.set_shader_parameter("direcao", vetor)
		mat.set_shader_parameter("altura_luz", p.z)
		mat.set_shader_parameter("indice_luz", melhor)
		mat.set_shader_parameter("opacidade", 0.22)
