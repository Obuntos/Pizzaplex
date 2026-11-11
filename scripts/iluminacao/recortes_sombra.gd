class_name RecortesSombraPlex
extends RefCounted

const LARGURA=64
const ALTURA=128
const COLUNAS=8
const TIPOS=["antigo_recorte_chao_coelho","antigo_recorte_chao_ovelha","antigo_recorte_chao_raposa"]
static var perfis: Dictionary={}
static var imagem: Image
static var textura: ImageTexture

static func garantir() -> void:
	if imagem!=null: return
	imagem=Image.create_empty(LARGURA*COLUNAS,ALTURA*COLUNAS,false,Image.FORMAT_R8)
	textura=ImageTexture.create_from_image(imagem)

static func eh(item: Dictionary) -> bool:
	return MobiliaPlex.visual(item) in TIPOS

static func perfil(item: Dictionary) -> int:
	garantir()
	var tipo:=MobiliaPlex.visual(item)
	var estado:=MobiliaPlex.estado(item)
	var chave:=tipo+":"+estado
	if perfis.has(chave): return int(perfis[chave])
	if perfis.size()>=COLUNAS*COLUNAS: return -1
	var indice:=perfis.size()
	var origem:=Vector2i(indice%COLUNAS*LARGURA,floori(float(indice)/COLUNAS)*ALTURA)
	var volume:=GeometriaPlex.obter(tipo,0,4,0,false,estado)
	for p in volume.pontos:
		var altura: float=(p.z-2.0*p.y)/3.0
		var lateral: float=p.x/64.0+(p.y+altura)/32.0
		var x:=roundi(lateral*32.0)+(LARGURA >> 1)
		var y:=ALTURA-1-roundi(altura)
		if x>=0 and x<LARGURA and y>=0 and y<ALTURA: imagem.set_pixelv(origem+Vector2i(x,y),Color.WHITE)
	perfis[chave]=indice
	textura.update(imagem)
	return indice

static func intersecao(volume: Dictionary, a: Vector3, b: Vector3, entrada: float=0.0, saida: float=1.0) -> bool:
	var normal:=Vector2(GradePlex.frente(int(volume.rotacao)))
	var lado:=Vector2(normal.y,-normal.x)
	var centro: Vector3=(volume.a+volume.b)*.5
	var delta:=Vector2(b.x-a.x,b.y-a.y)
	var divisor:=delta.dot(normal)
	if absf(divisor)<.000001: return false
	var t: float=Vector2(centro.x-a.x,centro.y-a.y).dot(normal)/divisor
	if t<=maxf(entrada,.00001) or t>=minf(saida,.99999): return false
	var q:=a.lerp(b,t)
	var lateral:=Vector2(q.x-centro.x,q.y-centro.y).dot(lado)
	var x:=floori(lateral*32.0+LARGURA*.5)
	var y:=ALTURA-1-roundi(q.z-volume.a.z)
	if x<0 or x>=LARGURA or y<0 or y>=ALTURA: return false
	var indice:=int(volume.mascara)
	var origem:=Vector2i(indice%COLUNAS*LARGURA,floori(float(indice)/COLUNAS)*ALTURA)
	return imagem.get_pixelv(origem+Vector2i(x,y)).r>.5



static func perfil_cadeira(item:Dictionary) -> int:
	garantir()
	var tipo:=MobiliaPlex.visual(item);var estado:=MobiliaPlex.estado(item);var rotacao:=int(item.rotacao)
	var chave:="encosto:"+tipo+":"+estado+":"+str(rotacao)
	if perfis.has(chave):return int(perfis[chave])
	if perfis.size()>=COLUNAS*COLUNAS:return -1
	var altura:float=MobiliaPlex.dados(item).get("altura",37);var base:=altura*.48
	var volume:=GeometriaPlex.obter(tipo,rotacao,4,0,false,estado)
	var normal:=Vector2(GradePlex.frente(rotacao));var lado:=Vector2(normal.y,-normal.x)
	var indice:=perfis.size();var origem:=Vector2i(indice%COLUNAS*LARGURA,floori(float(indice)/COLUNAS)*ALTURA);var total:=0
	for p in volume.pontos:
		var z:float=(p.z-2.0*p.y)/3.0
		if z<base or z>altura+1:continue
		var local:=GradePlex.inverter_local(Vector2(p.x,p.y+z))
		if local.dot(normal)>-.12:continue
		var x:=roundi(local.dot(lado)*32.0)+(LARGURA>>1);var y:=ALTURA-1-roundi(z-base)
		if x>=0 and x<LARGURA and y>=0 and y<ALTURA:imagem.set_pixelv(origem+Vector2i(x,y),Color.WHITE);total+=1
	if total==0:return -1
	perfis[chave]=indice;textura.update(imagem);return indice
