class_name CriancasPerdidasPlex
extends RefCounted

const CHANCE_MINUTO:=.0004
const PERDA:=8.0
const SUMIU:=15.0
const VOLTA:=120.0
var jogo:Node
var casos:Array=[]
var espera:=0.0
var ultimo:=-1.0

func _init(cena:Node) -> void:jogo=cena
func agora() -> float:return float(jogo.calendario.dias)*1440.0+float(jogo.calendario.minutos)
func ator(id:int) -> PersonagemPlex:return jogo.clientes.ator(id)

func reputacao(chave:String,valor:float) -> void:
	for k in ["geral",chave]:
		var r:Dictionary=jogo.servicos.reputacao.get(k,{"nota":ReputacaoClientesPlex.ambiente(jogo.servicos),"visitas":0,"ultima_festa":-10})
		r.nota=clampf(float(r.nota)+valor,0.0,100.0);jogo.servicos.reputacao[k]=r

func caso(a:PersonagemPlex) -> Dictionary:
	for c in casos:
		if int(c.crianca)==a.identificador:return c
	return {}

func perder(a:PersonagemPlex,grupo:Dictionary) -> void:
	var destinos:Array=jogo.clientes.vagas(a.celula,12,6)
	if destinos.is_empty():return
	var alvo:Vector2i=destinos[-1]
	var rota:Array[Vector2i]=jogo.rotas.caminho(a.origem_rota(),alvo)
	if rota.is_empty():return
	var chave:=str(grupo.get("familia_bairro","visita:"+str(grupo.id)))
	casos.append({"crianca":a.identificador,"grupo":int(grupo.id),"familia":chave,"volta":-1.0,"responsavel":-1,"nome":IdentidadesPlex.completo(a)})
	grupo.teve_perdida=true
	a.visita.perdida=true;a.movimento.cancelar();a.andar(rota);a.trabalho="perdida"
	reputacao(chave,-PERDA)
	jogo.sistemas.baloes.exibir(a,"Cadê minha mãe?",4)
	jogo.painel.mensagem(IdentidadesPlex.completo(a)+" se perdeu da família.")
	jogo.sistemas.avisos.marcar(a.local)

func devolver(a:PersonagemPlex,quem:PersonagemPlex=null) -> bool:
	var c:=caso(a)
	if c.is_empty():return false
	var grupo:Dictionary=jogo.clientes.grupos.get(int(c.grupo),{})
	if grupo.is_empty() or str(grupo.get("estado",""))=="saindo":return false
	a.visita.erase("perdida");a.visita.voltar_responsavel=true;a.trabalho=""
	reputacao(str(c.familia),PERDA)
	casos.erase(c)
	if quem!=null:jogo.sistemas.baloes.exibir(quem,"Vem, vou te levar até sua família.",3)
	return true

func atualizar(delta:float) -> void:
	espera+=delta
	if espera<1.0:return
	espera=0.0
	var instante:=agora()
	var minutos:=0.0 if ultimo<0 else clampf(instante-ultimo,0.0,60.0)
	ultimo=instante
	if casos.is_empty() and minutos>0.0:
		for a in jogo.personagens:
			if a.cargo!="crianca" or a.ocupado() or a.visita.get("perdida",false) or a.familia<0:continue
			var grupo:Dictionary=jogo.clientes.grupos.get(a.familia,{})
			if grupo.is_empty() or str(grupo.get("estado",""))!="visita" or grupo.get("teve_perdida",false) or FestasRestaurantePlex.pendente(grupo):continue
			if randf()<CHANCE_MINUTO*minutos:perder(a,grupo);break
	for c in casos.duplicate():acompanhar(c,instante)

func acompanhar(c:Dictionary,instante:float) -> void:
	var a:=ator(int(c.crianca))
	var viva:bool=is_instance_valid(a) and not a.visita.get("morto",false)
	var grupo:Dictionary=jogo.clientes.grupos.get(int(c.grupo),{})
	if float(c.volta)<0.0:
		if not viva:casos.erase(c);sumiu(c);return
		a.trabalho="perdida";a.animacao.expressao="triste"
		if not grupo.is_empty() and str(grupo.get("estado",""))!="saindo":
			for f in jogo.personagens:
				if f.cargo=="funcionario" and not f.robo and not f.visita.get("fora_turno",false) and f.local.distance_to(a.local)<=3.0 and VisaoNPCPlex.ve(jogo,f,a,4.0):devolver(a,f);return
			return
		for campo in ["criancas","adolescentes"]:grupo[campo]=grupo.get(campo,[]).filter(func(v):return int(v)!=a.identificador)
		a.familia=-1;c.volta=instante+VOLTA
		jogo.painel.mensagem("A família foi embora sem "+str(c.nome)+". Eles voltam em 2 horas para procurar.")
		return
	if int(c.responsavel)<0:
		if viva:a.trabalho="perdida"
		if instante<float(c.volta):return
		chegar(c)
		return
	var p:=ator(int(c.responsavel))
	if not is_instance_valid(p):casos.erase(c);return
	if str(c.get("etapa",""))=="saindo":
		if not p.ocupado():
			if viva:jogo.despawn(a)
			jogo.despawn(p);casos.erase(c)
		return
	if not viva:
		casos.erase(c);sumiu(c);jogo.sistemas.baloes.exibir(p,"Onde está minha criança?!",5)
		var volta:Array[Vector2i]=jogo.rotas.caminho(p.origem_rota(),Vector2i(int(c.saida[0]),int(c.saida[1])))
		if volta.is_empty():jogo.despawn(p)
		else:p.andar(volta)
		return
	if p.ocupado():return
	if p.local.distance_to(a.local)>1.8:
		var rota:Array[Vector2i]=jogo.rotas.caminho(p.origem_rota(),a.celula)
		if rota.is_empty():jogo.despawn(p);c.responsavel=-1;c.volta=instante+30.0
		else:p.andar(rota)
		return
	jogo.sistemas.baloes.exibir(p,"Achei você!",3);a.visita.erase("perdida")
	c.etapa="saindo"
	var saida:=Vector2i(int(c.saida[0]),int(c.saida[1]))
	var r1:Array[Vector2i]=jogo.rotas.caminho(p.origem_rota(),saida);var r2:Array[Vector2i]=jogo.rotas.caminho(a.origem_rota(),saida)
	if not r1.is_empty():p.andar(r1)
	if not r2.is_empty():a.andar(r2)

func chegar(c:Dictionary) -> void:
	var a:=ator(int(c.crianca))
	if not is_instance_valid(a):casos.erase(c);sumiu(c);return
	var saida:Vector2i=jogo.clientes.saida(a.origem_rota())
	if saida.x<0:return
	var p:PersonagemPlex=jogo.spawn("humano",saida,"morador",true)
	if not is_instance_valid(p):return
	p.automatico=false;p.visita.servico_publico=true
	p.identidade={"nome":"Responsável","sobrenome":"de "+str(c.nome),"apelido":"","idade":38,"sexo":"feminino"}
	c.responsavel=p.identificador;c.saida=[saida.x,saida.y]
	jogo.painel.mensagem("A família de "+str(c.nome)+" voltou para procurar.")

func sumiu(c:Dictionary) -> void:
	reputacao(str(c.familia),-SUMIU)
	jogo.sistemas.investigacao.relatar("perdida:"+str(c.crianca),str(c.nome))
	jogo.painel.mensagem(str(c.nome)+" desapareceu. A família procurou a polícia.")

func opcoes(menu:CanvasLayer,a:PersonagemPlex) -> void:
	if not a.visita.get("perdida",false):return
	menu.adicionar("Levar até a família",func():
		if not devolver(a,jogo.controle.administrador()):jogo.painel.mensagem("A família já foi embora. Eles voltam para procurar."))

func gravar() -> Dictionary:return {"casos":casos.duplicate(true)}
func restaurar(d:Dictionary) -> void:casos=d.get("casos",[]).duplicate(true)
