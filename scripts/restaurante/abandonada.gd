class_name PizzariaAbandonadaPlex
extends RefCounted

static func montar(jogo: Node) -> bool:
	if not jogo.planta.objetos.is_empty(): return false
	var p: PlantaPlex = jogo.planta
	var b := PlantaExemploPlex.new(p)
	p.set_block_signals(true)
	for r in [[20,12,25,19],[20,12,9,10],[20,21,9,10]]: b.retangulo(r[0],r[1],r[2],r[3])
	for c in b.paredes:
		b.objeto("antigo_parede_quebrada_modulo",c.x,c.y)
	b.abertura("antigo_porta_antiga_2",44,20,1)
	b.abertura("antigo_porta_antiga_1",28,17,1)
	b.abertura("antigo_porta_antiga_1",28,26,1)
	b.abertura("antigo_porta_antiga_1",24,21,0)
	for x in [31,35,39]: b.abertura("antigo_barricada_horizontal",x,12,0)
	for y in range(13,30):
		for x in range(21,44):
			p.pisos[Vector2i(x,y)] = "antigo_piso_velho"
	for registro in [["antigo_geladeira_antiga",21,13,0],["antigo_fogao_uma_boca",24,13,0],["antigo_estante_velha_1",25,19,2],["antigo_armario_oficina",21,22,0],["antigo_armario_vestiario",21,27,0],["antigo_mesa_velha_1",24,24,0],["terminal_ibm",24,24,0],["antigo_barril_enferrujado",42,28,0],["vassoura",22,25,0],["balde",23,26,0],["ponto_recebimento",45,25,0]]:
		b.objeto(registro[0],registro[1],registro[2],registro[3])
	for c in [Vector2i(33,21),Vector2i(39,25)]:
		b.objeto("antigo_mesa_velha_1",c.x,c.y)
		b.objeto("antigo_cadeira_velha",c.x,c.y+1,2)
		b.objeto("antigo_cadeira_velha",c.x,c.y-1,0)
	for x in range(32,38): b.objeto("antigo_palco_madeira_pequeno",x,14)
	b.objeto("antigo_escada_madeira_3",34,15)
	for r in [["antigo_saco_monte",31,27],["antigo_saco_grande",42,16],["antigo_fragmento_parede_medio",30,17],["antigo_fragmento_parede_pequeno",26,27],["antigo_fragmento_piso_medio",37,18],["antigo_fragmento_piso_pequeno",41,23]]:
		b.objeto(r[0],r[1],r[2])
	for c in [Vector2i(24,17),Vector2i(24,26),Vector2i(34,22),Vector2i(40,26)]:
		var id := b.objeto("luz_teto",c.x,c.y)
		if id >= 0: p.objetos[id].energia = .8
	p.set_block_signals(false)
	p.reindexar()
	p.alterada.emit()
	jogo.campanha = true
	jogo.calendario.restaurar({})
	jogo.servicos.saldo = 1200
	jogo.selecionado = null
	jogo.ambientes.atualizar()
	jogo.conforto.atualizar(2.0)
	jogo.painel.hud.atualizar(1.0)
	jogo.enquadrar()
	jogo.painel.mensagem("Pizzaria abandonada · $ 1.200 para começar. Limpe o salão, reforme os móveis e equipe a cozinha. Animatrônicos são encomendados pelo computador.")
	return b.erros.is_empty()
