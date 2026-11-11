class_name PosesPlex
extends RefCounted

var planta: PlantaPlex
var rotas: RotasPlex
var personagens: Array

func _init(p: PlantaPlex, r: RotasPlex, atores: Array) -> void:
	planta = p
	rotas = r
	personagens = atores

func valida(id: int) -> bool:
	if not planta.objetos.has(id): return false
	var item: Dictionary = planta.objetos[id]
	if item.tipo=="pose_montagem": return item.get("confirmado",false) and planta.em(item.celula).get("tipo","") in ["","palco"]
	if item.tipo=="pose_quebrado": return planta.em(item.celula).is_empty() and is_zero_approx(planta.altura(item.celula))
	return item.tipo=="pose" and (planta.em(item.celula).is_empty() or EscadasPlex.palco(planta.em(item.celula)))

func livre(id: int, ator: PersonagemPlex) -> bool:
	if not valida(id):
		return false
	var celula: Vector2i = planta.objetos[id].celula
	for outro in personagens:
		if outro != ator and (outro.pose == id or outro.celula == celula or (outro.movimento.atravessando and outro.movimento.destino == celula)):
			return false
	return true

func planejar(ator: PersonagemPlex, preferida: int = -1) -> Dictionary:
	if not ator.pronto_para_destino():
		return {}
	var destino: int = -1
	var melhor: Array[Vector2i] = []
	for item in planta.objetos.values():
		if not adequada(item,ator) or (preferida >= 0 and item.id != preferida) or not livre(item.id, ator):
			continue
		var caminho := rotas.sair_suporte(ator.suporte, item.celula) if ator.suporte >= 0 else rotas.caminho(ator.origem_rota(), item.celula)
		if CatalogoMontagemPlex.quebrado(ator.modelo) and caminho.any(func(c):return planta.altura(c)>0 or planta.em(c).get("tipo","")=="escada"): continue
		if not caminho.is_empty() and (destino < 0 or caminho.size() < melhor.size()):
			destino = item.id
			melhor = caminho
	if destino < 0:
		return {}
	return {"pose": destino, "caminho": melhor}

func encaminhar(ator: PersonagemPlex, preferida: int = -1) -> bool:
	if ator.aguardando_saida or AnimatronicosPlex.pausado(ator):
		return false
	var plano := planejar(ator, preferida)
	if plano.is_empty():
		return false
	var destino: int = plano.pose
	var melhor: Array[Vector2i] = plano.caminho
	ator.pose = destino
	if ator.suporte >= 0:
		planta.objetos[ator.suporte].robo_saiu = true
		ator.suporte = -1
	ator.trabalho = "ir_pose"
	ator.andar(melhor)
	return true

func retirar_sem_pose(ator: PersonagemPlex) -> bool:
	if encaminhar(ator):
		return true
	var melhor: Array[Vector2i] = []
	for y in GradePlex.TAMANHO.y:
		for x in GradePlex.TAMANHO.x:
			var destino := Vector2i(x, y)
			if not planta.transitavel(destino) or not is_zero_approx(planta.altura(destino)):
				continue
			if personagens.any(func(outro): return outro != ator and outro.celula == destino):
				continue
			var rota := rotas.caminho(ator.origem_rota(), destino)
			if not rota.is_empty() and (melhor.is_empty() or rota.size() < melhor.size()):
				melhor = rota
	if melhor.is_empty():
		return false
	ator.trabalho = ""
	ator.andar(melhor)
	return true

func atualizar() -> void:
	var reservadas: Dictionary = {}
	for ator in personagens:
		if OficinaRobosPlex.controlado(ator):continue
		var pausado: bool=ator.robo and AnimatronicosPlex.pausado(ator)
		if pausado and not ator.visita.get("recolhendo_deposito",false) and ator.trabalho!="ir_manutencao": ator.movimento.cancelar()
		if ator.pose >= 0:
			if not valida(ator.pose) or not adequada(planta.objetos.get(ator.pose,{}),ator) or reservadas.has(ator.pose):
				ator.pose = -1
				ator.trabalho = ""
				ator.movimento.cancelar()
			else:
				reservadas[ator.pose] = ator.identificador
				var marca: Dictionary = planta.objetos[ator.pose]
				if not ator.ocupado():
					if ator.celula == marca.celula:
						ator.direcao = GradePlex.direcao_suporte(marca.rotacao)
						ator.trabalho = "reservado_pecas" if marca.tipo=="pose_quebrado" else "apresentar"
					elif ator.automatico and not pausado:
						ator.trabalho = "ir_pose"
						var caminho := rotas.caminho(ator.celula, marca.celula)
						if not caminho.is_empty():
							ator.andar(caminho)
		if ator.pose < 0 and ator.trabalho == "apresentar":
			ator.trabalho = ""
		if ator.robo and ator.modelo != "endo" and ator.pose < 0 and not pausado and not ator.ocupado() and planta.em(ator.celula).get("tipo", "") == "palco":
			retirar_sem_pose(ator)

func adequada(item: Dictionary, ator: PersonagemPlex) -> bool:
	if ator.visita.has("destino_montagem"):
		return int(item.get("id",-1))==int(ator.visita.destino_montagem) and item.get("dono",-1)==ator.identificador
	if item.get("tipo","")=="pose_montagem": return false
	if CatalogoMontagemPlex.quebrado(ator.modelo):
		return item.get("tipo","")=="pose_quebrado" and item.get("dono",-1)==ator.identificador
	return item.get("tipo","")=="pose"


