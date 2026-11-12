class_name AdministradorPlex
extends RefCounted

static func eh(ator: PersonagemPlex) -> bool:
	return ator.funcao=="administrador" or bool(ator.visita.get("administrador",false))

static func reservar_cabelo(jogo: Node) -> void:
	var reservado := str(jogo.operacao.criacao.get("cabelo","nenhum"))
	for ator in jogo.personagens:
		ator.set_meta("cabelo_reservado",reservado)
		if eh(ator) or reservado=="nenhum" or not AparenciaPlex.permitida(ator): continue
		if AparenciaPlex.cabelo(ator)==reservado or ator.cabelo==reservado:
			ator.cabelo = alternativa(ator,reservado)

static func alternativa(ator: PersonagemPlex, reservado: String) -> String:
	AparenciaPlex.carregar()
	var opcoes: Array = VariedadeAparenciaPlex.cabelos(ator).filter(func(c): return c.id!=reservado)
	return str(opcoes[posmod(ator.identificador,opcoes.size())].id) if not opcoes.is_empty() else "nenhum"

static func criar(jogo: Node) -> PersonagemPlex:
	var d: Dictionary = jogo.operacao.criacao
	var local: Vector2i = jogo.planta.lote_restaurante.position+Vector2i(6,6) if jogo.planta.bairro_ativo else Vector2i(30,25)
	for c in jogo.clientes.vagas(local,1,6):
		local=c
		break
	var a: PersonagemPlex = jogo.spawn(str(d.get("modelo","humano")),local)
	a.funcao = "administrador"
	a.visita.administrador = true
	a.necessidades.turno = true
	a.uniforme = str(d.get("uniforme","administrador_masculino_1"))
	a.cabelo = str(d.get("cabelo","curto"))
	a.visita.cor_cabelo=CoresCabeloPlex.validar(str(d.get("cor_cabelo","marrom_escuro")))
	a.visita.pele=PelePlex.validar(str(d.get("pele",PelePlex.PADRAO)))
	a.visita.olhos=RostoPlex.olhos(str(d.get("olhos","padrao")));a.visita.itens_faciais=RostoPlex.itens(d.get("itens_faciais",[]))
	a.identidade = {"nome":str(d.get("nome","Administrador")).strip_edges().left(40),"sobrenome":"","apelido":"","idade":30,"sexo":"feminino" if a.modelo=="humana" else "masculino"}
	jogo.operacao.administrador = a.identificador
	reservar_cabelo(jogo)
	a.atualizar_visual(false)
	jogo.selecionar(a)
	jogo.painel.mensagem("Bem-vindo à "+jogo.operacao.nome+". Abra o catálogo para começar a reforma.")
	return a

static func contratar(jogo: Node, funcao: String, candidato:Dictionary={}) -> PersonagemPlex:
	if not FolhaPagamentoPlex.SALARIOS.has(funcao):return null
	if not candidato.is_empty():
		candidato=RecrutamentoPlex.buscar(jogo,funcao,str(candidato.get("id","")))
		if candidato.is_empty() or jogo.servicos.saldo<float(candidato.custo):return null
	var admin: PersonagemPlex = jogo.clientes.ator(jogo.operacao.administrador)
	var origem := admin.celula if is_instance_valid(admin) else Vector2i(30,25)
	var vagas: Array = jogo.clientes.vagas(origem,1,6)
	if vagas.is_empty(): return null
	var a: PersonagemPlex = jogo.spawn(str(candidato.modelo) if not candidato.is_empty() else ("humana" if randi()%2==0 else "humano"),vagas[0])
	if not is_instance_valid(a):return null
	if not candidato.is_empty():
		a.identidade={"nome":str(candidato.nome),"sobrenome":str(candidato.sobrenome),"apelido":"","idade":30,"sexo":"feminino" if a.modelo=="humana" else "masculino"}
		a.visita.habilidades=candidato.habilidades.duplicate(true)
		jogo.servicos.saldo=snappedf(jogo.servicos.saldo-float(candidato.custo),.01)
		RecrutamentoPlex.remover(jogo,funcao,str(candidato.id))
	EquipePlex.definir(a,funcao,[])
	a.necessidades.turno = true
	FolhaPagamentoPlex.registrar(a,int(jogo.calendario.dias))
	reservar_cabelo(jogo)
	jogo.painel.mensagem(IdentidadesPlex.completo(a)+" contratado para "+str(EquipePlex.NOMES.get(funcao,funcao))+" · Salário: US$ %d por semana."%HabilidadesEquipePlex.salario(a))
	if "turnos" in jogo and jogo.turnos!=null:
		if jogo.operacao.aberto:jogo.turnos.chegada(a,1.0)
		else:a.visita.fora_turno=true;a.hide()
	if is_instance_valid(jogo.sistemas.tutorial):jogo.sistemas.tutorial.contratado()
	return a

static func demitir(jogo:Node,a:PersonagemPlex) -> bool:
	if not is_instance_valid(a) or not TurnosEquipePlex.funcionario(a) or a.funcao=="seguranca":return false
	if a.funcao=="seguranca" and jogo.sistemas.guarda.escala.guarda==a.identificador:
		jogo.sistemas.guarda.liberar_terminal(a);jogo.sistemas.guarda.escala.carimbada=false
	jogo.controle.interromper(a);jogo.turnos.liberar_cadeira(a);a.visita.demitido=true;a.visita.turno_manual=false
	if a.visita.get("fora_turno",false):jogo.despawn(a)
	else:jogo.turnos.sair(a)
	return true
