class_name EntregasMercadoPlex
extends RefCounted

const ABRE:=420.0
const FECHA:=1200.0
var jogo:Node
var entregador:=-1
var etapa:=""
var espera:=0.0
var tempo_etapa:=0.0
var origem_entrega:=Vector2i(-1,-1)

func _init(cena:Node) -> void:jogo=cena
func ator() -> PersonagemPlex:return jogo.clientes.ator(entregador) if entregador>=0 else null
func horario() -> bool:return float(jogo.calendario.minutos)>=ABRE and float(jogo.calendario.minutos)<FECHA
func pendentes() -> Array:return jogo.compras.encomendas.filter(func(p):return int(p.restantes)>0 and float(p.tempo)<=0.0 and not p.get("tutorial_aguarda",false))
func restantes() -> Array:return jogo.compras.encomendas.filter(func(p):return int(p.restantes)>0 and not p.get("tutorial_aguarda",false))
func liberado(pedido:Dictionary) -> bool:return pedido.get("tutorial_aguarda",false) or etapa=="entregando"

func origem() -> Vector2i:
	if jogo.populacao!=null:
		var p:Vector2i=jogo.populacao.locais.ponto("mercadinho")
		if p.x>=0:return p
	var admin:PersonagemPlex=jogo.controle.administrador()
	return jogo.clientes.saida(admin.origem_rota()) if is_instance_valid(admin) else Vector2i(-1,-1)

func destino(a:PersonagemPlex) -> Array[Vector2i]:
	for pedido in pendentes():
		if not jogo.planta.objetos.has(int(pedido.get("recebimento",-1))):pedido.recebimento=jogo.compras.destino(-1)
		var ponto:Dictionary=jogo.planta.objetos.get(int(pedido.get("recebimento",-1)),{})
		if ponto.is_empty():continue
		for c in RecebimentosPlex.acessos(jogo.planta,ponto):
			if a.celula==c or a.local.distance_to(Vector2(c))<=.6:return []
			var rota:Array[Vector2i]=jogo.rotas.caminho(a.origem_rota(),c)
			if not rota.is_empty():return rota
	return []

func perto(a:PersonagemPlex) -> bool:
	for pedido in pendentes():
		var ponto:Dictionary=jogo.planta.objetos.get(int(pedido.get("recebimento",-1)),{})
		if not ponto.is_empty() and a.local.distance_to(Vector2(ponto.celula))<=1.6:return true
	return false

func chamar() -> void:
	origem_entrega=origem()
	if origem_entrega.x<0:return
	var a:PersonagemPlex=jogo.spawn("entregador",origem_entrega,"autoridade",true)
	if not is_instance_valid(a):return
	a.automatico=false;a.visita.servico_publico=true;a.visita.entregador_mercado=true
	a.identidade={"nome":"Entregador","sobrenome":"do Mercadinho","apelido":"","idade":30,"sexo":"masculino"}
	entregador=a.identificador;etapa="indo";tempo_etapa=0.0
	var rota:=destino(a)
	if rota.is_empty():jogo.despawn(a);entregador=-1;etapa="";return
	a.andar(rota);a.trabalho="entregar_compras"
	for p in pendentes():p.estado="Entregador a caminho"

func atualizar(delta:float) -> void:
	espera+=delta
	if espera<.5:return
	tempo_etapa+=espera;espera=0.0
	var a:=ator()
	if entregador>=0 and not is_instance_valid(a):entregador=-1;etapa=""
	match etapa:
		"":
			if pendentes().is_empty():return
			if not horario():
				for p in pendentes():p.estado="Aguardando 07:00"
				return
			chamar()
		"indo":
			if a.ocupado():return
			if tempo_etapa>90.0:sair(a);return
			var rota:=destino(a)
			if rota.is_empty() or perto(a):etapa="entregando";tempo_etapa=0.0;jogo.sistemas.baloes.exibir(a,"Entrega do mercadinho!",3)
			else:a.andar(rota)
		"entregando":
			a.trabalho="entregar_compras"
			if restantes().is_empty() or tempo_etapa>120.0:sair(a)
		"voltando":
			if not a.ocupado() or tempo_etapa>120.0:jogo.despawn(a);entregador=-1;etapa=""

func sair(a:PersonagemPlex) -> void:
	etapa="voltando";tempo_etapa=0.0
	var rota:Array[Vector2i]=[]
	if origem_entrega.x>=0:rota=jogo.rotas.caminho(a.origem_rota(),origem_entrega)
	if rota.is_empty():jogo.despawn(a);entregador=-1;etapa="";return
	a.andar(rota);a.trabalho="voltar_mercado"
