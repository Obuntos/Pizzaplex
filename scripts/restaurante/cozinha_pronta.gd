class_name CozinhaProntaPlex
extends RefCounted

const CAPACIDADE=4

const EQUIPAMENTOS=["forno","geladeira","bancada_preparo","pia"]
const ALCANCE=3
const OUTRAS=["salao","salao_festas","recepcao","escritorio","deposito","limpeza","jogos","apresentacoes"]

static func equipamento_cozinha(item:Dictionary) -> bool:
	return FornoPlex.eh(item) or CatalogoPlex.base(str(item.tipo)) in EQUIPAMENTOS

static func na_cozinha(s:ServicosPlex,id:int) -> bool:
	var sala:Dictionary=s.salas.do_objeto(id)
	if not FuncoesSalaPlex.aceita(sala,["cozinha"]):return false
	var funcoes:Array=sala.get("funcoes",[])
	if not funcoes.any(func(f):return f in OUTRAS):return true
	var raiz:=ApoiosPlex.raiz(s.planta,id)
	if raiz<0 or not s.planta.objetos.has(raiz):return false
	var origem:Vector2i=s.planta.objetos[raiz].celula
	for outro in sala.get("objetos",[]):
		var item:Dictionary=s.planta.objetos.get(int(outro),{})
		if item.is_empty() or int(item.get("sobre",-1))>=0 or not equipamento_cozinha(item):continue
		for c in s.planta.celulas(item.tipo,item.celula,item.rotacao):
			if maxi(absi(c.x-origem.x),absi(c.y-origem.y))<=ALCANCE:return true
	return false

static func mesas(s:ServicosPlex) -> Array:
	return s.planta.objetos.values().filter(func(o):return LugaresPlex.mesa(str(o.tipo)) and o.get("mesa_cozinha",false))

static func atualizar_mesas(s:ServicosPlex) -> void:
	var mudou:=false
	for item in s.planta.objetos.values():
		if not LugaresPlex.mesa(str(item.tipo)) and item.tipo!="amb_carrinho_louca":continue
		var cozinha:=na_cozinha(s,int(item.id))
		if bool(item.get("mesa_cozinha",false))!=cozinha:item.mesa_cozinha=cozinha;mudou=true
	if mudou:s.planta.alterada.emit()

static func pontos(item:Dictionary) -> Array:
	var lista:Array=[]
	var tamanho:=Vector2(CatalogoPlex.dimensoes(item.tipo,0))
	var altura:=float(MobiliaPlex.dados(item).get("altura_tampo",29))
	for p in [Vector2(-.23,-.23),Vector2(.23,-.23),Vector2(-.23,.23),Vector2(.23,.23)]:
		var local:=GradePlex.girar(p*tamanho,int(item.rotacao))
		lista.append({"u":local.x,"v":local.y,"z":altura,"accepts":["prato"] if item.tipo=="amb_carrinho_louca" else ["pizza","prato"],"capacity":1})
	return lista

static func encomendar(s:ServicosPlex) -> void:
	if s.pedidos.any(func(p):return p.estado=="aguardando"):return
	for mesa in mesas(s):
		var ocupados:=ApoiosPlex.filhos(s.planta,mesa.id).size()
		var a_caminho:=s.pedidos.filter(func(p):return p.get("estoque_cozinha",false) and int(p.mesa)==int(mesa.id) and p.estado not in ["consumido","cancelado"] and int(s.planta.objetos.get(int(p.pizza),{}).get("sobre",-1))!=int(mesa.id)).size()
		if ocupados+a_caminho>=CAPACIDADE:continue
		s.pedidos.append({"id":s.proximo_pedido,"mesa":int(mesa.id),"estado":"aguardando","pizza":-1,"tempo":0.0,"cliente":-1,"familia":-1,"slot":-1,"fatias_restantes":4,"fatias_comidas":0,"estoque_cozinha":true})
		s.proximo_pedido+=1
		return

static func adotar(s:ServicosPlex) -> void:
	for pedido in s.pedidos:
		if pedido.estado!="aguardando" or pedido.get("estoque_cozinha",false):continue
		for estoque in s.pedidos:
			if not estoque.get("estoque_cozinha",false) or estoque.estado!="pronta" or not s.livre(int(estoque.pizza)):continue
			pedido.pizza=int(estoque.pizza);pedido.estado="pronta"
			for campo in ["sabor","geladeira","ingrediente_retirado"]:
				if estoque.has(campo):pedido[campo]=estoque[campo]
			PartilhaPizzaPlex.marcar_fonte(s,pedido)
			estoque.pizza=-1;estoque.estado="consumido"
			break

static func retirar(s:ServicosPlex,a:PersonagemPlex) -> bool:
	for pedido in s.pedidos:
		if pedido.estado!="pronta" or not s.livre(int(pedido.pizza)):continue
		var pizza:Dictionary=s.planta.objetos[int(pedido.pizza)]
		var forno:=int(pizza.get("sobre",-1))
		if not FornoPlex.eh(s.planta.objetos.get(forno,{})) or FornoPlex.tempo(s.planta,pedido)>0:continue
		for mesa in mesas(s):
			if pedido.get("estoque_cozinha",false) and int(pedido.mesa)!=int(mesa.id):continue
			if not s.livre(int(mesa.id)):continue
			var slot:=ApoiosPlex.livre(s.planta,mesa.id,"pizza")
			if slot<0:continue
			if s.iniciar(a,"Guardar pizza pronta",[s.etapa(forno,"pegar_pizza",.7),s.etapa(mesa.id,"apoiar",.6,{"slot":slot})],[pizza.id,mesa.id],pedido.id):return true
	return false

static func organizar(s:ServicosPlex,a:PersonagemPlex) -> bool:
	for caixa in s.inventario.caixas():
		if caixa.get("recurso","") not in ["ingredientes","utensilios"] or not na_cozinha(s,int(caixa.id)):continue
		var base:Dictionary=s.planta.objetos.get(int(caixa.get("sobre",-1)),{})
		if CatalogoPlex.base(str(base.get("tipo",""))) in ["estante","armario_utensilios"]:continue
		for pai in s.estantes():
			if not na_cozinha(s,int(pai)):continue
			var slot:=ApoiosPlex.livre(s.planta,int(pai),str(caixa.tipo))
			if slot>=0 and s.iniciar(a,"Organizar caixa da cozinha",[s.etapa(caixa.id,"pegar"),s.etapa(pai,"apoiar",.6,{"slot":slot})],[caixa.id,pai]):return true
	return false
