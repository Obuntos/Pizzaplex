class_name SombrasEstruturasPlex
extends RefCounted
const LIMITE=2048
var planta: PlantaPlex
var dados_cidade: Dictionary={}
var revisao:=-1
var assinatura:=0
var assinatura_externa:=0
var celulas: Dictionary={}
var volumes: Array[Dictionary]=[]
var colunas: Dictionary={}
var indices: ImageTexture
var indices_extra: ImageTexture
var minimos: ImageTexture
var maximos: ImageTexture
func _init(p: PlantaPlex, dados: Dictionary={}) -> void:
	planta=p
	dados_cidade=dados
	indices=ImageTexture.create_from_image(Image.create_empty(GradePlex.TAMANHO.x,GradePlex.TAMANHO.y,false,Image.FORMAT_RGBAF))
	indices_extra=ImageTexture.create_from_image(Image.create_empty(GradePlex.TAMANHO.x,GradePlex.TAMANHO.y,false,Image.FORMAT_RGBAF))
	minimos=ImageTexture.create_from_image(Image.create_empty(LIMITE,1,false,Image.FORMAT_RGBAF))
	maximos=ImageTexture.create_from_image(Image.create_empty(LIMITE,1,false,Image.FORMAT_RGBAF))
func adicionar(a: Vector3, b: Vector3, elipse: bool=false, mascara: int=-1, rotacao: int=0) -> void:
	if volumes.size()>=LIMITE-1: return
	if b.x-a.x<.01 or b.y-a.y<.01 or b.z-a.z<.2: return
	var coluna:=str([roundi(a.x*1000),roundi(a.y*1000),roundi(b.x*1000),roundi(b.y*1000)])
	if not elipse and mascara<0:
		for anterior in colunas.get(coluna,[]):
			var v: Dictionary=volumes[anterior-1]
			if int(v.get("mascara",-1))<0 and not v.elipse and a.z<=v.b.z+.01 and b.z>=v.a.z-.01:
				v.a.z=minf(v.a.z,a.z);v.b.z=maxf(v.b.z,b.z)
				return
	volumes.append({"a":a,"b":b,"elipse":elipse,"mascara":mascara,"rotacao":rotacao})
	var id:=volumes.size()
	if not colunas.has(coluna): colunas[coluna]=[]
	colunas[coluna].append(id)
	for y in range(maxi(0,floori(a.y+.5)),mini(GradePlex.TAMANHO.y,ceili(b.y+.5))):
		for x in range(maxi(0,floori(a.x+.5)),mini(GradePlex.TAMANHO.x,ceili(b.x+.5))):
			var c:=Vector2i(x,y)
			if not celulas.has(c): celulas[c]=[]
			if celulas[c].size()<8: celulas[c].append(id)
func limites(registro: Dictionary, margem: float=.12) -> Rect2:
	var tamanho:=Vector2(CatalogoPlex.dimensoes(registro.tipo,registro.rotacao))
	return Rect2(Vector2(registro.celula)-Vector2(.5,.5)+Vector2.ONE*margem,tamanho-Vector2.ONE*margem*2.0)
func ponto_cidade(item: Dictionary, local: Vector2) -> Vector2:
	var tamanho:=Vector2(CatalogoPlex.dimensoes(item.tipo,item.rotacao))
	return Vector2(item.celula)+(tamanho-Vector2.ONE)*.5+GradePlex.girar(local-Vector2(5,5),item.rotacao)
func caixa(area: Rect2, baixo: float, alto: float, elipse: bool=false) -> void:
	adicionar(Vector3(area.position.x,area.position.y,baixo),Vector3(area.end.x,area.end.y,alto),elipse)
func objeto(item: Dictionary) -> void:
	var info:=MobiliaPlex.dados(item)
	var tipo:=str(item.tipo)
	if SombrasItensPlex.elegivel(item):return
	if tipo in SalasPlex.ESTRUTURA or tipo in ["palco","escada","ponto_recebimento","suporte"] or ManchasPlex.eh(tipo) or planta.sobreposto(tipo) or info.get("piso",false): return
	if tipo.begins_with("caixa") and int(item.get("carregada_por",0))>0: return
	if ApoiosPlex.portador(planta,item.id)>0: return
	if RecortesSombraPlex.eh(item):
		var indice:=RecortesSombraPlex.perfil(item)
		if indice<0: return
		var apoio_recorte:=ApoiosPlex.posicao(planta,item)
		var normal:=Vector2(GradePlex.frente(item.rotacao))
		var lateral:=Vector2(normal.y,-normal.x)
		var tamanho:=lateral.abs()*2.0+normal.abs()*.032
		var centro:=Vector2(apoio_recorte.x,apoio_recorte.y)
		adicionar(Vector3(centro.x-tamanho.x*.5,centro.y-tamanho.y*.5,apoio_recorte.z),Vector3(centro.x+tamanho.x*.5,centro.y+tamanho.y*.5,apoio_recorte.z+RecortesSombraPlex.ALTURA),false,indice,item.rotacao)
		return
	var escala:=ItensPlex.escala(tipo)
	var altura:=maxf(0.0,float(info.get("altura",0.0)))*escala
	if ItensPlex.personalizado(tipo): altura=ItensPlex.altura(tipo)
	if altura<2.0: return
	var area:=limites(item)
	if not is_equal_approx(escala,1.0):
		var centro:=area.get_center()
		area.size*=escala;area.position=centro-area.size*.5
	if info.get("bairro",false):
		if SombrasObjetosPlex.cidade(self,item,area): return
		if area.size.x>=9.0 and area.size.y>=9.0:
			var config: Dictionary=dados_cidade.get("casas",{}).get(tipo,{})
			var volume: Array=config.get("volume",[1.0,1.0,9.0,8.4])
			var a:=ponto_cidade(item,Vector2(volume[0],volume[1]))
			var b:=ponto_cidade(item,Vector2(volume[2],volume[3]))
			area=Rect2(Vector2(minf(a.x,b.x),minf(a.y,b.y)),Vector2(absf(b.x-a.x),absf(b.y-a.y)))
			caixa(area,0.0,altura)
		elif tipo.contains("poste"):
			caixa(Rect2(Vector2(item.celula)-Vector2(.045,.045),Vector2(.09,.09)),0,altura-5)
		elif sombra_natural(item,area,altura): pass
		else: caixa(area,0.0,altura,tipo.contains("flor") or tipo.contains("arbusto"))
		return
	var apoio:=ApoiosPlex.posicao(planta,item)
	area.position+=Vector2(apoio.x,apoio.y)-(Vector2(item.celula)+(Vector2(CatalogoPlex.dimensoes(tipo,item.rotacao))-Vector2.ONE)*.5)
	var z:=apoio.z
	if SombrasObjetosPlex.bancada_montagem(self,item,apoio):return
	if ApoiosPlex.decoracao_mesa(tipo) and not tipo.contains("papelao") and not tipo.begins_with("presente_"):
		var centro_decoracao:=Vector2(apoio.x,apoio.y)
		caixa(Rect2(centro_decoracao-Vector2(.13,.13),Vector2(.26,.26)),z,z+altura*.35)
		caixa(Rect2(centro_decoracao-Vector2(.26,.26),Vector2(.52,.52)),z+altura*.25,z+altura,true)
		return
	if EstudosPlex.eh_mesa(tipo):
		caixa(area,z+altura*.72,z+altura*.84)
		for lado in [-1.0,1.0]:
			var pe:=area.get_center()+Vector2(lado*.45,0)
			caixa(Rect2(pe-Vector2(.08,.08),Vector2(.16,.16)),z,z+altura*.75)
		return
	if tipo.begins_with("festa_baloes"):
		caixa(Rect2(Vector2(apoio.x,apoio.y)-Vector2(.16,.16),Vector2(.32,.32)),z+altura*.70,z+altura,true)
		return
	if SombrasObjetosPlex.carga(self,item,apoio): return
	if SombrasObjetosPlex.armario(self,item,apoio): return
	if LugaresPlex.mesa(tipo) or CatalogoPlex.base(tipo) in ["bancada","balcao"] or tipo.contains("banco"):
		caixa(area,z+maxf(2.0,altura-5.0),z+altura)
		for x in [0.0,1.0]:
			for y in [0.0,1.0]:
				var pe:=area.position+Vector2(lerpf(.05,maxf(.05,area.size.x-.13),x),lerpf(.05,maxf(.05,area.size.y-.13),y))
				caixa(Rect2(pe,Vector2(.08,.08)),z,z+altura-4)
	elif CatalogoPlex.base(tipo)=="cadeira":
		caixa(area,z+altura*.44,z+altura*.53)
		for x in [0.0,1.0]:
			for y in [0.0,1.0]:
				var pe:=area.position+Vector2(lerpf(.03,maxf(.03,area.size.x-.10),x),lerpf(.03,maxf(.03,area.size.y-.10),y))
				caixa(Rect2(pe,Vector2(.07,.07)),z,z+altura*.48)
		var frente:=Vector2(GradePlex.frente(item.rotacao))
		var centro:=area.get_center()-frente*(area.size.x*.42)
		var tamanho:=Vector2(area.size.x,.1) if absf(frente.y)>.5 else Vector2(.1,area.size.y)
		var mascara:=RecortesSombraPlex.perfil_cadeira(item)
		if mascara>=0:adicionar(Vector3(centro.x-tamanho.x*.5,centro.y-tamanho.y*.5,z+altura*.48),Vector3(centro.x+tamanho.x*.5,centro.y+tamanho.y*.5,z+altura),false,mascara,item.rotacao)
		else:caixa(Rect2(centro-tamanho*.5,tamanho),z+altura*.5,z+altura)
	else: caixa(area,z,z+altura)
func sombra_natural(item: Dictionary, area: Rect2, altura: float) -> bool:
	var tipo:=str(item.tipo)
	var centro:=area.get_center()
	if tipo.contains("folhas_no_chao"): return true
	if tipo.contains("arvore"):
		caixa(Rect2(centro-Vector2(.055,.055),Vector2(.11,.11)),0,altura*.78)
		if tipo.contains("seca"):
			caixa(Rect2(centro-Vector2(.28,.035),Vector2(.56,.07)),altura*.52,altura*.66)
			caixa(Rect2(centro-Vector2(.035,.23),Vector2(.07,.46)),altura*.64,altura*.77)
		elif tipo.contains("pinheiro"):
			for nivel in 3:
				var largura:=area.size*(1.0-float(nivel)*.26)
				caixa(Rect2(centro-largura*.5,largura),altura*(.25+float(nivel)*.19),altura*(.66+float(nivel)*.16),true)
		else: caixa(area,altura*.4,altura,true)
		return true
	var tamanho:=Vector2.ZERO
	var alto:=altura
	if tipo.contains("grama"): tamanho=Vector2(.18,.18);alto=minf(altura,14.0)
	elif tipo.contains("pedra_pequena"): tamanho=Vector2(.24,.23);alto=minf(altura,8.0)
	elif tipo.contains("pedra_grande"): tamanho=Vector2(.57,.5);alto=minf(altura,24.0)
	elif tipo.contains("tronco"):
		tamanho=Vector2(.72,.24) if int(item.rotacao)%2==0 else Vector2(.24,.72)
		alto=minf(altura,12.0)
	elif tipo.contains("arbusto"): tamanho=Vector2(.5,.48);alto=minf(altura,24.0)
	if tamanho==Vector2.ZERO: return false
	caixa(Rect2(centro-tamanho*.5,tamanho),0,alto,true)
	return true
func atualizar() -> bool:
	if revisao==planta.revisao: return false
	revisao=planta.revisao
	var registros: Array=[GradePlex.visao]
	var externos: Array=[]
	for item in planta.objetos.values():
		if item.tipo in SalasPlex.ESTRUTURA: continue
		var registro: Array=[item.id,item.tipo,item.celula,item.rotacao,item.get("sobre",-1),item.get("slot",-1),item.get("carregada_por",0),item.get("carregada",false),item.get("variante","")]
		if RecortesSombraPlex.eh(item) or MobiliaPlex.visual(item).contains("armario") or MobiliaPlex.visual(item).begins_with("lixeira"): registro.append(MobiliaPlex.estado(item))
		registros.append(registro)
		if not TerrenoPlex.contem(planta,item.celula): externos.append(registro)
	var atual:=hash(registros)
	if atual==assinatura: return false
	assinatura=atual
	assinatura_externa=hash(externos)
	volumes.clear();celulas.clear();colunas.clear()
	for item in planta.objetos.values(): objeto(item)
	var mapa:=Image.create_empty(GradePlex.TAMANHO.x,GradePlex.TAMANHO.y,false,Image.FORMAT_RGBAF)
	var mapa_extra:=Image.create_empty(GradePlex.TAMANHO.x,GradePlex.TAMANHO.y,false,Image.FORMAT_RGBAF)
	var baixos:=Image.create_empty(LIMITE,1,false,Image.FORMAT_RGBAF)
	var altos:=Image.create_empty(LIMITE,1,false,Image.FORMAT_RGBAF)
	for c in celulas:
		var ids: Array=celulas[c].duplicate()
		while ids.size()<8: ids.append(0)
		mapa.set_pixelv(c,Color(ids[0],ids[1],ids[2],ids[3]))
		mapa_extra.set_pixelv(c,Color(ids[4],ids[5],ids[6],ids[7]))
	for i in volumes.size():
		var v: Dictionary=volumes[i]
		baixos.set_pixel(i+1,0,Color(v.a.x,v.a.y,v.a.z,2.0+v.mascara if int(v.mascara)>=0 else 1.0 if v.elipse else 0.0))
		altos.set_pixel(i+1,0,Color(v.b.x,v.b.y,v.b.z,float(v.rotacao)))
	indices.update(mapa);indices_extra.update(mapa_extra);minimos.update(baixos);maximos.update(altos)
	return true
func aplicar(mat: ShaderMaterial) -> void:
	RecortesSombraPlex.garantir()
	mat.set_shader_parameter("silhuetas_estruturas",RecortesSombraPlex.textura)
	mat.set_shader_parameter("indices_estruturas",indices)
	mat.set_shader_parameter("indices_estruturas_extra",indices_extra)
	mat.set_shader_parameter("minimos_estruturas",minimos)
	mat.set_shader_parameter("maximos_estruturas",maximos)
func visivel(a: Vector3, b: Vector3) -> bool:
	var delta:=Vector2(b.x-a.x,b.y-a.y)
	var passo:=Vector2i(int(signf(delta.x)),int(signf(delta.y)))
	var origem:=Vector2(a.x,a.y)+Vector2(.5,.5)
	var c:=Vector2i(origem.floor())
	var incremento:=Vector2(1e20 if passo.x==0 else absf(1.0/delta.x),1e20 if passo.y==0 else absf(1.0/delta.y))
	var limite:=Vector2(c)+Vector2(1 if passo.x>0 else 0,1 if passo.y>0 else 0)
	var t:=Vector2(1e20 if passo.x==0 else absf(limite.x-origem.x)*incremento.x,1e20 if passo.y==0 else absf(limite.y-origem.y)*incremento.y)
	var vistos: Dictionary={}
	for trecho in GradePlex.TAMANHO.x+GradePlex.TAMANHO.y+4:
		for id in celulas.get(c,[]):
			if vistos.has(id): continue
			vistos[id]=true
			var v: Dictionary=volumes[id-1]
			if a.x>=v.a.x-.035 and a.x<=v.b.x+.035 and a.y>=v.a.y-.035 and a.y<=v.b.y+.035 and a.z>=v.a.z-1.5 and a.z<=v.b.z+1.5: continue
			if int(v.get("mascara",-1))>=0:
				if RecortesSombraPlex.intersecao(v,a,b): return false
			elif v.elipse:
				var raio: Vector3=(v.b-v.a)*.5
				var inicio: Vector3=(a-(v.a+v.b)*.5)/raio
				var direcao: Vector3=(b-a)/raio
				var aa:=direcao.length_squared()
				var bb:=inicio.dot(direcao)
				var cc:=inicio.length_squared()-1.0
				var d:=bb*bb-aa*cc
				if d>=0.0 and aa>.000001 and maxf(0.0,(-bb-sqrt(d))/aa)<minf(1.0,(-bb+sqrt(d))/aa)-.000001: return false
			elif OclusaoPlex.raio_caixa(a,b,v.a,v.b,0.0,1.0): return false
		if minf(t.x,t.y)>=1.0: return true
		if absf(t.x-t.y)<.000001: c+=passo;t+=incremento
		elif t.x<t.y: c.x+=passo.x;t.x+=incremento.x
		else: c.y+=passo.y;t.y+=incremento.y
	return true
