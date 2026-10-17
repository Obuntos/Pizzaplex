class_name PlantaExemploPlex
extends RefCounted

var planta: PlantaPlex
var erros: Array[String] = []
var ids: Dictionary = {}
var paredes: Dictionary = {}

func _init(p: PlantaPlex) -> void:
	planta = p

func retangulo(x: int, y: int, largura: int, altura: int) -> void:
	for u in range(x, x + largura):
		paredes[Vector2i(u, y)] = true
		paredes[Vector2i(u, y + altura - 1)] = true
	for v in range(y, y + altura):
		paredes[Vector2i(x, v)] = true
		paredes[Vector2i(x + largura - 1, v)] = true

func objeto(tipo: String, x: int, y: int, rotacao: int = 0, nome: String = "") -> int:
	var id := planta.colocar(tipo, Vector2i(x, y), rotacao)
	if id < 0: erros.append(tipo + " em " + str(Vector2i(x, y)))
	if not nome.is_empty(): ids[nome] = id
	return id

func porta(x: int, y: int, rotacao: int = 0, dupla: bool = false) -> void:
	var tipo := "porta_dupla" if dupla else "porta"
	for celula in planta.celulas(tipo, Vector2i(x, y), rotacao):
		var anterior := planta.em(celula)
		if not anterior.is_empty(): planta.remover(anterior.id)
	objeto(tipo, x, y, rotacao)

func sala(tipo: String, x: int, y: int, largura: int, altura: int, cor: int) -> void:
	planta.funcoes_salas[Vector2i(x, y)] = tipo
	for v in range(y, y + altura):
		for u in range(x, x + largura): planta.cores[Vector2i(u, v)] = cor

func mesa(x: int, y: int) -> void:
	objeto("mesa", x, y)
	for item in [[1,0,1], [0,1,2], [-1,0,3], [0,-1,0]]: objeto("cadeira", x + item[0], y + item[1], item[2])

func construir() -> bool:
	var bloqueados := planta.is_blocking_signals()
	planta.set_block_signals(true)
	retangulo(1, 1, 30, 22)
	for r in [[1,1,7,8], [7,1,10,8], [16,1,8,8], [23,1,8,5], [23,5,8,4], [1,11,7,12], [7,11,17,12], [23,11,8,6], [23,16,8,7]]: retangulo(r[0], r[1], r[2], r[3])
	for celula in paredes: objeto("parede", celula.x, celula.y)
	for item in [[4,8,0], [11,8,0], [20,8,0], [27,8,0], [23,3,1], [4,11,0], [23,14,1], [23,19,1], [4,22,0]]: porta(item[0], item[1], item[2])
	porta(13, 11, 0, true)
	porta(7, 18, 1, true)
	sala("deposito", 2, 2, 5, 6, 2)
	sala("cozinha", 8, 2, 8, 6, 1)
	sala("oficina", 17, 2, 6, 6, 2)
	sala("limpeza", 24, 2, 6, 3, 1)
	sala("vestiario", 24, 6, 6, 2, 1)
	sala("recepcao", 2, 12, 5, 10, 1)
	sala("salao_festas", 8, 12, 15, 10, 0)
	sala("jogos", 24, 12, 6, 4, 2)
	sala("banheiro", 24, 17, 6, 5, 1)
	for item in [["estante",2,2,0], ["estante",2,5,3], ["caixa_ingredientes",5,3,0], ["caixa_utensilios",5,5,0], ["bancada_preparo",9,2,0], ["forno",12,2,0], ["geladeira",15,4,1], ["pia",12,6,2], ["armario_utensilios",8,5,3], ["armario_ferramentas",17,2,0], ["bancada",20,5,0], ["armario_limpeza",24,2,0], ["vassoura",28,3,0], ["balde",29,3,0], ["armario_funcionarios",24,6,0], ["cadeira",28,6,0], ["cadeira",29,6,0], ["balcao",3,14,0], ["registradora",3,14,0], ["cadeira",3,17,3]]: objeto(item[0],item[1],item[2],item[3])
	var inventario := InventarioPlex.new(planta)
	for registro in planta.objetos.values():
		if registro.tipo == "geladeira": registro.ingredientes = 8
		if registro.tipo == "armario_utensilios":
			for slot in 3:
				var prato := inventario.criar("prato", registro.celula)
				if not ApoiosPlex.fixar(planta, prato, registro.id, slot): erros.append("prato no armário")
	objeto("suporte",20,3,3,"suporte")
	for y in range(12,14):
		for x in range(12,20): objeto("palco",x,y)
	for x in [13,14]: objeto("escada",x,14)
	for x in [13,16,18]:
		objeto("pose",x,12)
		objeto("luz_chao",x,13)
	for y in [17,20]:
		for x in [10,14,18]: mesa(x,y)
	for x in [25,27,29]: objeto("maquina_fliperama",x,12)
	for x in [25,27]:
		objeto("divisoria_porta",x,17)
		objeto("vaso_sanitario",x,17)
	for item in [["pia_banheiro",24,20,3], ["pia_banheiro",28,20,2], ["lixeira",9,12,0], ["lixeira",29,21,2], ["mancha_chao",21,18,0], ["bebida_derramada",25,14,0]]: objeto(item[0],item[1],item[2],item[3])
	for ponto in [[4,4], [11,4], [14,6], [20,4], [27,3], [27,7], [5,10], [13,10], [21,10], [4,16], [10,15], [17,15], [10,20], [18,20], [26,14], [27,19]]:
		var luz := objeto("luz_teto",ponto[0],ponto[1])
		if luz >= 0: planta.objetos[luz].energia = 1.5
	if not erros.is_empty():
		planta.objetos.clear()
		planta.ocupacao.clear()
		planta.cabines_por_celula.clear()
		planta.cores.clear()
		planta.funcoes_salas.clear()
		planta.proximo_id = 1
	planta.set_block_signals(bloqueados)
	planta.atualizar_reservas()
	planta.alterada.emit()
	return erros.is_empty()
