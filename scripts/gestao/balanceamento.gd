class_name BalanceamentoPlex
extends RefCounted

static var dados: Dictionary={}

static func carregar() -> void:
	if dados.is_empty(): dados=JSON.parse_string(FileAccess.get_file_as_string("res://dados/balanceamento.json"))

static func catalogar(objetos: Dictionary) -> void:
	carregar()
	for tipo in objetos:
		var item: Dictionary=objetos[tipo]
		if dados.itens.has(tipo): item.merge(dados.itens[tipo],true)
		if item.get("bairro",false) or item.get("entulho",false) or tipo.begins_with("caixa") or tipo in dados.utilitarios:
			item.conforto=0
		item.peso_conforto=0.0 if int(item.get("conforto",0))==0 else 2.0 if CatalogoPlex.base(str(item.get("logico",tipo))) in ["mesa","cadeira","banco_espera"] else 1.0

static func revenda(item: Dictionary) -> int:
	carregar()
	if EmbalagensMoveisPlex.eh(item): return maxi(0,int(item.get("valor_pago",0)))
	var tipo:=MobiliaPlex.visual(item)
	if tipo.begins_with("caixa") or dados.nao_revendaveis.has(tipo): return 0
	var preco:=MobiliaPlex.preco(tipo)
	if preco<=0 or MobiliaPlex.dados(item).get("entulho",false) or MobiliaPlex.dados(item).get("bairro",false): return 0
	var original:=maxi(0,int(item.get("valor_pago",0)))
	var taxa: float=float(dados.reembolso) if item.has("valor_pago") else float(dados.reciclagem_inicial)
	if not item.has("valor_pago"): original=preco
	var estado:=MobiliaPlex.estado(item)
	if estado in ["partido","danificada","rasgado","sem-porta","buraco","topo-partido"]: taxa*=.5
	return maxi(0,floori(mini(original,preco)*taxa))

static func total_revenda(planta: PlantaPlex, id: int) -> int:
	if not planta.objetos.has(id): return 0
	var total:=revenda(planta.objetos[id])
	for filho in ApoiosPlex.filhos(planta,id): total+=total_revenda(planta,filho.id)
	return total

static func remover(editor: EditorPlex, id: int) -> void:
	if not editor.planta.objetos.has(id): return
	var item:Dictionary=editor.planta.objetos[id]
	if item.has("robo_reserva") or item.has("reparo_reserva") or item.has("reparo_robo"):editor.aviso.emit("Libere a base e termine o conserto antes de remover o equipamento.");return
	if editor.jogo!=null and not editor.jogo.atracoes.ordem(id).is_empty():editor.aviso.emit("Conclua a montagem antes de remover a bancada.");return
	if LimpezaAmbientesPlex.eh(editor.planta.objetos[id]) and not LimpezaAmbientesPlex.remocao_direta(editor.planta.objetos[id]):
		editor.aviso.emit("Use a limpeza para remover os resíduos.")
		return
	var valor:=total_revenda(editor.planta,id)
	if editor.jogo==null or not editor.jogo.campanha: valor=0
	editor.planta.remover(id)
	if valor>0:
		editor.jogo.servicos.receber(valor)
		editor.aviso.emit("Item removido · Reembolso: $%d."%valor)

