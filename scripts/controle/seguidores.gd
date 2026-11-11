class_name SeguidoresAdministradorPlex
extends RefCounted

var referencia: WeakRef
var controle: ControleAdministradorPlex:
	get: return referencia.get_ref()
var espera := 0.0

func _init(c: ControleAdministradorPlex) -> void:
	referencia=weakref(c)

func lista() -> Array:
	return controle.jogo.personagens.filter(func(a): return int(a.visita.get("seguindo_adm",-1))>0 and not a.visita.get("morto",false))

func adicionar(a: PersonagemPlex) -> bool:
	var admin := controle.administrador()
	if not is_instance_valid(admin) or not is_instance_valid(a) or a==admin or a.robo or ControleAdministradorPlex.ocupado(a): return false
	if lista().size()>=4:
		controle.aviso("Você já está acompanhado por quatro pessoas.")
		return false
	a.visita.seguindo_automatico=a.automatico
	a.visita.seguindo_tinha_etapa=a.visita.has("etapa")
	a.visita.seguindo_etapa=str(a.visita.get("etapa",""))
	controle.interromper(a)
	a.visita.seguindo_adm=admin.identificador
	a.visita.seguindo_inicio=float(controle.jogo.calendario.dias)*1440.0+controle.jogo.calendario.minutos
	a.automatico=false
	a.trabalho="seguir_administrador"
	controle.aviso(IdentidadesPlex.completo(a)+" vai acompanhar você.")
	return true

func dispensar(a: PersonagemPlex) -> void:
	if not is_instance_valid(a): return
	a.visita.erase("seguindo_adm");a.visita.erase("seguindo_inicio")
	a.automatico=bool(a.visita.get("seguindo_automatico",true))
	if a.visita.get("seguindo_tinha_etapa",true): a.visita.etapa=str(a.visita.get("seguindo_etapa","arcade"))
	else: a.visita.erase("etapa")
	a.visita.erase("seguindo_tinha_etapa")
	a.visita.erase("seguindo_automatico")
	a.visita.erase("seguindo_etapa")
	a.movimento.cancelar()
	a.trabalho=""

func dispensar_todos() -> void:
	for a in lista(): dispensar(a)

func atualizar(delta: float) -> void:
	espera+=delta
	if espera<.35: return
	espera=0.0
	var admin:=controle.administrador()
	if not is_instance_valid(admin) or admin.visita.get("morto",false):
		dispensar_todos()
		return
	var reservados: Array[Vector2i]=[admin.origem_rota()]
	var anterior:=admin
	for a in lista():
		if not a.visita.has("seguindo_inicio"):a.visita.seguindo_inicio=float(controle.jogo.calendario.dias)*1440.0+controle.jogo.calendario.minutos
		if a.cargo in ["crianca","adolescente"] and float(controle.jogo.calendario.dias)*1440.0+controle.jogo.calendario.minutos-float(a.visita.get("seguindo_inicio",0))>=DiversaoFamiliaPlex.PACIENCIA_MASCOTE:
			CirculacaoVisitantesPlex.encerrar_espera(controle.jogo,a);continue
		if int(a.visita.seguindo_adm)!=admin.identificador:
			dispensar(a)
			continue
		if a.ocupado():
			reservados.append(a.movimento.rota[-1] if not a.movimento.rota.is_empty() else a.origem_rota())
			anterior=a
			continue
		if a.local.distance_to(anterior.local)<1.8 and not admin.movimento.rota.has(a.celula):
			controle.jogo.tarefas.orientar(a,anterior.local)
			reservados.append(a.celula)
			anterior=a
			continue
		var candidatos: Array[Vector2i]=[]
		for raio in [1,2,3]:
			for d in GradePlex.VIZINHOS:
				var c: Vector2i=anterior.origem_rota()+d*raio
				if reservados.has(c) or not controle.jogo.planta.transitavel(c) or admin.movimento.rota.has(c): continue
				if controle.jogo.personagens.any(func(o): return o!=a and not o.visita.get("morto",false) and o.origem_rota()==c): continue
				candidatos.append(c)
		candidatos.sort_custom(func(x,y): return a.local.distance_squared_to(Vector2(x))+Vector2(x).distance_squared_to(anterior.local)*2<a.local.distance_squared_to(Vector2(y))+Vector2(y).distance_squared_to(anterior.local)*2)
		for c in candidatos:
			var rota:Array[Vector2i]=CirculacaoVisitantesPlex.rota(controle.jogo,a.origem_rota(),c) if a.cargo in ["crianca","adolescente"] else controle.jogo.rotas.caminho(a.origem_rota(),c)
			if rota.is_empty(): continue
			a.andar(rota)
			a.trabalho="seguir_administrador"
			reservados.append(c)
			break
		anterior=a
