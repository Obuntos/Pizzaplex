class_name PontosUsoPlex
extends RefCounted

static var definicoes: Dictionary = {}

static func carregar() -> void:
	if definicoes.is_empty(): definicoes = JSON.parse_string(FileAccess.get_file_as_string("res://dados/pontos_uso.json"))

static func frente(objeto: Dictionary, distancia: int = 1) -> Vector2i:
	var tamanho:=CatalogoPlex.dimensoes(objeto.tipo,0)
	var centro0:=Vector2(tamanho-Vector2i.ONE)*.5
	var centro:=Vector2(CatalogoPlex.dimensoes(objeto.tipo,objeto.rotacao)-Vector2i.ONE)*.5
	var coordenada:=Vector2(floorf(centro0.x),tamanho.y-1+maxi(1,distancia))
	return objeto.celula+Vector2i((centro+GradePlex.girar(coordenada-centro0,objeto.rotacao)).round())

static func interacao(objeto: Dictionary, referencia: Dictionary) -> Vector2i:
	if objeto.tipo in ["geladeira","forno","bancada_preparo","pia","estante","estante_compacta","balcao","bancada","armario_limpeza","armario_ferramentas","armario_utensilios","armario_funcionarios"]: return frente(objeto)
	var centro0:=Vector2(CatalogoPlex.dimensoes(objeto.tipo,0)-Vector2i.ONE)*.5
	var centro:=Vector2(CatalogoPlex.dimensoes(objeto.tipo,objeto.rotacao)-Vector2i.ONE)*.5
	var coordenada: Vector2=(centro0+Vector2(referencia.u,referencia.v)).round()-centro0
	return objeto.celula+Vector2i((centro+GradePlex.girar(coordenada,objeto.rotacao)).round())

static func tem(tipo: String) -> bool:
	carregar()
	return definicoes.has(tipo)

static func ponto(objeto: Dictionary, nome: String) -> Vector3:
	carregar()
	var dimensao := CatalogoPlex.dimensoes(objeto.tipo, objeto.rotacao)
	var centro := Vector2(objeto.celula) + Vector2(dimensao - Vector2i.ONE) * .5
	var vetor_frente := Vector2(GradePlex.frente(objeto.rotacao))
	var lado := Vector2(vetor_frente.y, -vetor_frente.x)
	var dados: Array = definicoes.get(objeto.tipo, {}).get(nome, [0, 1, 0])
	var local := centro + lado * float(dados[0]) + vetor_frente * float(dados[1])
	return Vector3(local.x, local.y, float(dados[2]))

static func parada(objeto: Dictionary) -> Vector2:
	var p := ponto(objeto, "parada")
	return Vector2(p.x, p.y)

static func terminal(planta: PlantaPlex, objeto: Dictionary) -> Vector2i:
	var posicao:=ApoiosPlex.posicao(planta,objeto)
	var centro:=Vector2i(roundi(posicao.x),roundi(posicao.y))
	var vetor_frente:=GradePlex.frente(objeto.rotacao)
	var pai: Dictionary=planta.objetos.get(ApoiosPlex.raiz(planta,objeto.id),{})
	var ocupadas: Array[Vector2i]=planta.celulas(pai.tipo,pai.celula,pai.rotacao) if not pai.is_empty() else []
	for distancia in range(1,5):
		var local:=centro+vetor_frente*distancia
		if not ocupadas.has(local): return local
	return centro+vetor_frente

static func acessos_cadeira(planta: PlantaPlex, objeto: Dictionary) -> Array[Vector2i]:
	if not PassagemCadeirasPlex.mesa(planta,objeto).is_empty():return PassagemCadeirasPlex.entradas(planta,objeto)
	var resultado: Array[Vector2i]=[]
	var vetor_frente:=GradePlex.frente(objeto.rotacao)
	var posto: Vector2i=objeto.celula+vetor_frente
	if planta.transitavel(posto) and is_zero_approx(planta.altura(posto)): return [posto]
	var mesa:=planta.em(posto)
	var escritorio:=MobiliaPlex.visual(objeto).begins_with("oficina_cadeira_escritorio_")
	if not escritorio:
		if not LugaresPlex.mesa(str(mesa.get("tipo",""))): return resultado
		if not LugaresPlex.posicoes(mesa).any(func(p): return p.celula==objeto.celula and p.frente==vetor_frente): return resultado
	var lado:=Vector2i(vetor_frente.y,-vetor_frente.x)
	for d in [lado,-lado,-vetor_frente]:
		var local: Vector2i=objeto.celula+d
		if planta.transitavel(local) and is_zero_approx(planta.altura(local)): resultado.append(local)
	return resultado

static func caixa(objeto: Dictionary) -> Vector3:
	return ponto(objeto, "caixa")

static func alvos(objeto: Dictionary) -> Array[Vector2i]:
	carregar()
	var resultado: Array[Vector2i] = []
	var dados: Array = definicoes.get(objeto.tipo, {}).get("acessos", [])
	if dados.is_empty(): return [Vector2i(parada(objeto).round())]
	var centro := Vector2(objeto.celula) + Vector2(CatalogoPlex.dimensoes(objeto.tipo,objeto.rotacao)-Vector2i.ONE)*.5
	var vetor_frente := Vector2(GradePlex.frente(objeto.rotacao))
	var lado := Vector2(vetor_frente.y,-vetor_frente.x)
	for local in dados: resultado.append(Vector2i((centro+lado*float(local[0])+vetor_frente*float(local[1])).round()))
	return resultado


