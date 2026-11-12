class_name GorePlex
extends RefCounted

static func por(planta:PlantaPlex,tipo:String,celula:Vector2i,rotacao:int=0,estado:String="") -> void:
	if not CatalogoPlex.objetos.has(tipo):return
	var id:=planta.colocar(tipo,celula,rotacao)
	if id<0 or estado.is_empty():return
	planta.objetos[id].estado=estado

static func sorteio(lista:Array) -> String:return str(lista[randi()%lista.size()])

static func espalhar(jogo:Node,celula:Vector2i,violencia:int,rotacao:int=-1) -> void:
	var planta:PlantaPlex=jogo.planta
	jogo.sistemas.cartazes.morte(celula)
	var giro:int=randi()%4 if rotacao<0 else rotacao
	var nivel:=clampi(violencia,1,3)
	if nivel==1:
		por(planta,"macabro_poca_pequena",celula,giro,sorteio(["fresco","com-gotas"]))
		por(planta,"macabro_respingos",celula+GradePlex.frente(giro),giro,sorteio(["radial","lateral","gotas"]))
	elif nivel==2:
		por(planta,"macabro_poca_grande",celula-Vector2i.ONE,giro,sorteio(["fresca","com-respingos"]))
		por(planta,"macabro_gotejamento",celula+GradePlex.frente(giro)*2,giro,sorteio(["trilha","tres"]))
		if randf()<.5:por(planta,"macabro_olho_solto",celula,giro,sorteio(["azul","verde","castanho","injetado"]))
		if randf()<.4:por(planta,"macabro_cerebro_inteiro",celula,giro,"sobre-sangue")
	else:
		por(planta,"macabro_banho_de_sangue",celula-Vector2i.ONE,giro,sorteio(["radial","jato","chuva"]))
		por(planta,"macabro_monte_tripas",celula,giro,sorteio(["rosadas","escuras"]))
		por(planta,"macabro_cerebro_esmagado",celula-GradePlex.frente(giro),giro,sorteio(["esmagado","pedacos"]))
		por(planta,"macabro_olhos_espalhados",celula+GradePlex.frente(giro),giro,sorteio(["par","trio","cinco"]))
		por(planta,"macabro_arrasto",celula+GradePlex.frente(giro),giro,sorteio(["arrasto","dedos"]))
		if randf()<.5:por(planta,"macabro_tripas_arrastadas",celula-GradePlex.frente(giro)*2,giro,"rosa")
	if not planta.objetos.values().any(func(o):return o.celula==celula and MobiliaPlex.dados(o).get("sangue",false)):por(planta,"cenario_poca_pequena",celula)

static func fresco(item:Dictionary) -> bool:
	if str(item.tipo).begins_with("cenario_poca_"):return str(item.estado)=="fresco"
	return MobiliaPlex.dados(item).get("sangue",false) and not (str(item.estado).contains("sec") or str(item.estado).contains("escur"))
