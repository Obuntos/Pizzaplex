class_name LocaisBairroPlex
extends RefCounted
var jogo: Node
var grafo:=AStar2D.new()
var faixas: Array[AStar2D]=[]
var indice_paradas: Dictionary={}
var tiles: Array[Vector2i]=[]
var paradas: Array[Vector2i]=[]
var permitidas: Dictionary={}
var enderecos: Dictionary={}
var cache_rotas: Dictionary={}
var assinatura:=-1
func _init(cena: Node) -> void:
	jogo=cena
func chave(c: Vector2i) -> int:
	return c.y*GradePlex.TAMANHO.x+c.x
func preparar(tipos: Dictionary) -> bool:
	var edificios: Dictionary={}
	for item in jogo.planta.objetos.values():
		for nome in tipos:
			if item.tipo==tipos[nome]: edificios[nome]=item
	var nova:=hash(edificios.values().map(func(o): return [o.tipo,o.celula,o.rotacao]))
	if nova==assinatura: return not enderecos.is_empty()
	assinatura=nova;
	grafo.clear();faixas=[grafo,AStar2D.new(),AStar2D.new()];permitidas.clear();tiles.clear();paradas.clear();indice_paradas.clear();enderecos.clear();cache_rotas.clear()
	if edificios.is_empty(): return false
	for c in jogo.planta.pisos:
		var tipo: String=jogo.planta.pisos[c]
		if (tipo.begins_with("cidade_calcada") or tipo.begins_with("cidade_faixa_de_pedestre")) and jogo.planta.transitavel(c) and not TerrenoPlex.contem(jogo.planta,c):
			permitidas[c]=true;tiles.append(c)
			var faixa:=distancia_rua(c)
			for i in faixas.size(): faixas[i].add_point(chave(c),Vector2(c),1.0+absf(float(faixa-i-1))*.24 if faixa>0 else 1.0)
			if tipo.begins_with("cidade_calcada") and jogo.planta.em(c).is_empty(): paradas.append(c);indice_paradas[c]=true
	for c in tiles:
		for d in [Vector2i(1,0),Vector2i(0,1)]:
			var outro: Vector2i=c+d
			if permitidas.has(outro) and jogo.rotas.conectavel(c,outro):
				for via in faixas: via.connect_points(chave(c),chave(outro))
	for nome in edificios:
		var item: Dictionary=edificios[nome]
		var tamanho:=CatalogoPlex.dimensoes(item.tipo,item.rotacao)
		var centro:=Vector2(item.celula)+Vector2(tamanho-Vector2i.ONE)*.5
		var frente:=Vector2(GradePlex.frente(item.rotacao))
		var alvo:=centro+frente*(float(tamanho.y if item.rotacao%2==0 else tamanho.x)*.5+.5)
		var melhor:=Vector2i(-1,-1)
		var distancia:=INF
		for c in paradas:
			var v:=Vector2(c)-alvo
			var peso:=v.length_squared()+maxf(0,-(Vector2(c)-centro).dot(frente))*8.0
			if peso<distancia: distancia=peso;melhor=c
		if melhor.x>=0: enderecos[nome]={"celula":melhor,"objeto":item.id,"centro":centro}
	return true
func distancia_rua(c: Vector2i) -> int:
	if str(jogo.planta.pisos.get(c,"")).begins_with("cidade_faixa_de_pedestre"): return 0
	var menor:=0
	for direcao in GradePlex.VIZINHOS:
		for d in range(1,6):
			var tipo:=str(jogo.planta.pisos.get(c+direcao*d,""))
			if tipo.is_empty() or tipo.begins_with("cidade_grama") or tipo.begins_with("cidade_terra"): break
			if tipo.begins_with("cidade_calcada") or tipo.begins_with("cidade_faixa_de_pedestre"): continue
			menor=d if menor==0 else mini(menor,d)
			break
	return menor
func ponto(local: String, perfil: Dictionary = {}) -> Vector2i:
	if local=="casa": local=str(perfil.get("moradia","fora"))
	if local=="rua": return passeio(ponto(str(perfil.get("moradia","apartamentos"))),hash(perfil.get("id","")))
	return enderecos.get(local,{}).get("celula",Vector2i(-1,-1))
func passeio(origem: Vector2i, semente: int) -> Vector2i:
	var candidatos: Array[Vector2i]=[]
	for c in paradas:
		var d:=c.distance_squared_to(origem)
		if d>=9 and d<=196: candidatos.append(c)
	return (origem if parada_segura(origem) else parada_proxima(origem)) if candidatos.is_empty() else candidatos[posmod(semente,candidatos.size())]
func parada_proxima(origem: Vector2i) -> Vector2i:
	var melhor:=Vector2i(-1,-1)
	var distancia:=INF
	for c in paradas:
		var atual:=float(c.distance_squared_to(origem))
		if atual<distancia: distancia=atual;melhor=c
	return melhor
func parada_segura(c: Vector2i) -> bool:
	return indice_paradas.has(c)
func caminho(a: Vector2i, b: Vector2i, preferencia: int = 0) -> Array[Vector2i]:
	var resultado:=_caminho(a,b,preferencia)
	return resultado
func _caminho(a: Vector2i, b: Vector2i, preferencia: int = 0) -> Array[Vector2i]:
	var faixa:=posmod(preferencia,3)
	var id:=str([a,b,faixa])
	if cache_rotas.has(id): return cache_rotas[id]
	var resultado: Array[Vector2i]=[]
	if permitidas.has(a) and permitidas.has(b):
		for p in faixas[faixa].get_point_path(chave(a),chave(b)): resultado.append(Vector2i(p))
	if cache_rotas.size()>=128: cache_rotas.erase(cache_rotas.keys()[0])
	cache_rotas[id]=resultado
	return resultado
