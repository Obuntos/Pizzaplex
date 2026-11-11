class_name RotasPlex
extends RefCounted
const PASSOS=[Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0),Vector2i(0,-1),Vector2i(1,1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(-1,-1)]
var planta: PlantaPlex
var grafo := AStar2D.new()
var assinatura: int = -1
var revisao := 0
var cache: Dictionary = {}
var bloqueios_ativos: Dictionary = {}
var assinatura_bloqueios := -1
var solidos: Dictionary = {}
var ordem_cache: Array[String] = []
var estrutura_celulas: Dictionary = {}
var cache_versoes: Dictionary = {}
var assinatura_estatica := -1
var baloes_pesos: Dictionary = {}
func _init(valor: PlantaPlex) -> void:
	planta = valor
	planta.alterada.connect(reconstruir)
	reconstruir()
func indice(celula_local: Vector2i) -> int:
	return celula_local.y * GradePlex.TAMANHO.x + celula_local.x
func celula(id: int) -> Vector2i:
	return Vector2i(id % GradePlex.TAMANHO.x, floori(float(id) / GradePlex.TAMANHO.x))
func escada_ligada(a: Vector2i, b: Vector2i) -> bool:
	var escada := planta.em(a)
	if not EscadasPlex.eh(escada):
		return false
	var frente := GradePlex.frente(escada.rotacao)
	var entrada: Vector2i = a + frente
	var saida: Vector2i = a - frente
	var conectada := EscadasPlex.faixa(a,planta).any(func(c): return EscadasPlex.palco(planta.em(c-frente)))
	if not conectada: return false
	var vizinho := planta.em(b)
	if EscadasPlex.eh(vizinho):
		return vizinho.rotacao == escada.rotacao and Vector2(b - a).dot(Vector2(frente)) == 0.0
	if b == entrada:
		return GradePlex.dentro(b) and is_zero_approx(planta.altura(b))
	return b == saida and EscadasPlex.palco(vizinho)
func conectavel(a: Vector2i, b: Vector2i) -> bool:
	var d:=b-a
	if abs(d.x)==1 and abs(d.y)==1:
		var x:=a+Vector2i(d.x,0);var y:=a+Vector2i(0,d.y)
		for c in [a,b,x,y]:
			if not planta.transitavel(c) or bloqueios_ativos.has(c) or planta.em(c).get("tipo","") in CatalogoPlex.PORTAS or EscadasPlex.eh(planta.em(c)):return false
		return conectavel(a,x) and conectavel(a,y) and conectavel(x,b) and conectavel(y,b)
	if not CabinesPlex.permite(planta, a, b): return false
	var primeiro := planta.em(a)
	var segundo := planta.em(b)
	if EscadasPlex.eh(primeiro):
		return escada_ligada(a, b)
	if EscadasPlex.eh(segundo):
		return escada_ligada(b, a)
	for item in [primeiro, segundo]:
		if item.get("tipo", "") in CatalogoPlex.PORTAS:
			var normal := GradePlex.frente(item.rotacao)
			if a - b != normal and b - a != normal:
				return false
	return is_equal_approx(planta.altura(a), planta.altura(b))
func reconstruir() -> void:
	_reconstruir()
func _reconstruir() -> void:
	var estrutura: Array = []
	var celulas_atuais: Dictionary = {}
	for item in planta.objetos.values():
		if item.tipo in (CatalogoPlex.PORTAS + ["divisoria_porta"]) or EscadasPlex.tipo(item) in ["palco","escada"]:
			var estado:=hash([item.tipo,item.celula,item.rotacao,item.get("trancada",false)])
			estrutura.append(estado)
			for c in planta.celulas(item.tipo,item.celula,item.rotacao): celulas_atuais[c]=estado
	var atual := hash(estrutura)
	if assinatura != atual:
		assinatura = atual
		cache.clear();ordem_cache.clear();cache_versoes.clear()
		var regiao: Dictionary={}
		if grafo.get_point_count()==0:
			for y in GradePlex.TAMANHO.y:
				for x in GradePlex.TAMANHO.x:
					var c:=Vector2i(x,y)
					grafo.add_point(indice(c),Vector2(c))
					regiao[c]=true
		else:
			for c in estrutura_celulas.keys()+celulas_atuais.keys():
				if estrutura_celulas.get(c,-1)==celulas_atuais.get(c,-1): continue
				regiao[c]=true
				for d in PASSOS:
					if GradePlex.dentro(c+d): regiao[c+d]=true
		for c in regiao.keys():
			for degrau in EscadasPlex.faixa(c,planta):
				regiao[degrau]=true
				for d in PASSOS:
					if GradePlex.dentro(degrau+d): regiao[degrau+d]=true
		for c in regiao:
			for d in PASSOS:
				var b: Vector2i=c+d
				if not GradePlex.dentro(b): continue
				var conectada:=grafo.are_points_connected(indice(c),indice(b))
				var permitida:=conectavel(c,b)
				if permitida and not conectada: grafo.connect_points(indice(c),indice(b))
				elif conectada and not permitida: grafo.disconnect_points(indice(c),indice(b))
		estrutura_celulas=celulas_atuais
	atualizar_bloqueios()
func atualizar_diagonais(celulas_alteradas:Array) -> void:
	var regiao:Dictionary={}
	for c in celulas_alteradas:
		regiao[c]=true
		for d in PASSOS:
			if GradePlex.dentro(c+d):regiao[c+d]=true
	for c in regiao:
		for d in [Vector2i(1,1),Vector2i(1,-1)]:
			var b:Vector2i=c+d
			if not GradePlex.dentro(b):continue
			var conectada:=grafo.are_points_connected(indice(c),indice(b))
			var permitida:=conectavel(c,b)
			if permitida and not conectada:grafo.connect_points(indice(c),indice(b))
			elif conectada and not permitida:grafo.disconnect_points(indice(c),indice(b))
func atualizar_bloqueios() -> void:
	var baloes: Dictionary={}
	for item in planta.objetos.values():
		if str(MobiliaPlex.visual(item)).begins_with("festa_baloes") and int(item.get("carregada_por",0))==0:
			for c in planta.celulas(item.tipo,item.celula,item.rotacao):baloes[c]=true
	if hash(baloes)!=hash(baloes_pesos):
		for c in baloes_pesos:
			if grafo.has_point(indice(c)):grafo.set_point_weight_scale(indice(c),1.0)
		for c in baloes:
			if grafo.has_point(indice(c)):grafo.set_point_weight_scale(indice(c),8.0)
		baloes_pesos=baloes
		cache.clear();ordem_cache.clear();cache_versoes.clear()
	var novos: Dictionary = {}
	for c in planta.ocupacao:
		var item := planta.em(c)
		if item.get("trancada",false):novos[c]=true;continue
		if CaminhosCidadePlex.passagem(item,c): continue
		if item.get("tipo","") not in CatalogoPlex.PORTAS and EscadasPlex.tipo(item) not in ["palco","escada"]: novos[c]=true
	for c in planta.reservas_abertura:
		if planta.bloqueio_abertura(c): novos[c]=true
	for c in planta.bairro_bloqueios: novos[c]=true
	var atual := hash(novos)
	var mudou_estrutura:=atual!=assinatura_estatica
	assinatura_estatica=atual
	for c in solidos: novos[c]=true
	atual = hash(novos)
	if atual == assinatura_bloqueios: return
	assinatura_bloqueios = atual
	for c in bloqueios_ativos:
		if not novos.has(c) and grafo.has_point(indice(c)): grafo.set_point_disabled(indice(c),false)
	for c in novos:
		if not bloqueios_ativos.has(c) and grafo.has_point(indice(c)): grafo.set_point_disabled(indice(c),true)
	var alteradas:Array=[]
	for c in novos:
		if not bloqueios_ativos.has(c):alteradas.append(c)
	for c in bloqueios_ativos:
		if not novos.has(c):alteradas.append(c)
	bloqueios_ativos = novos
	atualizar_diagonais(alteradas)
	revisao += 1
	if mudou_estrutura:
		cache.clear();ordem_cache.clear();cache_versoes.clear()
func caminho(origem: Vector2i, destino: Vector2i, bloqueados: Array[Vector2i] = []) -> Array[Vector2i]:
	var resultado:=_caminho(origem,destino,bloqueados)
	return resultado
func _caminho(origem: Vector2i, destino: Vector2i, bloqueados: Array[Vector2i] = []) -> Array[Vector2i]:
	var chave := str(Vector4i(origem.x,origem.y,destino.x,destino.y))+":"+str(bloqueados)
	if cache.has(chave) and cache_valido(chave,origem):
		var salva: Array[Vector2i] = []
		salva.assign(cache[chave])
		return salva
	var resultado: Array[Vector2i] = []
	if not GradePlex.dentro(origem) or not GradePlex.dentro(destino):
		return resultado
	if not grafo.has_point(indice(origem)) or not grafo.has_point(indice(destino)):
		return resultado
	if grafo.is_point_disabled(indice(destino)) and destino != origem: return resultado
	var origem_bloqueada := grafo.is_point_disabled(indice(origem))
	if origem_bloqueada: grafo.set_point_disabled(indice(origem),false)
	var desativados: Array[int] = []
	for local in bloqueados:
		if local != origem and GradePlex.dentro(local) and grafo.has_point(indice(local)) and not grafo.is_point_disabled(indice(local)):
			grafo.set_point_disabled(indice(local), true)
			desativados.append(indice(local))
	var temporarias:Array=[]
	for id in desativados:
		var c:=celula(id);bloqueios_ativos[c]=true;temporarias.append(c)
	atualizar_diagonais(temporarias)
	for id in grafo.get_id_path(indice(origem), indice(destino)):
		resultado.append(celula(id))
	for id in desativados:
		grafo.set_point_disabled(id, false);bloqueios_ativos.erase(celula(id))
	atualizar_diagonais(temporarias)
	if origem_bloqueada: grafo.set_point_disabled(indice(origem),true)
	if not cache.has(chave):
		if cache.size()>=4096:
			var antiga: String=ordem_cache.pop_front()
			cache.erase(antiga);cache_versoes.erase(antiga)
		ordem_cache.append(chave)
	cache[chave] = resultado.duplicate()
	cache_versoes[chave]=assinatura_bloqueios
	return resultado
func cache_valido(chave: String, origem: Vector2i) -> bool:
	var rota: Array=cache[chave]
	if rota.is_empty(): return cache_versoes.get(chave,-1)==assinatura_bloqueios
	for i in rota.size():
		var c:Vector2i=rota[i]
		if c!=origem and grafo.is_point_disabled(indice(c)): return false
		if i>0 and abs(c.x-rota[i-1].x)==1 and abs(c.y-rota[i-1].y)==1 and not conectavel(rota[i-1],c):return false
	return true
func aproximar(origem: Vector2i, objeto: int) -> Array[Vector2i]:
	var melhor: Array[Vector2i] = []
	for destino in planta.interacoes(objeto):
		var rota := caminho(origem, destino)
		if not rota.is_empty() and (melhor.is_empty() or rota.size() < melhor.size()):
			melhor = rota
	return melhor
func sair_suporte(suporte: int, destino: Vector2i) -> Array[Vector2i]:
	var resultado: Array[Vector2i] = []
	for entrada in planta.interacoes(suporte):
		var rota := caminho(entrada, destino)
		if not rota.is_empty():
			resultado.append(planta.objetos[suporte].celula)
			resultado.append_array(rota)
			return resultado
	return resultado
func aproximar_montagem(origem: Vector2i, suporte: int) -> Array[Vector2i]:
	var opcoes := planta.interacoes(suporte)
	var centro: Vector2i = planta.objetos[suporte].celula
	var frente := GradePlex.frente(planta.objetos[suporte].rotacao)
	opcoes.sort_custom(func(a, b):
		var nota_a: float = GradePlex.projetar_local(Vector2(a - centro)).y + (2.0 if a - centro == frente else 0.0)
		var nota_b: float = GradePlex.projetar_local(Vector2(b - centro)).y + (2.0 if b - centro == frente else 0.0)
		return nota_a > nota_b)
	for destino in opcoes:
		var rota := caminho(origem, destino)
		if not rota.is_empty():
			return rota
	return []
func atualizar_atores(atores: Array) -> void:
	var atuais: Dictionary = {}
	for ator in atores:
		if not is_instance_valid(ator) or not ator.robo or ator.ocupado() or ator.suporte>=0: continue
		atuais[ator.celula]=true
	if hash(atuais)==hash(solidos): return
	solidos=atuais
	atualizar_bloqueios()

func caminho_chao(origem:Vector2i,destino:Vector2i) -> Array[Vector2i]:
	var bloqueados:Array[Vector2i]=[]
	for o in planta.objetos.values():
		if EscadasPlex.tipo(o) in ["palco","escada"]:
			for c in planta.celulas(o.tipo,o.celula,o.rotacao):bloqueados.append(c)
	return caminho(origem,destino,bloqueados)
