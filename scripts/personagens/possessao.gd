class_name PossessaoPlex
extends RefCounted

static func registrar(a: PersonagemPlex) -> void:
	AnimatronicosPlex.garantir(a)
	if a.robotica.get("sangrando",false): return
	a.robotica.merge({"sangrando":true,"assombrado":true,"tempo_sangue":0.0,"surto":0.0,"proximo_surto":0.0},true)
	a.movimento.cancelar()
	AnimatronicosPlex.mudar(a,"sangrando")

static func limpar(a: PersonagemPlex) -> void:
	a.robotica.sangrando=false
	a.robotica.assombrado=true
	a.robotica.surto=0.0
	a.robotica.proximo_surto=18.0+float(posmod(a.identificador*7,15))
	a.robotica.desligado_manual=false
	AnimatronicosPlex.mudar(a,"desligado")

static func atualizar(a: PersonagemPlex, delta: float) -> bool:
	if int(a.visita.get("corpo_oculto",-1))>0 and not a.robotica.has("assombrado"): registrar(a)
	if a.robotica.get("sangrando",false):
		a.robotica.tempo_sangue=float(a.robotica.get("tempo_sangue",0.0))+maxf(0,delta)
		a.movimento.cancelar()
		AnimatronicosPlex.mudar(a,"sangrando")
		return true
	if not a.robotica.get("assombrado",false): return false
	var ativo: bool=not AnimatronicosPlex.pausado(a) and (a.ocupado() or a.robotica.get("estado","")=="ligado" and a.trabalho=="apresentar")
	if not ativo:
		a.robotica.surto=0.0
		return false
	if float(a.robotica.get("surto",0.0))>0.0:
		a.robotica.surto=maxf(0,float(a.robotica.surto)-delta)
		return false
	a.robotica.proximo_surto=float(a.robotica.get("proximo_surto",18.0))-delta
	if float(a.robotica.proximo_surto)<=0:
		var rodada:=int(a.robotica.get("surtos",0))+1
		a.robotica.surtos=rodada
		a.robotica.surto=1.0+float(posmod(a.identificador*11+rodada*7,11))*.1
		a.robotica.proximo_surto=14.0+float(posmod(a.identificador*3+rodada*13,19))
	return false

static func acao(a: PersonagemPlex, normal: String, andando: bool) -> String:
	if a.robotica.get("sangrando",false) and ClipesPlex.possui(a.modelo,"sangrando"): return "sangrando"
	if not andando:
		var pose:=str(a.visita.get("controle_pose","")) if a.visita.has("controle_animatronico") else str(a.robotica.get("pose_dia","")) if normal in ["cantar","parado","apresentar","dancar","falar"] else ""
		if not pose.is_empty() and ClipesPlex.possui(a.modelo,pose):return pose
	if a.visita.has("controle_animatronico") and a.relogio-float(a.visita.get("controle_inicio",-999.0))<AnimatronicosPlex.duracao_partida(a):return "ativando"
	if a.visita.has("controle_animatronico") and not andando:
		if a.visita.get("controle_desligado",false):return "desligado"
		if a.visita.get("controle_cantando",false) and ClipesPlex.possui(a.modelo,"cantar"):return "cantar"
	if not andando and str(a.robotica.get("espirito",""))=="medio" and normal in ["cantar","falar","apresentar","dancar"] and fposmod(a.relogio+float(a.identificador)*7.0,40.0)<1.6 and ClipesPlex.possui(a.modelo,"cantar_possuido"):return "cantar_possuido"
	var debug: bool=a.visita.has("controle_animatronico")
	if not debug and float(a.robotica.get("surto",0.0))<=0.0: return normal
	var variante: String="andar_possuido" if andando else "cantar_possuido" if debug or normal in ["cantar","falar","apresentar","parado","dancar"] else ""
	return variante if not variante.is_empty() and ClipesPlex.possui(a.modelo,variante) else normal
