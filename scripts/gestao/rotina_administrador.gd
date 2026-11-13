class_name RotinaAdministradorPlex
extends RefCounted

var jogo: Node
var caminhos: CaminhosCidadePlex
var espera:=0.0
var tentativa_rota:=0.0

func _init(cena: Node) -> void:
	jogo=cena
	caminhos=CaminhosCidadePlex.new(jogo.planta,jogo.rotas)

func agora() -> float:
	return float(jogo.calendario.dias)*1440.0+jogo.calendario.minutos

func casa() -> Dictionary:
	for item in jogo.planta.objetos.values():
		if item.tipo==CaminhosCidadePlex.CASA:
			item.casa_administrador=true
			return item
	return {}

func trabalho() -> Vector2i:
	var area:=TerrenoPlex.area(jogo.planta)
	for item in jogo.planta.objetos.values():
		if item.tipo not in CatalogoPlex.PORTAS or not TerrenoPlex.protegido(jogo.planta,item): continue
		for c in jogo.planta.celulas(item.tipo,item.celula,item.rotacao):
			for d in GradePlex.VIZINHOS:
				var destino: Vector2i=c+d
				if area.grow(-1).has_point(destino) and jogo.planta.transitavel(destino): return destino
	return Vector2i(area.get_center())

func atualizar_lar(a: PersonagemPlex) -> void:
	var lar:=casa()
	var presente: bool=is_instance_valid(a) and not a.visita.get("morto",false) and str(a.visita.get("rotina_casa_etapa",""))=="em_casa" and bool(a.visita.get("fora_turno",false))
	if presente and not a.visita.has("casa_chegada"):
		var noite:=float(jogo.calendario.dias)*1440.0+1380.0
		if jogo.calendario.minutos<720.0: noite-=1440.0
		a.visita.casa_chegada=minf(agora(),noite)
	jogo.iluminacao.cidade.definir_lar(int(lar.get("id",-1)),presente,agora(),float(a.visita.get("casa_chegada",-1.0)) if presente else -1.0)

func cancelar(a: PersonagemPlex) -> void:
	if str(a.visita.get("rotina_casa_etapa","")).is_empty(): return
	a.visita.erase("rotina_casa_etapa")
	a.visita.erase("fora_turno")
	a.automatico=true
	a.show()
	a.trabalho=""
	a.movimento.cancelar()
	a.visita.erase("casa_chegada")
	atualizar_lar(a)

func sair(a: PersonagemPlex) -> void:
	if agora()<tentativa_rota: return
	tentativa_rota=agora()+2.0
	var lar:=casa()
	if lar.is_empty(): return
	var entrada: Vector2i=CaminhosCidadePlex.acesso(lar)[-1]
	var rota:=caminhos.caminho(a.origem_rota(),entrada)
	if rota.is_empty():
		return
	a.visita.casa_destino=[entrada.x,entrada.y]
	a.visita.rotina_casa_etapa="indo"
	a.visita.erase("fora_turno")
	a.show()
	a.trabalho="ir_para_casa"
	a.andar(rota)
	var volta:=caminhos.caminho(entrada,trabalho())
	var duracao:=caminhos.duracao(volta)+.35
	var dia: int=jogo.calendario.dias+(1 if jogo.calendario.minutos>=1380.0 else 0)
	a.visita.casa_turno=float(dia)*1440.0+360.0
	a.visita.casa_partida=float(a.visita.casa_turno)-duracao

func iniciar(a: PersonagemPlex) -> void:
	jogo.atracoes.pausar_ator(a,"Aguardando")
	jogo.controle.interromper(a)
	tentativa_rota=0.0
	a.automatico=false
	a.visita.erase("comando_manual_ate")
	a.visita.rotina_casa_etapa="trocar" if a.modelo.begins_with("fantasia_") else "preparar_saida"
	a.visita.casa_troca=0.0
	a.trabalho="ir_para_casa"

func atualizar(delta: float) -> void:
	espera+=delta
	if espera<.25: return
	var tempo:=espera
	espera=0.0
	var a: PersonagemPlex=jogo.controle.administrador()
	atualizar_lar(a)
	if not is_instance_valid(a) or a.visita.get("morto",false): return
	if a.visita.get("tutorial_ativo",false) or TurnosEquipePlex.ocupado(a) or a.visita.get("estudando",false) or a.visita.get("controle_manual",false) or a.visita.get("socializando",false) or jogo.controle.acao.get("tipo","")=="limpar_robo": return
	var fase:=str(a.visita.get("rotina_casa_etapa",""))
	var lar:=casa()
	if fase in ["indo","em_casa"] and not lar.is_empty():
		var soleira: Vector2i=CaminhosCidadePlex.acesso(lar)[-1]
		var antiga: Array=a.visita.get("casa_destino",[soleira.x,soleira.y])
		if Vector2i(antiga[0],antiga[1])!=soleira:
			a.visita.casa_destino=[soleira.x,soleira.y]
			if fase=="em_casa":
				a.movimento.cancelar();a.celula=soleira;a.local=Vector2(soleira)
			else:
				a.movimento.cancelar()
				a.visita.rotina_casa_etapa="preparar_saida"
				tentativa_rota=0.0
				return
	if fase.is_empty():
		if jogo.operacao.aberto: return
		if (jogo.calendario.minutos>=1380.0 or jogo.calendario.minutos<300.0) and not casa().is_empty(): iniciar(a)
		return
	match fase:
		"trocar":
			if not a.modelo.begins_with("fantasia_"):
				a.visita.rotina_casa_etapa="preparar_saida"
				return
			if jogo.fantasias.mover_armario(a):
				a.trabalho="usar_armario"
				a.visita.casa_troca=float(a.visita.casa_troca)+tempo
				if float(a.visita.casa_troca)<1.5: return
				jogo.fantasias.retirar(a)
				a.visita.rotina_casa_etapa="preparar_saida"
			elif int(a.visita.get("fantasia_armario",-1))<0:
				jogo.fantasias.retirar(a)
				a.visita.rotina_casa_etapa="preparar_saida"
		"preparar_saida":
			if not a.ocupado(): sair(a)
		"indo":
			if a.ocupado(): return
			var destino: Array=a.visita.get("casa_destino",[-1,-1])
			if a.celula!=Vector2i(destino[0],destino[1]): sair(a); return
			a.visita.rotina_casa_etapa="em_casa"
			a.visita.fora_turno=true
			a.visita.casa_chegada=agora()
			atualizar_lar(a)
			a.trabalho="dormir_em_casa"
			a.hide()
		"em_casa":
			a.hide()
			if agora()<float(a.visita.get("casa_partida",INF)): return
			var rota:=caminhos.caminho(a.celula,trabalho())
			if rota.is_empty(): return
			TurnosEquipePlex.recuperar_descanso(a)
			a.visita.erase("fora_turno")
			a.visita.rotina_casa_etapa="voltando"
			a.visita.erase("casa_chegada")
			atualizar_lar(a)
			a.trabalho="voltar_ao_restaurante"
			a.show()
			a.andar(rota)
		"voltando":
			if a.ocupado(): return
			if a.celula!=trabalho():
				var rota:=caminhos.caminho(a.origem_rota(),trabalho())
				if not rota.is_empty(): a.andar(rota)
				return
			a.visita.rotina_casa_etapa="aguardar_turno"
			a.trabalho="aguardar_turno"
		"aguardar_turno":
			if agora()<float(a.visita.get("casa_turno",0)): return
			a.visita.erase("rotina_casa_etapa")
			a.visita.erase("fora_turno")
			a.automatico=true
			TurnosEquipePlex.recuperar_descanso(a)
			a.trabalho=""
