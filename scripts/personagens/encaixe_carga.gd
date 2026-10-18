class_name EncaixeCargaPlex
extends RefCounted

const APOIADOS = ["prato","pizza","fatia_pizza","bandeja","dinheiro"]
static var bordas: Dictionary = {}

static func apoiado(tipo: String) -> bool:
	return tipo in APOIADOS

static func borda(tipo: String, rotacao: int) -> float:
	var chave := tipo+":"+str(rotacao)
	if not bordas.has(chave):
		var inferior := 0.0
		for ponto in GeometriaPlex.obter(tipo,rotacao).pontos: inferior = maxf(inferior,ponto.y)
		bordas[chave] = maxf(.5,inferior-.5)
	return float(bordas[chave])

static func ponto(ator: PersonagemPlex, item: Dictionary, dados: Dictionary, direcao: int, quadro: int, extra: bool = false) -> Vector3:
	var valores: Array = dados.carga_extra[direcao][quadro] if extra else dados.carga[direcao][quadro]
	var origem := Vector3(valores[0],valores[1],valores[2])
	if not apoiado(str(item.get("tipo",""))) or not dados.get("bracos_separados",false) or not dados.has("segmentos"): return origem
	var bracos: Array = dados.segmentos[direcao][quadro]
	var mao := Vector2.ZERO
	if dados.has("carga_extra"):
		var pulso: Array = bracos[1 if extra else 0][2]
		mao = Vector2(pulso[0],pulso[1]+.45)
	else:
		for braco in bracos: mao += Vector2(braco[2][0],braco[2][1]+.45)
		mao /= maxf(1,bracos.size())
	var local := (mao-Vector2(24,55))*ator.animacao.scale
	local.y -= borda(item.tipo,GradePlex.rotacao_visual(int(item.get("rotacao",0))))
	return Vector3(local.x,local.y,origem.z+origem.y-local.y)

static func aplicar(sprite: Sprite2D, material_carga: ShaderMaterial, ator: PersonagemPlex, ponto_apoio: Vector3) -> void:
	var tela := Vector2(ponto_apoio.x,ponto_apoio.y).round()
	sprite.position = tela-Vector2(96,144)
	var profundidade := GradePlex.profundidade(ator.local,ator.altura)+2*ponto_apoio.y+3*ponto_apoio.z+2*(tela.y-ponto_apoio.y)
	material_carga.set_shader_parameter("base",profundidade)
