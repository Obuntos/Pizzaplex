class_name CircuitoLuzesPlex
extends RefCounted

var estados: Dictionary={}
var tempo:=0.0
var revisao:=-1
var fontes: Array[Dictionary]=[]
var lampadas: Array[Dictionary]=[]
var energizado:=false
var palcos_ativos: Dictionary={}
var palcos: PalcosPlex

func sincronizar(planta: PlantaPlex) -> void:
	if revisao==planta.revisao: return
	revisao=planta.revisao
	if palcos==null or palcos.planta!=planta: palcos=PalcosPlex.new(planta)
	palcos.atualizar()
	fontes.clear();lampadas.clear()
	for item in planta.objetos.values():
		if MobiliaPlex.dados(item).get("gerador",false): fontes.append(item)
		elif LuminariasPlex.eh(item.tipo): lampadas.append(item)
	lampadas.sort_custom(func(a,b): return int(a.id)<int(b.id))
	for id in estados.keys():
		if not planta.objetos.has(id): estados.erase(id)

func carga(rede: RedeEnergiaPlex) -> float:
	var soma:=0.0
	var peso:=0.0
	for item in fontes:
		if not rede.conectado(item): continue
		var potencia:=float(MobiliaPlex.dados(item).get("potencia",1.0))
		soma+=float(item.get("combustivel",0))*potencia
		peso+=potencia
	return soma/maxf(.001,peso)/100.0

func atualizar(delta: float, planta: PlantaPlex, rede: RedeEnergiaPlex) -> void:
	tempo+=maxf(0.0,delta)
	sincronizar(planta)
	energizado=rede.fator>.001
	var nivel:=carga(rede)
	var ligar:=0
	var desligar:=0
	for item in lampadas:
		var id:=int(item.id)
		if not estados.has(id): estados[id]={"pedido":false,"valor":0.0,"inicio":tempo,"origem":0.0,"duracao":.65}
		var estado: Dictionary=estados[id]
		var palco:=int(palcos.grupos.get(item.celula,-1))
		var alvo:=energizado and bool(item.get("ligada",true)) and (palco<0 or bool(palcos_ativos.get(palco,false)))
		if alvo!=bool(estado.pedido):
			estado.origem=estado.valor
			estado.inicio=tempo+(ligar*.22 if alvo else desligar*.28)
			estado.duracao=.65 if alvo else 1.1
			estado.pedido=alvo
			if alvo: ligar+=1
			else: desligar+=1
		var progresso:=smoothstep(float(estado.inicio),float(estado.inicio)+float(estado.duracao),tempo)
		var fase:=float(posmod(id*37,97))/97.0
		var limite:=lerpf(.012,.065,fase)
		var reserva:=smoothstep(limite,limite+.018,nivel)
		var fragilidade:=maxf(1.0-smoothstep(.07,.20,nivel),1.0-smoothstep(.45,.98,rede.fator))
		var pulso:=pow(.5+.5*sin(tempo*(1.35+fase*.4)+fase*12.0),12.0)
		var tremor:=1.0-fragilidade*pulso*.30
		if LuminariasPlex.economica(item.tipo): tremor*=1.0-.025*pow(.5+.5*sin(tempo*2.1+id*1.734),6.0)
		var destino:=rede.fator*reserva*tremor if alvo else 0.0
		estado.valor=clampf(lerpf(float(estado.origem),destino,progresso),0.0,1.0)

func fator(id: int) -> float:
	return float(estados.get(id,{}).get("valor",0.0))
