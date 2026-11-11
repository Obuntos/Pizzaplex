class_name EntradaNaturalPlex
extends RefCounted

const BASE=30.0
const TOPO=88.0
var planta: PlantaPlex
var janelas: Array[Dictionary]=[]
var textura: ImageTexture
var mapa: Image
var assinatura:=-1

func _init(p: PlantaPlex) -> void:
	planta=p
	textura=ImageTexture.create_from_image(Image.create_empty(GradePlex.TAMANHO.x,GradePlex.TAMANHO.y,false,Image.FORMAT_RF))

static func eh(item: Dictionary) -> bool:
	if item.is_empty(): return false
	return str(item.get("tipo","")).begins_with("janela") or MobiliaPlex.visual(item).contains("_janela") or MobiliaPlex.visual(item).contains("_vitrine")

static func largura(item: Dictionary) -> float:
	return float(CatalogoPlex.objetos[item.tipo].largura)

static func bloqueia(item: Dictionary, a: Vector3, b: Vector3, entrada: float, saida: float) -> bool:
	var meio:=largura(item)*.5
	if OclusaoPlex.raio_caixa(a,b,Vector3(-meio,-.495,0),Vector3(meio,.495,BASE),entrada,saida): return true
	if OclusaoPlex.raio_caixa(a,b,Vector3(-meio,-.495,TOPO),Vector3(meio,.495,160),entrada,saida): return true
	for x in range(int(largura(item))+1):
		var u: float=-meio+float(x)
		if OclusaoPlex.raio_caixa(a,b,Vector3(u-.055,-.495,BASE),Vector3(u+.055,.495,TOPO),entrada,saida): return true
	return false

func atualizar(salas: Dictionary) -> void:
	var fontes: Array=[]
	for item in planta.objetos.values():
		if eh(item): fontes.append([item.id,item.tipo,item.get("variante",""),item.celula,item.rotacao])
	var chave:=hash([fontes,planta.revisao])
	if chave==assinatura: return
	assinatura=chave;janelas.clear()
	var imagem:=Image.create_empty(GradePlex.TAMANHO.x,GradePlex.TAMANHO.y,false,Image.FORMAT_RF)
	for fonte in fontes:
		var item: Dictionary=planta.objetos[fonte[0]]
		var normal:=GradePlex.frente(item.rotacao)
		var centro:=Vector2(item.celula)+Vector2(CatalogoPlex.dimensoes(item.tipo,item.rotacao)-Vector2i.ONE)*.5
		var exterior:=false
		for c in planta.celulas(item.tipo,item.celula,item.rotacao):
			if salas.has(c+normal)!=salas.has(c-normal): exterior=true
		if not exterior: continue
		janelas.append({"item":item,"centro":centro,"frente":Vector2(normal),"largura":largura(item)})
		for y in range(maxi(0,item.celula.y-5),mini(GradePlex.TAMANHO.y,item.celula.y+6)):
			for x in range(maxi(0,item.celula.x-5),mini(GradePlex.TAMANHO.x,item.celula.x+6)):
				var c:=Vector2i(x,y)
				if not salas.has(c): continue
				var distancia:=Vector2(c).distance_to(centro)
				if distancia>5: continue
				var origem:=GradePlex.projetar(Vector2(c))
				var janela:=GradePlex.projetar(centro)
				var visivel:=OclusaoPlex.visibilidade(planta,Vector3(origem.x,origem.y*2.0,18),Vector3(janela.x,janela.y*2.0,58))
				var energia: float=pow(maxf(0,1.0-distancia/5.2),2)*visivel*.85
				imagem.set_pixel(x,y,Color(maxf(imagem.get_pixel(x,y).r,energia),0,0))
	mapa=imagem
	textura.update(imagem)

func permite_raio(ponto: Vector3, direcao: Vector3) -> bool:
	if direcao.z<=.001: return false
	var a:=GradePlex.inverter(Vector2(ponto.x,ponto.y*.5))
	var b:=GradePlex.inverter(Vector2(ponto.x+direcao.x*1200.0,(ponto.y+direcao.y*1200.0)*.5))
	var delta:=b-a
	for janela in janelas:
		var normal: Vector2=janela.frente
		var denominador:=delta.dot(normal)
		if absf(denominador)<.000001: continue
		var t: float=(Vector2(janela.centro)-a).dot(normal)/denominador
		var altura:=ponto.z+direcao.z*1200.0*t
		var lateral: float=(a+delta*t-Vector2(janela.centro)).dot(Vector2(normal.y,-normal.x))
		if t>0 and altura>BASE+1 and altura<TOPO-1 and absf(lateral)<float(janela.largura)*.5-.06: return true
	return false
