class_name EncaixeCargaPlex
extends RefCounted

const APOIADOS = ["prato","pizza","fatia_pizza","bandeja","dinheiro","guarana_copo","guarana_tampa"]
static var volumes_carga: Dictionary={}
static var bordas: Dictionary = {}
static var pontos_agarre: Dictionary = {}
static var apoios: Dictionary = {}

static func apoio(tipo: String, rotacao: int) -> Vector3:
	var chave:=tipo+":"+str(rotacao)
	if apoios.has(chave): return apoios[chave]
	var pontos: PackedVector3Array=GeometriaPlex.obter(tipo,rotacao).pontos
	if pontos.is_empty(): return Vector3.ZERO
	var inferior: float=pontos[0].y
	var minimo: float=pontos[0].x
	var maximo:=minimo
	for p in pontos:
		inferior=maxf(inferior,p.y)
		minimo=minf(minimo,p.x)
		maximo=maxf(maximo,p.x)
	var alvo:=Vector2((minimo+maximo)*.5,inferior)
	var melhor:=Vector3.ZERO
	var distancia:=INF
	for p in pontos:
		var d:=Vector2(p.x,p.y).distance_squared_to(alvo)
		if d<distancia:
			distancia=d
			melhor=Vector3(p.x,p.y,(p.z-2*p.y)/3.0)
	apoios[chave]=melhor
	return melhor

static func agarre(tipo: String, rotacao: int, estado: String = "") -> Vector3:
	if tipo=="saco_lixo": return Vector3(0,-27,22.68)
	var chave := str([tipo,rotacao,estado])
	if pontos_agarre.has(chave): return pontos_agarre[chave]
	var pontos: PackedVector3Array = GeometriaPlex.obter(tipo,rotacao,4,0,false,estado).pontos
	var limites := Rect2(Vector2(pontos[0].x,pontos[0].y),Vector2.ZERO)
	for p in pontos: limites=limites.expand(Vector2(p.x,p.y))
	var categoria := ItensPlex.categoria(tipo)
	var fracao := .42 if categoria == "vassoura" else .08 if categoria == "balde" else .5
	var alvo := Vector2(limites.get_center().x,limites.position.y+limites.size.y*fracao)
	var melhor := Vector3.ZERO
	var distancia := INF
	for p in pontos:
		var d := Vector2(p.x,p.y).distance_squared_to(alvo)
		if d < distancia:
			distancia=d
			melhor=Vector3(p.x,p.y,(p.z-2*p.y)/3.0)
	pontos_agarre[chave]=melhor
	return melhor

static func apoiado(tipo: String) -> bool:
	return tipo in APOIADOS

static func borda(tipo: String, rotacao: int) -> float:
	var chave := tipo+":"+str(rotacao)
	if not bordas.has(chave):
		var inferior := 0.0
		for ponto_local in GeometriaPlex.obter(tipo,rotacao).pontos: inferior = maxf(inferior,ponto_local.y)
		bordas[chave] = maxf(.5,inferior-.5)
	return float(bordas[chave])

static func ponto(ator: PersonagemPlex, item: Dictionary, dados: Dictionary, direcao: int, quadro: int, extra: bool = false) -> Vector3:
	var valores: Array = dados.carga_extra[direcao][quadro] if extra else dados.carga[direcao][quadro]
	var origem := Vector3(valores[0],valores[1],valores[2])
	if not apoiado(str(item.get("tipo",""))) or not dados.get("bracos_separados",false) or not dados.has("segmentos"): return origem
	var bracos: Array = dados.segmentos[direcao][quadro]
	var mao := Vector3.ZERO
	if dados.has("carga_extra"):
		var pulso: Array = bracos[1 if extra else 0][2]
		mao=Vector3((float(pulso[0])-24)*ator.animacao.scale.x,(float(pulso[1])+.45-55)*ator.animacao.scale.y,(float(pulso[2])-2*(float(pulso[1])-55))/3.0*ator.animacao.scale.y)
	else:
		for braco in bracos:
			var pulso: Array=braco[2]
			mao+=Vector3((float(pulso[0])-24)*ator.animacao.scale.x,(float(pulso[1])+.45-55)*ator.animacao.scale.y,(float(pulso[2])-2*(float(pulso[1])-55))/3.0*ator.animacao.scale.y)
		mao /= maxf(1,bracos.size())
	return mao-apoio(item.tipo,GradePlex.rotacao_visual(int(item.get("rotacao",0))))

static func aplicar(sprite: Sprite2D, material_carga: ShaderMaterial, ator: PersonagemPlex, ponto_apoio: Vector3) -> void:
	var tela := Vector2(ponto_apoio.x,ponto_apoio.y).round()
	sprite.position = tela-Vector2(96,144)
	var profundidade := GradePlex.profundidade(ator.local,ator.altura)+2*ponto_apoio.y+3*ponto_apoio.z+2*(tela.y-ponto_apoio.y)
	material_carga.set_shader_parameter("base",profundidade)



static func fator_carga(tipo: String) -> float:
	return .72 if CaixasVisuaisPlex.eh(tipo) or tipo=="saco_lixo" else 1.0

static func volume_carga(tipo: String, rotacao: int, estado: String="") -> Dictionary:
	var chave:=str([tipo,rotacao,estado])
	if volumes_carga.has(chave): return volumes_carga[chave]
	var original:=GeometriaPlex.obter(tipo,rotacao,4,0,false,estado)
	var fator:=fator_carga(tipo)
	if is_equal_approx(fator,1.0): return original
	var volume:=original.duplicate()
	var pontos: PackedVector3Array=original.pontos.duplicate()
	for i in pontos.size():
		var v:=pontos[i]
		var y:=roundf(v.y*fator)
		pontos[i]=Vector3(roundf(v.x*fator),y,y*2+(v.z-2*v.y)*fator)
	volume.pontos=pontos
	volume.image=str(original.image)+":carga"
	volumes_carga[chave]=volume
	return volume

static func encaixe(tipo: String, rotacao: int, estado: String="") -> Vector3:
	if CaixasVisuaisPlex.eh(tipo):
		var altura:=ItensPlex.altura(tipo)*.65
		return Vector3(0,-altura,altura)*fator_carga(tipo)
	return (apoio(tipo,rotacao) if apoiado(tipo) else agarre(tipo,rotacao,estado))*fator_carga(tipo)
