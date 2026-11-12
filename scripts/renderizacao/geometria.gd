class_name GeometriaPlex
extends RefCounted

static var definicoes: Dictionary = {}
static var cache: Dictionary = {}
static var oficina_carregada:=false

static func conecta(outro: Dictionary, objeto_local: Dictionary, niveis: Dictionary) -> bool:
	return outro.get("tipo", "") in SalasPlex.ESTRUTURA and int(niveis.get(outro.id, 4)) >= int(niveis.get(objeto_local.id, 4))

static func mascara(objeto_local: Dictionary, planta: PlantaPlex, niveis: Dictionary = {}) -> int:
	var valor: int = 0
	if objeto_local.tipo in ["parede", "parede_fachada"]:
		var direcoes := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
		for i in 4:
			var vizinha:=planta.em(objeto_local.celula+direcoes[i])
			if vizinha.get("tipo","") in CatalogoPlex.PORTAS: continue
			if conecta(vizinha, objeto_local, niveis):
				valor |= 1 << i
	elif objeto_local.tipo == "palco":
		for i in 4:
			if planta.em(objeto_local.celula + GradePlex.VIZINHOS[i]).get("tipo", "") == "palco":
				valor |= 1 << i
	elif objeto_local.tipo == "escada":
		var frente := GradePlex.frente(objeto_local.rotacao)
		var lado := Vector2i(frente.y, -frente.x)
		for i in 2:
			var outro := planta.em(objeto_local.celula + lado * (-1 if i == 0 else 1))
			if outro.get("tipo", "") == "escada" and outro.rotacao == objeto_local.rotacao:
				valor |= 1 << i
	elif objeto_local.tipo in CatalogoPlex.PORTAS:
		var frente := GradePlex.frente(objeto_local.rotacao)
		var lado := Vector2i(frente.y, -frente.x)
		var ocupadas := planta.celulas(objeto_local.tipo, objeto_local.celula, objeto_local.rotacao)
		for i in 2:
			for celula in ocupadas:
				var vizinha: Vector2i = celula + lado * (-1 if i == 0 else 1)
				if not ocupadas.has(vizinha) and conecta(planta.em(vizinha), objeto_local, niveis):
					valor |= 1 << i
	return valor

static func obter(tipo: String, rotacao: int, nivel: int = 4, ligacoes: int = 0, aberta: bool = false, estado: String = "", variedade: int = 0) -> Dictionary:
	if AmbientesAssetsPlex.eh(tipo):return AmbientesAssetsPlex.obter(tipo,rotacao,estado)
	if tipo in ["pose","pose_quebrado","pose_montagem"]:return UtilitariosVisuaisPlex.marcador(tipo,rotacao)
	if AssetsSistemasPlex.eh(tipo):return AssetsSistemasPlex.obter(tipo,rotacao,estado,ligacoes)
	if CatalogoPlex.objetos.get(tipo,{}).get("piso",false):return piso(tipo,rotacao,estado)
	if DecoracaoEstudoPlex.eh(tipo):return DecoracaoEstudoPlex.obter(tipo,rotacao,610.0,estado)
	if CaixasVisuaisPlex.eh(tipo): return CaixasVisuaisPlex.obter(tipo,rotacao,estado)
	if tipo in ["ponto_recebimento","suporte","area_montagem_atracao","saco_lixo"]: return UtilitariosVisuaisPlex.obter(tipo,rotacao)
	if CatalogoPlex.objetos.get(tipo,{}).get("cenario_parede",false):
		var chave_parede := str([tipo,rotacao,nivel,ligacoes,estado])
		if not cache.has(chave_parede): cache[chave_parede] = ParedeCenarioPlex.obter(tipo,rotacao,nivel,ligacoes,estado)
		return cache[chave_parede]
	var tipo_logico := tipo
	if CatalogoPlex.objetos.get(tipo, {}).has("origem_volume"):
		tipo = CatalogoPlex.objetos[tipo].origem_volume
	if definicoes.is_empty():
		definicoes = JSON.parse_string(FileAccess.get_file_as_string("res://dados/volumes.json"))
		definicoes.merge(JSON.parse_string(FileAccess.get_file_as_string("res://dados/volumes_fachada.json")), true)
		definicoes.merge(JSON.parse_string(FileAccess.get_file_as_string("res://dados/volumes_antigos.json")), true)
		definicoes.merge(JSON.parse_string(FileAccess.get_file_as_string("res://dados/volumes_cenario.json")),true)
	if not definicoes.has("festa_prato_ceramica_raso:0:4:0:0:padrao"):
		definicoes.merge(JSON.parse_string(FileAccess.get_file_as_string("res://dados/volumes_festa.json")),true)
	if not oficina_carregada:
		definicoes.merge(JSON.parse_string(FileAccess.get_file_as_string("res://dados/volumes_oficina.json")),true)
		oficina_carregada=true
	var info_tipo: Dictionary=CatalogoPlex.objetos.get(tipo_logico,{})
	if info_tipo.has("estados") and not info_tipo.estados.has(estado): estado=str(info_tipo.get("estado_padrao",""))
	if tipo == "parede": estado = ""
	var chave := ":".join([tipo, str(0 if tipo in ["parede", "palco"] else rotacao), str(nivel if tipo in SalasPlex.ESTRUTURA else 4), str(ligacoes), str(int(aberta)), estado])
	var fachada := bool(CatalogoPlex.objetos.get(tipo_logico, {}).get("fachada", false))
	if fachada:
		var info_fachada: Dictionary = CatalogoPlex.objetos[tipo_logico]
		if not info_fachada.estados.has(estado): estado = info_fachada.estado_padrao
		if tipo_logico in CatalogoPlex.PORTAS: estado = "aberta" if aberta else "fechada"
		chave = ":".join([tipo_logico, str(rotacao), str(nivel if tipo_logico in SalasPlex.ESTRUTURA else 4), "0", "0", estado])
	if CatalogoPlex.objetos.get(tipo_logico, {}).get("mobilia", false):
		var item: Dictionary = CatalogoPlex.objetos[tipo_logico]
		if estado.is_empty() or not item.estados.has(estado): estado = item.estado_padrao
		chave = ":".join([tipo_logico, str(0 if item.get("conectavel", false) else rotacao), str(nivel if item.get("estrutura", false) else 4), str(ligacoes if item.get("conectavel", false) else 0), "0", estado])
	if variedade>0 and definicoes.has(chave+":v"+str(variedade)): chave+=":v"+str(variedade)
	var chave_cache := tipo_logico+":"+chave
	if cache.has(chave_cache):
		return cache[chave_cache]
	var dados: Dictionary = definicoes[chave].duplicate()
	if str(tipo_logico).begins_with("caixa_") and not ResourceLoader.exists(dados.image):
		var substituto:=obter("caixa",rotacao).duplicate(true)
		ItensPlex.ajustar(substituto,tipo_logico)
		substituto.textura=ItensPlex.compor([{"volume":substituto}]).textura
		cache[chave_cache]=substituto
		return substituto
	dados.textura = CatalogoPlex.textura(dados.image)
	var imagem: Image = CatalogoPlex.imagem(dados.image)
	var imagem_superficies: Image = CatalogoPlex.imagem(dados.normal) if dados.has("normal") and FileAccess.file_exists(dados.normal) else null
	if imagem_superficies!=null and imagem_superficies.get_size()!=imagem.get_size():imagem_superficies=null
	var faces := PackedColorArray()
	var profundidades: PackedFloat32Array = FileAccess.get_file_as_bytes(dados.depth).to_float32_array() if FileAccess.file_exists(dados.depth) else PackedFloat32Array()
	if tipo=="palco": profundidades=PalcosMadeiraPlex.mapa(imagem,Vector2i(dados.origin[0],dados.origin[1]))
	var pontos := PackedVector3Array()
	var cores := PackedColorArray()
	for y in imagem.get_height():
		for x in imagem.get_width():
			var cor := imagem.get_pixel(x, y)
			if cor.a > 0.0:
				pontos.append(Vector3(x + int(dados.origin[0]), y + int(dados.origin[1]), profundidades[y * imagem.get_width() + x]))
				cores.append(Color(cor,1.0) if CatalogoPlex.base(tipo_logico)=="parede" else cor)
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
	if info_tipo.get("mobilia",false) and info_tipo.get("logico","")=="parede":
		for i in cores.size():
			var cor: Color=cores[i]
			if cor.is_equal_approx(Color("a09d8f")) or cor.is_equal_approx(Color("ded9c5")):
				cores[i]=Color("b5b09e")
	dados.pontos = pontos
	dados.cores = cores
	dados.superficies = SuperficiesPlex.parede(pontos, nivel, ligacoes) if tipo == "parede" else faces
	if not fachada and tipo in CatalogoPlex.PORTAS:
		dados.superficies = SuperficiesPlex.porta(pontos, cores, nivel)
	if not fachada and tipo in SalasPlex.ESTRUTURA:
		dados.cores = SuperficiesPlex.cores_continuas(pontos, cores, dados.superficies)
	if dados.superficies.is_empty(): dados.superficies=SuperficiesPlex.normais_volume(pontos)
	if tipo_logico not in SalasPlex.ESTRUTURA and not CatalogoPlex.objetos.get(tipo_logico,{}).get("estrutura",false):
		for i in dados.superficies.size():
			if dados.superficies[i].a<.75: dados.superficies[i].a=.2
	if CatalogoPlex.base(tipo_logico)=="lixeira":
		for i in dados.superficies.size(): dados.superficies[i].a=.22
	if tipo_logico=="antigo_armario_vestiario":
		for i in dados.superficies.size(): dados.superficies[i].a=.24
	if ItensPlex.personalizado(tipo_logico):
		dados.rotacao_marca = rotacao
		ItensPlex.ajustar(dados,tipo_logico)
		dados.textura = ItensPlex.compor([{"volume":dados}]).textura
		dados.origin = [-96,-144]
	if tipo_logico.begins_with("janela"): dados=FachadaPlex.recortar_janela(dados,tipo_logico,rotacao)
	if CortinasPalcoPlex.eh(tipo_logico):CortinasPalcoPlex.aparar(dados,tipo_logico,rotacao)
	dados=EncaixesMobiliaPlex.volume(dados,tipo_logico,rotacao)
	cache[chave_cache] = dados
	return dados

static func objeto(registro: Dictionary, planta: PlantaPlex, nivel: int, niveis: Dictionary = {}) -> Dictionary:
	if str(registro.tipo).begins_with("ajuste_cabeca_") or str(registro.tipo).begins_with("ajuste_estrutura_"):return OficinaRobosPlex.volume_cabeca(registro)
	if registro.has("modelo_vi") and registro.has("modulo"):return ViVisuaisPlex.volume(registro)
	if str(registro.tipo)=="sistema_camera_parede":return CamerasVigilanciaPlex.volume(registro)
	if registro.has("fantasia_bancada") and CatalogoPlex.objetos.has("of_fantasia_bancada"):return AmbientesAssetsPlex.obter("of_fantasia_bancada",GradePlex.rotacao_visual(int(registro.rotacao)),str(registro.fantasia_bancada))
	if DecoracaoEstudoPlex.eh(str(registro.tipo)):return DecoracaoEstudoPlex.obter(str(registro.tipo),GradePlex.rotacao_visual(registro.rotacao),floorf(float(registro.get("relogio_minutos",610.0))*4)/4.0,MobiliaPlex.estado(registro))
	if PacotesPratosPlex.guardado(registro): return PacotesPratosPlex.volume(registro,GradePlex.rotacao_visual(registro.rotacao))
	var ligacoes := mascara(registro, planta, niveis)
	if registro.tipo in ["parede", "parede_fachada", "palco"]: ligacoes = GradePlex.mascara_visual(ligacoes)
	var visual := MobiliaPlex.visual(registro)
	if visual.begins_with("festa_bolo") and registro.has("porcoes"):
		return FestasRestaurantePlex.recortar_bolo(obter(visual,GradePlex.rotacao_visual(registro.rotacao),4,0,false,MobiliaPlex.estado(registro)),registro)
	if PalcosMadeiraPlex.eh(visual): return PalcosMadeiraPlex.obter(MobiliaPlex.estado(registro),ligacoes)
	if CatalogoPlex.objetos.get(visual, {}).get("mobilia", false):
		if nivel<4 and MobiliaPlex.logico(visual)=="parede":
			var estado_fonte:=MobiliaPlex.estado(registro)
			return ParedesContinuasPlex.obter(obter(visual,GradePlex.rotacao_visual(registro.rotacao),4,ligacoes,false,estado_fonte),nivel,ligacoes)
		var variedade:=posmod(hash(registro.celula),4) if visual=="antigo_parede_quebrada_modulo" and MobiliaPlex.estado(registro)=="rachada" else 0
		var volume_mobilia:=obter(visual, GradePlex.rotacao_visual(registro.rotacao), nivel, ligacoes, registro.get("aberta",false), MobiliaPlex.estado(registro),variedade)
		return AcabamentoEsquadriasPlex.aplicar(volume_mobilia,planta,registro,nivel) if AcabamentoEsquadriasPlex.eh(registro) else volume_mobilia
	if visual!=registro.tipo or visual.begins_with("festa_"):
		return obter(visual,GradePlex.rotacao_visual(registro.rotacao),nivel,ligacoes,registro.get("aberta",false),MobiliaPlex.estado(registro))
	var volume:=obter(registro.tipo, GradePlex.rotacao_visual(registro.rotacao), nivel, ligacoes, registro.aberta if registro.tipo in CatalogoPlex.PORTAS else false, FachadaPlex.estado(planta, registro))
	return AcabamentoEsquadriasPlex.aplicar(volume,planta,registro,nivel) if AcabamentoEsquadriasPlex.eh(registro) else volume



static func piso(tipo:String,rotacao:int,estado:String) -> Dictionary:
	var chave:="piso:"+str([tipo,rotacao,estado])
	if cache.has(chave):return cache[chave]
	var t:=CatalogoPlex.sprite(tipo,rotacao,estado);var imagem:=t.get_image()
	var pivo:Array=CatalogoPlex.objetos[tipo].get("pivo",[96,144])
	var origem:=Vector2i(-int(pivo[0]),-int(pivo[1]));var pontos:=PackedVector3Array();var cores:=PackedColorArray();var normais:=PackedColorArray()
	for y in imagem.get_height():
		for x in imagem.get_width():
			var cor:=imagem.get_pixel(x,y)
			if cor.a<=0:continue
			var p:=Vector2i(x,y)+origem;pontos.append(Vector3(p.x,p.y,p.y*2.0));cores.append(cor);normais.append(Color(.5,.5,1,.2))
	var d:={"image":"","origin":[origem.x,origem.y],"textura":t,"pontos":pontos,"cores":cores,"superficies":normais};cache[chave]=d;return d
