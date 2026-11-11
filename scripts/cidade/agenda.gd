class_name AgendaMoradoresPlex
extends RefCounted

const DIAS={0:"domingo",1:"segunda",2:"terca",3:"quarta",4:"quinta",5:"sexta",6:"sabado"}
var fila: Array[Dictionary]=[]

static func semana(dia: int) -> int:
	return int(Time.get_datetime_dict_from_unix_time(CalendarioPlex.INICIO_UNIX+dia*86400).weekday)

static func rotina(perfil: Dictionary, dia: int) -> Array:
	var original: Array=perfil.rotinas.get(DIAS[semana(dia)],perfil.rotinas.get("util",[]))
	return EscolaBairroPlex.rotina(perfil,dia,original)

static func situacao(perfil: Dictionary, agora: float) -> Dictionary:
	var dia:=floori(agora/1440.0)
	var atual: Dictionary={"quando":-INF,"atividade":"Dormindo em casa","local":"casa","modo":"sono","transporte":"pe"}
	var anterior: Dictionary=atual
	var proximo: Dictionary={"quando":INF}
	for d in range(dia-2,dia+3):
		for evento in rotina(perfil,d):
			var quando:=float(d*1440+int(evento.minuto))
			var e: Dictionary=evento.duplicate();e.quando=quando
			if quando<=agora:
				if quando>=float(atual.quando): anterior=atual;atual=e
			elif quando<float(proximo.quando): proximo=e
	return {"atual":atual,"anterior":anterior,"proximo":proximo}

func inserir(id: String, quando: float) -> void:
	if is_inf(quando): return
	fila.append({"id":id,"quando":quando})
	var i:=fila.size()-1
	while i>0:
		var pai:=floori(float(i-1)/2.0)
			
		if float(fila[pai].quando)<=quando: break
		var t: Dictionary=fila[pai];fila[pai]=fila[i];fila[i]=t;i=pai

func retirar() -> Dictionary:
	var resultado: Dictionary=fila[0]
	var ultimo: Dictionary=fila.pop_back()
	if fila.is_empty(): return resultado
	fila[0]=ultimo
	var i:=0
	while i*2+1<fila.size():
		var filho:=i*2+1
		if filho+1<fila.size() and float(fila[filho+1].quando)<float(fila[filho].quando): filho+=1
		if float(fila[i].quando)<=float(fila[filho].quando): break
		var t: Dictionary=fila[filho];fila[filho]=fila[i];fila[i]=t;i=filho
	return resultado

