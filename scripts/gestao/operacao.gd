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

func _init(cena: Node) -> void:
	jogo = cena

func configurar(valor: Dictionary, modo_debug: bool) -> void:
	criacao = valor.duplicate(true)
	nome = str(criacao.get("restaurante","Pizzaplex")).strip_edges().left(40)
	if nome.is_empty(): nome = "Pizzaplex"
	debug = modo_debug
	aberto = modo_debug
	aplicar_precos()

func aplicar_precos() -> void:
	jogo.compras.catalogo = JSON.parse_string(FileAccess.get_file_as_string("res://dados/compras.json"))
	if debug:
		for item in jogo.compras.catalogo.values(): item.preco = 0

func mudar_abertura(valor: bool) -> void:
	if aberto!=valor and valor: jogo.fantasias.abertura()
	aberto = valor
	espera_chegada = minf(espera_chegada,15.0)
	jogo.painel.mensagem("Restaurante aberto. Novas visitas chegam quando o salão e a cozinha estiverem prontos." if aberto else "Restaurante fechado para novas visitas. Quem já entrou pode terminar a refeição e sair.")
	jogo.painel.hud.atualizar(1.0)

func chegada() -> Vector2i:
	for celula_porta in jogo.clientes.portas_externas():
		var porta: Dictionary = jogo.planta.em(celula_porta)
		if porta.is_empty(): continue
		var frente := GradePlex.frente(porta.rotacao)
		for lado in [frente,-frente]:
			for distancia in [2,3,1]:
				var c: Vector2i = porta.celula + lado*distancia
				if not jogo.clientes.chao(c) or jogo.personagens.any(func(a): return a.celula==c): continue
				if not jogo.ambientes.em(c).get("fechada",false): return c
	return Vector2i(-1,-1)

func atualizar(delta: float) -> void:
	if not aberto or debug: return
	espera_chegada -= delta
	if espera_chegada>0: return
	espera_chegada = 85.0
	if jogo.clientes.grupos.size()>=3: return
	if jogo.ambientes.equipamentos("mesa",["salao"]).is_empty(): return
	if jogo.ambientes.equipamentos("forno",["cozinha"]).is_empty(): return
	var local := chegada()
	if not GradePlex.dentro(local): return
	if randi()%4==0 and not jogo.ambientes.equipamentos("maquina_fliperama",["jogos"]).is_empty():
		jogo.lazer.criar(local,randi()%2==0)
	else: jogo.clientes.criar_preset(local,"variada")

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
