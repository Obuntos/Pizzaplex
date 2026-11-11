class_name CirculacaoVisitantesPlex
extends RefCounted

const PRIVADAS=["cozinha","oficina","vestiario","descanso","limpeza","deposito","escritorio","seguranca"]
static var cache:Dictionary={}
static func restrita(sala:Dictionary) -> bool:return str(sala.get("tipo","")) in PRIVADAS
static func permitida(jogo:Node,c:Vector2i) -> bool:return not restrita(jogo.ambientes.em(c))
static func bloqueios(jogo:Node,origem:Vector2i) -> Array[Vector2i]:
	jogo.ambientes.atualizar()
	var chave:=str([jogo.planta.get_instance_id(),jogo.ambientes.assinatura_estrutura,jogo.ambientes.assinatura_requisitos])
	if cache.get("chave","")!=chave:
		var portas:Dictionary={}
		for sala in jogo.ambientes.ambientes:
			if not restrita(sala):continue
			for id in sala.get("portas",[]):
				var porta:Dictionary=jogo.planta.objetos.get(int(id),{})
				if porta.is_empty():continue
				for c in jogo.planta.celulas(porta.tipo,porta.celula,porta.rotacao):
					if not portas.has(c):portas[c]=[]
					portas[c].append(int(sala.id))
		cache={"chave":chave,"portas":portas}
	var atual:Dictionary=jogo.ambientes.em(origem)
	var saida:=int(atual.get("id",-1)) if restrita(atual) else -1
	var lista:Array[Vector2i]=[]
	for c in cache.portas:
		if not cache.portas[c].has(saida):lista.append(c)
	return lista
static func rota(jogo:Node,origem:Vector2i,destino:Vector2i,extras:Array[Vector2i]=[]) -> Array[Vector2i]:
	if not permitida(jogo,destino):return []
	var bloqueadas:=bloqueios(jogo,origem)
	for c in extras:
		if not bloqueadas.has(c):bloqueadas.append(c)
	return jogo.rotas.caminho(origem,destino,bloqueadas)
static func concluir_brincadeira(jogo:Node,a:PersonagemPlex) -> void:
	if a.cargo not in ["crianca","adolescente"]:return
	if int(a.visita.get("seguindo_adm",-1))>0:jogo.controle.seguidores.dispensar(a)
	a.visita.brincou=true;a.visita.jogou=true;a.visita.erase("show");a.visita.erase("voltar_responsavel")
	a.movimento.cancelar();a.assento=-1
	DiversaoFamiliaPlex.concluir(jogo,a)
static func encerrar_espera(jogo:Node,a:PersonagemPlex) -> void:
	if int(a.visita.get("seguindo_adm",-1))>0:jogo.controle.seguidores.dispensar(a)
	a.visita.diversao_concluida=true;a.visita.espera_diversao_esgotada=true;a.visita.etapa="aguardar";a.visita.erase("show")
	a.movimento.cancelar();a.assento=-1;a.trabalho="aguardar_familia"
static func voltar(jogo:Node,a:PersonagemPlex) -> void:
	if a.ocupado():return
	var grupo:Dictionary=jogo.clientes.grupos.get(a.familia,{})
	var pai:PersonagemPlex=jogo.clientes.ator(a.responsavel)
	if not is_instance_valid(pai):pai=jogo.clientes.ator(int(grupo.get("adulta",-1)))
	if not is_instance_valid(pai):return
	if a.local.distance_to(pai.local)<=2.5 and permitida(jogo,a.celula):a.visita.erase("voltar_responsavel");a.trabalho="aguardar_familia";return
	for c in jogo.clientes.vagas(pai.celula,12,3):
		var caminho:=rota(jogo,a.origem_rota(),c)
		if caminho.is_empty():continue
		a.set_meta("limites_rota",bloqueios(jogo,a.origem_rota()));a.andar(caminho);a.trabalho="voltar_responsavel";return
static func atualizar(jogo:Node) -> void:
	var funcionarios:Array=jogo.personagens.filter(func(p):return p.cargo=="funcionario" and not p.visita.get("morto",false) and not p.visita.get("fora_turno",false))
	for a in jogo.personagens:
		if a.cargo!="crianca" or a.visita.get("morto",false) or a.visita.get("fugindo",false):continue
		if a.visita.get("voltar_responsavel",false):voltar(jogo,a);continue
		var sala:Dictionary=jogo.ambientes.em(a.celula)
		if not restrita(sala):continue
		for funcionario in funcionarios:
			if jogo.ambientes.em(funcionario.celula).get("id",-1)!=sala.get("id",-2) or funcionario.local.distance_to(a.local)>6:continue
			if not VisaoNPCPlex.ve(jogo,funcionario,a,6.0):continue
			if not jogo.social.conversa.is_empty() and jogo.social.conversa.get("alvo")==a:jogo.social.cancelar()
			if int(a.visita.get("seguindo_adm",-1))>0:jogo.controle.seguidores.dispensar(a)
			a.movimento.cancelar();a.assento=-1;a.visita.voltar_responsavel=true;a.visita.repreendida_por=funcionario.identificador
			jogo.sistemas.baloes.exibir(funcionario,"Esta área é de funcionários. Volte para o seu responsável.",5)
			a.emocao.exibir("exclamacao");voltar(jogo,a);break
