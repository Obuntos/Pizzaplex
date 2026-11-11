class_name IncidentesPlex
extends RefCounted

var referencia: WeakRef
var controle: ControleAdministradorPlex:
	get: return referencia.get_ref()
var espera:=0.0

func _init(c: ControleAdministradorPlex) -> void:
	referencia=weakref(c)

func linha_livre(a: Vector2, b: Vector2) -> bool:
	var passos:=maxi(1,ceili(a.distance_to(b)*5))
	for i in range(1,passos):
		var c:=Vector2i(a.lerp(b,float(i)/passos).round())
		var item: Dictionary=controle.jogo.planta.em(c)
		if item.get("tipo","") in SalasPlex.ESTRUTURA and not item.get("aberta",false): return false
	return true

func testemunhas(vitima: PersonagemPlex) -> Array:
	var admin:=controle.administrador()
	return controle.jogo.personagens.filter(func(a): return a!=vitima and a!=admin and not a.robo and not a.visita.get("morto",false) and VisaoNPCPlex.ve(controle.jogo,a,vitima))

func atacar(vitima: PersonagemPlex) -> bool:
	var admin:=controle.administrador()
	if not controle.manual() or not is_instance_valid(vitima) or vitima.robo or AdministradorPlex.eh(vitima) or vitima.visita.get("morto",false) or not admin.visita.get("faca_equipada",false): return false
	var presentes:=testemunhas(vitima)
	controle.jogo.sistemas.investigacao.registrar_incidente(vitima)
	controle.interromper(vitima)
	vitima.visita.erase("seguindo_adm")
	vitima.visita.erase("fugindo")
	vitima.visita.morto=true
	vitima.visita.morto_em=controle.jogo.calendario.dias*1440.0+controle.jogo.calendario.minutos
	vitima.visita.morto_direcao=vitima.direcao
	vitima.trabalho="morto"
	vitima.automatico=false
	vitima.animacao.expressao="cansado"
	controle.corpos.criar(vitima)
	vitima.visible=false
	GorePlex.espalhar(controle.jogo,vitima.celula,1,posmod(roundi(float(vitima.direcao)/2.0),4))
	if "seguranca" in controle.jogo and controle.jogo.seguranca!=null:controle.jogo.seguranca.registrar(vitima,presentes)
	for a in presentes: fugir(a)
	controle.aviso("Os presentes na sala fugiram." if not presentes.is_empty() else "Não havia testemunhas na sala.")
	return true

func fugir(a: PersonagemPlex) -> void:
	if a.visita.get("morto",false): return
	if int(a.visita.get("seguindo_adm",-1))>0: controle.seguidores.dispensar(a)
	controle.interromper(a)
	a.visita.fugindo=true
	a.visita.correndo=true
	a.visita.panico_espera=0.0
	a.automatico=false
	a.animacao.expressao="assustado"
	a.trabalho="fugir"

func destino(a: PersonagemPlex) -> Vector2i:
	var melhor:=Vector2i(-1,-1)
	var tamanho:=99999
	for c in controle.jogo.clientes.portas_externas():
		var porta: Dictionary=controle.jogo.planta.em(c)
		if porta.is_empty(): continue
		for sinal in [-1,1]:
			var fora: Vector2i=c+GradePlex.frente(porta.rotacao)*sinal*2
			if not controle.jogo.planta.transitavel(fora) or controle.jogo.ambientes.em(fora).get("fechada",false): continue
			var rota: Array[Vector2i]=controle.jogo.rotas.caminho(a.origem_rota(),fora)
			if not rota.is_empty() and rota.size()<tamanho: melhor=fora; tamanho=rota.size()
	if melhor.x>=0: return melhor
	var candidatos: Array[Vector2i]=[]
	for x in range(0,GradePlex.TAMANHO.x,3):
		candidatos.append(Vector2i(x,0)); candidatos.append(Vector2i(x,GradePlex.TAMANHO.y-1))
	for y in range(0,GradePlex.TAMANHO.y,3):
		candidatos.append(Vector2i(0,y)); candidatos.append(Vector2i(GradePlex.TAMANHO.x-1,y))
	candidatos.sort_custom(func(x,y): return x.distance_squared_to(a.celula)<y.distance_squared_to(a.celula))
	for c in candidatos:
		if not controle.jogo.planta.transitavel(c): continue
		var rota: Array[Vector2i]=controle.jogo.rotas.caminho(a.origem_rota(),c)
		if not rota.is_empty(): return c
	return melhor

func atualizar(delta: float) -> void:
	espera+=delta
	if espera<.3: return
	var tempo:=espera
	espera=0.0
	for a in controle.jogo.personagens.duplicate():
		if not a.visita.get("fugindo",false) or a.visita.get("morto",false): continue
		var alvo: Array=a.visita.get("panico_destino",[-1,-1])
		if not a.ocupado() and a.celula==Vector2i(alvo[0],alvo[1]) and not controle.jogo.ambientes.em(a.celula).get("fechada",false):
			controle.jogo.despawn(a)
			continue
		a.visita.panico_espera=maxf(0.0,float(a.visita.get("panico_espera",0.0))-tempo)
		if a.ocupado() or float(a.visita.panico_espera)>0: continue
		a.visita.panico_espera=2.0
		var fora:=destino(a)
		if fora.x<0: continue
		a.visita.panico_destino=[fora.x,fora.y]
		a.andar(controle.jogo.rotas.caminho(a.origem_rota(),fora))
		a.trabalho="fugir"
