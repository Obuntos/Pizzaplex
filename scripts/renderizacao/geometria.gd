class_name GeometriaPlex
extends RefCounted

static var definicoes: Dictionary = {}
static var cache: Dictionary = {}

static func conecta(outro: Dictionary, objeto: Dictionary, niveis: Dictionary) -> bool:
	return outro.get("tipo", "") in SalasPlex.ESTRUTURA and int(niveis.get(outro.id, 4)) >= int(niveis.get(objeto.id, 4))

static func mascara(objeto: Dictionary, planta: PlantaPlex, niveis: Dictionary = {}) -> int:
	var valor: int = 0
	if objeto.tipo in ["parede", "parede_fachada"]:
		var direcoes := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
		for i in 4:
			if conecta(planta.em(objeto.celula + direcoes[i]), objeto, niveis):
				valor |= 1 << i
	elif objeto.tipo == "palco":
		for i in 4:
			if planta.em(objeto.celula + GradePlex.VIZINHOS[i]).get("tipo", "") == "palco":
				valor |= 1 << i
	elif objeto.tipo == "escada":
		var frente := GradePlex.frente(objeto.rotacao)
		var lado := Vector2i(frente.y, -frente.x)
		for i in 2:
			var outro := planta.em(objeto.celula + lado * (-1 if i == 0 else 1))
			if outro.get("tipo", "") == "escada" and outro.rotacao == objeto.rotacao:
				valor |= 1 << i
	elif objeto.tipo in CatalogoPlex.PORTAS:
		var frente := GradePlex.frente(objeto.rotacao)
		var lado := Vector2i(frente.y, -frente.x)
		var ocupadas := planta.celulas(objeto.tipo, objeto.celula, objeto.rotacao)
		for i in 2:
			for celula in ocupadas:
				var vizinha: Vector2i = celula + lado * (-1 if i == 0 else 1)
				if not ocupadas.has(vizinha) and conecta(planta.em(vizinha), objeto, niveis):
					valor |= 1 << i
	return valor

static func obter(tipo: String, rotacao: int, nivel: int = 4, ligacoes: int = 0, aberta: bool = false, estado: String = "") -> Dictionary:
	var tipo_logico := tipo
	if CatalogoPlex.objetos.get(tipo, {}).has("origem_volume"):
		tipo = CatalogoPlex.objetos[tipo].origem_volume
	if definicoes.is_empty():
		definicoes = JSON.parse_string(FileAccess.get_file_as_string("res://dados/volumes.json"))
		definicoes.merge(JSON.parse_string(FileAccess.get_file_as_string("res://dados/volumes_fachada.json")), true)
	if tipo == "parede": estado = ""
	var chave := ":".join([tipo, str(0 if tipo in ["parede", "palco"] else rotacao), str(nivel if tipo in SalasPlex.ESTRUTURA else 4), str(ligacoes), str(int(aberta)), estado])
	var fachada := bool(CatalogoPlex.objetos.get(tipo_logico, {}).get("fachada", false))
	if fachada:
		if estado.is_empty(): estado = CatalogoPlex.objetos[tipo_logico].estado_padrao
		if tipo_logico in CatalogoPlex.PORTAS: estado = "aberta" if aberta else "fechada"
		chave = ":".join([tipo_logico, str(rotacao), str(nivel if tipo_logico in SalasPlex.ESTRUTURA else 4), "0", "0", estado])
	var chave_cache := tipo_logico+":"+chave
	if cache.has(chave_cache):
		return cache[chave_cache]
	var dados: Dictionary = definicoes[chave].duplicate()
	dados.textura = CatalogoPlex.textura(dados.image)
	var imagem: Image = dados.textura.get_image()
	var imagem_superficies: Image = CatalogoPlex.imagem(dados.normal) if dados.has("normal") else null
	var faces := PackedColorArray()
	var profundidades: PackedFloat32Array = FileAccess.get_file_as_bytes(dados.depth).to_float32_array()
	var pontos := PackedVector3Array()
	var cores := PackedColorArray()
	for y in imagem.get_height():
		for x in imagem.get_width():
			var cor := imagem.get_pixel(x, y)
			if cor.a > 0.0:
				pontos.append(Vector3(x + int(dados.origin[0]), y + int(dados.origin[1]), profundidades[y * imagem.get_width() + x]))
				cores.append(cor)
				if imagem_superficies != null: faces.append(imagem_superficies.get_pixel(x, y))
	if not fachada and tipo in CatalogoPlex.PORTAS and nivel == 1 and not aberta:
		FolhaPortaPlex.acrescentar(tipo, rotacao, pontos, cores)
	elif not fachada and tipo in CatalogoPlex.PORTAS and nivel == 1:
		var referencia := obter(tipo, rotacao, 2, ligacoes, aberta, estado)
		for i in referencia.pontos.size():
			var ponto: Vector3 = referencia.pontos[i]
			var altura := (ponto.z - ponto.y * 2.0) / 3.0
			var cor: Color = referencia.cores[i]
			if altura <= 6.6 and cor.r > cor.g * 1.04 and cor.g > cor.b * 1.08:
				pontos.append(ponto)
				cores.append(cor)
	dados.pontos = pontos
	dados.cores = cores
	dados.superficies = SuperficiesPlex.parede(pontos, nivel, ligacoes) if tipo == "parede" else faces
	if not fachada and tipo in CatalogoPlex.PORTAS:
		dados.superficies = SuperficiesPlex.porta(pontos, cores, nivel)
	if not fachada and tipo in SalasPlex.ESTRUTURA:
		dados.cores = SuperficiesPlex.cores_continuas(pontos, cores, dados.superficies)
	if dados.superficies.is_empty(): dados.superficies=SuperficiesPlex.normais_volume(pontos)
	if tipo_logico not in SalasPlex.ESTRUTURA:
		for i in dados.superficies.size():
			if dados.superficies[i].a<.75: dados.superficies[i].a=.2
	if ItensPlex.personalizado(tipo_logico):
		dados.rotacao_marca = rotacao
		ItensPlex.ajustar(dados,tipo_logico)
		dados.textura = ItensPlex.compor([{"volume":dados}]).textura
		dados.origin = [-96,-144]
	cache[chave_cache] = dados
	return dados

static func objeto(registro: Dictionary, planta: PlantaPlex, nivel: int, niveis: Dictionary = {}) -> Dictionary:
	var ligacoes := mascara(registro, planta, niveis)
	if registro.tipo in ["parede", "parede_fachada", "palco"]: ligacoes = GradePlex.mascara_visual(ligacoes)
	return obter(registro.tipo, GradePlex.rotacao_visual(registro.rotacao), nivel, ligacoes, registro.aberta if registro.tipo in CatalogoPlex.PORTAS else false, FachadaPlex.estado(planta, registro))

