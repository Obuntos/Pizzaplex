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
		paredes[Vector2i(u,y)] = true
		paredes[Vector2i(u,y+altura-1)] = true
	for v in range(y, y + altura):
		paredes[Vector2i(x,v)] = true
		paredes[Vector2i(x+largura-1,v)] = true

func objeto(tipo: String, x: int, y: int, rotacao: int = 0, nome: String = "") -> int:
	var id := planta.colocar(tipo,Vector2i(x,y),rotacao)
	if id < 0: erros.append(tipo + " em " + str(Vector2i(x,y)))
	if not nome.is_empty(): ids[nome] = id
	return id

func abertura(tipo: String, x: int, y: int, rotacao: int = 0) -> void:
	for celula in planta.celulas(tipo,Vector2i(x,y),rotacao):
		var anterior := planta.em(celula)
		if not anterior.is_empty(): planta.remover(anterior.id)
	objeto(tipo,x,y,rotacao)

func sala(tipo: String, x: int, y: int, largura: int, altura: int, cor: int) -> void:
	planta.funcoes_salas[Vector2i(x,y)] = tipo
	for v in range(y,y+altura):
		for u in range(x,x+largura): planta.cores[Vector2i(u,v)] = cor

func mesa(x: int, y: int, arredondada: bool) -> void:
	var id := objeto("mesa_longa_arredondada" if arredondada else "mesa_longa",x,y)
	if id < 0: return
	for p in LugaresPlex.posicoes(planta.objetos[id]):
		var rotacao := 0
		for r in 4:
			if GradePlex.frente(r) == p.frente: rotacao = r
		objeto("cadeira",p.celula.x,p.celula.y,rotacao)

func construir() -> bool:
	var bloqueados := planta.is_blocking_signals()
	planta.set_block_signals(true)
	var retangulos := [[10,8,9,8],[10,8,9,5],[10,12,9,4],[18,8,12,7],[29,8,5,7],[33,8,5,7],[37,8,5,7],[41,8,9,7],[10,15,9,5],[10,19,9,13],[18,14,16,14],[33,14,17,5],[33,18,7,10],[39,18,7,10],[22,27,12,9],[18,27,5,9]]
	var area: Dictionary = {}
	for r in retangulos:
		retangulo(r[0],r[1],r[2],r[3])
		for y in range(r[1],r[1]+r[3]):
			for x in range(r[0],r[0]+r[2]): area[Vector2i(x,y)]=true
	for c in paredes:
		var externa := GradePlex.VIZINHOS.any(func(d): return not area.has(c+d))
		objeto("parede_fachada" if externa else "parede",c.x,c.y)
	for p in [[14,12,0],[14,15,0],[19,14,0],[31,14,0],[35,14,0],[39,14,0],[45,14,0],[18,17,1],[18,22,1],[18,29,1],[36,18,0],[42,18,0],[25,27,0],[22,33,1],[20,35,0],[10,17,1]]: abertura("porta_servico",p[0],p[1],p[2])
	abertura("porta_dupla",33,16,1)
	abertura("porta_principal",49,10,1)
	abertura("janela_2",49,12,1)
	for x in range(43,48): abertura("janela",x,8)
	for x in range(11,16): abertura("janela",x,8)
	for y in range(9,15):
		for x in range(50,53): objeto("externo_piso",x,y)
	for y in range(6,8):
		for x in range(10,50): objeto("externo_piso",x,y)
	for s in [["vestiario",11,9,7,3,2],["limpeza",11,13,7,2,1],["oficina",19,9,10,5,2],["escritorio",30,9,3,5,2],["escritorio",34,9,3,5,2],["escritorio",38,9,3,5,2],["recepcao",42,9,7,5,1],["circulacao",11,16,7,3,1],["jogos",11,20,7,11,2],["salao_festas",19,15,14,12,0],["circulacao",34,15,15,3,1],["banheiro",34,19,5,8,1],["banheiro",40,19,5,8,1],["cozinha",23,28,10,7,1],["deposito",19,28,3,7,2]]: sala(s[0],s[1],s[2],s[3],s[4],s[5])
	for p in [["armario_funcionarios",11,9,0],["cadeira",16,10,0],["armario_limpeza",11,13,0],["vassoura",15,13,0],["balde",17,13,0],["armario_ferramentas",19,9,0],["bancada",22,11,0],["balcao",31,9,0],["terminal_ibm",31,9,0],["balcao",35,9,0],["terminal_ibm",35,9,0],["balcao",39,9,0],["terminal_ibm",39,9,0],["balcao",44,10,0],["registradora",44,10,0],["banco_espera",46,12,0],["lixeira_salao",48,13,0],["bancada_preparo",23,28,0],["forno",27,28,0],["forno",30,28,0],["geladeira",32,31,1],["pia",27,33,2],["armario_utensilios",23,31,3],["lixeira",32,34,0],["estante",19,28,0],["estante",19,31,0],["ponto_recebimento",20,33,0]]: objeto(p[0],p[1],p[2],p[3])
	objeto("suporte",22,9,0,"suporte")
	for base in [34,40]:
		for x in [base,base+3]:
			objeto("divisoria_porta",x,20)
			objeto("vaso_sanitario",x,20)
		objeto("pia_banheiro",base,24,3)
		objeto("lixeira_salao",base+4,25)
	for p in [[11,20],[15,20],[11,26],[15,26]]: objeto("maquina_fliperama",p[0],p[1])
	for y in range(15,17):
		for x in range(21,30): objeto("palco",x,y)
	for x in [25,26]: objeto("escada",x,17)
	for x in [23,25,27]:
		objeto("pose",x,15)
		objeto("luz_chao",x,16)
	objeto("cortina_central_9",21,16)
	objeto("cortina_lateral_esquerda",21,16)
	objeto("cortina_lateral_direita",29,16)
	for y in [20,24]:
		for x in [20,27]: mesa(x,y,(x+y)%2==0)
	objeto("lixeira_salao",19,24)
	objeto("lixeira_salao",17,29)
	objeto("prateleira_suspensa",24,27)
	var inventario := InventarioPlex.new(planta)
	for registro in planta.objetos.values():
		if registro.tipo == "geladeira":
			registro.estoque = {"pizza":12,"guarana":16}
			SuprimentosPlex.preparar(registro)
		if registro.tipo == "armario_utensilios":
			for slot in ApoiosPlex.pontos(registro,planta).size():
				var prato := inventario.criar("prato",registro.celula)
				if not ApoiosPlex.fixar(planta,prato,registro.id,slot): erros.append("prato no armário")
	for p in [[14,10],[15,14],[24,11],[31,12],[35,12],[39,12],[45,11],[14,17],[14,23],[14,29],[23,19],[29,19],[23,24],[29,24],[37,16],[45,16],[36,23],[42,23],[26,31],[31,33],[20,32]]:
		var id := objeto("luz_teto",p[0],p[1])
		if id >= 0: planta.objetos[id].energia = 1.5
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
