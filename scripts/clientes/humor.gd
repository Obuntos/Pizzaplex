class_name HumorClientesPlex
extends RefCounted

const INCOMODO=60.0
const LIMITE=180.0
static func definir(a:PersonagemPlex,estado:String) -> void:
	if not is_instance_valid(a) or a.visita.get("morto",false):return
	a.visita.humor_cliente=estado;a.animacao.expressao=estado
static func atualizar(clientes:ClientesPlex,g:Dictionary,delta:float) -> void:
	if g.estado=="saindo":return
	var membros:=FamiliasVisitantesPlex.membros(g)
	var fase:=""
	if g.estado=="recepcao" and g.get("fase_recepcao","")=="acompanhar":
		g.minutos_espera_humor=0.0
		for id in membros:definir(clientes.ator(int(id)),"feliz")
		return
	if not g.get("acesso",false) or g.estado=="recepcao":fase="mesa"
	elif g.estado=="visita":
		for id in membros:
			var a:PersonagemPlex=clientes.ator(int(id))
			if not is_instance_valid(a) or a.visita.get("comeu",false):continue
			var p:Dictionary=clientes.jogo.servicos.pedido_por_id(int(a.visita.get("pedido",g.get("pedido",-1))))
			if p.get("estado","") not in ["entregue","cortando","consumido"]:fase="comida";break
	if fase!=g.get("fase_espera_humor",""):g.fase_espera_humor=fase;g.minutos_espera_humor=0.0
	if fase.is_empty():
		for id in membros:
			var a:PersonagemPlex=clientes.ator(int(id))
			if is_instance_valid(a):definir(a,"muito_feliz" if a.visita.get("comeu",false) or a.trabalho in ["brincar","assistir","assistir_mascote"] else "feliz")
		return
	g.minutos_espera_humor=float(g.get("minutos_espera_humor",0.0))+maxf(0,delta)*CalendarioPlex.MINUTOS_POR_SEGUNDO
	var minutos:=float(g.minutos_espera_humor)
	var estado:="raivoso" if minutos>=LIMITE else "triste" if minutos>=INCOMODO else "feliz"
	for id in membros:
		var pessoa:PersonagemPlex=clientes.ator(int(id))
		if is_instance_valid(pessoa):pessoa.visita.motivo_insatisfacao=("Pedido não veio." if minutos>=LIMITE else "Pedido demorado.") if fase=="comida" else "Espera por uma mesa."
	for id in membros:definir(clientes.ator(int(id)),estado)
	if minutos>=LIMITE:g.irritado=true;clientes.sair(g)
