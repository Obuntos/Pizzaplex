class_name ResumoNoitePlex
extends RefCounted

var jogo:Node
var ativo:=false
var dados:Dictionary={}
var espera:=0.0

func _init(cena:Node) -> void:jogo=cena
func noite() -> bool:return float(jogo.calendario.minutos)>=1380.0 or float(jogo.calendario.minutos)<360.0

func atualizar(delta:float) -> void:
	espera+=delta
	if espera<1.0:return
	espera=0.0
	var s=jogo.sistemas
	if noite() and not ativo:
		ativo=true
		dados={"medo":{},"incidentes":s.investigacao.historico.size(),"fitas":int(s.vhs.proximo),"quedas":int(s.tempestade.quedas),"trancas":int(s.guarda.trancamentos)}
	if not ativo:return
	if noite():
		for a in jogo.personagens:
			if s.caca.guarda(a):
				var nome:=IdentidadesPlex.completo(a)
				dados.medo[nome]=maxf(float(dados.medo.get(nome,0.0)),s.caca.medo(a))
		return
	ativo=false
	mostrar()

func mostrar() -> void:
	var s=jogo.sistemas
	var linhas:Array=[]
	if dados.medo.is_empty():linhas.append({"nome":"Segurança","valor":"Sem turno","formato":"texto"})
	for nome in dados.medo:
		var medo:=roundi(float(dados.medo[nome]))
		linhas.append({"nome":str(nome),"valor":"Medo %d / 4"%medo,"formato":"texto","alerta":medo>=3})
	var incidentes:=0
	for h in s.investigacao.historico.slice(int(dados.incidentes)):
		if h.get("incidente",false):incidentes+=1
	linhas.append({"nome":"Ataques e mortes","valor":incidentes,"alerta":incidentes>0})
	linhas.append({"nome":"Fitas VHS gravadas","valor":int(s.vhs.proximo)-int(dados.fitas)})
	linhas.append({"nome":"Quedas de energia","valor":int(s.tempestade.quedas)-int(dados.quedas)})
	linhas.append({"nome":"Portas trancadas","valor":int(s.guarda.trancamentos)-int(dados.trancas)})
	CartazDinerPlex.resumo(jogo,"06:00","Noite",linhas,incidentes==0)
