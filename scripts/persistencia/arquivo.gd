class_name ArquivoPlex
extends RefCounted

const CAMINHO = ""
const TIPO = "pizzaplex_partida"
static var cache_listagem: Dictionary = {}
const PASTA = "user://saves"
const TOTAL_SLOTS=3
static var ultimo_caminho := ""

static func salvar(planta: PlantaPlex, personagens: Array, servicos: Dictionary = {}, clientes: Dictionary = {}, compras: Dictionary = {}, campanha: Dictionary = {}, slot:int=1) -> bool:
	var sucesso:=_salvar(planta,personagens,servicos,clientes,compras,campanha,slot)
	return sucesso

static func _salvar(planta: PlantaPlex, personagens: Array, servicos: Dictionary = {}, clientes: Dictionary = {}, compras: Dictionary = {}, campanha: Dictionary = {}, slot:int=1) -> bool:
	if slot<1 or slot>TOTAL_SLOTS:return false
	recuperar_slots();migrar_slots()
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
	for c in planta.pisos: pisos.append([c.x,c.y,planta.pisos[c],int(planta.rotacoes_pisos.get(c,0))])
	var atores: Array = []
	for ator in personagens:
		if ator.cargo=="morador" and not ator.visita.get("morto",false) and not ControleAdministradorPlex.ocupado(ator): continue
		var visita: Dictionary=ator.visita.duplicate(true)
		var automatico: bool=bool(visita.get("autonomia_social",ator.automatico))
		visita.erase("socializando");visita.erase("autonomia_social")
		atores.append({"id": ator.identificador, "relogio":ator.relogio, "identidade":ator.identidade, "modelo": ator.modelo, "robo": ator.robo, "celula": [ator.celula.x, ator.celula.y], "direcao": ator.direcao, "automatico": automatico, "carregando": ator.carregando, "suporte": ator.suporte, "pose": ator.pose, "pecas": ator.pecas, "expressao": ator.animacao.expressao, "apresentando": ator.trabalho == "apresentar", "carga_item": ator.carga_item, "carga_extra":ator.carga_extra, "energia": ator.energia, "necessidades": ator.necessidades, "cargo": ator.cargo, "funcao":ator.funcao, "funcoes_secundarias":ator.funcoes_secundarias, "caixa_tipo":ator.caixa_tipo, "caixa_qualidade":ator.caixa_qualidade, "caixa_durabilidade":ator.caixa_durabilidade, "cabelo":ator.cabelo,"uniforme":ator.uniforme,"familia": ator.familia, "responsavel": ator.responsavel, "visita": visita,"robotica":ator.robotica})
	var salas: Array = []
	for c in planta.funcoes_salas: salas.append([c.x, c.y, planta.funcoes_salas[c]])
	if DirAccess.make_dir_recursive_absolute(PASTA)!=OK: return false
	var caminho:=caminho_slot(slot)
	var dados := {"versao":3,"tipo":TIPO,"origem":"jogador","objetos":objetos,"cores":cores,"personagens":atores,"salas":salas,"servicos":servicos,"clientes":clientes,"compras":compras,"pisos":pisos,"uso_pisos":DesgastePisosPlex.gravar(planta),"terreno":TerrenoPlex.gravar(planta),"terrenos_adquiridos":planta.terrenos_adquiridos.duplicate(),"campanha":campanha,"salvo_em":Time.get_datetime_string_from_system(),"salvo_unix":Time.get_unix_time_from_system()}
	if not valido(dados): return false
	var temporario := caminho+".tmp"
	var arquivo := FileAccess.open(temporario,FileAccess.WRITE)
	if arquivo==null: return false
	arquivo.store_string(JSON.stringify(dados))
	arquivo.flush()
	var erro := arquivo.get_error()
	arquivo.close()
	if erro!=OK:return false
	var backup:=caminho+".bak"
	if FileAccess.file_exists(backup):DirAccess.remove_absolute(backup)
	if FileAccess.file_exists(caminho) and DirAccess.rename_absolute(caminho,backup)!=OK:return false
	if DirAccess.rename_absolute(temporario,caminho)!=OK:
		if FileAccess.file_exists(backup):DirAccess.rename_absolute(backup,caminho)
		return false
	if FileAccess.file_exists(backup):DirAccess.remove_absolute(backup)
	cache_listagem.erase(caminho)
	ultimo_caminho=caminho
	return true

static func conteudo(caminho: String) -> Dictionary:
	if not FileAccess.file_exists(caminho): return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(caminho))!=OK or not json.data is Dictionary: return {}
	return json.data

static func dicionario(valor: Variant) -> Dictionary:
	return valor if valor is Dictionary else {}

static func _num(v: Variant) -> bool:
	return v is int or v is float

static func _txt(v: Variant) -> bool:
	return v is String or v is StringName

static func _par(v: Variant) -> bool:
	return v is Array and v.size()==2 and _num(v[0]) and _num(v[1])

static func valido(dados: Dictionary) -> bool:
	if int(dados.get("versao",0)) not in [2,3] or not dados.get("objetos") is Array or not dados.get("personagens") is Array or not dados.get("cores") is Array: return false
	if not dados.get("pisos") is Array or not dados.get("salas",[]) is Array: return false
	var campanha_salva:=dicionario(dados.get("campanha",{}))
	var operacao:=dicionario(campanha_salva.get("operacao",{}))
	var admin:=int(operacao.get("administrador",-1))
	if str(operacao.get("nome","")).strip_edges().is_empty() or admin<0: return false
	if not dados.personagens.any(func(a): return a is Dictionary and int(a.get("id",-1))==admin and (a.get("funcao","")=="administrador" or dicionario(a.get("visita",{})).get("administrador",false))): return false
	if int(dados.versao)==3 and (dados.get("tipo","")!=TIPO or dados.get("origem","")!="jogador"): return false
	for item in dados.objetos:
		if not item is Dictionary or not _par(item.get("celula")): return false
		for chave in ["id","tipo","rotacao"]:
			if not item.has(chave): return false
		if not _num(item.id) or not _txt(item.tipo) or not _num(item.rotacao): return false
	for ator in dados.personagens:
		if not ator is Dictionary or not _par(ator.get("celula")): return false
		for chave in ["id","modelo","direcao","carregando","suporte","pecas","expressao"]:
			if not ator.has(chave): return false
		if not _num(ator.id) or not _txt(ator.modelo) or not _num(ator.direcao) or not _num(ator.suporte) or not _num(ator.pecas): return false
		for chave in ["identidade","visita","robotica","necessidades"]:
			if ator.has(chave) and not ator[chave] is Dictionary: return false
		for chave in ["funcoes_secundarias","carga_extra"]:
			if ator.has(chave) and not ator[chave] is Array: return false
	for cor in dados.cores:
		if not cor is Array or cor.size()!=3 or not _num(cor[0]) or not _num(cor[1]) or not _num(cor[2]): return false
	for piso in dados.pisos:
		if not piso is Array or piso.size()<3 or not _num(piso[0]) or not _num(piso[1]): return false
	for marca in dados.get("salas",[]):
		if not marca is Array or marca.size()<3 or not _num(marca[0]) or not _num(marca[1]): return false
	return true

static func ler(caminho: String = CAMINHO) -> Dictionary:
	var resultado:=_ler(caminho)
	return resultado

static func _ler(caminho: String) -> Dictionary:
	if not caminho.begins_with(PASTA+"/") or caminho.get_file().is_empty() or not caminho.ends_with(".json"): return {}
	var dados := conteudo(caminho)
	return normalizar(dados) if valido(dados) else {}

static func _listar_arquivos(apenas_slots:bool=false,limite:int=0) -> Array[Dictionary]:
	var caminhos: Array[String] = []
	var pasta := DirAccess.open(PASTA)
	if pasta!=null:
		for nome in pasta.get_files():
			if nome.ends_with(".json") and (not apenas_slots or nome in ["slot_1.json","slot_2.json","slot_3.json"]): caminhos.append(PASTA+"/"+nome)
	caminhos.sort_custom(func(a,b):return FileAccess.get_modified_time(a)>FileAccess.get_modified_time(b) or (FileAccess.get_modified_time(a)==FileAccess.get_modified_time(b) and a>b))
	var resultado: Array[Dictionary] = []
	for caminho in caminhos:
		if limite>0 and resultado.size()>=limite:break
		var modificado:=FileAccess.get_modified_time(caminho)
		var f:=FileAccess.open(caminho,FileAccess.READ)
		if f==null: continue
		var assinatura:=str([modificado,f.get_length()]);f.close()
		if cache_listagem.has(caminho) and cache_listagem[caminho].assinatura==assinatura:
			if not cache_listagem[caminho].registro.is_empty(): resultado.append(cache_listagem[caminho].registro)
			continue
		var dados := conteudo(caminho)
		var compativel := valido(dados)
		if not compativel: cache_listagem[caminho]={"assinatura":assinatura,"registro":{}};continue
		var campanha_salva := dicionario(dados.get("campanha",{}))
		var operacao := dicionario(campanha_salva.get("operacao",{}))
		var calendario := dicionario(campanha_salva.get("calendario",{}))
		var saldo: float=float(dicionario(dados.get("servicos",{})).get("saldo",0.0))
		var alterado := FileAccess.get_modified_time(caminho)
		resultado.append({"caminho":caminho,"nome":str(operacao.get("nome","Partida anterior" if caminho==CAMINHO else "Pizzaplex")),"data":str(dados.get("salvo_em",Time.get_datetime_string_from_unix_time(alterado))).replace("T"," · "),"alterado":alterado,"carregavel":compativel,"dia":int(calendario.get("dias",0))+1,"hora":"%02d:%02d" % [floori(float(calendario.get("minutos",480))/60.0),int(calendario.get("minutos",480))%60],"saldo":saldo})
		cache_listagem[caminho]={"assinatura":assinatura,"registro":resultado[-1]}
	resultado.sort_custom(func(a,b): return a.alterado>b.alterado or (a.alterado==b.alterado and a.caminho>b.caminho))
	return resultado

static func normalizar(valor: Variant) -> Variant:
	if valor is Dictionary:
		for chave in valor: valor[chave] = normalizar(valor[chave])
	elif valor is Array:
		for i in valor.size(): valor[i] = normalizar(valor[i])
	elif valor is float and is_finite(valor) and absf(valor)<9.0e15 and valor == floor(valor):
		return int(valor)
	return valor


static func tem_saves() -> bool:
	return not listar().is_empty()


static func apagar(caminho: String) -> bool:
	if caminho.get_base_dir()!=PASTA or not caminho.ends_with(".json") or not FileAccess.file_exists(caminho): return false
	if DirAccess.remove_absolute(caminho)!=OK: return false
	for sufixo in [".bak",".tmp"]:
		if FileAccess.file_exists(caminho+sufixo): DirAccess.remove_absolute(caminho+sufixo)
	cache_listagem.erase(caminho)
	if ultimo_caminho==caminho: ultimo_caminho=""
	return true

static func caminho_slot(slot:int) -> String:
	return PASTA+"/slot_"+str(slot)+".json" if slot>=1 and slot<=TOTAL_SLOTS else ""

static func migrar_slots() -> void:
	limpar_saves_anteriores()
	var marcador:=PASTA+"/.slots_migrados"
	if FileAccess.file_exists(marcador):return
	if DirAccess.make_dir_recursive_absolute(PASTA)!=OK:return
	var antigos:=_listar_arquivos(false,TOTAL_SLOTS).filter(func(r):return not str(r.caminho).get_file().begins_with("slot_"))
	for slot in range(1,TOTAL_SLOTS+1):
		var destino:=caminho_slot(slot)
		if FileAccess.file_exists(destino):continue
		if antigos.is_empty():break
		var r:Dictionary=antigos.pop_front()
		if DirAccess.copy_absolute(str(r.caminho),destino)!=OK:return
	var marca:=FileAccess.open(marcador,FileAccess.WRITE)
	if marca!=null:marca.store_string("3");marca.close()
	cache_listagem.clear()

static func listar_slots() -> Array[Dictionary]:
	recuperar_slots();migrar_slots()
	var existentes:=_listar_arquivos(true)
	var resultado:Array[Dictionary]=[]
	for slot in range(1,TOTAL_SLOTS+1):
		var caminho:=caminho_slot(slot)
		var r:Dictionary={"caminho":caminho,"nome":"Slot "+str(slot)+" · Vazio","data":"","alterado":0,"carregavel":false,"dia":1,"hora":"08:00","saldo":0.0}
		for registro in existentes:
			if registro.caminho==caminho:r=registro.duplicate();r.nome="Slot "+str(slot)+" · "+str(r.nome);break
		r.slot=slot;r.vazio=not bool(r.carregavel);resultado.append(r)
	return resultado

static func listar() -> Array[Dictionary]:
	return listar_slots().filter(func(r):return bool(r.carregavel))

static func recuperar_slots() -> void:
	for slot in range(1,TOTAL_SLOTS+1):
		var caminho:=caminho_slot(slot)
		if not FileAccess.file_exists(caminho) and FileAccess.file_exists(caminho+".bak"):
			DirAccess.rename_absolute(caminho+".bak",caminho);cache_listagem.erase(caminho)

static func limpar_saves_anteriores() -> void:
	var marcador:=PASTA+"/.inicio_limpo_1000_v1"
	if FileAccess.file_exists(marcador):return
	if DirAccess.make_dir_recursive_absolute(PASTA)!=OK:return
	var marca:=FileAccess.open(marcador,FileAccess.WRITE)
	if marca==null:return
	marca.store_string("1");marca.close()
	var pasta:=DirAccess.open(PASTA)
	if pasta==null:return
	for nome in pasta.get_files():
		if nome.ends_with(".json") or nome.ends_with(".json.bak") or nome.ends_with(".json.tmp"):
			if DirAccess.remove_absolute(PASTA+"/"+nome)!=OK:return
	cache_listagem.clear();ultimo_caminho=""
