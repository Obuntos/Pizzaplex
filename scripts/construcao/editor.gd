class_name EditorPlex
extends RefCounted

signal aviso(texto: String)
signal destino_quebrado_escolhido(id: int, celula: Vector2i, rotacao: int)
signal spawn_solicitado(modelo: String, celula: Vector2i)
var jogo: Node
var acessos:=AcessosConstrucaoPlex.new()
var planta: PlantaPlex
var personagens: Array = []
var marca_quebrado := -1
var alvo_pose_atracao:=-1
var atracao_pendente:=""
var ferramenta: String = "selecionar"
var rotacao: int = 0
var cor: int = 0
var estado_visual := ""
var item_movendo:=-1
var historico: Array[Dictionary]=[]
var pintura_ativa:=false
var pintura_acao:Dictionary={}
var remocao_direta:=-1
var remocao_celula:=Vector2i(-1,-1)

func folha_remocao(id:int) -> Dictionary:
	var item:Dictionary=planta.objetos.get(id,{})
	if item.is_empty():return {}
	var filhos:=ApoiosPlex.filhos(planta,id).filter(func(o):return int(o.get("carregada_por",0))==0)
	if not filhos.is_empty():return folha_remocao(int(filhos[-1].id))
	return item

func remover_uma_vez(c:Vector2i,visitadas:Dictionary) -> void:
	if visitadas.has(c):return
	visitadas[c]=true
	if permitido(c):aplicar(c)
var luz_padrao: Dictionary = {"cor_luz":"#fff0d5","energia":1.2,"ligada":true}

func _init(valor: PlantaPlex) -> void:
	planta = valor

func livre(celula: Vector2i) -> bool:
	for pessoa in personagens:
		if pessoa.celula == celula or (pessoa.movimento.atravessando and pessoa.movimento.destino == celula):
			return false
	return true

func construindo() -> bool:
	return ferramenta in ["remover","chao","editar_luz","pose_quebrado","pose_montagem"] or ferramenta.begins_with("sala:") or CatalogoPlex.objetos.has(ferramenta)

func alvo_remocao(celula: Vector2i) -> Dictionary:
	if celula==remocao_celula and planta.objetos.has(remocao_direta):return folha_remocao(remocao_direta)
	var cortinas:Array=planta.objetos.values().filter(func(o):return CortinasPalcoPlex.eh(str(o.tipo)) and planta.celulas(o.tipo,o.celula,o.rotacao).has(celula))
	if not cortinas.is_empty():return folha_remocao(int(cortinas[-1].id))
	var adicionais:=planta.sobre(celula).filter(func(registro): return not LimpezaAmbientesPlex.eh(registro))
	var item: Dictionary=adicionais[-1] if not adicionais.is_empty() else planta.em(celula)
	if item.is_empty(): item=CabinesPlex.em(planta,celula)
	if item.is_empty():
		var residuos:=planta.residuos(celula)
		if not residuos.is_empty(): item=residuos[-1]
	return folha_remocao(int(item.id)) if not item.is_empty() else {}

func permitido(celula: Vector2i) -> bool:
	if jogo!=null and "sistemas" in jogo and jogo.sistemas!=null and "tutorial" in jogo.sistemas and is_instance_valid(jogo.sistemas.tutorial) and not jogo.sistemas.tutorial.permite_editor(ferramenta,celula,rotacao):return false
	if ferramenta=="area_montagem_atracao" and not atracao_pendente.is_empty() and planta.objetos.values().any(func(o): return o.tipo=="area_montagem_atracao"): return false
	if CatalogoPlex.objetos.get(ferramenta,{}).get("camera",false) and jogo!=null and not CamerasVigilanciaPlex.instalacao_permitida(jogo,{"celula":celula,"rotacao":rotacao}):return false
	if item_movendo>=0: return MoverItensPlex.avaliar(self,celula).permitido
	if CatalogoPlex.objetos.get(ferramenta,{}).get("apenas_cenario",false): return false
	if not construindo(): return GradePlex.dentro(celula)
	if ferramenta=="remover":
		var alvo:=alvo_remocao(celula)
		if not alvo.is_empty():return (not LimpezaAmbientesPlex.eh(alvo) or LimpezaAmbientesPlex.remocao_direta(alvo)) and not TerrenoPlex.protegido(planta,alvo) and TerrenoPlex.cabe(planta,alvo.tipo,alvo.celula,alvo.rotacao)
	if not TerrenoPlex.contem(planta,celula): return false
	if CatalogoPlex.objetos.has(ferramenta): return TerrenoPlex.permite(planta,ferramenta,celula,rotacao)
	if ferramenta=="remover":
		var item:=alvo_remocao(celula)
		if not item.is_empty(): return (not LimpezaAmbientesPlex.eh(item) or LimpezaAmbientesPlex.remocao_direta(item)) and not TerrenoPlex.protegido(planta,item) and TerrenoPlex.cabe(planta,item.tipo,item.celula,item.rotacao)
	return true

func aplicar(celula: Vector2i) -> void:
	_aplicar(celula)

func _aplicar(celula: Vector2i) -> void:
	if item_movendo>=0:
		MoverItensPlex.aplicar(self,celula)
		return
	if not GradePlex.dentro(celula):
		return
	if ferramenta=="remover":
		var alvo:=alvo_remocao(celula)
		if (LimpezaAmbientesPlex.eh(alvo) and not LimpezaAmbientesPlex.remocao_direta(alvo)) or alvo.is_empty() and not planta.residuos(celula).is_empty():
			aviso.emit("Limpe os entulhos antes de construir. A marreta não remove resíduos.")
			return
	if CatalogoPlex.objetos.get(ferramenta,{}).get("apenas_cenario",false):
		aviso.emit("Este detalhe pertence ao cenário do imóvel e não está à venda.")
		return
	if not permitido(celula):
		if CatalogoPlex.objetos.get(ferramenta,{}).get("camera",false):aviso.emit("Vire a câmera para uma sala interna. Não é permitido filmar a rua nem o banheiro.");return
		aviso.emit("As paredes do perímetro são protegidas. Coloque uma nova parede sobre a antiga para reformar." if ferramenta=="remover" and TerrenoPlex.contem(planta,celula) else "Construa apenas dentro do terreno do restaurante. Os tiles vermelhos marcam o limite.")
		return
	if ferramenta=="pose_quebrado" and jogo.sistemas.armazem.lugar>=0:
		jogo.sistemas.armazem.posicionar(celula,rotacao)
		return
	if ferramenta in ["pose_quebrado","pose_montagem"]:
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
		var objeto:=alvo_remocao(celula)
		if not objeto.is_empty():
			if not planta.sobreposto(objeto.tipo) and int(objeto.get("sobre",-1))<0:
				for local in planta.celulas(objeto.tipo,objeto.celula,objeto.rotacao):
					if not livre(local):
						aviso.emit("Mova o personagem antes de remover esse objeto.")
						return
			BalanceamentoPlex.remover(self,objeto.id)
		return
	if ferramenta=="pose" and alvo_pose_atracao>=0 and not jogo.atracoes.destino_valido(alvo_pose_atracao,celula):
		aviso.emit("Sem acesso à seta. Verifique as escadas e o caminho.")
		return
	if PinturaPisosPlex.eh(ferramenta):
		PinturaPisosPlex.aplicar(self,[celula])
		return
	if not CatalogoPlex.objetos.has(ferramenta):
		return
	var rotacao_real := PortasPlex.rotacao_para(planta, ferramenta, celula, rotacao) if PortasPlex.ajusta(str(ferramenta)) else rotacao
	for local in planta.celulas(ferramenta, celula, rotacao_real):
		if not planta.sobreposto(ferramenta) and not livre(local):
			aviso.emit("Este tile está ocupado por um personagem.")
			return
	var modulos := MobiliaPlex.modulos(ferramenta,celula,rotacao)
	for c in modulos:
		if not planta.construcao_limpa(ferramenta,c,rotacao_real):
			aviso.emit("Limpe os entulhos antes de colocar objetos neste espaço.")
			return
		if (not planta.pode_colocar(ferramenta,c,rotacao) and not SubstituicaoParedesPlex.permite(planta,ferramenta,c,rotacao)) or (not planta.sobreposto(ferramenta) and not livre(c)):
			aviso.emit("O objeto não cabe ou o acesso está ocupado.")
			return
	var uso:=acessos.avaliar(self,celula)
	if not uso.permitido:
		aviso.emit(str(uso.motivo))
		return
	var desenho:=LembrancasPlex.desenho(ferramenta)
	if desenho and (jogo==null or not jogo.servicos.presentes.has(ferramenta)):
		aviso.emit("Este desenho é um presente dos visitantes.")
		return
	var custo := 0 if desenho else MobiliaPlex.preco(ferramenta)*modulos.size()
	if not cobrar(custo): return
	var colocados: Array[int]=[]
	var anteriores: Array[Dictionary]=[]
	if CatalogoPlex.base(ferramenta) in SalasPlex.ESTRUTURA or MobiliaPlex.logico(ferramenta) in SalasPlex.ESTRUTURA:
		for c in modulos:
			var antigo:=planta.em(c)
			if not antigo.is_empty(): anteriores.append(antigo.duplicate(true))
			for luz in planta.sobre(c):
				if LuminariasPlex.eh(str(luz.tipo)):anteriores.append(luz.duplicate(true))
	var id := -1
	var bloqueado := planta.is_blocking_signals()
	planta.set_block_signals(true)
	planta.entrega_embalada=true
	for c in modulos:
		var colocado := SubstituicaoParedesPlex.aplicar(planta,ferramenta,c,rotacao,estado_visual) if SubstituicaoParedesPlex.permite(planta,ferramenta,c,rotacao) else planta.colocar(ferramenta,c,rotacao)
		if colocado >= 0:
			id = colocado
			colocados.append(id)
			planta.objetos[id].valor_pago = MobiliaPlex.preco(ferramenta) if jogo!=null and jogo.campanha else 0
			if CatalogoPlex.objetos[ferramenta].get("estados",[]).has(estado_visual):
				if planta.objetos[id].has("variante"): planta.objetos[id].estado_visual=estado_visual
				else: planta.objetos[id].estado=estado_visual
			EmbalagensMoveisPlex.embalar(planta,id)
	planta.entrega_embalada=false
	planta.set_block_signals(bloqueado)
	planta.alterada.emit()
	if id == -1:
		aviso.emit("Pose precisa de palco." if ferramenta == "pose" else "Luz de parede precisa de uma parede livre." if LuminariasPlex.tipo(ferramenta) == "luz_parede" else "O objeto não cabe ou o tile já está ocupado.")
	else:
		historico.append({"ids":colocados,"anteriores":anteriores})
		if historico.size()>64: historico.pop_front()
		if desenho:
			jogo.servicos.presentes.erase(ferramenta)
			planta.objetos[id].valor_pago=0
			ferramenta="selecionar"
			aviso.emit("Desenho pendurado.")
			return
		if ferramenta=="area_montagem_atracao" and not atracao_pendente.is_empty():
			if jogo.livro.reservar(atracao_pendente,id): atracao_pendente="";jogo.escolher_ferramenta("selecionar")
			else: planta.remover(id)
			return
		if ferramenta=="pose" and alvo_pose_atracao>=0:
			planta.objetos[id].seta_de=alvo_pose_atracao
			if jogo.atracoes.definir_pose(alvo_pose_atracao,id):
				alvo_pose_atracao=-1;jogo.escolher_ferramenta("selecionar")
			else: planta.remover(id);aviso.emit("Sem acesso à seta. Verifique as escadas e o caminho.")
			return
		if ferramenta.begins_with("luz_"):
			planta.objetos[id].merge(luz_padrao, true)
			planta.alterada.emit()
		aviso.emit(CatalogoPlex.objetos[ferramenta].nome + (" entregue em caixa. Botão direito para desembalar ou cancelar com reembolso integral." if EmbalagensMoveisPlex.eh(planta.objetos[id]) else " colocado. R gira o próximo objeto."))


func cobrar(valor: int) -> bool:
	if jogo == null or not jogo.campanha: return true
	if jogo.servicos.saldo < valor:
		aviso.emit("Dinheiro insuficiente. Custo: $ "+str(valor)+".")
		return false
	jogo.servicos.saldo -= valor
	jogo.compras_construcao += valor
	return true


func desfazer() -> bool:
	pintura_ativa=false;pintura_acao={}
	while not historico.is_empty():
		var acao: Dictionary=historico.back()
		if acao.has("pisos"):
			historico.pop_back()
			for anterior in acao.pisos:
				for campo in ["pisos","rotacoes_pisos","cores","uso_pisos"]:
					var mapa:Dictionary=planta.get(campo)
					if anterior.has(campo):mapa[anterior.celula]=anterior[campo]
					else:mapa.erase(anterior.celula)
			if jogo!=null and jogo.campanha:
				jogo.servicos.saldo+=int(acao.get("custo",0))
				jogo.compras_construcao=maxi(0,jogo.compras_construcao-int(acao.get("custo",0)))
			planta.notificar_piso();return true
		var ids: Array=acao.ids.filter(func(id): return planta.objetos.has(int(id)))
		if ids.is_empty(): historico.pop_back();continue
		for id in ids:
			var item: Dictionary=planta.objetos[int(id)]
			if int(item.get("carregada_por",0))>0 or personagens.any(func(a): return a.assento==int(item.id)) or not planta.sobreposto(item.tipo) and planta.celulas(item.tipo,item.celula,item.rotacao).any(func(c): return not livre(c)): return false
		historico.pop_back()
		for id in ids: BalanceamentoPlex.remover(self,int(id))
		for anterior in acao.get("anteriores",[]):
			planta.objetos[int(anterior.id)]=anterior
		planta.reindexar();planta.alterada.emit();return true
	return false
