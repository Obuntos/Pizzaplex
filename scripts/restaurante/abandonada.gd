class_name PizzariaAbandonadaPlex
extends RefCounted

static func montar(jogo: Node) -> bool:
	if not jogo.planta.objetos.is_empty(): return false
	var p: PlantaPlex = jogo.planta
	var mapa: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://dados/cidade/bairro_jardim.json"))
	var lote:=Rect2i(mapa.restaurante[0],mapa.restaurante[1],mapa.restaurante[2],mapa.restaurante[3])
	p.set_block_signals(true)
	if not LayoutRestaurantePlex.aplicar(p,lote):
		p.set_block_signals(false)
		return false
	p.set_block_signals(false)
	p.reindexar()
	jogo.campanha=true
	jogo.calendario.restaurar({})
	jogo.servicos.saldo=500.0
	jogo.selecionado=null
	jogo.bairro.ativar(true)
	jogo.iluminacao.atualizar_sol(jogo.calendario)
	jogo.ambientes.atualizar()
	jogo.conforto.atualizar(2.0)
	jogo.painel.hud.atualizar(1.0)
	jogo.enquadrar()
	jogo.painel.mensagem("1º de janeiro de 1958 · Restaurante abandonado de 12 × 12. Saldo inicial: US$ 500.")
	return true
