class_name FichasPremiosPlex
extends RefCounted

const PACOTE:=4
const PRECO_PACOTE:=1.0
const TICKETS_MIN:=2
const TICKETS_MAX:=6
const PRECO_TEMPORADA:=25
const PRECO_NORMAL:=40
const PRECO_RARO:=60

static func maquinas(jogo:Node) -> Array:
	return jogo.planta.objetos.values().filter(func(o):return o.tipo=="amb_maquina_fichas")

static func precisa(jogo:Node,a:PersonagemPlex) -> bool:
	return int(a.visita.get("fichas",0))<=0 and not maquinas(jogo).is_empty()

static func perto(jogo:Node,a:PersonagemPlex,o:Dictionary) -> bool:
	return jogo.planta.interacoes(int(o.id)).has(a.celula) or a.local.distance_to(Vector2(o.celula))<=1.6

static func comprar(jogo:Node,a:PersonagemPlex) -> bool:
	if a.visita.has("indo_fichas"):
		var alvo:Dictionary=jogo.planta.objetos.get(int(a.visita.indo_fichas),{})
		if a.ocupado():return true
		a.visita.erase("indo_fichas")
		if alvo.is_empty() or not perto(jogo,a,alvo):return false
		jogo.tarefas.orientar(a,Vector2(alvo.celula))
		if int(alvo.get("fichas",0))<PACOTE:jogo.sistemas.baloes.exibir(a,"Acabaram as fichas...",3);a.visita.espera_jogo=20.0;return true
		alvo.fichas=int(alvo.fichas)-PACOTE;alvo.caixa_fichas=float(alvo.get("caixa_fichas",0.0))+PRECO_PACOTE
		a.visita.fichas=PACOTE;jogo.sistemas.baloes.exibir(a,"Fichas!",2)
		return true
	var lista:=maquinas(jogo).filter(func(o):return int(o.get("fichas",0))>=PACOTE)
	lista.sort_custom(func(x,y):return a.local.distance_squared_to(Vector2(x.celula))<a.local.distance_squared_to(Vector2(y.celula)))
	for o in lista:
		if perto(jogo,a,o):a.visita.indo_fichas=int(o.id);return comprar(jogo,a)
		var rota:Array[Vector2i]=jogo.rotas.aproximar(a.origem_rota(),int(o.id))
		if rota.is_empty():continue
		a.visita.indo_fichas=int(o.id);a.andar(rota);a.trabalho="comprar_fichas";return true
	return false

static func jogou(a:PersonagemPlex) -> void:
	if not a.visita.has("fichas"):return
	a.visita.fichas=maxi(0,int(a.visita.fichas)-1)
	a.visita.tickets=int(a.visita.get("tickets",0))+TICKETS_MIN+randi()%(TICKETS_MAX-TICKETS_MIN+1)

static func temporada(jogo:Node) -> String:
	var toys_palco:bool=jogo.personagens.any(func(r):return r.robo and r.modelo.begins_with("vi_toy") and not r.modelo.ends_with("_quebrado") and r.pose>=0)
	var antigos_quebrados:bool=jogo.personagens.any(func(r):return r.robo and r.modelo in ["vi_orelhitas_quebrado","vi_patitas_quebrado"])
	return "toy" if toys_palco and antigos_quebrados else "antigo"

static func preco(jogo:Node,tipo:String) -> int:
	var linha:="toy" if tipo.begins_with("toy_pelucia") else "antigo" if tipo.begins_with("antigo_pelucia_orelhitas") or tipo.begins_with("antigo_pelucia_patitas") else ""
	if linha.is_empty():return PRECO_NORMAL
	if linha==temporada(jogo):return PRECO_TEMPORADA
	return PRECO_RARO if linha=="antigo" else PRECO_NORMAL

static func premios(jogo:Node,balcao:Dictionary) -> Array:
	var celulas:Array[Vector2i]=jogo.planta.celulas(balcao.tipo,balcao.celula,balcao.rotacao)
	var lista:Array=[]
	for o in jogo.planta.objetos.values():
		if not str(o.tipo).contains("pelucia"):continue
		var raiz:=ApoiosPlex.raiz(jogo.planta,int(o.id))
		var base:Dictionary=jogo.planta.objetos.get(raiz,o)
		var c:Vector2i=base.celula
		if celulas.any(func(x):return absi(x.x-c.x)<=2 and absi(x.y-c.y)<=2):lista.append(o)
	return lista

static func trocar(jogo:Node,a:PersonagemPlex) -> bool:
	var tickets:=int(a.visita.get("tickets",0))
	if a.visita.has("indo_premio"):
		if a.ocupado():return true
		var item:Dictionary=jogo.planta.objetos.get(int(a.visita.indo_premio),{})
		a.visita.erase("indo_premio")
		if item.is_empty() or tickets<preco(jogo,str(item.tipo)):return false
		a.visita.tickets=tickets-preco(jogo,str(item.tipo))
		var nome:=str(CatalogoPlex.objetos.get(item.tipo,{}).get("nome","pelúcia"))
		jogo.planta.remover(int(item.id))
		a.visita.satisfacao=clampf(float(a.visita.get("satisfacao",70.0))+12.0,0.0,100.0);a.emocao.exibir("muito_feliz")
		jogo.sistemas.baloes.exibir(a,"Ganhei: "+nome+"!",4)
		return true
	if tickets<PRECO_TEMPORADA:return false
	for balcao in jogo.planta.objetos.values():
		if balcao.tipo!="amb_balcao_tickets" or balcao.get("estado","")!="aberto":continue
		var disponiveis:=premios(jogo,balcao).filter(func(o):return preco(jogo,str(o.tipo))<=tickets)
		if disponiveis.is_empty():continue
		disponiveis.sort_custom(func(x,y):return preco(jogo,str(x.tipo))>preco(jogo,str(y.tipo)))
		var rota:Array[Vector2i]=jogo.rotas.aproximar(a.origem_rota(),int(balcao.id))
		if rota.is_empty():continue
		a.visita.indo_premio=int(disponiveis[0].id);a.andar(rota);a.trabalho="trocar_tickets"
		return true
	return false

static func opcoes(jogo:Node,menu:CanvasLayer,p:Dictionary) -> void:
	var caixa:=float(p.get("caixa_fichas",0.0))
	menu.adicionar("Fichas restantes: %d · Caixa: US$ %.2f"%[int(p.get("fichas",0)),caixa],func():pass)
	if caixa>0.0:menu.adicionar("Retirar US$ %.2f"%caixa,func():jogo.servicos.saldo=snappedf(jogo.servicos.saldo+caixa,.01);p.caixa_fichas=0.0)
