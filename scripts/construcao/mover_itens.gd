class_name MoverItensPlex
extends RefCounted

static var assinatura:=-1
static var resultado: Dictionary={}
static var base_previa: PlantaPlex
static var chave_previa:=-1

static func grupo(planta: PlantaPlex, id: int, lista: Array[int]) -> void:
	if lista.has(id): return
	lista.append(id)
	for filho in ApoiosPlex.filhos(planta,id): grupo(planta,filho.id,lista)

static func permitido(jogo: Node, id: int) -> bool:
	var item: Dictionary=jogo.planta.objetos.get(id,{})
	if item.is_empty() or not TerrenoPlex.contem(jogo.planta,item.celula): return false
	if item.has("robo_reserva") or item.has("reparo_reserva") or item.has("reparo_robo"):return false
	if "atracoes" in jogo and jogo.atracoes!=null and not jogo.atracoes.ordem(id).is_empty():return false
	if SubstituicaoParedesPlex.estrutural(item) or LimpezaAmbientesPlex.eh(item) or MobiliaPlex.dados(item).get("bairro",false): return false
	if item.tipo in ["pose_quebrado","pose_montagem","saco_lixo","palco","escada"]: return false
	var ids: Array[int]=[]
	grupo(jogo.planta,id,ids)
	for n in ids:
		var parte: Dictionary=jogo.planta.objetos[n]
		if int(parte.get("reserva",0))!=0 or int(parte.get("carregada_por",0))>0 or int(parte.get("familia_cliente",-1))>=0: return false
	for a in jogo.personagens:
		if ids.has(a.assento) or ids.has(a.suporte) or ids.has(a.pose): return false
	return true

static func iniciar(jogo: Node, id: int) -> void:
	var raiz:=ApoiosPlex.raiz(jogo.planta,id)
	if raiz>=0 and jogo.planta.objetos.get(raiz,{}).get("tipo","")=="armario_limpeza":id=raiz
	if not permitido(jogo,id):
		jogo.painel.mensagem("Aguarde o item ficar livre antes de movê-lo.")
		return
	var item: Dictionary=jogo.planta.objetos[id]
	jogo.escolher_ferramenta(item.tipo)
	jogo.editor.item_movendo=id
	jogo.editor.rotacao=item.rotacao
	jogo.editor.estado_visual=MobiliaPlex.estado(item)
	jogo.painel.hud.catalogo.painel.hide()
	jogo.painel.mensagem("Escolha o destino. R gira · Botão direito cancela · Sem custo.")

static func sem_original(editor: EditorPlex) -> PlantaPlex:
	var chave:=hash([editor.planta.get_instance_id(),editor.planta.revisao,editor.item_movendo])
	if chave==chave_previa and base_previa!=null: return base_previa
	var p:=PlantaPlex.new()
	p.objetos=editor.planta.objetos.duplicate(true)
	p.area_construcao=editor.planta.area_construcao
	p.terrenos_adquiridos=editor.planta.terrenos_adquiridos.duplicate()
	p.lote_restaurante=editor.planta.lote_restaurante
	p.bairro_ativo=editor.planta.bairro_ativo
	p.bairro_bloqueios=editor.planta.bairro_bloqueios
	p.pisos=editor.planta.pisos.duplicate()
	p.rotacoes_pisos=editor.planta.rotacoes_pisos.duplicate()
	var ids: Array[int]=[]
	grupo(editor.planta,editor.item_movendo,ids)
	for id in ids: p.objetos.erase(id)
	p.reindexar();p.atualizar_reservas()
	chave_previa=chave;base_previa=p
	return p

static func avaliar(editor: EditorPlex, celula: Vector2i) -> Dictionary:
	if not permitido(editor.jogo,editor.item_movendo): return {"pontos":[],"reservas":[],"permitido":false,"motivo":"O item está ocupado."}
	var chave:=hash([editor.planta.get_instance_id(),editor.planta.revisao,editor.item_movendo,editor.rotacao,celula,editor.personagens.map(func(a): return [a.celula,a.assento,a.suporte,a.pose])])
	if chave==assinatura: return resultado
	assinatura=chave
	resultado={"pontos":[],"reservas":[],"permitido":false,"motivo":"O item está ocupado ou o destino está bloqueado."}
	if not permitido(editor.jogo,editor.item_movendo): return resultado
	var p:=sem_original(editor)
	var novo:=EditorPlex.new(p)
	novo.jogo=editor.jogo
	novo.ferramenta=editor.ferramenta;novo.rotacao=editor.rotacao;novo.estado_visual=editor.estado_visual
	var item: Dictionary=editor.planta.objetos[editor.item_movendo]
	if EmbalagensMoveisPlex.eh(item): novo.ferramenta=MobiliaPlex.visual(item.conteudo_movel)
	resultado=novo.acessos.avaliar(novo,celula)
	if not TerrenoPlex.permite(p,novo.ferramenta,celula,novo.rotacao) or not p.pode_colocar(novo.ferramenta,celula,novo.rotacao): resultado.permitido=false
	if CatalogoPlex.objetos.get(novo.ferramenta,{}).get("camera",false) and not CamerasVigilanciaPlex.instalacao_permitida(editor.jogo,{"id":editor.item_movendo,"celula":celula,"rotacao":novo.rotacao}):resultado.permitido=false
	if not p.sobreposto(novo.ferramenta) and not ApoiosPlex.superficie(novo.ferramenta):
		for c in p.celulas(novo.ferramenta,celula,novo.rotacao):
			if not editor.livre(c): resultado.permitido=false
	return resultado

static func aplicar(editor: EditorPlex, celula: Vector2i) -> void:
	var avaliacao:=avaliar(editor,celula)
	if not avaliacao.permitido:
		editor.aviso.emit("Deixe o destino e os pontos de uso livres para mover o item.")
		return
	var p:=editor.planta
	var item: Dictionary=p.objetos[editor.item_movendo]
	var ids: Array[int]=[]
	grupo(p,item.id,ids)
	var anterior: Vector2i=item.celula
	var giro:=posmod(editor.rotacao-int(item.rotacao),4)
	var original:=MobiliaPlex.visual(item.conteudo_movel) if EmbalagensMoveisPlex.eh(item) else str(item.tipo)
	var apoio:=ApoiosPlex.encontrar(sem_original(editor),celula,original) if ApoiosPlex.superficie(original) or ApoiosPlex.decoracao_mesa(original) else {}
	for id in ids:
		var parte: Dictionary=p.objetos[id]
		parte.celula=celula+Vector2i(GradePlex.girar(Vector2(parte.celula-anterior),giro))
		parte.rotacao=posmod(int(parte.rotacao)+giro,4)
	item.sobre=int(apoio.get("pai",-1));item.slot=int(apoio.get("slot",-1))
	p.reindexar();p.alterada.emit()
	editor.item_movendo=-1
	editor.jogo.escolher_ferramenta("selecionar")
	editor.aviso.emit("Item movido.")
