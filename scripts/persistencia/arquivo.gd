class_name ArquivoPlex
extends RefCounted

const CAMINHO = "user://pizzaplex.json"

static func salvar(planta: PlantaPlex, personagens: Array, servicos: Dictionary = {}, clientes: Dictionary = {}, compras: Dictionary = {}, campanha: Dictionary = {}) -> void:
	var objetos: Array = []
	for item in planta.objetos.values():
		var objeto: Dictionary = item.duplicate(true)
		objeto.celula = [item.celula.x, item.celula.y]
		objeto.reserva = 0
		objetos.append(objeto)
	var cores: Array = []
	for local in planta.cores:
		cores.append([local.x, local.y, planta.cores[local]])
	var pisos: Array = []
	for c in planta.pisos: pisos.append([c.x,c.y,planta.pisos[c]])
	var atores: Array = []
	for ator in personagens:
		atores.append({"id": ator.identificador, "relogio":ator.relogio, "identidade":ator.identidade, "modelo": ator.modelo, "robo": ator.robo, "celula": [ator.celula.x, ator.celula.y], "direcao": ator.direcao, "automatico": ator.automatico, "carregando": ator.carregando, "suporte": ator.suporte, "pose": ator.pose, "pecas": ator.pecas, "expressao": ator.animacao.expressao, "apresentando": ator.trabalho == "apresentar", "carga_item": ator.carga_item, "carga_extra":ator.carga_extra, "energia": ator.energia, "necessidades": ator.necessidades, "cargo": ator.cargo, "funcao":ator.funcao, "funcoes_secundarias":ator.funcoes_secundarias, "caixa_tipo":ator.caixa_tipo, "caixa_qualidade":ator.caixa_qualidade, "caixa_durabilidade":ator.caixa_durabilidade, "cabelo":ator.cabelo,"uniforme":ator.uniforme,"familia": ator.familia, "responsavel": ator.responsavel, "visita": ator.visita,"robotica":ator.robotica})
	var salas: Array = []
	for c in planta.funcoes_salas: salas.append([c.x, c.y, planta.funcoes_salas[c]])
	var arquivo := FileAccess.open(CAMINHO, FileAccess.WRITE)
	if arquivo != null:
		arquivo.store_string(JSON.stringify({"versao": 2, "objetos": objetos, "cores": cores, "personagens": atores, "salas": salas, "servicos": servicos, "clientes": clientes, "compras":compras,"pisos":pisos,"campanha":campanha}, "\t"))

static func ler() -> Dictionary:
	if not FileAccess.file_exists(CAMINHO):
		return {}
	var conteudo: Variant = JSON.parse_string(FileAccess.get_file_as_string(CAMINHO))
	if not conteudo is Dictionary or int(conteudo.get("versao", 0)) not in [1, 2]:
		return {}
	return normalizar(conteudo)

static func normalizar(valor: Variant) -> Variant:
	if valor is Dictionary:
		for chave in valor: valor[chave] = normalizar(valor[chave])
	elif valor is Array:
		for i in valor.size(): valor[i] = normalizar(valor[i])
	elif valor is float and valor == floor(valor):
		return int(valor)
	return valor

