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
	var linhas:=PackedStringArray(["Fim da noite. O controle dos animatrônicos foi encerrado.",""])
	if dados.medo.is_empty():linhas.append("Nenhum segurança em turno.")
	for nome in dados.medo:linhas.append("%s · medo máximo %d/4"%[nome,roundi(float(dados.medo[nome]))])
	var incidentes:=0
	for h in s.investigacao.historico.slice(int(dados.incidentes)):
		if h.get("incidente",false):incidentes+=1
	linhas.append("Ataques e mortes: %d"%incidentes)
	linhas.append("Fitas VHS gravadas: %d"%(int(s.vhs.proximo)-int(dados.fitas)))
	linhas.append("Quedas de energia: %d"%(int(s.tempestade.quedas)-int(dados.quedas)))
	linhas.append("Portas trancadas pelo segurança: %d"%(int(s.guarda.trancamentos)-int(dados.trancas)))
	var popup:=AcceptDialog.new()
	popup.title="Resumo da noite · 06:00"
	popup.dialog_text="\n".join(linhas)
	popup.ok_button_text="Fechar"
	popup.theme=preload("res://scripts/interface/tema_hud.gd").criar()
	jogo.add_child(popup)
	popup.confirmed.connect(popup.queue_free);popup.close_requested.connect(popup.queue_free)
	popup.popup_centered(Vector2i(460,320))
