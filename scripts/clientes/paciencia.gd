class_name PacienciaClientesPlex
extends RefCounted
const LIMITE=300.0
static func aguardando(jogo:Node,g:Dictionary) -> bool:
	if str(g.get("estado","")) in ["saindo","pagamento","comprar_baloes"] or g.get("pago",false):return false
	if g.get("estado","")=="recepcao":return true
	if g.get("estado","")!="visita":return false
	for id in FamiliasVisitantesPlex.adultos(g):
		var a:PersonagemPlex=jogo.clientes.ator(int(id))
		if not is_instance_valid(a) or a.visita.get("comeu",false):continue
		var pedido:Dictionary=jogo.servicos.pedido_por_id(int(a.visita.get("pedido",g.get("pedido",-1))))
		if pedido.is_empty() or str(pedido.get("estado","")) not in ["entregue","comendo","consumido"]:return true
	return false
static func atualizar(jogo:Node,g:Dictionary,delta:float) -> bool:
	if not aguardando(jogo,g):g.espera_sem_atendimento=0.0;return false
	g.espera_sem_atendimento=float(g.get("espera_sem_atendimento",0))+delta
	if float(g.espera_sem_atendimento)<LIMITE:return false
	g.irritado=true;g.abandono_atendimento=true
	for p in jogo.servicos.pedidos:
		if int(p.get("familia",-1))!=int(g.id) or p.estado in ["consumido","cancelado"]:continue
		FornoPlex.liberar(jogo.planta,int(p.id));p.estado="cancelado";p.bebida_estado="cancelada"
	for id in FamiliasVisitantesPlex.membros(g):
		var a:PersonagemPlex=jogo.clientes.ator(int(id))
		if not is_instance_valid(a):continue
		a.visita.irritado=true;a.assento=-1
	jogo.sistemas.baloes.exibir(jogo.clientes.ator(int(g.adulta)),"Esperamos demais. Vamos embora.",5)
	jogo.clientes.sair(g);return true
