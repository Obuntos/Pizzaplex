class_name CalendarioPlex
extends RefCounted

const MESES = ["Janeiro","Fevereiro","Março","Abril","Maio","Junho","Julho","Agosto","Setembro","Outubro","Novembro","Dezembro"]
const CLIMAS = ["Ensolarado","Nublado","Chuva","Calor","Neve"]
var dias := 0
var minutos := 480.0
var agenda: Dictionary = {}
var semente := 1965

func atualizar(delta: float) -> void:
	minutos += maxf(0.0, delta)
	while minutos >= 1440.0:
		minutos -= 1440.0
		dias += 1

func minuto_do_dia() -> int:
	return int(minutos)

func data(deslocamento: int = 0) -> Dictionary:
	var valor := Time.get_datetime_dict_from_unix_time(-157766400 + (dias + deslocamento) * 86400)
	return {"dia":int(valor.day),"mes":int(valor.month),"ano":int(valor.year),"semana":int(valor.weekday)}

func hora() -> String:
	return "%02d:%02d" % [floori(minutos / 60.0), int(minutos) % 60]

func periodo() -> String:
	return "noite" if minutos < 330 or minutos >= 1170 else "entardecer" if minutos >= 960 else "sol"

func previsao(deslocamento: int = 0) -> String:
	var d := data(deslocamento)
	var numero := posmod((dias+deslocamento)*37 + semente*13, 100)
	if d.mes in [6,7,8] and numero < 18: return "Neve"
	if numero < 28: return "Chuva"
	if numero < 48: return "Nublado"
	if d.mes in [12,1,2] and numero > 72: return "Calor"
	return "Ensolarado"

func temperatura(deslocamento: int = 0) -> int:
	return {"Neve":-2,"Chuva":18,"Nublado":21,"Calor":33,"Ensolarado":26}.get(previsao(deslocamento),22) + posmod(dias+deslocamento,3)

func luz_ambiente() -> float:
	return float(estado_solar().ambiente)

func estado_solar() -> Dictionary:
	return CicloSolarPlex.estado(minutos,previsao())

func chave(dia: int, palco: int) -> String:
	return str(dia)+":"+str(palco)

func horarios(dia: int, palco: int) -> Array:
	return agenda.get(chave(dia,palco),[480,720,960]).duplicate()

func alternar(dia: int, palco: int, horario: int) -> void:
	var lista := horarios(dia,palco)
	if lista.has(horario): lista.erase(horario)
	else: lista.append(horario)
	lista.sort()
	agenda[chave(dia,palco)] = lista

func show_agora(palco: int) -> bool:
	for inicio in horarios(dias,palco):
		if minutos >= float(inicio) and minutos < float(inicio) + 240.0: return true
	return false

func gravar() -> Dictionary:
	return {"dias":dias,"minutos":minutos,"agenda":agenda.duplicate(true),"semente":semente}

func restaurar(valor: Dictionary) -> void:
	dias = maxi(0,int(valor.get("dias",0)))
	minutos = clampf(float(valor.get("minutos",480.0)),0.0,1439.99)
	agenda = valor.get("agenda",{}).duplicate(true)
	semente = int(valor.get("semente",1965))
