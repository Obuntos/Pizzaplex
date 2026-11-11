class_name SaidaMontagemPlex
extends RefCounted

var planta: PlantaPlex
var rotas: RotasPlex
var poses: PosesPlex
var personagens: Array
var pendentes: Array[Dictionary] = []

func _init(p: PlantaPlex, r: RotasPlex, marcas: PosesPlex, atores: Array) -> void:
	planta = p
	rotas = r
	poses = marcas
	personagens = atores

func bloqueios(ator: PersonagemPlex) -> Array[Vector2i]:
	var locais: Array[Vector2i] = []
	for outro in personagens:
		if outro != ator:
			locais.append(outro.celula)
			if outro.movimento.atravessando:
				locais.append(outro.movimento.destino)
			if outro.trabalho == "liberar_saida" and not outro.movimento.rota.is_empty():
				locais.append(outro.movimento.rota[-1])
	return locais

func estacionamento(ajudante: PersonagemPlex, corredor: Array[Vector2i], suporte: int) -> Array[Vector2i]:
	var melhor: Array[Vector2i] = []
	var vetados := bloqueios(ajudante)
	var interacoes := planta.interacoes(suporte)
	var origem := ajudante.origem_rota()
	for raio in range(1,9):
		for y in range(maxi(0,origem.y-raio),mini(GradePlex.TAMANHO.y,origem.y+raio+1)):
			for x in range(maxi(0,origem.x-raio),mini(GradePlex.TAMANHO.x,origem.x+raio+1)):
				var local := Vector2i(x,y)
				if maxi(absi(x-origem.x),absi(y-origem.y))!=raio: continue
				if corredor.has(local) or interacoes.has(local) or vetados.has(local): continue
				if not planta.transitavel(local) or not is_zero_approx(planta.altura(local)): continue
				if planta.em(local).get("tipo","") in (CatalogoPlex.PORTAS+["escada"]): continue
				var caminho := rotas.caminho(origem,local,vetados)
				if not caminho.is_empty() and (melhor.is_empty() or caminho.size()<melhor.size()): melhor=caminho
		if not melhor.is_empty(): return melhor
	return melhor

func iniciar(robo: PersonagemPlex, suporte: int) -> void:
	var plano := poses.planejar(robo)
	var corredor: Array[Vector2i] = []
	if not plano.is_empty():
		corredor.assign(plano.caminho)
	else:
		corredor.assign(planta.interacoes(suporte))
	var ajudantes: Array[PersonagemPlex] = []
	for ajudante in personagens:
		if ajudante.robo or ajudante.ocupado() or not planta.interacoes(suporte).has(ajudante.celula):
			continue
		var caminho := estacionamento(ajudante, corredor, suporte)
		if not caminho.is_empty():
			ajudante.trabalho = "liberar_saida"
			ajudante.andar(caminho)
			ajudantes.append(ajudante)
	if ajudantes.is_empty():
		poses.encaminhar(robo)
		return
	robo.aguardando_saida = true
	pendentes.append({"robo": robo, "suporte": suporte, "ajudantes": ajudantes, "liberado": false})

func limpar() -> void:
	for registro in pendentes:
		if is_instance_valid(registro.robo):
			registro.robo.aguardando_saida = false
		for ajudante in registro.ajudantes:
			if is_instance_valid(ajudante) and ajudante.trabalho == "liberar_saida":
				ajudante.trabalho = ""
	pendentes.clear()

func atualizar() -> void:
	for registro in pendentes.duplicate():
		var robo: PersonagemPlex = registro.robo
		var valido := is_instance_valid(robo) and planta.objetos.has(registro.suporte)
		var esperando := false
		for ajudante in registro.ajudantes:
			if is_instance_valid(ajudante) and ajudante.trabalho == "liberar_saida":
				esperando = esperando or ajudante.ocupado()
		if valido and not registro.liberado:
			if esperando:
				continue
			robo.aguardando_saida = false
			poses.encaminhar(robo)
			registro.liberado = true
		if valido and registro.liberado and robo.suporte < 0 and Vector2(robo.local).distance_to(Vector2(planta.objetos[registro.suporte].celula)) <= 1.6:
			continue
		if valido:
			robo.aguardando_saida = false
		for ajudante in registro.ajudantes:
			if is_instance_valid(ajudante) and ajudante.trabalho == "liberar_saida":
				ajudante.trabalho = ""
		pendentes.erase(registro)

