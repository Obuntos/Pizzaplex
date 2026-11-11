class_name PlantaPlex
extends RefCounted

signal alterada
signal piso_alterado
var entrega_embalada:=false
var bairro_ativo := false
var lote_restaurante := Rect2i(33,25,12,12)
var bairro_bloqueios: Dictionary = {}
var objetos: Dictionary = {}
var ocupacao: Dictionary = {}
var cores: Dictionary = {}
var pisos: Dictionary = {}
var rotacoes_pisos: Dictionary = {}
var uso_pisos: Dictionary = {}
var proximo_id: int = 1
var funcoes_salas: Dictionary = {}
var reservas_abertura: Dictionary = {}
var cabines_por_celula: Dictionary = {}
var revisao := 0
var indice_filhos: Dictionary = {}
var indice_sujo := true
var area_construcao := Rect2i()
var terrenos_adquiridos: Dictionary = {}
var indice_residuos: Dictionary = {}
var revisao_residuos := -1
var indice_tipos: Dictionary = {}
var revisao_tipos := -1

func _init() -> void:
	alterada.connect(invalidar_indices)
	alterada.connect(atualizar_reservas)

func notificar_piso() -> void:
	piso_alterado.emit()

func invalidar_indices() -> void:
	revisao += 1
	indice_sujo = true

func listar(chave: String) -> Array:
	if revisao_tipos != revisao:
		indice_tipos.clear()
		revisao_tipos = revisao
	if not indice_tipos.has(chave):
		var itens: Array = []
		for item in objetos.values():
			if pertence(item, chave): itens.append(item)
		indice_tipos[chave] = itens
	return indice_tipos[chave]

static func pertence(item: Dictionary, chave: String) -> bool:
	match chave:
		"portas": return item.tipo in CatalogoPlex.PORTAS
		"cameras": return MobiliaPlex.dados(item).get("camera", false)
		"terminais": return item.tipo == "terminal_ibm"
	return false

func filhos_de(pai: int, slot: int = -1) -> Array:
	if indice_sujo:
		indice_filhos.clear()
		for item in objetos.values():
			var base: int = item.get("sobre",-1)
			if base<0 or item.get("carregada_por",0)>0: continue
			if not indice_filhos.has(base): indice_filhos[base] = []
			indice_filhos[base].append(item)
		indice_sujo = false
	var lista: Array = indice_filhos.get(pai,[])
	return lista.duplicate() if slot<0 else lista.filter(func(item): return int(item.get("slot",-1))==slot)

func atualizar_reservas() -> void:
	cabines_por_celula.clear()
	for item in objetos.values():
		if item.tipo == "divisoria_porta":
			for local in celulas(item.tipo, item.celula, item.rotacao): cabines_por_celula[local] = item.id
	for porta in objetos.values():
		if porta.tipo not in CatalogoPlex.PORTAS: continue
		for c in celulas(porta.tipo,porta.celula,porta.rotacao):
			if pisos.has(c): continue
			for d in [GradePlex.frente(porta.rotacao),-GradePlex.frente(porta.rotacao)]:
				if pisos.has(c+d):
					pisos[c]=pisos[c+d]
					rotacoes_pisos[c]=rotacoes_pisos.get(c+d,0)
					break
	LugaresPlex.sincronizar(self)
	reservas_abertura.clear()
	ApoiosPlex.carregar()
	for objeto in objetos.values():
		if not ApoiosPlex.definicoes.has(objeto.tipo) or objeto.get("carregada_por",0)>0: continue
		var definicao: Dictionary = ApoiosPlex.definicoes[objeto.tipo]
		var estado: String = objeto.get("estado",CatalogoPlex.objetos[objeto.tipo].estado_padrao)
		var pontos: Array = definicao.estados.get(estado,definicao.estados.values()[0])[objeto.rotacao].reserva
		var centro := ApoiosPlex.posicao(self,objeto)
		for ponto in pontos:
			reservas_abertura[Vector2i(roundi(centro.x+ponto.u),roundi(centro.y+ponto.v))] = objeto.id

	for ponto in objetos.values():
		if ponto.tipo not in ["ponto_recebimento","area_montagem_atracao"]: continue
		var caixas := ApoiosPlex.filhos(self,ponto.id)
		if caixas.is_empty(): continue
		for c in celulas(ponto.tipo,ponto.celula,ponto.rotacao): reservas_abertura[c] = caixas[-1].id

func celulas(tipo: String, celula: Vector2i, rotacao: int) -> Array[Vector2i]:
	var dimensao := CatalogoPlex.dimensoes(tipo, rotacao)
	var resultado: Array[Vector2i] = []
	for x in dimensao.x:
		for y in dimensao.y:
			resultado.append(celula + Vector2i(x, y))
	return resultado

func sobreposto(tipo: String) -> bool:
	return tipo in ["luz_teto", "luz_parede", "luz_chao", "luz_teto_economica", "luz_parede_economica", "luz_chao_economica", "pose", "pose_quebrado", "pose_montagem"] or bool(CatalogoPlex.objetos.get(tipo, {}).get("sobreposto", false))

func sobre(celula: Vector2i, tipo: String = "") -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	for objeto in objetos.values():
		if objeto.celula == celula and (sobreposto(objeto.tipo) or objeto.get("sobre", -1) >= 0) and (tipo.is_empty() or objeto.tipo == tipo):
			resultado.append(objeto)
	return resultado

func residuos(celula: Vector2i) -> Array:
	if revisao_residuos!=revisao:
		indice_residuos.clear()
		for item in objetos.values():
			if item.get("carregada_por",0)>0 or item.get("sobre",-1)>=0 or not LimpezaAmbientesPlex.eh(item): continue
			for c in celulas(item.tipo,item.celula,item.rotacao):
				if not indice_residuos.has(c): indice_residuos[c]=[]
				indice_residuos[c].append(item)
		revisao_residuos=revisao
	return indice_residuos.get(celula,[])

func construcao_limpa(tipo: String, celula: Vector2i, rotacao: int) -> bool:
	if CatalogoPlex.objetos.get(tipo,{}).get("piso",false): return true
	for c in celulas(tipo,celula,rotacao):
		if not residuos(c).is_empty(): return false
	return true

func pode_colocar(tipo: String, celula: Vector2i, rotacao: int) -> bool:
	if PortasPlex.ajusta(tipo):
		rotacao = PortasPlex.rotacao_para(self, tipo, celula, rotacao)
	if not construcao_limpa(tipo,celula,rotacao): return false
	if tipo=="amb_coifa_industrial" or EncaixesMobiliaPlex.bloqueia_camera(self,tipo,celula,rotacao):return false
	if CatalogoPlex.objetos.get(tipo,{}).get("camera",false) and not EncaixesMobiliaPlex.camera_livre(self,{"tipo":tipo,"celula":celula,"rotacao":rotacao}):return false
	if not GradePlex.dentro(celula):
		return false
	if tipo in ["ponto_recebimento","area_montagem_atracao"]:
		for c in celulas(tipo,celula,rotacao):
			if not GradePlex.dentro(c) or not em(c).is_empty(): return false
			for p in objetos.values():
				if p.tipo == tipo and celulas(tipo,p.celula,p.rotacao).has(c): return false
		return true
	if tipo == "divisoria_porta":
		var modulo := {"tipo":tipo,"celula":celula,"rotacao":rotacao}
		for local in celulas(tipo, celula, rotacao):
			if not GradePlex.dentro(local) or not CabinesPlex.em(self, local).is_empty(): return false
			var base := em(local)
			if not base.is_empty() and (base.tipo != "vaso_sanitario" or base.rotacao != rotacao or local != CabinesPlex.fundo(self, modulo)): return false
		return true
	if ApoiosPlex.decoracao_mesa(tipo):
		if not ApoiosPlex.encontrar(self,celula,tipo).is_empty():return true
		return celulas(tipo,celula,rotacao).all(func(c):return GradePlex.dentro(c) and em(c).is_empty() and sobre(c,tipo).is_empty())
	if ApoiosPlex.superficie(tipo):
		var apoio := ApoiosPlex.encontrar(self, celula, tipo)
		if tipo == "prato" and LugaresPlex.mesa(objetos.get(apoio.get("pai", -1), {}).get("tipo", "")): return false
		return not apoio.is_empty()
	if CortinasPalcoPlex.eh(tipo):
		for c in celulas(tipo,celula,rotacao):
			if not GradePlex.dentro(c) or CatalogoPlex.base(em(c).get("tipo","")) in SalasPlex.ESTRUTURA: return false
		return CortinasPalcoPlex.livre(self,{"tipo":tipo,"celula":celula,"rotacao":rotacao})
	if tipo=="sistema_caixa_som_chao" and EscadasPlex.palco(em(celula)):
		return not objetos.values().any(func(o):return o.tipo==tipo and o.celula==celula)
	if tipo.begins_with("festa_baloes") and not em(celula).is_empty() and not EscadasPlex.palco(em(celula)):return false
	if sobreposto(tipo):
		if tipo.begins_with("luz_") and objetos.values().filter(func(item): return item.tipo.begins_with("luz_")).size() >= 32:
			return false
		if tipo != "pose" and not sobre(celula, tipo).is_empty():
			return false
		if LuminariasPlex.eh(tipo):
			for item in sobre(celula):
				if LuminariasPlex.tipo(item.tipo)==LuminariasPlex.tipo(tipo): return false
		var base := em(celula).get("tipo", "") as String
		if tipo=="oficina_duto_grade":return EncaixesMobiliaPlex.parede_permitida(self,tipo,celula,rotacao)
		if tipo.begins_with("oficina_duto_"):return base not in CatalogoPlex.PORTAS
		if tipo == "pose_montagem": return base in ["","palco"]
		if tipo == "pose_quebrado": return base==""
		if tipo == "pose":
			return base in ["","palco"] or EscadasPlex.palco(em(celula))
		if CatalogoPlex.objetos[tipo].get("parede_requerida",false):
			return EncaixesMobiliaPlex.parede_permitida(self,tipo,celula,rotacao)
		if LuminariasPlex.tipo(tipo) == "luz_parede":
			return EncaixesMobiliaPlex.parede_permitida(self,tipo,celula,rotacao)
		if LuminariasPlex.tipo(tipo) == "luz_chao":
			return base in ["", "palco"] or EscadasPlex.palco(em(celula))
		return CatalogoPlex.base(base) not in SalasPlex.ESTRUTURA and celulas(tipo,celula,rotacao).all(func(c):return GradePlex.dentro(c) and CatalogoPlex.base(em(c).get("tipo","")) not in SalasPlex.ESTRUTURA)
	if EncaixesMobiliaPlex.corta_parede(self,tipo,celula,rotacao): return false
	for local in celulas(tipo, celula, rotacao):
		var cabine := CabinesPlex.em(self, local)
		if not cabine.is_empty() and (tipo != "vaso_sanitario" or rotacao != cabine.rotacao or local != CabinesPlex.fundo(self, cabine)): return false
		if not GradePlex.dentro(local) or ocupacao.has(local) or reservas_abertura.has(local):
			return false
		if not sobre(local,"pose_quebrado").is_empty() or not sobre(local,"pose_montagem").is_empty(): return false
		if tipo != "palco" and LuminariasPlex.no_chao(self,local):
			return false
	return true

func colocar(tipo: String, celula: Vector2i, rotacao: int = 0) -> int:
	if PortasPlex.ajusta(tipo):
		rotacao = PortasPlex.rotacao_para(self, tipo, celula, rotacao)
	if not pode_colocar(tipo, celula, rotacao):
		return -1
	if tipo == "pose" and not sobre(celula, "pose").is_empty():
		var existente: Dictionary = sobre(celula, "pose")[0]
		existente.rotacao = posmod(rotacao, 4)
		alterada.emit()
		return existente.id
	if tipo=="sistema_caixa_som_chao" and EscadasPlex.palco(em(celula)):return inserir(tipo,celula,rotacao,{},{"sobre_palco":true})
	var encaixe := ApoiosPlex.encontrar(self, celula, tipo) if ApoiosPlex.superficie(tipo) or ApoiosPlex.decoracao_mesa(tipo) else {}
	return inserir(tipo,celula,rotacao,encaixe)

func registrar_cidade(tipo: String, celula: Vector2i, rotacao: int, extras: Dictionary) -> int:
	if not CatalogoPlex.objetos.has(tipo) or not GradePlex.dentro(celula): return -1
	return inserir(tipo,celula,rotacao,{},extras)

func inserir(tipo: String, celula: Vector2i, rotacao: int, encaixe: Dictionary, extras: Dictionary = {}) -> int:
	var id := proximo_id
	proximo_id += 1
	objetos[id] = {"id": id, "tipo": tipo, "celula": celula, "rotacao": posmod(rotacao, 4), "aberta": false, "endo": false, "pecas": 0, "montado": false, "robo_saiu": false, "caixa": false, "reserva": 0, "entregue": false, "ligada": true, "cor_luz": "#fff0d5", "energia": 1.2}
	var registro: Dictionary = objetos[id]
	registro.estado = CatalogoPlex.objetos[tipo].get("estado_padrao", "")
	registro.sobre = encaixe.get("pai", -1)
	registro.slot = encaixe.get("slot", -1)
	registro.carregada_por = 0
	registro.ingredientes = 0
	registro.lixo = 0
	if CatalogoPlex.objetos[tipo].get("gerador",false): registro.combustivel = 100.0
	MobiliaPlex.preparar(registro, tipo)
	if tipo.begins_with("caixa"):
		registro.recurso = CatalogoPlex.objetos[tipo].get("recurso", "pecas")
		registro.quantidade = CatalogoPlex.objetos[tipo].get("quantidade", 1)
	if tipo == "divisoria_porta":
		for local in celulas(tipo, celula, rotacao): cabines_por_celula[local] = id
	registro.merge(extras,true)
	if ocupa(registro):
		for local in celulas(tipo, celula, rotacao):
			ocupacao[local] = id
	KitLimpezaPlex.fornecer(self,registro)
	alterada.emit()
	return id

func em(celula: Vector2i) -> Dictionary:
	return objetos.get(ocupacao.get(celula, -1), {})

func remover(id: int) -> void:
	if not objetos.has(id):
		return
	var objeto: Dictionary = objetos[id]
	var destino: int = objeto.get("destino_montagem",-1)
	if objetos.has(destino) and int(objetos[destino].get("dono",-1))<0: objetos.erase(destino)
	for filho in ApoiosPlex.filhos(self, id): remover(filho.id)
	if ocupa(objeto):
		for local in celulas(objeto.tipo, objeto.celula, objeto.rotacao):
			if ocupacao.get(local, -1) == id: ocupacao.erase(local)
			for adicional in sobre(local):
				if adicional.tipo in ["pose", "pose_quebrado", "pose_montagem", "luz_parede", "luz_parede_economica"] or CatalogoPlex.objetos[adicional.tipo].get("parede_requerida",false):
					objetos.erase(adicional.id)
	objetos.erase(id)
	PilhasPlex.compactar(self,int(objeto.get("sobre",-1)))
	alterada.emit()

func ocupa(objeto: Dictionary) -> bool:
	return objeto.tipo != "divisoria_porta" and not objeto.get("sobre_palco",false) and not sobreposto(objeto.tipo) and not objeto.get("solto", false) and objeto.get("sobre", -1) < 0 and objeto.get("carregada_por", 0) == 0

func reindexar() -> void:
	indice_sujo = true
	revisao_residuos = -1
	for item in objetos.values():
		if item.tipo=="estante" and item.get("variante","")=="antigo_estante_velha_1":
			item.tipo="estante_compacta"
			var filhos: Array=objetos.values().filter(func(f): return int(f.get("sobre",-1))==int(item.id))
			for i in filhos.size():
				if i<3: filhos[i].slot=i
				else: filhos[i].sobre=-1;filhos[i].slot=-1;filhos[i].celula=item.celula+GradePlex.frente(item.rotacao);filhos[i].solto=true
		if SubstituicaoParedesPlex.estrutural(item): item.erase("solto")
	for objeto in objetos.values():
		if objeto.tipo == "ponto_recebimento": PilhasPlex.compactar(self,objeto.id)
	ocupacao.clear()
	for objeto in objetos.values():
		if ocupa(objeto):
			for local in celulas(objeto.tipo, objeto.celula, objeto.rotacao):
				ocupacao[local] = objeto.id
	corrigir_apoios_mesas()

func corrigir_apoios_mesas() -> void:
	var tabelas: Dictionary = {}
	for item in objetos.values():
		var pai: int = int(item.get("sobre",-1))
		if pai < 0 or int(item.get("carregada_por",0)) > 0 or item.get("atracao_caixa",false) or not objetos.has(pai): continue
		var mesa: Dictionary = objetos[pai]
		if not LugaresPlex.mesa(str(mesa.tipo)) or mesa.get("mesa_cozinha",false): continue
		if not tabelas.has(pai): tabelas[pai] = ApoiosPlex.pontos(mesa,self)
		var pontos: Array = tabelas[pai]
		var slot: int = int(item.get("slot",-1))
		var caixa: bool = ApoiosPlex.caixa_ou_ibm(str(item.tipo))
		var categoria: String = "terminal-ibm" if MobiliaPlex.logico(str(item.tipo)) == "terminal_ibm" else "registradora"
		if slot >= 0 and slot < pontos.size() and (not caixa or pontos[slot].accepts.has(categoria)): continue
		var tipo: String = MobiliaPlex.visual(item.conteudo_movel) if EmbalagensMoveisPlex.eh(item) and item.has("conteudo_movel") else str(item.tipo)
		if caixa: tipo = MobiliaPlex.logico(str(item.tipo))
		item.sobre = -1
		indice_sujo = true
		var novo: int = ApoiosPlex.livre(self,pai,tipo)
		item.sobre = pai
		indice_sujo = true
		if novo >= 0: item.slot = novo

func altura(celula: Vector2i) -> float:
	var objeto := em(celula)
	if EscadasPlex.palco(objeto):
		return GradePlex.ALTURA_PALCO
	if EscadasPlex.eh(objeto):
		return GradePlex.ALTURA_PALCO * 0.5
	return 0.0

func bloqueio_abertura(celula: Vector2i) -> bool:
	if not reservas_abertura.has(celula): return false
	var item: Dictionary=objetos.get(int(reservas_abertura[celula]),{})
	return item.get("tipo","") not in ["geladeira","forno"] or PontosUsoPlex.frente(item)!=celula

func transitavel(celula: Vector2i) -> bool:
	if not GradePlex.dentro(celula) or bloqueio_abertura(celula) or bairro_bloqueios.has(celula):
		return false
	var objeto := em(celula)
	if CaminhosCidadePlex.passagem(objeto,celula): return true
	return objeto.is_empty() or objeto.tipo in CatalogoPlex.PORTAS and not objeto.get("trancada",false) or EscadasPlex.tipo(objeto) in ["palco","escada"]

func interacoes(id: int) -> Array[Vector2i]:
	var resultado: Array[Vector2i] = []
	if not objetos.has(id):
		return resultado
	var objeto: Dictionary = objetos[id]
	if EmbalagensMoveisPlex.eh(objeto) and not PassagemCadeirasPlex.mesa(self,objeto).is_empty():
		var diretas:=PassagemCadeirasPlex.entradas_diretas(self,objeto)
		return diretas if not diretas.is_empty() else PassagemCadeirasPlex.entradas(self,objeto)
	if AmbientesAssetsPlex.eh(MobiliaPlex.visual(objeto)) and MobiliaPlex.dados(objeto).get("parede_requerida",false):
		for c in celulas(objeto.tipo,objeto.celula,objeto.rotacao):
			var local:Vector2i=c+GradePlex.frente(objeto.rotacao)
			if transitavel(local):resultado.append(local)
		return resultado
	if MobiliaPlex.dados(objeto).get("ambiente_novo",false) and AcessosConstrucaoPlex.exige_uso(objeto) and not LugaresPlex.mesa(str(objeto.tipo)) and objeto.tipo not in ["forno","pia","vaso_sanitario","pia_banheiro","cadeira","registradora","divisoria_porta"] and int(objeto.get("sobre",-1))<0:
		var dimensao:=CatalogoPlex.dimensoes(objeto.tipo,objeto.rotacao)
		var centro:=Vector2(objeto.celula)+Vector2(dimensao-Vector2i.ONE)*.5
		var frente:=Vector2(GradePlex.frente(objeto.rotacao))
		var alcance:=float(dimensao.x if frente.x!=0 else dimensao.y)*.5+.5
		var local:=Vector2i((centro+frente*alcance).round())
		if transitavel(local):resultado.append(local)
		return resultado
	if objeto.tipo=="area_montagem_atracao":
		var dimensao:=CatalogoPlex.dimensoes(objeto.tipo,objeto.rotacao)
		var centro:=Vector2(objeto.celula)+Vector2(dimensao-Vector2i.ONE)*.5
		var frente:=Vector2(GradePlex.frente(objeto.rotacao))
		var alcance:=float(dimensao.x if frente.x!=0 else dimensao.y)*.5+.5
		var local:=Vector2i((centro+frente*alcance).round())
		if transitavel(local):resultado.append(local)
		return resultado
	if objeto.tipo=="armario_funcionarios":return ArmariosPlex.acessos_vestiario(self,objeto)
	if MontagemAtracoesPlex.bancada(objeto):
		var tamanho:=CatalogoPlex.dimensoes(objeto.tipo,objeto.rotacao)
		var deslocamento:=Vector2(tamanho-Vector2i.ONE)*0.5
		var centro:Vector2i=objeto.celula+Vector2i(deslocamento)
		for lado in [GradePlex.frente(objeto.rotacao),-GradePlex.frente(objeto.rotacao)]:
			if transitavel(centro+lado):resultado.append(centro+lado)
		return resultado
	if DescartePlex.eh(objeto): return DescartePlex.acessos(self,objeto)
	if objeto.tipo=="banco_espera": return BancosCidadePlex.acessos(self,objeto)
	if objeto.tipo=="cadeira": return PontosUsoPlex.acessos_cadeira(self,objeto)
	if objeto.tipo=="registradora": return CaixaPlex.postos(self,objeto,true)
	if FornoPlex.eh(objeto) and objeto.tipo!="forno": return FornoPlex.acessos(self,id)
	if objeto.tipo=="terminal_ibm":
		var posto:=PontosUsoPlex.terminal(self,objeto)
		if transitavel(posto) and is_zero_approx(altura(posto)): resultado.append(posto)
		return resultado
	if objeto.get("sobre", -1) >= 0:
		return interacoes(ApoiosPlex.raiz(self, id))
	if LugaresPlex.mesa(objeto.tipo): return LugaresPlex.acessos(self,objeto)
	ApoiosPlex.carregar()
	if ApoiosPlex.definicoes.has(objeto.tipo) and (not sobreposto(objeto.tipo) or objeto.tipo=="prateleira_suspensa"):
		return interacoes_estado(id,objeto.get("estado",CatalogoPlex.objetos[objeto.tipo].estado_padrao))
	if objeto.tipo == "mesa":
		for deslocamento in [Vector2i(1,1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(-1,-1)]:
			var local: Vector2i = objeto.celula + deslocamento
			if transitavel(local) and is_zero_approx(altura(local)): resultado.append(local)
		return resultado
	if PontosUsoPlex.tem(objeto.tipo):
		for local in PontosUsoPlex.alvos(objeto):
			if transitavel(local) and is_zero_approx(altura(local)): resultado.append(local)
		return resultado
	for ocupado in celulas(objeto.tipo, objeto.celula, objeto.rotacao):
		for deslocamento in GradePlex.VIZINHOS:
			var local: Vector2i = ocupado + deslocamento
			if transitavel(local) and is_zero_approx(altura(local)) and not resultado.has(local):
				resultado.append(local)
	return resultado

func interacoes_estado(id: int, estado: String) -> Array[Vector2i]:
	var resultado: Array[Vector2i] = []
	if not objetos.has(id): return resultado
	var objeto: Dictionary = objetos[id]
	ApoiosPlex.carregar()
	if not ApoiosPlex.definicoes.has(objeto.tipo): return interacoes(id)
	var definicao: Dictionary = ApoiosPlex.definicoes[objeto.tipo]
	var vista: Dictionary = definicao.estados.get(estado,definicao.estados.values()[0])[0]
	var ponto: Dictionary = vista.interacao
	var preferida:=PontosUsoPlex.interacao(objeto,ponto)
	if transitavel(preferida) and is_zero_approx(altura(preferida)): resultado.append(preferida)
	return resultado

func bancada_proxima(suporte: int) -> bool:
	if not objetos.has(suporte):
		return false
	for objeto in objetos.values():
		if objeto.tipo == "bancada" and Vector2(objeto.celula).distance_to(Vector2(objetos[suporte].celula)) <= 2.1:
			return true
	return false

func ponto_caixa(bancada: int) -> Vector3:
	return PontosUsoPlex.caixa(objetos[bancada])


