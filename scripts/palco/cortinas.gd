class_name CortinasPalcoPlex
extends RefCounted

var jogo: Node
var espera := 0.0
var ligacoes: Dictionary = {}
var fases: Dictionary = {}
var assinatura := 0
var palcos_ativos: Dictionary = {}

func _init(cena: Node) -> void:
	jogo = cena

func vincular() -> void:
	jogo.animatronicos.palcos.atualizar()
	var cortinas: Array = jogo.planta.objetos.values().filter(func(o): return CatalogoPlex.objetos[o.tipo].get("cortina", false))
	var atual := hash([jogo.animatronicos.palcos.assinatura, cortinas.map(func(o): return [o.id, o.celula, o.rotacao])])
	if atual == assinatura: return
	assinatura = atual
	ligacoes.clear()
	for o in cortinas:
		var frente := GradePlex.frente(o.rotacao)
		for c in jogo.planta.celulas(o.tipo, o.celula, o.rotacao):
			for distancia in range(7):
				var palco := int(jogo.animatronicos.palcos.grupos.get(c - frente * distancia, -1))
				if palco >= 0:
					ligacoes[o.id] = palco
					break
			if ligacoes.has(o.id): break
	for id in fases.keys():
		if not jogo.planta.objetos.has(id): fases.erase(id)

func atualizar(delta: float) -> void:
	espera += delta
	if espera < .1: return
	var tempo := espera
	espera = 0.0
	vincular()
	var palcos: Dictionary = {}
	for a in jogo.personagens:
		if not a.robo: continue
		var palco: int = jogo.animatronicos.palcos.da_pose(a.pose)
		if palco < 0: continue
		if not palcos.has(palco): palcos[palco] = []
		palcos[palco].append(a)
	palcos_ativos.clear()
	var apresentadores: Dictionary={}
	for palco in palcos:
		var robos: Array=palcos[palco]
		if robos.all(func(a): return not a.ocupado() and a.trabalho=="apresentar" and a.robotica.get("estado","")=="ligado" and not a.robotica.get("avariado",false) and not AnimatronicosPlex.pausado(a)):
			apresentadores[palco]=robos
	var humano: PersonagemPlex=jogo.fantasias.presenter()
	if is_instance_valid(humano) and humano.trabalho=="animar_visitantes":
		var palco:=int(jogo.animatronicos.palcos.grupos.get(humano.celula,-1))
		if palco>=0:
			if not apresentadores.has(palco): apresentadores[palco]=[]
			apresentadores[palco].append(humano)
	for palco in apresentadores: palcos_ativos[palco]=true
	jogo.iluminacao.circuito.palcos_ativos=palcos_ativos
	for id in ligacoes:
		var item: Dictionary = jogo.planta.objetos.get(id, {})
		if item.is_empty(): continue
		var artistas: Array=apresentadores.get(ligacoes[id],[])
		var abrir:=artistas.any(func(a): return encarando(jogo.planta,item,a))
		var inicial := float(str(item.estado).trim_prefix("abertura_").to_int()) / 8.0
		var fase := move_toward(float(fases.get(id, inicial)), 1.0 if abrir else 0.0, tempo / 1.6)
		fases[id] = fase
		item.estado = (["fechada","meia","aberta"][clampi(roundi(fase*2),0,2)] if CatalogoPlex.objetos[item.tipo].get("cortina_circo",false) else "abertura_" + str(clampi(roundi(fase * 8), 0, 8)))


static func ancora(planta:PlantaPlex,item:Dictionary) -> Vector3:
	var dimensao:=CatalogoPlex.dimensoes(item.tipo,item.rotacao)
	var centro:=Vector2(item.celula)+Vector2(dimensao-Vector2i.ONE)*.5
	var circo:=bool(CatalogoPlex.objetos[item.tipo].get("cortina_circo",false))
	if str(item.tipo).contains("quina"):
		var sentido:=1.0 if item.tipo=="cortina_quina_interna" else -1.0
		centro+=GradePlex.girar(Vector2.ONE*.5*sentido,int(item.rotacao))
	else:centro+=Vector2(GradePlex.frente(int(item.rotacao)))*(.5-(.635 if circo else 0.0))
	var altura:=planta.altura(item.celula)
	var frente_altura:=GradePlex.frente(int(item.rotacao))
	for local in planta.celulas(item.tipo,item.celula,item.rotacao):
		for vizinha in [local,local+frente_altura,local-frente_altura]:altura=maxf(altura,planta.altura(vizinha))
	return Vector3(centro.x,centro.y,altura if circo else altura-18.0)

static func encarando(planta: PlantaPlex, cortina: Dictionary, ator: PersonagemPlex) -> bool:
	var esperado:=GradePlex.direcao_suporte(int(cortina.rotacao))
	var frontal: int=[7,1,1,3,3,5,5,7][posmod(ator.direcao,8)]
	if frontal!=esperado: return false
	var centro:=ancora(planta,cortina)
	return (Vector2(centro.x,centro.y)-ator.local).dot(Vector2(GradePlex.frente(cortina.rotacao)))>=-.05

static func eh(tipo:String) -> bool:
	return tipo.begins_with("cortina_") or bool(CatalogoPlex.objetos.get(tipo,{}).get("cortina",false))

static func segmentos(planta:PlantaPlex,item:Dictionary) -> Array:
	var p:=ancora(planta,item);var centro:=Vector2(p.x,p.y)
	if CatalogoPlex.objetos[item.tipo].get("cortina_circo",false):centro+=Vector2(GradePlex.frente(int(item.rotacao)))*.635
	var u:=GradePlex.girar(Vector2.RIGHT,int(item.rotacao));var v:=GradePlex.girar(Vector2.DOWN,int(item.rotacao))
	if item.tipo=="cortina_quina_interna":return [PackedVector2Array([centro-u*.5,centro]),PackedVector2Array([centro-v*.5,centro])]
	if item.tipo=="cortina_quina_externa":return [PackedVector2Array([centro,centro+u*.5]),PackedVector2Array([centro,centro+v*.5])]
	var meia:=float(CatalogoPlex.objetos[item.tipo].get("largura",1))*.5
	return [PackedVector2Array([centro-u*meia,centro+u*meia])]

static func sobrepoe(novo:PackedVector2Array,antigo:PackedVector2Array) -> bool:
	var a:=novo[0];var b:=novo[1];var c:=antigo[0];var d:=antigo[1]
	if absf((b-a).cross(d-c))<.0001:
		if absf((b-a).normalized().cross(c-a))>.05:return false
		var eixo:=(b-a).normalized()
		return minf(maxf(a.dot(eixo),b.dot(eixo)),maxf(c.dot(eixo),d.dot(eixo)))-maxf(minf(a.dot(eixo),b.dot(eixo)),minf(c.dot(eixo),d.dot(eixo)))>.05
	var cruzamento:Variant=Geometry2D.segment_intersects_segment(a,b,c,d)
	if cruzamento==null:return false
	var p:Vector2=cruzamento
	return not ((p.distance_to(a)<=.05 or p.distance_to(b)<=.05) and (p.distance_to(c)<=.05 or p.distance_to(d)<=.05))

static func livre(planta:PlantaPlex,item:Dictionary) -> bool:
	var novos:=segmentos(planta,item)
	for outro in planta.objetos.values():
		if not eh(str(outro.tipo)) or int(outro.id)==int(item.get("id",-1)):continue
		for novo in novos:
			for antigo in segmentos(planta,outro):
				if sobrepoe(novo,antigo):return false
	return true

static func aparar(volume:Dictionary,tipo:String,rotacao:int) -> void:
	if not tipo.begins_with("cortina_"):return
	var pontos:=PackedVector3Array();var cores:=PackedColorArray();var faces:=PackedColorArray()
	var meia:=float(CatalogoPlex.objetos[tipo].get("largura",1))*.5
	for i in volume.pontos.size():
		var p:Vector3=volume.pontos[i];var z:float=(p.z-2.0*p.y)/3.0
		var local:=GradePlex.girar(GradePlex.inverter_local(Vector2(p.x,p.y+z)),-rotacao)
		if z>116.0:
			if tipo=="cortina_quina_interna" and (local.x<-.5 or local.y<-.5 or local.x>.065 or local.y>.065):continue
			if tipo=="cortina_quina_externa" and (local.x<-.065 or local.y<-.065 or local.x>.5 or local.y>.5):continue
			if not tipo.contains("quina") and absf(local.x)>meia:continue
		pontos.append(p);cores.append(volume.cores[i])
		if not volume.superficies.is_empty():faces.append(volume.superficies[i])
	volume.pontos=pontos;volume.cores=cores;volume.superficies=faces
	var imagem:=Image.create_empty(volume.textura.get_width(),volume.textura.get_height(),false,Image.FORMAT_RGBA8)
	for i in pontos.size():
		var pixel:=Vector2i(roundi(pontos[i].x)-int(volume.origin[0]),roundi(pontos[i].y)-int(volume.origin[1]))
		if Rect2i(Vector2i.ZERO,imagem.get_size()).has_point(pixel):imagem.set_pixelv(pixel,cores[i])
	volume.textura=ImageTexture.create_from_image(imagem)
