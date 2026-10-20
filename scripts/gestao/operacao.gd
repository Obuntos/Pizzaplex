class_name OperacaoRestaurantePlex
extends RefCounted

var jogo: Node
var nome := "Pizzaplex"
var debug := false
var aberto := false
var administrador := -1
var criacao: Dictionary = {}
var espera_chegada := 25.0
var mostrar_controle := true
var motivo_chegada := ""

func _init(cena: Node) -> void:
	jogo = cena

func configurar(valor: Dictionary, modo_debug: bool) -> void:
	criacao = valor.duplicate(true)
	nome = str(criacao.get("restaurante","Pizzaplex")).strip_edges().left(40)
	if nome.is_empty(): nome = "Pizzaplex"
	debug = modo_debug
	aberto = modo_debug
	espera_chegada=3.0
	aplicar_precos()

func aplicar_precos() -> void:
	jogo.compras.catalogo = JSON.parse_string(FileAccess.get_file_as_string("res://dados/compras.json"))
	if debug:
		for item in jogo.compras.catalogo.values(): item.preco = 0

func mudar_abertura(valor: bool) -> void:
	if aberto!=valor and valor: jogo.fantasias.abertura()
	aberto = valor
	espera_chegada = minf(espera_chegada,3.0)
	jogo.painel.mensagem("Restaurante aberto. Novas visitas chegam quando houver uma entrada e espaço interno para recebê-las." if aberto else "Restaurante fechado para novas visitas. Quem já entrou pode terminar a refeição e sair.")
	jogo.painel.hud.atualizar(1.0)

func chegada() -> Vector2i:
	for celula_porta in jogo.clientes.portas_externas():
		var porta: Dictionary = jogo.planta.em(celula_porta)
		if porta.is_empty(): continue
		var frente := GradePlex.frente(porta.rotacao)
		for lado in [frente,-frente]:
			var dentro: Vector2i=celula_porta-lado
			if not jogo.ambientes.em(dentro).get("fechada",false): continue
			for distancia in [2,3,1]:
				var c: Vector2i = celula_porta + lado*distancia
				if not jogo.clientes.chao(c) or jogo.personagens.any(func(a): return a.celula==c): continue
				if not jogo.ambientes.em(c).get("fechada",false) and not jogo.clientes.caminho(c,dentro).is_empty(): return c
	return Vector2i(-1,-1)

func atualizar(delta: float) -> void:
	if not aberto: return
	espera_chegada -= delta
	if espera_chegada>0: return
	espera_chegada = 5.0
	if jogo.clientes.grupos.size()>=3: return
	jogo.ambientes.atualizar()
	var salao: bool=jogo.ambientes.ambientes.any(func(sala): return sala.fechada and (sala.funcoes.has("salao") or sala.objetos.any(func(id): return LugaresPlex.mesa(jogo.planta.objetos[id].tipo) and LugaresPlex.total(jogo.planta,id)>0)))
	var arcade: bool=not jogo.ambientes.equipamentos("maquina_fliperama",["jogos"]).is_empty()
	if not salao and not arcade:
		motivo_chegada="Prepare uma área interna com mesas e cadeiras, ou uma sala de jogos, para receber visitantes."
		return
	var local := chegada()
	if not GradePlex.dentro(local):
		motivo_chegada="A entrada precisa ligar o exterior a uma área interna, com passagem livre."
		return
	var criou: bool=false
	if arcade and (not salao or randi()%4==0): criou=jogo.lazer.criar(local,randi()%2==0)
	else: criou=jogo.clientes.criar_preset(local,"variada")
	if criou:
		motivo_chegada=""
		espera_chegada=45.0
	else: motivo_chegada="Libere espaço próximo à entrada para os visitantes chegarem juntos."

func gravar() -> Dictionary:
	return {"nome":nome,"debug":debug,"aberto":aberto,"administrador":administrador,"criacao":criacao,"espera_chegada":espera_chegada,"mostrar_controle":mostrar_controle,"fantasia_adiada":jogo.fantasias.adiou}

func restaurar(valor: Dictionary) -> void:
	nome = str(valor.get("nome","Pizzaplex"))
	debug = bool(valor.get("debug",false))
	aberto = bool(valor.get("aberto",true))
	administrador = int(valor.get("administrador",-1))
	criacao = valor.get("criacao",{}).duplicate(true)
	espera_chegada = float(valor.get("espera_chegada",25.0))
	mostrar_controle = bool(valor.get("mostrar_controle",true))
	jogo.fantasias.adiou=bool(valor.get("fantasia_adiada",false))
	aplicar_precos()
