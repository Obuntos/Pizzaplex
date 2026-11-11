class_name TarefasTutorialPlex
extends RefCounted

var jogo:Node
func _init(cena:Node) -> void:jogo=cena
func conteudo(item:Dictionary) -> Dictionary:return PassagemCadeirasPlex.conteudo(item)
func objetos(tipo:String) -> Array:
	return jogo.planta.objetos.values().filter(func(o):return MobiliaPlex.visual(conteudo(o))==tipo)
func mesa() -> Dictionary:
	var geradores:Array=jogo.planta.objetos.values().filter(func(o):return MobiliaPlex.dados(o).get("gerador",false) and TerrenoPlex.contem(jogo.planta,o.celula))
	var mesas:Array=jogo.planta.objetos.values().filter(func(o):return CatalogoPlex.base(MobiliaPlex.logico(MobiliaPlex.visual(conteudo(o)))) in ["mesa","bancada","balcao"] and TerrenoPlex.contem(jogo.planta,o.celula))
	if mesas.is_empty():return {}
	if not geradores.is_empty():mesas.sort_custom(func(a,b):return a.celula.distance_squared_to(geradores[0].celula)<b.celula.distance_squared_to(geradores[0].celula))
	return mesas[0]
func parede(a:PersonagemPlex) -> Dictionary:
	var mesa_alvo:=mesa();var origem:Vector2i=mesa_alvo.get("celula",a.celula)
	var paredes:Array=jogo.planta.objetos.values().filter(func(o):return CatalogoPlex.base(str(o.tipo))=="parede" and not TerrenoPlex.protegido(jogo.planta,o) and TerrenoPlex.contem(jogo.planta,o.celula))
	paredes.sort_custom(func(x,y):return x.celula.distance_squared_to(origem)<y.celula.distance_squared_to(origem))
	var alternativa:Dictionary={}
	for p in paredes:
		var alcancavel:=Vector2i(-1,-1);var abre_sala:=false
		for d in GradePlex.VIZINHOS:
			var c:Vector2i=p.celula+d
			if not TerrenoPlex.contem(jogo.planta,c) or not jogo.planta.transitavel(c):continue
			if jogo.rotas.caminho(a.origem_rota(),c).is_empty():abre_sala=true
			else:alcancavel=c
		if alcancavel.x<0:continue
		var escolha:Dictionary={"id":int(p.id),"celula":p.celula,"olhar":alcancavel}
		if abre_sala:return escolha
		if alternativa.is_empty():alternativa=escolha
	return alternativa
func ventilacoes() -> Array:
	var m:=mesa();var origem:Vector2i=m.get("celula",Vector2i(TerrenoPlex.area(jogo.planta).get_center()));var resultado:Array=[]
	for o in jogo.planta.objetos.values():
		if CatalogoPlex.base(str(o.tipo))!="parede" or not TerrenoPlex.protegido(jogo.planta,o) or o.celula.distance_squared_to(origem)>40:continue
		for r in 4:
			if jogo.planta.pode_colocar("oficina_duto_grade",o.celula,r):resultado.append({"celula":o.celula,"r":r})
	resultado.sort_custom(func(x,y):return x.celula.distance_squared_to(origem)<y.celula.distance_squared_to(origem))
	return resultado
func desembalar(a:PersonagemPlex,id:int) -> bool:
	if not is_instance_valid(a) or jogo.servicos.trabalhos.has(a.identificador):return false
	var s:ServicosPlex=jogo.servicos
	return s.iniciar(a,"Desembalar móvel",[s.etapa(id,"desembalar",3.0)],[id])
func residuos() -> Array:
	return jogo.planta.objetos.values().filter(func(o):return LimpezaAmbientesPlex.eh(o) and CatalogoPlex.base(str(o.tipo))!="parede" and o.tipo!="cenario_buraco_madeira" and TerrenoPlex.contem(jogo.planta,o.celula))
func limpar(a:PersonagemPlex,proprios:bool) -> bool:
	var s:ServicosPlex=jogo.servicos
	if not is_instance_valid(a) or s.trabalhos.has(a.identificador) or a.ocupado():return false
	if proprios and jogo.planta.objetos.get(a.carga_item,{}).has("tutorial_dono") and not jogo.planta.objetos.values().any(func(o):return DescartePlex.interna(jogo.planta,o) and int(o.get("lixo",0))<6):
		var ferramenta_antiga:=a.carga_item;a.carga_item=-1;jogo.planta.remover(ferramenta_antiga)
	if SacosLixoPlex.iniciar(s,a):return true
	var sujeiras:=residuos();sujeiras.sort_custom(func(x,y):return x.celula.distance_squared_to(a.celula)<y.celula.distance_squared_to(a.celula))
	if not proprios:
		for item in sujeiras:
			if LimpezaAmbientesPlex.iniciar(s,a,item.id):return true
		return false
	for item in sujeiras:
		if not LimpezaAmbientesPlex.acessivel(s,item):continue
		var tipo:="balde" if item.tipo=="bebida_derramada" or str(item.tipo).contains("poca") else "vassoura"
		var carregada:Dictionary=jogo.planta.objetos.get(a.carga_item,{})
		if not carregada.is_empty() and (carregada.tipo!=tipo or int(carregada.get("tutorial_dono",-1))!=a.identificador):
			if not carregada.has("tutorial_dono"):continue
			a.carga_item=-1;jogo.planta.remover(int(carregada.id))
		var ferramentas:Array=jogo.planta.objetos.values().filter(func(o):return o.tipo==tipo and int(o.get("tutorial_dono",-1))==a.identificador)
		var ferramenta:int
		if ferramentas.is_empty():
			ferramenta=s.inventario.criar(tipo,a.celula);jogo.planta.objetos[ferramenta].tutorial_dono=a.identificador
		else:ferramenta=ferramentas[0].id
		if a.carga_item!=ferramenta and not s.inventario.pegar(a,ferramenta):continue
		var lixeiras:Array=jogo.planta.objetos.values().filter(func(o):return DescartePlex.interna(jogo.planta,o) and int(o.get("lixo",0))<6 and s.livre(o.id))
		for lixo in DescartePlex.ordenar(s,item.celula,a,lixeiras):
			var passos:Array=[s.etapa(item.id,"limpar",2.5),s.etapa(lixo.id,"lixo",.7)]
			if s.iniciar(a,"Limpeza guiada",passos,[ferramenta,item.id,lixo.id]):return true
	return false
func ocupados(atores:Array) -> bool:
	return atores.any(func(a):return is_instance_valid(a) and jogo.servicos.trabalhos.has(a.identificador))
func liberar_passagem(a:PersonagemPlex,forcar:bool=false) -> bool:
	if not is_instance_valid(a) or a.ocupado() or jogo.servicos.trabalhos.has(a.identificador):return false
	if not forcar and GradePlex.VIZINHOS.filter(func(d):return jogo.planta.transitavel(a.celula+d)).size()>=3:return false
	var destinos:Array=[]
	for x in range(-5,6):
		for y in range(-5,6):
			var c:=a.celula+Vector2i(x,y)
			if c.distance_squared_to(a.celula)<4 or not TerrenoPlex.contem(jogo.planta,c) or not jogo.planta.transitavel(c) or jogo.personagens.any(func(b):return b!=a and b.celula==c):continue
			if GradePlex.VIZINHOS.all(func(d):return jogo.planta.transitavel(c+d)):destinos.append(c)
	destinos.sort_custom(func(x,y):return x.distance_squared_to(a.celula)<y.distance_squared_to(a.celula))
	for c in destinos:
		var rota:Array[Vector2i]=jogo.rotas.caminho(a.origem_rota(),c)
		if not rota.is_empty():a.andar(rota);return true
	return false
func guardar_ferramentas() -> void:
	for a in jogo.personagens:
		if a.visita.get("tutorial_ativo",false) and jogo.servicos.trabalhos.has(a.identificador):jogo.servicos.cancelar(a)
	for o in jogo.planta.objetos.values().duplicate():
		if not o.has("tutorial_dono"):continue
		for a in jogo.personagens:
			if a.carga_item==int(o.id):a.carga_item=-1
		jogo.planta.remover(int(o.id))
