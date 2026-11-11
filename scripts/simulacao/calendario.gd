class_name CalendarioPlex
extends RefCounted

const MESES = ["Janeiro","Fevereiro","Março","Abril","Maio","Junho","Julho","Agosto","Setembro","Outubro","Novembro","Dezembro"]
const CLIMAS = ["Ensolarado","Nublado","Chuva","Calor","Neve"]
const INICIO_UNIX = -378691200
const DIAS_MESES = [31,28,31,30,31,30,31,31,30,31,30,31,31]
const TOTAL_MESES = 13
const MINUTOS_POR_SEGUNDO=1.0/3.0
var dias := 0
var minutos := 480.0
var agenda: Dictionary = {}
var semente := 1958
var perfis: Array = []
var cache: Dictionary = {}

func _init() -> void:
	var configuracao: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://dados/cidade/clima_mensal.json"))
	perfis = configuracao.meses

func atualizar(delta: float) -> void:
	minutos += maxf(0.0, delta)*MINUTOS_POR_SEGUNDO
	while minutos >= 1440.0:
		minutos -= 1440.0
		dias += 1

func minuto_do_dia() -> int:
	return int(minutos)

func data(deslocamento: int = 0) -> Dictionary:
	var valor := Time.get_datetime_dict_from_unix_time(INICIO_UNIX + (dias + deslocamento) * 86400)
	return {"dia":int(valor.day),"mes":int(valor.month),"ano":int(valor.year),"semana":int(valor.weekday)}

func inicio_mes(indice: int) -> int:
	var resultado := 0
	for i in clampi(indice,0,TOTAL_MESES): resultado += DIAS_MESES[i]
	return resultado

func indice_mes() -> int:
	var d := data()
	return clampi((int(d.ano)-1958)*12+int(d.mes)-1,0,TOTAL_MESES-1)

func hora() -> String:
	return "%02d:%02d" % [floori(minutos / 60.0), int(minutos) % 60]

func periodo() -> String:
	return "noite" if minutos < 330 or minutos >= 1170 else "entardecer" if minutos >= 960 else "sol"

func perfil(deslocamento: int = 0) -> Dictionary:
	return perfis[int(data(deslocamento).mes)-1]

func estacao(deslocamento: int = 0) -> String:
	return str(perfil(deslocamento).estacao)

func sorteio(dia: int, canal: int = 0) -> int:
	var numero := posmod((dia+370)*1103515245+semente*12345+canal*2654435761,2147483647)
	return posmod(numero ^ (numero >> 11),100)

func previsao(deslocamento: int = 0) -> String:
	var dia := dias+deslocamento
	if cache.has(dia): return cache[dia]
	var d := data(deslocamento)
	var p := perfil(deslocamento)
	var valor := sorteio(dia)
	var resultado := "Ensolarado"
	if int(d.mes)==12 and int(d.dia) in [24,25]: resultado="Neve"
	elif valor<int(p.neve): resultado="Neve"
	elif valor<int(p.neve)+int(p.chuva): resultado="Chuva"
	elif valor<int(p.neve)+int(p.chuva)+int(p.nublado): resultado="Nublado"
	elif valor<int(p.neve)+int(p.chuva)+int(p.nublado)+int(p.calor): resultado="Calor"
	if cache.size()>800: cache.clear()
	cache[dia]=resultado
	return resultado

func temperatura(deslocamento: int = 0) -> int:
	var base := int(perfil(deslocamento).temperatura)
	var valor := base+posmod(sorteio(dias+deslocamento,2),7)-3
	match previsao(deslocamento):
		"Neve": return mini(-1,valor)
		"Chuva": return valor-2
		"Calor": return maxi(30,valor+5)
	return valor

func intensidade() -> float:
	return .4+float(sorteio(dias,4))*.006 if previsao() in ["Chuva","Neve"] else .35

func variacao() -> String:
	var tempo := previsao()
	if tempo=="Neve": return "neve"
	if tempo=="Chuva": return "outono_chuva" if estacao()=="Outono" else "chuva"
	return "outono" if estacao()=="Outono" else "padrao"

func evento(deslocamento: int = 0) -> String:
	var d := data(deslocamento)
	if int(d.mes)==12 and int(d.dia)==24: return "Véspera de Natal"
	if int(d.mes)==12 and int(d.dia)==25: return "Natal"
	if int(d.mes)==12 and int(d.dia)==31: return "Véspera de Ano-Novo"
	if int(d.mes)==1 and int(d.dia)==1: return "Ano-Novo"
	return ""

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

func gravar() -> Dictionary:
	return {"versao_calendario":2,"dias":dias,"minutos":minutos,"agenda":agenda.duplicate(true),"semente":semente}

func restaurar(valor: Dictionary) -> void:
	dias = maxi(0,int(valor.get("dias",0)))
	minutos = clampf(float(valor.get("minutos",480.0)),0.0,1439.99)
	agenda = valor.get("agenda",{}).duplicate(true)
	semente = int(valor.get("semente",1958)) if int(valor.get("versao_calendario",0))>=2 else 1958
	cache.clear()
