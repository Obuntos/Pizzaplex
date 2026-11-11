class_name ChegadasEquipePlex
extends RefCounted

static func campo(jogo:Node) -> Rect2:
	var tela:Rect2=jogo.get_viewport().get_visible_rect()
	var inversa:Transform2D=jogo.camera.get_canvas_transform().affine_inverse()
	var area:=Rect2(inversa*tela.position,Vector2.ZERO)
	for canto in [Vector2(tela.end.x,tela.position.y),tela.end,Vector2(tela.position.x,tela.end.y)]:area=area.expand(inversa*canto)
	return area.grow(72.0)

static func bordas(id:int=0) -> Array[Vector2i]:
	var limites:=GradePlex.TAMANHO-Vector2i.ONE
	var resultado:Array[Vector2i]=[]
	for i in range(2,limites.x-1,4):resultado.append_array([Vector2i(i,1),Vector2i(i,limites.y-1)])
	for i in range(2,limites.y-1,4):resultado.append_array([Vector2i(1,i),Vector2i(limites.x-1,i)])
	if not resultado.is_empty():
		for i in posmod(id,resultado.size()):resultado.append(resultado.pop_front())
	return resultado

static func origem(jogo:Node,a:PersonagemPlex,destino:Vector2i) -> Vector2i:
	var area:=campo(jogo)
	var candidatos:Array[Vector2i]=[]
	var borda:=bordas(a.identificador)
	for p in borda:
		if not area.has_point(GradePlex.projetar(Vector2(p))):candidatos.append(p)
	if candidatos.is_empty():candidatos=borda
	candidatos.sort_custom(func(x,y):return x.distance_squared_to(destino)<y.distance_squared_to(destino))
	for p in candidatos.slice(0,20):
		if jogo.planta.transitavel(p) and not jogo.rotas.caminho(p,destino).is_empty():return p
	return Vector2i(-1,-1)

static func entradas(jogo:Node) -> Array:
	var lista:Array=[]
	for porta in jogo.planta.objetos.values():
		if porta.tipo not in CatalogoPlex.PORTAS:continue
		for c in jogo.planta.celulas(porta.tipo,porta.celula,porta.rotacao):
			for frente in [GradePlex.frente(int(porta.rotacao)),-GradePlex.frente(int(porta.rotacao))]:
				var dentro:Vector2i=c-frente;var fora:Vector2i=c+frente
				if TerrenoPlex.contem(jogo.planta,dentro) and not TerrenoPlex.contem(jogo.planta,fora) and jogo.planta.transitavel(fora):lista.append({"dentro":dentro,"fora":fora,"frente":frente})
	return lista

static func destino_saida(jogo:Node,a:PersonagemPlex) -> Vector2i:
	var pontos:=bordas(a.identificador)
	pontos.sort_custom(func(x,y):return x.distance_squared_to(a.celula)<y.distance_squared_to(a.celula))
	for p in pontos:
		if jogo.planta.transitavel(p) and not jogo.rotas.caminho(a.origem_rota(),p).is_empty():return p
	return Vector2i(-1,-1)

static func pode_sumir(jogo:Node,a:PersonagemPlex) -> bool:
	if TerrenoPlex.contem(jogo.planta,a.celula):return false
	return not campo(jogo).has_point(GradePlex.projetar(a.local)) or a.celula.x<=1 or a.celula.y<=1 or a.celula.x>=GradePlex.TAMANHO.x-2 or a.celula.y>=GradePlex.TAMANHO.y-2
