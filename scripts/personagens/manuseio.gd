class_name ManuseioPlex
extends Node2D

static var definicoes: Dictionary = {}
var objeto := Sprite2D.new()
var maos := Sprite2D.new()
var objeto_extra := Sprite2D.new()
var uniforme_extra := ShaderMaterial.new()
var assinatura_extra := ""
var pernas := Sprite2D.new()
var atlas_maos := AtlasTexture.new()
var atlas_pernas := AtlasTexture.new()
var assinatura := ""
var uniforme := ShaderMaterial.new()
var movimento := ""
var arquivo_pernas := ""
var carga_na_frente := true
var carga_apoiada := false
var integrado := false

func _init() -> void:
	if definicoes.is_empty(): definicoes = JSON.parse_string(FileAccess.get_file_as_string("res://dados/animacoes_servico.json"))
	for sprite in [pernas,objeto,objeto_extra,maos]:
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
	maos.texture = atlas_maos
	pernas.texture = atlas_pernas
	maos.use_parent_material = true
	pernas.use_parent_material = true
	use_parent_material = true
	uniforme.shader = load("res://shaders/carga.gdshader")
	objeto.material = uniforme
	uniforme_extra.shader = uniforme.shader
	objeto_extra.material = uniforme_extra
	hide()

func configurar(cena: CenaPlex, luz: IluminacaoPlex) -> void:
	uniforme.set_shader_parameter("profundidade_cena",cena.profundidade)
	uniforme.set_shader_parameter("origem",Vector2(cena.ORIGEM))
	uniforme.set_shader_parameter("tamanho",Vector2(cena.TAMANHO))
	luz.vincular(uniforme)
	uniforme_extra.set_shader_parameter("profundidade_cena",cena.profundidade)
	uniforme_extra.set_shader_parameter("origem",Vector2(cena.ORIGEM))
	uniforme_extra.set_shader_parameter("tamanho",Vector2(cena.TAMANHO))
	luz.vincular(uniforme_extra)

func componentes(planta: PlantaPlex, id: int, origem: Vector3, resultado: Array, nivel: int = 0) -> void:
	if nivel>6 or not planta.objetos.has(id): return
	var item: Dictionary = planta.objetos[id]
	resultado.append({"volume":GeometriaPlex.obter(item.tipo,GradePlex.rotacao_visual(item.rotacao),4,0,false,item.get("estado","")),"posicao":ApoiosPlex.posicao(planta,item)-origem})
	for filho in ApoiosPlex.filhos(planta,id): componentes(planta,filho.id,origem,resultado,nivel+1)

func atualizar(ator: PersonagemPlex, planta: PlantaPlex, andando: bool) -> void:
	integrado = false
	objeto_extra.hide()
	var material_ator := ator.material as ShaderMaterial
	if material_ator!=null: material_ator.set_shader_parameter("usar_bracos",false)
	var item: Dictionary = planta.objetos.get(ator.carga_item,{})
	if ator.trabalho == "colocar":
		hide()
		return
	var caixa_virtual: bool = ator.carregando and ator.trabalho not in ["montar","colocar"]
	if caixa_virtual: item = {"tipo":ator.caixa_tipo,"id":-1}
	var acao: String = ator.trabalho
	if acao == "higienizar": acao = "lavar"
	elif acao in ["jogar", "usar_armario", "usar_caixa"]: acao = "preparar"
	if not definicoes.has(ator.modelo) or (item.is_empty() and acao not in ["lavar","varrer","esfregar","preparar"]):
		hide()
		return
	show()
	carga_apoiada = EncaixeCargaPlex.apoiado(str(item.get("tipo","")))
	var categoria := ItensPlex.categoria(item.get("tipo","prato"))
	movimento = acao if acao in ["lavar","varrer","esfregar","preparar"] and not andando else ("levar_" if andando else "segurar_")+categoria
	carga_na_frente = direcao_carga(ator,movimento)
	if categoria=="prato" and not ator.carga_extra.is_empty(): movimento = ("levar_" if andando else "segurar_")+"dois_pratos"
	var dados: Dictionary = definicoes[ator.modelo][movimento]
	integrado = dados.get("integrado",false)
	var direcao := GradePlex.direcao_visual(ator.direcao)
	var fase: float = ator.progresso_acao if movimento in ["lavar","varrer","esfregar","preparar"] else ator.fase if andando else 0.0
	if dados.get("relogio",false): fase=ator.relogio/maxf(.01,float(dados.get("duracao",1.0)))
	var quadro := int(floor(fposmod(fase,1.0)*12))
	if dados.has("segmentos") and material_ator!=null:
		var segmentos := PackedVector4Array()
		for braco in dados.segmentos[direcao][quadro]:
			for p in braco:
				var ponto := ator.position+ator.visual.position+(Vector2(p[0],p[1])-Vector2(24,55))*ator.animacao.scale
				segmentos.append(Vector4(ponto.x,ponto.y,GradePlex.profundidade(ator.local,ator.altura)+float(p[2]),0))
		material_ator.set_shader_parameter("bracos",segmentos)
		material_ator.set_shader_parameter("usar_bracos",true)
	var pasta := "res://assets/personagens/"+ator.modelo+"/servico/"+movimento
	var corpo: AtlasTexture = ator.animacao.atlases.corpo
	pernas.visible = ator.em_degraus
	if pernas.visible:
		arquivo_pernas = ator.animacao.arquivos.corpo
		atlas_pernas.atlas = corpo.atlas
		atlas_pernas.region = Rect2(corpo.region.position+Vector2(0,40),Vector2(48,20))
		pernas.position = Vector2(-24,-15)*ator.animacao.scale
		pernas.scale = ator.animacao.scale
	var arquivo_corpo := pasta+"_corpo.png"
	var pernas_completas := false
	if pernas.visible:
		var arquivo := AparenciaPlex.vestir(ator,arquivo_pernas).replace(".png","_pernas.png")
		var superior := AparenciaPlex.vestir(ator,pasta+"_corpo.png").replace("_corpo.png","_superior.png")
		if ResourceLoader.exists(arquivo) and ResourceLoader.exists(superior):
			pernas_completas = true
			arquivo_pernas = arquivo
			atlas_pernas.atlas = CatalogoPlex.textura_iluminada(arquivo)
			atlas_pernas.region = corpo.region
			pernas.position = Vector2(-24,-55)*ator.animacao.scale
			arquivo_corpo = superior
	corpo.atlas = CatalogoPlex.textura_iluminada(arquivo_corpo)
	ator.animacao.arquivos.corpo = arquivo_corpo
	corpo.region = Rect2(quadro*48,direcao*60,48,40 if pernas.visible and not pernas_completas else 60)
	var posicao: Array = dados.offsets[direcao][quadro]
	for nome in ["cabeca","olhos","boca"]: ator.animacao.camadas[nome].position += Vector2(posicao[0],posicao[1])
	maos.visible = not integrado
	if integrado:
		objeto.hide()
		return
	atlas_maos.atlas = CatalogoPlex.textura_iluminada(pasta+"_maos.png")
	atlas_maos.region = Rect2(quadro*48,direcao*60,48,60)
	maos.scale = ator.animacao.scale
	maos.position = Vector2(-24,-55)*ator.animacao.scale
	objeto.visible = not item.is_empty() and not dados.get("prop_integrado",false)
	if objeto.visible:
		var lista: Array = []
		if caixa_virtual: lista.append({"volume":GeometriaPlex.obter(item.tipo,GradePlex.rotacao_visual(0)),"posicao":Vector3.ZERO})
		else: componentes(planta,item.id,ApoiosPlex.posicao(planta,item),lista)
		var chave := str(lista.map(func(c): return [c.volume.image,c.posicao]))+str(item.id)
		if assinatura != chave:
			assinatura = chave
			var imagem := ItensPlex.compor(lista)
			objeto.texture = imagem.textura
			uniforme.set_shader_parameter("profundidade_item",imagem.profundidade)
			uniforme.set_shader_parameter("superficies_item",imagem.normais)
		EncaixeCargaPlex.aplicar(objeto,uniforme,ator,EncaixeCargaPlex.ponto(ator,item,dados,direcao,quadro))
	if not ator.carga_extra.is_empty() and dados.has("carga_extra"):
		var id := ator.carga_extra[0]
		if planta.objetos.has(id):
			objeto_extra.show()
			var lista: Array = []
			componentes(planta,id,ApoiosPlex.posicao(planta,planta.objetos[id]),lista)
			var chave := str(lista.map(func(c): return [c.volume.image,c.posicao]))+str(id)
			if chave!=assinatura_extra:
				assinatura_extra = chave
				var imagem := ItensPlex.compor(lista)
				objeto_extra.texture = imagem.textura
				uniforme_extra.set_shader_parameter("profundidade_item",imagem.profundidade)
				uniforme_extra.set_shader_parameter("superficies_item",imagem.normais)
			EncaixeCargaPlex.aplicar(objeto_extra,uniforme_extra,ator,EncaixeCargaPlex.ponto(ator,planta.objetos[id],dados,direcao,quadro,true))
	ator.visual.move_child(self,0 if direcao in [3,4,5] else ator.visual.get_child_count()-1)

func direcao_carga(ator: PersonagemPlex, acao: String) -> bool:
	if acao.contains("balde") or acao.contains("vassoura") or acao in ["varrer","esfregar"]: return true
	return GradePlex.direcao_visual(ator.direcao) not in [3,4,5]
