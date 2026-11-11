class_name EncerramentoPlex
extends RefCounted

var jogo: Node
var espera := 0.0

func _init(cena: Node) -> void:
	jogo=cena

func iniciar() -> void:
	jogo.social.cancelar()
	for grupo in jogo.clientes.grupos.values(): jogo.clientes.recepcao.liberar(grupo)
	jogo.controle.seguidores.dispensar_todos()
	for a in jogo.personagens:
		if a.visita.get("debug_evento",false):continue
		if a.funcao=="seguranca" and jogo.sistemas.guarda.escala.ativo(a,jogo.calendario.dias,jogo.calendario.minutos):continue
		if a.cargo in ["morador","autoridade"] or a.robo or AdministradorPlex.eh(a) or a.visita.get("morto",false) or a.visita.get("fora_turno",false): continue
		for item in jogo.planta.objetos.values():
			if int(item.get("carregada_por",0))!=a.identificador: continue
			item.carregada_por=0
			item.celula=a.celula
			item.sobre=-1
			item.slot=-1
			item.solto=true
		a.carga_item=-1
		a.carga_extra.clear()
		jogo.controle.interromper(a)
		a.visita.saindo_fechamento=true
		a.visita.erase("fugindo")
		a.visita.erase("panico_destino")
		a.automatico=false
		a.trabalho="sair_fechamento"
	jogo.turnos.fechar()
	for pedido in jogo.servicos.pedidos:
		if pedido.estado in ["consumido","cancelado"]: continue
		FornoPlex.liberar(jogo.planta,int(pedido.id))
		pedido.estado="cancelado"
		pedido.bebida_estado="cancelada"
	for grupo in jogo.clientes.grupos.values():
		if not grupo.get("debug_evento",false):grupo.estado="saindo"
	jogo.planta.reindexar()
	jogo.planta.alterada.emit()

func reabrir() -> void:
	jogo.turnos.abrir()

func atualizar(delta: float) -> void:
	espera+=delta
	if espera<.05: return
	espera=0.0
	var novas_rotas:=0
	for a in jogo.personagens.duplicate():
		if not a.visita.get("saindo_fechamento",false) or a.visita.get("fora_turno",false) or a.visita.get("morto",false): continue
		if TurnosEquipePlex.ocupado(a):continue
		var alvo: Array=a.visita.get("saida_fechamento",[-1,-1])
		if ChegadasEquipePlex.pode_sumir(jogo,a):
			if a.cargo=="funcionario" and not a.visita.get("demitido",false): a.visita.fora_turno=true; a.hide()
			else: jogo.despawn(a)
			continue
		if a.ocupado() or novas_rotas>=2: continue
		novas_rotas+=1
		var destino:Vector2i=Vector2i(alvo[0],alvo[1])
		if destino.x<0:destino=ChegadasEquipePlex.destino_saida(jogo,a)
		if destino.x<0: continue
		a.visita.saida_fechamento=[destino.x,destino.y]
		a.andar(jogo.rotas.caminho(a.origem_rota(),destino))
		a.trabalho="sair_fechamento"
	for id in jogo.clientes.grupos.keys():
		var grupo: Dictionary=jogo.clientes.grupos[id]
		if jogo.clientes.membros(grupo).all(func(ator_id): return not is_instance_valid(jogo.clientes.ator(ator_id)) or jogo.clientes.ator(ator_id).visita.get("morto",false)):
			MesasVisitasPlex.liberar(jogo.clientes,grupo)
			jogo.clientes.grupos.erase(id)
