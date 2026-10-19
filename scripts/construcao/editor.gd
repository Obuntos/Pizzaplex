class_name EditorPlex
extends RefCounted

signal aviso(texto: String)
signal destino_quebrado_escolhido(id: int, celula: Vector2i, rotacao: int)
signal spawn_solicitado(modelo: String, celula: Vector2i)
var jogo: Node
var planta: PlantaPlex
var personagens: Array = []
var marca_quebrado := -1
var ferramenta: String = "selecionar"
var rotacao: int = 0
var cor: int = 0
var estado_visual := ""
var luz_padrao: Dictionary = {"cor_luz":"#fff0d5","energia":1.2,"ligada":true}

func _init(valor: PlantaPlex) -> void:
	planta = valor

func livre(celula: Vector2i) -> bool:
	for pessoa in personagens:
		if pessoa.celula == celula or (pessoa.movimento.atravessando and pessoa.movimento.destino == celula):
			return false
	return true

func aplicar(celula: Vector2i) -> void:
	if not GradePlex.dentro(celula):
		return
	if ferramenta=="pose_quebrado":
		destino_quebrado_escolhido.emit(marca_quebrado,celula,rotacao)
		return
	if ferramenta.begins_with("spawn:"):
		var modelo: String = ferramenta.trim_prefix("spawn:")
		if modelo=="endo":
			aviso.emit("Encomende os componentes na aba Endo do terminal.")
			return
		var palco_sem_pose: bool = modelo in ["coelho", "ovelha", "raposa"] and planta.em(celula).get("tipo", "") == "palco" and planta.sobre(celula, "pose").is_empty()
		if planta.transitavel(celula) and livre(celula) and planta.em(celula).get("tipo", "") != "escada" and not palco_sem_pose:
			spawn_solicitado.emit(ferramenta.trim_prefix("spawn:"), celula)
		else:
			aviso.emit("Escolha um tile livre. Animatrônicos no palco precisam de Pose.")
		return
	if ferramenta == "remover":
		var adicionais := planta.sobre(celula)
		if not adicionais.is_empty():
			planta.remover(adicionais[-1].id)
			return
		var objeto := planta.em(celula)
		if objeto.is_empty(): objeto = CabinesPlex.em(planta, celula)
		if not objeto.is_empty():
			for local in planta.celulas(objeto.tipo, objeto.celula, objeto.rotacao):
				if not livre(local):
					aviso.emit("Mova o personagem antes de remover esse objeto.")
					return
			planta.remover(objeto.id)
		return
	if CatalogoPlex.objetos.get(ferramenta,{}).get("piso",false):
		if planta.pisos.get(celula,"") == ferramenta: return
		if not cobrar(MobiliaPlex.preco(ferramenta)): return
		planta.pisos[celula] = ferramenta
		planta.alterada.emit()
		return
	if ferramenta == "chao":
		if not cobrar(2): return
		planta.pisos.erase(celula)
		planta.cores[celula] = cor
		planta.alterada.emit()
		return
	if not CatalogoPlex.objetos.has(ferramenta):
		return
	var rotacao_real := PortasPlex.rotacao_para(planta, ferramenta, celula, rotacao) if ferramenta in CatalogoPlex.PORTAS else rotacao
	for local in planta.celulas(ferramenta, celula, rotacao_real):
		if not planta.sobreposto(ferramenta) and not livre(local):
			aviso.emit("Este tile está ocupado por um personagem.")
			return
	var modulos := MobiliaPlex.modulos(ferramenta,celula,rotacao)
	for c in modulos:
		if not planta.pode_colocar(ferramenta,c,rotacao) or (not planta.sobreposto(ferramenta) and not livre(c)):
			aviso.emit("O objeto não cabe ou o acesso está ocupado.")
			return
	var custo := MobiliaPlex.preco(ferramenta)*modulos.size()
	if not cobrar(custo): return
	var id := -1
	var bloqueado := planta.is_blocking_signals()
	planta.set_block_signals(true)
	for c in modulos:
		var colocado := planta.colocar(ferramenta,c,rotacao)
		if colocado >= 0:
			id = colocado
			planta.objetos[id].valor_pago = MobiliaPlex.preco(ferramenta)
			if CatalogoPlex.objetos[ferramenta].get("estados",[]).has(estado_visual):
				if planta.objetos[id].has("variante"): planta.objetos[id].estado_visual=estado_visual
				else: planta.objetos[id].estado=estado_visual
	planta.set_block_signals(bloqueado)
	planta.alterada.emit()
	if id == -1:
		aviso.emit("Pose precisa de palco." if ferramenta == "pose" else "Luz de parede precisa de uma parede livre." if ferramenta == "luz_parede" else "O objeto não cabe ou o tile já está ocupado.")
	else:
		if ferramenta.begins_with("luz_"):
			planta.objetos[id].merge(luz_padrao, true)
			planta.alterada.emit()
		aviso.emit(CatalogoPlex.objetos[ferramenta].nome + " colocado. R gira o próximo objeto.")


func cobrar(valor: int) -> bool:
	if jogo == null or not jogo.campanha or jogo.operacao.debug: return true
	if jogo.servicos.saldo < valor:
		aviso.emit("Dinheiro insuficiente. Custo: $ "+str(valor)+".")
		return false
	jogo.servicos.saldo -= valor
	jogo.compras_construcao += valor
	return true
