class_name ChaoPlex
extends Node2D
const CORES=["original","creme","grafite","vinho"]
const PASSO=8
var planta:PlantaPlex
var recortes:Dictionary={}
var blocos:Dictionary={}
var assinaturas:Dictionary={}
var visao:=-1
var espera:=0.0
class Bloco extends Node2D:
	var piso:ChaoPlex
	var celulas:Array[Vector2i]=[]
	func _draw() -> void:
		for c in celulas:piso.desenhar_tile(self,c)
func desenhar_em(alvo:Node2D,textura:Texture2D,posicao:Vector2) -> void:
	if not SilhuetasPlex.valida(textura):return
	var id:=textura.get_instance_id()
	if not recortes.has(id):
		var imagem:=SilhuetasPlex.imagem(textura)
		if imagem==null:return
		recortes[id]=imagem.get_used_rect()
	var r:=Rect2(recortes[id]);alvo.draw_texture_rect_region(textura,Rect2(posicao+r.position,r.size),r)
func desenhar_tile(alvo:Node2D,c:Vector2i) -> void:
	if planta.bairro_ativo and not TerrenoPlex.contem(planta,c):return
	var p:=GradePlex.projetar(Vector2(c));var soleira:=SoleirasPisoPlex.obter(planta,c)
	if soleira!=null:desenhar_em(alvo,soleira,p-Vector2(96,144));return
	if planta.pisos.has(c):
		var tipo:String=planta.pisos[c];var r:=PinturaPisosPlex.rotacao_visual(tipo,int(planta.rotacoes_pisos.get(c,0)))
		var origem:=Vector2(-96,-144)
		if AssetsSistemasPlex.eh(tipo):
			var v:=AssetsSistemasPlex.obter(tipo,r);origem=Vector2(v.origin[0],v.origin[1])
		desenhar_em(alvo,CatalogoPlex.sprite(tipo,r),p+origem);return
	var cor:int=planta.cores.get(c,0)
	var caminho:String="res://assets/objetos/chao/sprites/frente.png" if cor==0 else "res://assets/objetos/chao/sprites/cores/"+CORES[cor]+".png"
	desenhar_em(alvo,CatalogoPlex.textura(caminho),p-Vector2(96,144))
func _draw() -> void:
	if planta==null:return
	for by in range(0,GradePlex.TAMANHO.y,PASSO):
		for bx in range(0,GradePlex.TAMANHO.x,PASSO):
			var chave:=Vector2i(bx,by);var dados:Array=[GradePlex.visao,planta.bairro_ativo,TerrenoPlex.area(planta)];var locais:Array[Vector2i]=[]
			for y in range(by,mini(by+PASSO,GradePlex.TAMANHO.y)):
				for x in range(bx,mini(bx+PASSO,GradePlex.TAMANHO.x)):
					var c:=Vector2i(x,y);locais.append(c);var o:Dictionary=planta.em(c)
					dados.append([planta.pisos.get(c,""),planta.rotacoes_pisos.get(c,0),planta.cores.get(c,0),o.get("tipo","") if o.get("tipo","") in CatalogoPlex.PORTAS else "",o.get("rotacao",0)])
			var assinatura:=hash(dados)
			if not blocos.has(chave):
				var b:=Bloco.new();b.piso=self;b.use_parent_material=true;add_child(b);blocos[chave]=b
			if assinaturas.get(chave,-1)==assinatura:continue
			locais.sort_custom(func(a,b):return GradePlex.projetar(Vector2(a)).y<GradePlex.projetar(Vector2(b)).y)
			blocos[chave].celulas=locais;blocos[chave].queue_redraw();assinaturas[chave]=assinatura
	visao=GradePlex.visao
	_process(.16)
func _process(delta:float) -> void:
	if planta==null:return
	if visao!=GradePlex.visao:queue_redraw()
	espera+=delta
	if espera<.15:return
	espera=0
	var inversa:=get_canvas_transform().affine_inverse();var tela:=get_viewport_rect();var a:=inversa*tela.position;var z:=inversa*tela.end;var ret:=Rect2(a,z-a).abs().grow(128)
	for chave in blocos:
		var pontos:=PackedVector2Array()
		for c in [Vector2(chave),Vector2(chave)+Vector2(PASSO,0),Vector2(chave)+Vector2(0,PASSO),Vector2(chave)+Vector2(PASSO,PASSO)]:pontos.append(GradePlex.projetar(c))
		var limite:=Rect2(pontos[0],Vector2.ZERO)
		for p in pontos:limite=limite.expand(p)
		blocos[chave].visible=ret.intersects(limite.grow(40))
