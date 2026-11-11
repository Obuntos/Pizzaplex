class_name PontoEquipePlex
extends RefCounted

var jogo:Node
func _init(cena:Node) -> void:jogo=cena
static func uniformizado(a:PersonagemPlex) -> bool:return a.uniforme!="nenhum" or a.modelo.begins_with("fantasia_")
func iniciar(a:PersonagemPlex,entrada:bool) -> bool:
	if not TurnosEquipePlex.trabalhador(a) or not uniformizado(a) or entrada==bool(a.visita.get("ponto_ativo",false)):return false
	var lista:Array=jogo.planta.objetos.values().filter(func(p):return p.tipo=="amb_relogio_ponto")
	lista.sort_custom(func(x,y):return Vector2(x.celula).distance_squared_to(a.local)<Vector2(y.celula).distance_squared_to(a.local))
	for p in lista:
		if jogo.rotas.aproximar(a.origem_rota(),int(p.id)).is_empty():continue
		a.visita.turno_etapa="ponto_entrada" if entrada else "ponto_saida";a.visita.ponto_relogio=p.id;a.visita.ponto_tempo=0.0
		a.visita.turno_automatico=bool(a.visita.get("turno_automatico",a.automatico));a.automatico=false;return true
	return false
func liberar(a:PersonagemPlex) -> void:
	var p:Dictionary=jogo.planta.objetos.get(int(a.visita.get("ponto_relogio",-1)),{})
	if int(p.get("reserva",0))==a.identificador:p.reserva=0
	a.visita.erase("ponto_relogio");a.visita.erase("ponto_tempo")
func registrar(a:PersonagemPlex,entrada:bool) -> bool:
	if not uniformizado(a) or entrada==bool(a.visita.get("ponto_ativo",false)):return false
	a.visita.ponto_ativo=entrada
	var registros:Array=a.visita.get("ponto_registros",[])
	registros.append({"dia":int(jogo.calendario.dias),"minuto":float(jogo.calendario.minutos),"entrada":entrada,"uniforme":a.uniforme})
	while registros.size()>120:registros.pop_front()
	a.visita.ponto_registros=registros;return true
func atualizar(delta:float) -> void:
	for a in jogo.personagens:
		if not TurnosEquipePlex.trabalhador(a):continue
		if a.visita.get("ponto_ativo",false) and uniformizado(a) and not a.visita.get("fora_turno",false):
			var minutos:=delta*CalendarioPlex.MINUTOS_POR_SEGUNDO
			a.visita.minutos_trabalhados=float(a.visita.get("minutos_trabalhados",0))+minutos;a.visita.minutos_folha=float(a.visita.get("minutos_folha",0))+minutos
		var etapa:=str(a.visita.get("turno_etapa",""))
		if etapa=="aguardar_ponto":iniciar(a,not a.visita.get("ponto_ativo",false));continue
		if etapa not in ["ponto_entrada","ponto_saida"]:continue
		var entrada:=etapa=="ponto_entrada"
		var p:Dictionary=jogo.planta.objetos.get(int(a.visita.get("ponto_relogio",-1)),{})
		if not uniformizado(a):liberar(a);a.visita.turno_etapa="chegando" if entrada else "ir_trocar_saida";continue
		if p.is_empty():
			liberar(a)
			if not iniciar(a,entrada):a.visita.turno_etapa="aguardar_ponto"
			continue
		var dono:=int(p.get("reserva",0));var outro:PersonagemPlex=jogo.clientes.ator(dono)
		if dono!=0 and dono!=a.identificador and is_instance_valid(outro) and str(outro.visita.get("turno_etapa","")).begins_with("ponto_"):a.trabalho="aguardar_ponto";continue
		p.reserva=a.identificador
		if a.ocupado():continue
		if not jogo.planta.interacoes(int(p.id)).has(a.celula):
			var rota:Array[Vector2i]=jogo.rotas.aproximar(a.origem_rota(),int(p.id))
			if not rota.is_empty():a.andar(rota);a.trabalho="ir_bater_ponto"
			continue
		a.trabalho="usar_armario";jogo.tarefas.orientar(a,Vector2(p.celula));a.visita.ponto_tempo=float(a.visita.get("ponto_tempo",0))+delta
		if float(a.visita.ponto_tempo)<1.0:continue
		registrar(a,entrada);p.estado="manha" if entrada else "tarde";liberar(a)
		if entrada:jogo.turnos.voltar(a)
		else:a.visita.turno_etapa="ir_trocar_saida";a.trabalho="ir_vestiario_saida"
