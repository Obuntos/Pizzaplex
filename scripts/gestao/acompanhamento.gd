class_name AcompanhamentoEquipePlex
extends RefCounted
static func estado(jogo:Node,a:PersonagemPlex) -> String:
	if a.visita.get("demitido",false):return "Desligado · indo embora"
	if a.visita.get("morto",false):return "Ausente"
	if a.visita.get("fora_turno",false):return "Aguardando o horário" if a.visita.get("contrato_noturno",false) else "Fora do expediente"
	var fase:=str(a.visita.get("turno_etapa",""))
	if fase in ["descansando","ir_descansar"]:return "Descansando" if fase=="descansando" else "Indo descansar"
	if fase.contains("trocar"):return "No vestiário"
	if fase in ["aguardar_chegada","chegando","aguardar_acesso"]:return "Chegando ao restaurante"
	if a.visita.get("saindo_fechamento",false):return "Encerrando o turno"
	if a.ocupado():return "A caminho · "+a.trabalho.replace("_"," ")
	if not a.trabalho.is_empty() and a.trabalho not in ["aguardar","visitar"]:return a.trabalho.replace("_"," ").capitalize()
	if a.energia<25:return "Cansado · precisa de descanso"
	var grupos:Array=jogo.clientes.grupos.values()
	if EquipePlex.permite(a,"atendimento") and grupos.any(func(g):return g.get("estado","")=="recepcao"):return "Atendimento pendente · confira o acesso ao caixa"
	if EquipePlex.permite(a,"cozinha") and jogo.servicos.pedidos.any(func(p):return p.get("estado","")=="aguardando"):
		if not jogo.planta.objetos.values().any(func(o):return str(o.tipo)=="geladeira" and int(o.get("ingredientes",0))>0):return "Aguardando ingredientes"
		return "Pedidos pendentes · confira acesso ao forno"
	return "Disponível · aguardando tarefa"
