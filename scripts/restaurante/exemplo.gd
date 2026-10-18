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
	var funcionario: PersonagemPlex = jogo.spawn("humano", Vector2i(10, 10))
	funcionario.necessidades.banheiro = 18.0
	var atendente: PersonagemPlex = jogo.spawn("humana", Vector2i(12, 10))
	EquipePlex.definir(atendente,"atendimento",[])
	var tecnico: PersonagemPlex = jogo.spawn("humano", Vector2i(19, 9))
	EquipePlex.definir(tecnico,"manutencao",[])
	jogo.spawn("faxineiro", Vector2i(26, 3))
	jogo.spawn("caixista",Vector2i(3,15))
	jogo.spawn("seguranca",Vector2i(8,16))
	EquipePlex.definir(funcionario,"cozinha",["estoque"])
	planta.colocar("balcao",Vector2i(3,20),0)
	planta.colocar("terminal_ibm",Vector2i(3,20),0)
	planta.colocar("ponto_recebimento",Vector2i(2,12),0)
	jogo.servicos.saldo = 300
	for item in [["ovelha", Vector2i(16, 12)], ["raposa", Vector2i(18, 12)]]:
		var ator: PersonagemPlex = jogo.spawn(item[0], item[1])
		ator.pose = planta.sobre(item[1], "pose")[0].id
		ator.direcao = GradePlex.direcao_suporte(0)
	var suporte: int = construtor.ids.suporte
	planta.objetos[suporte].endo = false
	jogo.nivel_paredes = 2
	jogo.painel.paredes.text = "Paredes: 2 / 4 · Ctrl"
	planta.alterada.emit()
	jogo.enquadrar()
	jogo.painel.mensagem("Restaurante montado: nove áreas configuradas, seis funcionários e palco. Terminal e recebimento na recepção. Saldo de demonstração: $ 300. Clique direito no terminal. Na aba Animatrônicos, encomende um personagem para o suporte vazio. A Oficina vende peças para os reparos.")
	return true
