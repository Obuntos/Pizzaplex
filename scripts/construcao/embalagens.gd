class_name EmbalagensMoveisPlex
extends RefCounted

static func compravel(tipo: String, info: Dictionary) -> bool:
	var logico:=str(info.get("logico",info.get("familia",tipo)))
	if info.get("bairro",false) or info.get("entulho",false) or info.get("piso",false) or info.get("estrutura",false) or info.get("cenario_parede",false) or info.get("oculto",false): return false
	if logico in SalasPlex.ESTRUTURA or logico in ["palco","escada","pose","pose_quebrado","pose_montagem","ponto_recebimento","suporte"] or PalcosMadeiraPlex.eh(tipo): return false
	if tipo.begins_with("luz_") or tipo.begins_with("caixa") or tipo.begins_with("festa_") or tipo.begins_with("presente_") or tipo.begins_with("embalagem_"): return false
	if info.get("ambiente_novo",false) and not info.get("apoio",false) and not info.get("parede_requerida",false) and not info.get("sobreposto",false):return true
	return logico in ["mesa","mesa_longa","mesa_longa_arredondada","cadeira","banco_espera","balcao","bancada","bancada_preparo","suporte","pia","geladeira","forno","fogao","lixeira","estante","estante_compacta","armario_limpeza","armario_utensilios","armario_funcionarios","armario_ferramentas","registradora","terminal_ibm","maquina_fliperama","vaso_sanitario","prateleira_suspensa"] or info.get("gerador",false)

static func catalogar(objetos: Dictionary) -> void:
	for tipo in objetos.keys():
		var info: Dictionary=objetos[tipo]
		if not compravel(tipo,info): continue
		objetos["embalagem_"+tipo]={"nome":"Caixa · "+str(info.nome),"largura":info.largura,"profundidade":info.profundidade,"altura":clampf(float(info.get("altura",28))*.65,12,38),"pivo":[96,144],"sobreposto":info.get("sobreposto",false),"apoio":false,"transitavel":false,"oculto":true,"conforto":0,"peso_conforto":0.0,"preco":MobiliaPlex.preco(tipo),"estados":["fechada"],"estado_padrao":"fechada","pasta":""}

static func eh(item: Dictionary) -> bool:
	return str(item.get("tipo","")).begins_with("embalagem_")

static func embalar(planta: PlantaPlex, id: int) -> void:
	var item: Dictionary=planta.objetos.get(id,{})
	if item.is_empty(): return
	var visual:=MobiliaPlex.visual(item)
	if not CatalogoPlex.objetos.has("embalagem_"+visual): return
	item.conteudo_movel=item.duplicate(true)
	item.conteudo_movel.erase("celula")
	item.tipo="embalagem_"+visual
	item.erase("variante");item.estado="fechada"

static func abrir(planta: PlantaPlex, id: int) -> bool:
	var caixa: Dictionary=planta.objetos.get(id,{})
	if not eh(caixa) or not caixa.has("conteudo_movel"): return false
	var item: Dictionary=caixa.conteudo_movel.duplicate(true)
	for campo in ["id","celula","rotacao","sobre","slot","valor_pago"]:
		if caixa.has(campo): item[campo]=caixa[campo]
	item.reserva=0
	planta.objetos[id]=item
	planta.reindexar()
	KitLimpezaPlex.fornecer(planta,item)
	planta.alterada.emit()
	return true

static func atribuir(servico: ServicosPlex, ator: PersonagemPlex) -> bool:
	if ator.carregando or ator.carga_item>=0 or not (AdministradorPlex.eh(ator) or EquipePlex.permite(ator,"estoque") or EquipePlex.permite(ator,"manutencao")): return false
	var caixas: Array=servico.planta.objetos.values().filter(func(item): return eh(item) and servico.livre(item.id))
	caixas.sort_custom(func(a,b): return int(a.get("abrir_solicitado",false))>int(b.get("abrir_solicitado",false)) if a.get("abrir_solicitado",false)!=b.get("abrir_solicitado",false) else Vector2(a.celula).distance_squared_to(ator.local)<Vector2(b.celula).distance_squared_to(ator.local))
	for caixa in caixas:
		if servico.iniciar(ator,"Desembalar móvel",[servico.etapa(caixa.id,"desembalar",3.0)],[caixa.id]): return true
	return false

static func solicitar(jogo: Node, id: int) -> void:
	if not eh(jogo.planta.objetos.get(id,{})): return
	if jogo.controle.manual():
		jogo.controle.solicitar("desembalar",-1,id)
		return
	jogo.planta.objetos[id].abrir_solicitado=true
