class_name ArquivoPlex
extends RefCounted

const CAMINHO = "user://pizzaplex.json"
const PASTA = "user://saves"
static var ultimo_caminho := ""

static func salvar(planta: PlantaPlex, personagens: Array, servicos: Dictionary = {}, clientes: Dictionary = {}, compras: Dictionary = {}, campanha: Dictionary = {}) -> bool:
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
	if DirAccess.make_dir_recursive_absolute(PASTA)!=OK: return false
	var instante := Time.get_datetime_string_from_system().replace(":","-").replace("T","_")
	var caminho := PASTA+"/"+instante+"_"+str(Time.get_ticks_usec())+".json"
	var dados := {"versao":2,"objetos":objetos,"cores":cores,"personagens":atores,"salas":salas,"servicos":servicos,"clientes":clientes,"compras":compras,"pisos":pisos,"campanha":campanha,"salvo_em":Time.get_datetime_string_from_system(),"salvo_unix":Time.get_unix_time_from_system()}
	var temporario := caminho+".tmp"
	var arquivo := FileAccess.open(temporario,FileAccess.WRITE)
	if arquivo==null: return false
	arquivo.store_string(JSON.stringify(dados))
	arquivo.flush()
	var erro := arquivo.get_error()
	arquivo.close()
	if erro!=OK or DirAccess.rename_absolute(temporario,caminho)!=OK: return false
	ultimo_caminho=caminho
	return true

static func conteudo(caminho: String) -> Dictionary:
	if not FileAccess.file_exists(caminho): return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(caminho))!=OK or not json.data is Dictionary: return {}
	return json.data

static func dicionario(valor: Variant) -> Dictionary:
	return valor if valor is Dictionary else {}

static func valido(dados: Dictionary) -> bool:
	if int(dados.get("versao",0)) not in [1,2] or not dados.get("objetos") is Array or not dados.get("personagens") is Array or not dados.get("cores") is Array: return false
	for item in dados.objetos:
		if not item is Dictionary or not item.get("celula") is Array or item.celula.size()!=2: return false
		for chave in ["id","tipo","rotacao"]:
			if not item.has(chave): return false
	for ator in dados.personagens:
		if not ator is Dictionary or not ator.get("celula") is Array or ator.celula.size()!=2: return false
		for chave in ["id","modelo","direcao","carregando","suporte","pecas","expressao"]:
			if not ator.has(chave): return false
	for cor in dados.cores:
		if not cor is Array or cor.size()!=3: return false
	return true

static func ler(caminho: String = CAMINHO) -> Dictionary:
	var dados := conteudo(caminho)
	return normalizar(dados) if valido(dados) else {}

static func listar() -> Array[Dictionary]:
	var caminhos: Array[String] = []
	if FileAccess.file_exists(CAMINHO): caminhos.append(CAMINHO)
	var pasta := DirAccess.open(PASTA)
	if pasta!=null:
		for nome in pasta.get_files():
			if nome.ends_with(".json"): caminhos.append(PASTA+"/"+nome)
	var resultado: Array[Dictionary] = []
	for caminho in caminhos:
		var dados := conteudo(caminho)
		var compativel := valido(dados)
		var campanha_salva := dicionario(dados.get("campanha",{}))
		var operacao := dicionario(campanha_salva.get("operacao",{}))
		var calendario := dicionario(campanha_salva.get("calendario",{}))
		var saldo: int=int(dicionario(dados.get("servicos",{})).get("saldo",0))
		var alterado := FileAccess.get_modified_time(caminho)
		resultado.append({"caminho":caminho,"nome":str(operacao.get("nome","Partida anterior" if caminho==CAMINHO else "Pizzaplex")),"data":str(dados.get("salvo_em",Time.get_datetime_string_from_unix_time(alterado))).replace("T"," · "),"alterado":alterado,"carregavel":compativel,"dia":int(calendario.get("dias",0))+1,"hora":"%02d:%02d" % [floori(float(calendario.get("minutos",480))/60.0),int(calendario.get("minutos",480))%60],"saldo":saldo,"debug":bool(operacao.get("debug",false))})
	resultado.sort_custom(func(a,b): return a.alterado>b.alterado or (a.alterado==b.alterado and a.caminho>b.caminho))
	return resultado

static func normalizar(valor: Variant) -> Variant:
	if valor is Dictionary:
		for chave in valor: valor[chave] = normalizar(valor[chave])
	elif valor is Array:
		for i in valor.size(): valor[i] = normalizar(valor[i])
	elif valor is float and valor == floor(valor):
		return int(valor)
	return valor

