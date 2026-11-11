class_name EscolaBairroPlex
extends RefCounted

static var dados: Dictionary = {}
static var rotinas: Dictionary = {}
var bairro: RefCounted
var grupos: Dictionary = {}
var dia := -1

func _init(gerente: RefCounted) -> void:
	bairro=gerente
	carregar()

static func carregar() -> void:
	if dados.is_empty(): dados=JSON.parse_string(FileAccess.get_file_as_string("res://dados/rotinas_escola.json"))

static func rotina(perfil: Dictionary, data: int, original: Array) -> Array:
	carregar()
	if AgendaMoradoresPlex.semana(data) in [0,6] or perfil.get("fora_mapa",false): return original
	var chave:=str([perfil.id,data])
	if rotinas.has(chave): return rotinas[chave]
	var resultado: Array=original.duplicate(true)
	for grupo in dados.grupos:
		var entrada:=int(grupo.entrada)
		var saida:=int(grupo.saida)
		if perfil.id in grupo.alunos:
			resultado=resultado.filter(func(e): return (int(e.minuto)<entrada and e.local!="escola") or (int(e.minuto)>saida+30 and e.local!="escola"))
			if entrada>=780:
				resultado=resultado.filter(func(e): return int(e.minuto)>480)
				resultado.append({"minuto":480,"atividade":"Manhã em casa antes da escola","local":"casa","modo":"livre","transporte":"pe"})
				resultado.append({"minuto":690,"atividade":"Almoço antes da escola","local":"casa","modo":"livre","transporte":"pe"})
			resultado.append({"minuto":entrada,"atividade":"Aulas na escola","local":"escola","modo":"compromisso","transporte":"pe"})
			resultado.append({"minuto":saida,"atividade":"Aguardando o responsável na saída da escola","local":"escola","modo":"compromisso","transporte":"pe","saida_escolar":grupo.id})
			resultado.append({"minuto":saida+35,"atividade":"Em casa após a escola","local":"casa","modo":"livre","transporte":"pe"})
		elif perfil.id==grupo.responsavel:
			var retomada: Dictionary={"minuto":0,"atividade":"Em casa","local":"casa","modo":"livre","transporte":"pe"}
			for e in original:
				if int(e.minuto)<=saida+60 and int(e.minuto)>=int(retomada.minuto): retomada=e.duplicate(true)
			resultado=resultado.filter(func(e): return int(e.minuto)<saida-120 or int(e.minuto)>saida+60)
			resultado.append({"minuto":saida-120,"atividade":"Buscar os alunos na escola","local":"escola","modo":"compromisso","transporte":"pe","busca_escolar":grupo.id})
			retomada.minuto=saida+60
			resultado.append(retomada)
	resultado.sort_custom(func(a,b): return int(a.minuto)<int(b.minuto))
	if rotinas.size()>=760: rotinas.clear()
	rotinas[chave]=resultado
	return resultado

func preparar(reposicionar: bool = true) -> void:
	dia=floori(bairro.agora()/1440.0)
	grupos.clear()
	if AgendaMoradoresPlex.semana(dia) in [0,6]: return
	for registro in dados.grupos:
		if not bairro.perfis.has(registro.responsavel) or bairro.perfis[registro.responsavel].fora_mapa: continue
		var grupo: Dictionary=registro.duplicate(true)
		grupo.liberado=false;grupo.concluido=false;grupo.rota_enviada=false
		var passou: bool=bairro.agora()>=float(dia*1440+int(grupo.saida)+60)
		if passou:
			grupo.concluido=true
			for id in grupo.alunos:
				var s: Dictionary=bairro.estados[id]
				if s.get("atividade","")=="Aguardando o responsável na saída da escola":
					s.local=bairro.perfis[id].moradia;s.objetivo=s.local;s.modo="livre";s.rota=[];s.posicao=PopulacaoBairroPlex.vetor(bairro.locais.ponto(s.local))
		elif not reposicionar and bairro.estados[grupo.responsavel].get("escola_grupo","")==grupo.id:
			grupo.liberado=true
			grupo.rota_enviada=not bairro.estados[grupo.responsavel].get("rota",[]).is_empty()
		grupos[grupo.id]=grupo

func ocupado(id: String) -> bool:
	return bairro.estados.get(id,{}).has("escola_grupo") or bairro.estados.get(id,{}).has("escola_busca")

func presente(id: String) -> bool:
	var s: Dictionary=bairro.estados.get(id,{})
	return not s.is_empty() and not s.get("morto",false) and not s.get("restaurante",false)

func liberar(grupo: Dictionary) -> void:
	grupo.liberado=true
	var adulto: Dictionary=bairro.estados[grupo.responsavel]
	adulto.erase("escola_busca")
	adulto.escola_grupo=grupo.id;adulto.objetivo=bairro.perfis[grupo.responsavel].moradia;adulto.local="escola";adulto.rota=[]
	adulto.atividade="Voltando da escola com a família";adulto.modo="compromisso"
	bairro.encontros.cancelar(grupo.responsavel)
	bairro.solicitar_rota(grupo.responsavel)
	for id in grupo.alunos:
		if not presente(id): continue
		bairro.encontros.cancelar(id)
		var s: Dictionary=bairro.estados[id]
		s.escola_grupo=grupo.id;s.escola_acompanha=grupo.responsavel;s.local="escola";s.objetivo=bairro.perfis[grupo.responsavel].moradia
		s.rota=[];s.posicao=adulto.posicao.duplicate();s.modo="compromisso";s.atividade="Voltando da escola acompanhado"
		bairro.fila_rotas.erase(id)

func finalizar(grupo: Dictionary) -> void:
	grupo.concluido=true
	for id in [grupo.responsavel]+grupo.alunos:
		var s: Dictionary=bairro.estados[id]
		s.erase("escola_grupo");s.erase("escola_acompanha")
		if presente(id):
			var evento: Dictionary=AgendaMoradoresPlex.situacao(bairro.perfis[id],bairro.agora()).atual
			if evento.has("busca_escolar") or evento.has("saida_escolar"):
				s.modo="livre";s.atividade="Em casa após a escola"
			else: bairro.aplicar_evento(id)

func atualizar(_delta: float) -> void:
	if dia!=floori(bairro.agora()/1440.0): preparar()
	if not bairro.cidade_presente: return
	for grupo in grupos.values():
		if grupo.concluido or bairro.agora()<float(dia*1440+int(grupo.saida)): continue
		if not presente(grupo.responsavel):
			if bairro.estados[grupo.responsavel].get("restaurante",false):
				if FilhosRestaurantePlex.enviar(bairro,grupo): grupo.concluido=true
				continue
			grupo.concluido=true
			for id in grupo.alunos:
				if presente(id): bairro.estados[id].atividade="Aguardando responsável na escola"
			continue
		var adulto: Dictionary=bairro.estados[grupo.responsavel]
		if not grupo.liberado:
			if adulto.get("local","")!="escola" or not adulto.get("rota",[]).is_empty(): continue
			liberar(grupo)
		elif not grupo.rota_enviada:
			var rota: Array=adulto.get("rota",[])
			if rota.is_empty(): continue
			var indice:=0
			for id in grupo.alunos:
				if not presente(id): continue
				var s: Dictionary=bairro.estados[id]
				s.rota=rota.duplicate(true);s.inicio=float(adulto.inicio)+float(indice+1)*1.0*CalendarioPlex.MINUTOS_POR_SEGUNDO;s.duracao=adulto.duracao;s.local="trajeto"
				indice+=1
			grupo.rota_enviada=true
		elif adulto.get("rota",[]).is_empty() and grupo.alunos.all(func(id): return not presente(id) or bairro.estados[id].get("rota",[]).is_empty()):
			finalizar(grupo)
