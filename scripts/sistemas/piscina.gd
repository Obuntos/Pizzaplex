class_name PiscinaBolinhasPlex
extends RefCounted

const TIPO:="dec_piscina_bolinhas"
const BOLINHAS:="dec_bolinhas_caidas"
const VAGAS:=3
const LIMITE:=6
const CHANCE:=.04
const TEMPO_MIN:=40.0
const TEMPO_MAX:=90.0
var jogo:Node
var espera:=0.0

func _init(cena:Node) -> void:jogo=cena
func piscinas() -> Array:return jogo.planta.objetos.values().filter(func(o):return o.tipo==TIPO)
func ocupantes(p:Dictionary) -> Array:return jogo.personagens.filter(func(a):return int(a.visita.get("piscina",-1))==int(p.id))
func fora(p:Dictionary) -> int:return int(p.get("bolinhas_fora",0))
func entrada(p:Dictionary) -> Vector2i:
	var lista:Array[Vector2i]=jogo.planta.interacoes(int(p.id))
	return lista[0] if not lista.is_empty() else Vector2i(-1,-1)

func atualizar(delta:float) -> void:
	espera+=delta
	if espera<1.0:return
	var passo:=espera;espera=0.0
	for p in piscinas():
		var dentro:=ocupantes(p)
		for a in dentro:brincar(p,a,passo)
		convidar(p,dentro.size())
		if fora(p)>=LIMITE and not jogo.personagens.any(func(f):return int(f.visita.get("recolher_piscina",-1))==int(p.id)):chamar(p)
	for f in jogo.personagens:
		if f.visita.has("recolher_piscina"):recolher(f,passo)
		if f.visita.has("piscina_indo"):chegou(f)

func convidar(p:Dictionary,quantos:int) -> void:
	if quantos>=VAGAS or fora(p)>=LIMITE:return
	var porta:=entrada(p)
	if porta.x<0:return
	for a in jogo.personagens:
		if int(a.visita.get("piscina_indo",-1))==int(p.id):quantos+=1
	if quantos>=VAGAS:return
	for a in jogo.personagens:
		if a.cargo!="crianca" or not jogo.sistemas.jovens.livre(a) or a.local.distance_to(Vector2(porta))>10.0 or randf()>CHANCE:continue
		var rota:Array[Vector2i]=jogo.rotas.caminho(a.origem_rota(),porta)
		if rota.is_empty() and a.celula!=porta:continue
		a.movimento.cancelar();a.visita.brincando=true;a.visita.piscina_indo=int(p.id);a.trabalho="piscina"
		if not rota.is_empty():a.andar(rota)
		return

func brincar(p:Dictionary,a:PersonagemPlex,passo:float) -> void:
	a.visita.piscina_tempo=float(a.visita.get("piscina_tempo",0.0))+passo
	a.trabalho="piscina";a.visita.rindo=true
	var grupo:Dictionary=jogo.clientes.grupos.get(a.familia,{})
	if a.ocupado() or str(grupo.get("estado",""))=="saindo" or a.visita.get("perdida",false):sair(p,a);return
	if randf()<.08:jogo.sistemas.baloes.exibir(a,"Uhuuu!",2)
	if float(a.visita.piscina_tempo)>=float(a.visita.get("piscina_limite",TEMPO_MAX)):sair(p,a)

func entrar(p:Dictionary,a:PersonagemPlex) -> void:
	var celulas:Array[Vector2i]=jogo.planta.celulas(p.tipo,p.celula,p.rotacao)
	var usadas:Array=ocupantes(p).map(func(o):return o.celula)
	var livre:=Vector2i(-1,-1)
	for c in celulas:
		if not usadas.has(c):livre=c;break
	a.visita.erase("piscina_indo")
	if livre.x<0:soltar(a);return
	a.movimento.cancelar();a.visita.piscina=int(p.id);a.visita.piscina_tempo=0.0;a.visita.piscina_limite=randf_range(TEMPO_MIN,TEMPO_MAX)
	a.celula=livre;a.local=Vector2(livre);a.position=GradePlex.projetar(a.local)
	a.visita.humor_cliente="muito_feliz";a.necessidades.lazer=100.0

func soltar(a:PersonagemPlex) -> void:
	for chave in ["piscina","piscina_indo","piscina_tempo","piscina_limite","rindo","brincando"]:a.visita.erase(chave)
	a.trabalho="visitar";a.visita.brincou_grupo=true

func sair(p:Dictionary,a:PersonagemPlex) -> void:
	var porta:=entrada(p)
	if porta.x>=0:a.celula=porta;a.local=Vector2(porta);a.position=GradePlex.projetar(a.local)
	soltar(a);a.visita.humor_cliente="feliz";a.visita.satisfacao=minf(100.0,float(a.visita.get("satisfacao",50))+8)
	derramar(p)

func derramar(p:Dictionary) -> void:
	if fora(p)>=LIMITE:return
	var porta:=entrada(p)
	if porta.x<0:return
	var frente:=GradePlex.frente(int(p.rotacao))
	var lado:=Vector2i(-frente.y,frente.x)
	for c in [porta,porta+frente,porta+lado,porta-lado,porta+frente*2,porta+frente+lado]:
		if not jogo.planta.sobre(c,BOLINHAS).is_empty() or not jogo.planta.pode_colocar(BOLINHAS,c,0):continue
		var id:int=jogo.planta.colocar(BOLINHAS,c,randi()%4)
		if id<0:continue
		jogo.planta.objetos[id].estado=["poucas","muitas","rolando"][randi()%3];jogo.planta.objetos[id].piscina=int(p.id)
		p.bolinhas_fora=fora(p)+1;p.estado="baixa" if fora(p)>=3 else "cheia"
		jogo.planta.alterada.emit()
		if fora(p)>=LIMITE:jogo.painel.mensagem("As bolinhas da piscina estão espalhadas pelo chão. Alguém precisa recolhê-las.")
		return

func espalhadas(p:Dictionary) -> Array:return jogo.planta.objetos.values().filter(func(o):return o.tipo==BOLINHAS and int(o.get("piscina",-1))==int(p.id))

func funcionario() -> PersonagemPlex:
	var melhor:PersonagemPlex=null
	for a in jogo.personagens:
		if a.cargo!="funcionario" or a.robo or a.ocupado() or a.visita.get("fora_turno",false) or a.visita.get("morto",false) or TurnosEquipePlex.ocupado(a) or a.funcao=="caixa":continue
		if a.visita.has("recolher_piscina") or a.visita.has("fusivel") or a.visita.has("mec"):continue
		if melhor==null or a.funcao=="limpeza" and melhor.funcao!="limpeza":melhor=a
	return melhor

func chamar(p:Dictionary) -> void:
	var a:=funcionario()
	if a==null:return
	a.visita.recolher_piscina=int(p.id);a.visita.bolinhas_mao=0;a.trabalho="recolher_bolinhas"
	jogo.sistemas.baloes.exibir(a,"Vou recolher as bolinhas.",3)

func recolher(a:PersonagemPlex,passo:float) -> void:
	var p:Dictionary=jogo.planta.objetos.get(int(a.visita.recolher_piscina),{})
	if p.is_empty() or a.visita.get("morto",false) or a.visita.get("fora_turno",false):
		for chave in ["recolher_piscina","bolinhas_mao","recolher_tempo"]:a.visita.erase(chave)
		return
	if a.ocupado():return
	a.trabalho="recolher_bolinhas"
	var lista:=espalhadas(p)
	if not lista.is_empty():
		lista.sort_custom(func(x,y):return a.local.distance_squared_to(Vector2(x.celula))<a.local.distance_squared_to(Vector2(y.celula)))
		var b:Dictionary=lista[0]
		if a.local.distance_to(Vector2(b.celula))<=1.5:
			jogo.tarefas.orientar(a,Vector2(b.celula))
			jogo.planta.remover(int(b.id));a.visita.bolinhas_mao=int(a.visita.get("bolinhas_mao",0))+1
			return
		var rota:Array[Vector2i]=jogo.rotas.aproximar(a.origem_rota(),int(b.id))
		if rota.is_empty():jogo.planta.remover(int(b.id));a.visita.bolinhas_mao=int(a.visita.get("bolinhas_mao",0))+1
		else:a.andar(rota)
		return
	var porta:=entrada(p)
	if porta.x>=0 and a.celula!=porta:
		var rota:Array[Vector2i]=jogo.rotas.caminho(a.origem_rota(),porta)
		if not rota.is_empty():a.andar(rota);return
	jogo.tarefas.orientar(a,Vector2(p.celula))
	a.visita.recolher_tempo=float(a.visita.get("recolher_tempo",0.0))+passo
	if float(a.visita.recolher_tempo)<3.0:return
	p.bolinhas_fora=0;p.estado="cheia";jogo.planta.alterada.emit()
	for chave in ["recolher_piscina","bolinhas_mao","recolher_tempo"]:a.visita.erase(chave)
	a.trabalho=""
	jogo.sistemas.baloes.exibir(a,"Bolinhas de volta na piscina!",3)

func chegou(a:PersonagemPlex) -> void:
	if not a.visita.has("piscina_indo") or a.ocupado():return
	var p:Dictionary=jogo.planta.objetos.get(int(a.visita.piscina_indo),{})
	if p.is_empty() or ocupantes(p).size()>=VAGAS:soltar(a);return
	if a.celula==entrada(p) or a.local.distance_to(Vector2(entrada(p)))<=1.2:entrar(p,a)
	else:soltar(a)

func opcoes(menu:CanvasLayer,p:Dictionary) -> void:
	menu.adicionar("Recolher bolinhas (%d fora)"%fora(p),func():
		if espalhadas(p).is_empty():jogo.painel.mensagem("Não há bolinhas fora da piscina.");return
		chamar(p))

func limpar() -> void:
	for a in jogo.personagens:
		var p:Dictionary=jogo.planta.objetos.get(int(a.visita.get("piscina",-1)),{})
		if not p.is_empty():
			var porta:=entrada(p)
			if porta.x>=0:a.celula=porta;a.local=Vector2(porta)
		if a.visita.has("piscina") or a.visita.has("piscina_indo"):soltar(a)
