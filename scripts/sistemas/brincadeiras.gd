class_name BrincadeirasBairroPlex
extends RefCounted

var jogo:Node
var grupos:Array=[]
var provocacoes:Array=[]
var dinamica:JogosInfantisPlex
var espera:=0.0
var proximo:=0.0
func _init(cena:Node) -> void:jogo=cena;dinamica=JogosInfantisPlex.new(self,cena)
func livre(a:PersonagemPlex) -> bool:
	if not is_instance_valid(a) or a.cargo not in ["crianca","adolescente"] or ControleAdministradorPlex.ocupado(a) or a.assento>=0 or a.visita.get("brincando",false) or a.visita.get("perdida",false):return false
	var g:Dictionary=jogo.clientes.grupos.get(a.familia,{})
	return (g.get("estado","")=="visita" or a.cargo=="adolescente" and a.familia<0) and a.visita.get("etapa","") in ["jogar","show","arcade","esperar"] and not a.visita.get("brincou_grupo",false)
func terminar(g:Dictionary) -> void:
	for id in g.ids:
		var a:PersonagemPlex=jogo.clientes.ator(int(id))
		if not is_instance_valid(a):continue
		for chave in ["brincando","brincadeira_tipo","correndo","brincadeira_velocidade","escondido","rindo"]:a.visita.erase(chave)
		a.movimento.cancelar();a.trabalho="visitar";a.visita.brincou_grupo=true;a.visita.humor_cliente="feliz"
		if CirculacaoVisitantesPlex.restrita(jogo.ambientes.em(a.celula)):a.visita.voltar_responsavel=true
	grupos.erase(g)
	avisar_fim(g)
func formar() -> void:
	var criancas:Array=jogo.personagens.filter(func(a):return a.cargo=="crianca" and livre(a))
	if criancas.size()<2:return
	var lider:PersonagemPlex=criancas[0];var lista:Array=[lider]
	var resto:Array=criancas.slice(1)
	resto.sort_custom(func(x,y):return int(BandosCriancasPlex.amigos(jogo,lider,x))>int(BandosCriancasPlex.amigos(jogo,lider,y)))
	for a in resto:
		if a.local.distance_to(lider.local)<7 and not jogo.rotas.caminho(a.celula,lider.celula).is_empty():lista.append(a)
		if lista.size()>=3:break
	if lista.size()<2:return
	for a in jogo.personagens:
		if lista.size()>=3:break
		if a.cargo=="adolescente" and livre(a) and posmod(a.identificador+jogo.calendario.dias,4)==0 and a.local.distance_to(lider.local)<6:lista.append(a)
	var tipo:="esconde_esconde" if posmod(lider.identificador+jogo.calendario.dias,2)==0 else "pega_pega"
	iniciar_grupo(tipo,lista)
func iniciar_grupo(tipo:String,lista:Array,debug:bool=false) -> bool:
	return dinamica.iniciar(tipo,lista,debug)

func bullying() -> void:
	var jovens:Array=jogo.personagens.filter(func(a):return a.cargo=="adolescente" and livre(a))
	if jovens.size()<3:return
	for a in jogo.personagens:
		if a.cargo!="crianca" or not livre(a) or int(a.visita.get("bullying_dia",-1))==jogo.calendario.dias or BandosCriancasPlex.de(jogo,a)>=0:continue
		if jogo.personagens.any(func(p):return p!=a and not p.visita.get("morto",false) and p.cargo in ["crianca","cliente","funcionario"] and p.local.distance_to(a.local)<3):continue
		var perto:Array=jovens.filter(func(p):return VisaoNPCPlex.ve(jogo,p,a,7))
		if perto.size()<3 or posmod(hash([a.identificador,jogo.calendario.dias]),5)!=0:continue
		provocar_bullying(a,perto.slice(0,3))
		return
func provocar_bullying(a:PersonagemPlex,jovens:Array) -> bool:
	if not is_instance_valid(a) or jovens.size()<3:return false
	var lista:Array=[a]+jovens.slice(0,3)
	var g:Dictionary={"ids":lista.map(func(p):return p.identificador),"tempo":0.0,"riso":-1.0,"etapa":"provocar","debug":a.visita.get("debug_evento",false)}
	a.visita.bullying_dia=jogo.calendario.dias;a.visita.solitario=true;a.visita.triste_ate=jogo.servicos.tempo_servico+90;a.visita.humor_cliente="triste";a.visita.satisfacao=maxf(0,float(a.visita.get("satisfacao",50))-12);a.emocao.exibir("triste")
	for p in lista:p.movimento.cancelar();p.visita.brincando=true;p.trabalho="bullying"
	for p in jovens.slice(0,3):p.visita.rindo=true;p.visita.humor_cliente="muito_feliz";jogo.tarefas.orientar(p,a.local)
	provocacoes.append(g);return true
func avisar_fim(g:Dictionary) -> void:
	if not g.get("debug",false):return
	for id in g.ids:
		var a:PersonagemPlex=jogo.clientes.ator(int(id))
		if is_instance_valid(a):
			var familia:Dictionary=jogo.clientes.grupos.get(a.familia,{})
			if familia.get("debug_evento",false):familia.debug_concluido=true
func atualizar_bullying(dt:float) -> void:
	for g in provocacoes.duplicate():
		g.tempo=float(g.tempo)+dt
		var a:PersonagemPlex=jogo.clientes.ator(int(g.ids[0]))
		if not is_instance_valid(a) or g.ids.any(func(id):return not is_instance_valid(jogo.clientes.ator(int(id)))):provocacoes.erase(g);terminar(g);continue
		if g.etapa=="provocar":
			if float(g.tempo)>=float(g.riso):
				g.riso=float(g.tempo)+4.8
				for id in g.ids.slice(1):
					var p:PersonagemPlex=jogo.clientes.ator(int(id));p.emocao.exibir("feliz");jogo.sistemas.baloes.exibir(p,"Ha, ha!",3)
				a.emocao.exibir("triste");jogo.sistemas.baloes.exibir(a,"Me deixem em paz...",3)
			if float(g.tempo)<14:continue
			g.etapa="afastar"
			var opcoes:Array=dinamica.cantos().filter(func(c):return CirculacaoVisitantesPlex.permitida(jogo,c) and Vector2(c).distance_to(a.local)>5)
			opcoes.sort_custom(func(x,y):return Vector2(x).distance_squared_to(a.local)>Vector2(y).distance_squared_to(a.local))
			var i:=0
			for id in g.ids.slice(1):
				var p:PersonagemPlex=jogo.clientes.ator(int(id));p.visita.erase("rindo");p.trabalho="brincar_grupo"
				for c in opcoes.slice(i):
					if dinamica.mover(p,c):i=opcoes.find(c)+1;break
		if g.etapa=="afastar":
			var jovens:Array=g.ids.slice(1).map(func(id):return jogo.clientes.ator(int(id)))
			if jovens.all(func(p):return p.local.distance_to(a.local)>4) or float(g.tempo)>35:
				for p in jovens:p.visita.erase("brincando");p.visita.brincou_grupo=false
				iniciar_grupo("pega_pega",jovens,bool(g.debug))
				g.etapa="isolada";g.isolada_em=float(g.tempo)
		if g.etapa=="isolada" and float(g.tempo)-float(g.isolada_em)>=8:
			a.visita.erase("brincando");a.trabalho="isolada";a.visita.brincou_grupo=true;a.visita.isolamento_ate=jogo.servicos.tempo_servico+30.0
			provocacoes.erase(g);avisar_fim(g)

func acolher(a:PersonagemPlex) -> void:
	if a.cargo!="crianca" or not a.visita.get("solitario",false):return
	jogo.sistemas.baloes.exibir(a,"Obrigado por ficar comigo!",5)
	a.visita.solitario=false;a.visita.erase("isolamento_ate");a.visita.erase("triste_ate");a.visita.humor_cliente="feliz";a.visita.satisfacao=minf(100,float(a.visita.get("satisfacao",50))+15)
	var chave:String=jogo.social.chave(a);var registro:Dictionary=jogo.social.registros.get(chave,{})
	registro.fidelidade=minf(3,float(registro.get("fidelidade",0))+1);jogo.social.registros[chave]=registro
	var familia:Dictionary=jogo.clientes.grupos.get(a.familia,{})
	if not familia.is_empty():
		var id:=str(familia.get("familia_bairro",""));jogo.sistemas.fidelidade[id]=minf(3,float(jogo.sistemas.fidelidade.get(id,0))+1)
func atualizar(delta:float) -> void:
	dinamica.atualizar(delta);atualizar_bullying(delta)
	espera+=delta;proximo+=delta
	if espera>=8:espera=0;bullying()
	if proximo>=25:proximo=0;formar()
