class_name CaminhosCidadePlex
extends RefCounted

const CASA = "cidade_casa_b_10_10"
const PASSO_EXTERNO = 1.05
const ACESSO = [Vector2(3.5,10.5),Vector2(3.5,9.5),Vector2(3.5,8.5)]
static var acessos: Dictionary={}
var planta: PlantaPlex
var rotas: RotasPlex
var grafo:=AStar2D.new()
var revisao:=-1
var permitidas: Dictionary={}

func _init(p: PlantaPlex, navegacao: RotasPlex) -> void:
	planta=p
	rotas=navegacao

static func acesso(item: Dictionary) -> Array[Vector2i]:
	if item.get("tipo","")!=CASA: return []
	var chave:=str([item.celula,item.rotacao])
	if not acessos.has(chave):
		var centro:=Vector2(item.celula)+Vector2(4.5,4.5)
		var pontos: Array[Vector2i]=[]
		for local in ACESSO:
			var c:=Vector2i((centro+GradePlex.girar(local-Vector2(5,5),item.rotacao)).round())
			if not pontos.has(c): pontos.append(c)
		acessos[chave]=pontos
	return acessos[chave]

static func passagem(item: Dictionary, c: Vector2i) -> bool:
	return item.get("tipo","")=="cidade_poste_de_luz" or (item.get("tipo","")==CASA and acesso(item).has(c))

func piso(c: Vector2i) -> bool:
	var tipo:=str(planta.pisos.get(c,""))
	return tipo.begins_with("cidade_calcada") or tipo.begins_with("cidade_faixa_de_pedestre")

func reconstruir() -> void:
	if revisao==planta.revisao: return
	revisao=planta.revisao
	grafo.clear()
	permitidas.clear()
	var particulares: Dictionary={}
	for item in planta.objetos.values():
		for c in acesso(item): particulares[c]=true
	for y in GradePlex.TAMANHO.y:
		for x in GradePlex.TAMANHO.x:
			var c:=Vector2i(x,y)
			if not planta.transitavel(c) or not (TerrenoPlex.contem(planta,c) or piso(c) or particulares.has(c)): continue
			permitidas[c]=true
			grafo.add_point(y*GradePlex.TAMANHO.x+x,Vector2(c))
	for c in permitidas:
		for d in [Vector2i(1,0),Vector2i(0,1)]:
			var b: Vector2i=c+d
			if permitidas.has(b) and rotas.conectavel(c,b): grafo.connect_points(c.y*GradePlex.TAMANHO.x+c.x,b.y*GradePlex.TAMANHO.x+b.x)

func caminho(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var resultado:=_caminho(a,b)
	return resultado

func _caminho(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	reconstruir()
	var resultado: Array[Vector2i]=[]
	if not permitidas.has(b): return resultado
	var temporario:=not permitidas.has(a) and TerrenoPlex.contem(planta,a)
	if temporario:
		grafo.add_point(a.y*GradePlex.TAMANHO.x+a.x,Vector2(a))
		for d in GradePlex.VIZINHOS:
			var vizinha: Vector2i=a+d
			if permitidas.has(vizinha) and rotas.conectavel(a,vizinha): grafo.connect_points(a.y*GradePlex.TAMANHO.x+a.x,vizinha.y*GradePlex.TAMANHO.x+vizinha.x)
	elif not permitidas.has(a): return resultado
	for ponto in grafo.get_point_path(a.y*GradePlex.TAMANHO.x+a.x,b.y*GradePlex.TAMANHO.x+b.x): resultado.append(Vector2i(ponto))
	if temporario: grafo.remove_point(a.y*GradePlex.TAMANHO.x+a.x)
	return resultado

func duracao(rota: Array[Vector2i]) -> float:
	var tempo:=0.0
	for i in range(1,rota.size()): tempo+=1.0/(.88 if TerrenoPlex.contem(planta,rota[i]) else PASSO_EXTERNO)+.05
	return tempo*CalendarioPlex.MINUTOS_POR_SEGUNDO

