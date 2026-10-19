class_name ExemploSalasPlex
extends RefCounted

static func montar(jogo: Node) -> bool:
	var planta: PlantaPlex = jogo.planta
	if not planta.objetos.is_empty() or not jogo.personagens.is_empty():
		jogo.painel.mensagem("O exemplo só pode ser colocado em uma área vazia.")
		return false
	var construtor := PlantaExemploPlex.new(planta)
	if not construtor.construir():
		jogo.painel.mensagem("Não foi possível montar o exemplo: " + ", ".join(construtor.erros))
		return false
	jogo.ambientes.atualizar()
	for p in [["humano",26,31,"cozinha"],["humana",24,20,"atendimento"],["humano",31,20,"atendimento"],["humano",26,12,"manutencao"],["faxineiro",16,14,"limpeza"],["entregador",21,34,"estoque"],["caixista",44,11,"caixa"],["seguranca",37,16,"seguranca"]]:
		var a: PersonagemPlex = jogo.spawn(p[0],Vector2i(p[1],p[2]))
		EquipePlex.definir(a,p[3],["estoque"] if p[3]=="cozinha" else [])
		a.necessidades.turno = true
		if p[3]=="manutencao": a.visita.posto_oficina = [26,12]
	for p in [["coelho",23],["ovelha",25],["raposa",27]]:
		var a: PersonagemPlex = jogo.spawn(p[0],Vector2i(p[1],15))
		a.pose = planta.sobre(a.celula,"pose")[0].id
		a.direcao = GradePlex.direcao_suporte(0)
		a.altura = GradePlex.ALTURA_PALCO
		a.trabalho = "apresentar"
	jogo.clientes.criar_grupo(Vector2i(51,10),2,2,0)
	jogo.clientes.criar_grupo(Vector2i(51,13),2,1,1)
	jogo.lazer.criar(Vector2i(51,16),true)
	jogo.servicos.saldo = 600
	jogo.nivel_paredes = 4
	jogo.cortar_frente = true
	jogo.painel.paredes.text = "Paredes: 4 / 4 · Ctrl"
	planta.alterada.emit()
	jogo.enquadrar()
	jogo.painel.mensagem("Restaurante de demonstração pronto: fachada, salão com quatro mesas, palco compacto com cortina contínua, arcade, cozinha, banheiros, oficina e administração. Mercado: Pizza e Guaraná. Saldo: $ 600.")
	return true
