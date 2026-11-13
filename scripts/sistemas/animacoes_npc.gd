class_name AnimacoesNpcPlex
extends RefCounted

const PASTA:="res://assets/personagens/animacoes_npc/"
const TIPOS={"humano":"adulto_masculino","humana":"adulto_feminino","adolescente":"adolescente_masculino","adolescente_feminina":"adolescente_feminino","crianca":"crianca"}
const EXPRESSOES={"em_pe_chorando":"triste","deitada_encolhida":"pavor","sentada_maos_orelhas":"medo","sentada_tampando_olhos":"medo","sentada_mao_boca":"medo","apontar_rindo":"muito_feliz","rindo":"muito_feliz","rindo_mao_barriga":"muito_feliz","bater_palmas":"feliz","pular_bracos_cima":"muito_feliz","correr_fugindo":"feliz","correr_pegador":"feliz","andar_balao":"feliz","comer_pizza":"feliz","comer_bolo":"feliz"}
static var dados:Dictionary={}
static var centros:Dictionary={}
static var roupas:Dictionary={}
var jogo:Node
var ativos:Dictionary={}

func _init(cena:Node) -> void:jogo=cena

static func carregar() -> void:
	if dados.is_empty():dados=JSON.parse_string(FileAccess.get_file_as_string("res://dados/animacoes_npc.json"))

func tipo(a:PersonagemPlex) -> String:return str(TIPOS.get(a.modelo,""))

func grupo(a:PersonagemPlex,nome:String) -> String:
	var t:=tipo(a)
	for g in dados.grupos:
		if dados.grupos[g].has(t) and dados.grupos[g][t].has(nome):return str(g)
	return ""

func ciclo(a:PersonagemPlex,periodo:float) -> float:return fposmod(a.relogio+float(posmod(a.identificador,13)),periodo)

func escolher(a:PersonagemPlex) -> String:
	if a.robo or a.visita.get("morto",false) or a.visita.get("em_ataque",false) or tipo(a).is_empty() or a.em_degraus or a.carregando or a.carga_item>=0:return ""
	var t:=tipo(a)
	var andando:=a.ocupado()
	if t=="crianca":
		if andando:
			if a.trabalho=="brincar_grupo" and a.visita.get("correndo",false):return "correr_pegador" if a.visita.get("pegador",false) else "correr_fugindo"
			if a.visita.get("balao_comprado",false):return "andar_balao"
			return ""
		var medo:=float(a.visita.get("medo",0.0))
		if medo>=3.0:return "deitada_encolhida"
		if a.trabalho=="perdida":return "em_pe_chorando"
		if a.visita.get("paralisado",false) or medo>=2.0:return ["sentada_maos_orelhas","sentada_tampando_olhos","sentada_mao_boca"][posmod(a.identificador,3)]
		if a.trabalho in ["assistir","assistir_mascote"]:
			var c:=ciclo(a,12.0)
			return "pular_bracos_cima" if c<3.0 else "bater_palmas" if c<6.0 else "rindo_mao_barriga" if c<8.0 else ""
		return ""
	if andando:return ""
	if t.begins_with("adulto"):
		if a.trabalho=="estudar" and a.assento>=0:return "estudar"
		if a.trabalho=="vigiar_ibm" and a.assento>=0:return "sentado_ibm"
		if a.trabalho in ["montar","reparar"]:return ["consertar_chave_fenda","consertar_martelo","consertar_fita"][posmod(a.identificador,3)]
		if a.trabalho=="preparar":return "cozinhar"
		if a.trabalho=="lavar":return "lavar_pratos"
		if a.trabalho=="usar_caixa":return "mexer_caixa"
	if t.begins_with("adolescente"):
		if a.trabalho=="jogar":return "jogar_fliperama"
		if a.trabalho=="conversar" or a.visita.get("socializando",false):return "conversar_"+str(posmod(a.identificador,4)+1)
		if a.trabalho in ["assistir","assistir_mascote"]:
			var c:=ciclo(a,12.0)
			return "bater_palmas" if c<3.0 else "apontar_rindo" if c<5.0 else ""
		return ""
	if a.trabalho in ["assistir","assistir_mascote"]:
		var c:=ciclo(a,12.0)
		return "bater_palmas" if c<3.0 else "rindo" if c<5.0 else ""
	return ""

static func arquivo_roupa(a:PersonagemPlex) -> String:
	return AparenciaPlex.vestir(a,"res://assets/personagens/"+a.modelo+"/parado_corpo.png")

static func cor_dominante(imagem:Image,rect:Rect2i) -> Color:
	PelePlex.carregar()
	var pele:Dictionary=PelePlex.dados.mapas.get("branco",{})
	var contagem:={};var total_pele:=0
	for y in range(rect.position.y,rect.end.y):
		for x in range(rect.position.x,rect.end.x):
			if x<0 or y<0 or x>=imagem.get_width() or y>=imagem.get_height():continue
			var c:=imagem.get_pixel(x,y)
			if c.a<.5 or c.get_luminance()<.1:continue
			var hexa:=c.to_html(false)
			if pele.has(hexa):total_pele+=1;continue
			contagem[hexa]=int(contagem.get(hexa,0))+1
	var soma:=0;var melhor:="";var maior:=0
	for hexa in contagem:
		soma+=int(contagem[hexa])
		if int(contagem[hexa])>maior:maior=int(contagem[hexa]);melhor=str(hexa)
	if soma<4 or soma<total_pele:return Color(0,0,0,0)
	return Color("#"+melhor)

static func opaco(imagem:Image,x:int,y:int) -> bool:
	return x>=0 and x<48 and y>=0 and y<imagem.get_height() and imagem.get_pixel(x,y).a>.5

static func dados_manga(imagem:Image,r:Dictionary) -> Array:
	var pele:Dictionary=PelePlex.dados.mapas.get("branco",{})
	var frac:=0.0;var contagem:={}
	for chave in ["braco_e","braco_d"]:
		var b:Array=r[chave]
		var x0:=int(b[0]);var y0:=int(b[1]);var w:=int(b[2]);var h:=int(b[3])
		if w<=0 or h<=0:continue
		var fim:=-1
		for y in range(y0,y0+h):
			var tecido:=0;var nua:=0
			for x in range(x0,x0+w):
				var c:=imagem.get_pixel(x,y)
				if c.a<.5 or c.get_luminance()<.1:continue
				if pele.has(c.to_html(false)):nua+=1
				else:tecido+=1
			if tecido>0 and tecido>=nua:fim=y-y0
			else:break
		frac=maxf(frac,float(fim+1)/float(h))
		for y in range(y0,y0+fim+1):
			for x in range(x0,x0+w):
				var c:=imagem.get_pixel(x,y)
				if c.a<.5 or c.get_luminance()<.1 or pele.has(c.to_html(false)):continue
				var hexa:=c.to_html(false)
				contagem[hexa]=int(contagem.get(hexa,0))+1
	var melhor:="";var maior:=0
	for hexa in contagem:
		if int(contagem[hexa])>maior:maior=int(contagem[hexa]);melhor=str(hexa)
	return [1.0 if frac>=.9 else frac,Color("#"+melhor) if not melhor.is_empty() else Color(0,0,0,0)]

static func folha_saia(roupa:Image,nu:Image,t:String) -> ImageTexture:
	var saida:=Image.create_empty(48,480,false,Image.FORMAT_RGBA8)
	var tem:=false
	for d in 8:
		var q:Array=dados.retangulos[t][d].quadril
		var y0:=int(q[5])-3;var y1:=int(q[2])
		var excesso:={};var fortes:Array[Vector2i]=[];var a:=-1;var b:=-1
		for y in range(y0,y1+1):
			var forte:=false
			for x in 48:
				if opaco(roupa,x,d*60+y) and not opaco(nu,x,d*60+y):
					excesso[Vector2i(x,y)]=true
					if not opaco(nu,x-1,d*60+y) and not opaco(nu,x+1,d*60+y):forte=true;fortes.append(Vector2i(x,y))
			if forte:
				if a<0:a=y
				if b<0 or y-b<=2:b=y
		if a<0 or b-a<1:continue
		var fila:Array[Vector2i]=[]
		var visto:={}
		for p in fortes:
			if p.y>=a and p.y<=b:fila.append(p);visto[p]=true
		while not fila.is_empty():
			var atual:Vector2i=fila.pop_back()
			for dy in range(-1,2):
				for dx in range(-1,2):
					var n:=atual+Vector2i(dx,dy)
					if n.y>=a and n.y<=b and excesso.has(n) and not visto.has(n):visto[n]=true;fila.append(n)
		for chave in visto:
			var pos:Vector2i=chave
			saida.set_pixel(pos.x,d*60+pos.y,roupa.get_pixel(pos.x,d*60+pos.y));tem=true
	return ImageTexture.create_from_image(saida) if tem else null

static func dados_roupa(caminho:String,t:String,modelo:String) -> Dictionary:
	var chave:=caminho+":"+t
	if roupas.has(chave):return roupas[chave]
	PelePlex.carregar()
	var imagem:=CatalogoPlex.imagem(caminho)
	var nu:=CatalogoPlex.imagem("res://assets/personagens/"+modelo+"/parado_corpo.png")
	var r:Dictionary=dados.retangulos[t][0]
	var tronco:Array=r.tronco;var perna:Array=r.perna_e
	var manga:=dados_manga(imagem,r)
	var res:={"camisa":cor_dominante(imagem,Rect2i(int(tronco[0]),int(tronco[1]),int(tronco[2]),int(tronco[3]))),"calca":cor_dominante(imagem,Rect2i(int(perna[0]),int(perna[1]),int(perna[2]),int(perna[3]))),"manga":manga[1],"frac":manga[0],"saia":folha_saia(imagem,nu,t) if nu!=null else null}
	if roupas.size()>=64:roupas.erase(roupas.keys()[0])
	roupas[chave]=res
	return res

func material(a:PersonagemPlex,plano:float,altura:float,mascara:Texture2D,com_saia:bool=false) -> ShaderMaterial:
	var m:=ShaderMaterial.new()
	m.shader=preload("res://shaders/npc_roupa.gdshader")
	m.set_shader_parameter("profundidade_cena",jogo.composicao.profundidade)
	m.set_shader_parameter("origem",Vector2(CenaPlex.ORIGEM))
	m.set_shader_parameter("tamanho",Vector2(CenaPlex.TAMANHO))
	m.set_shader_parameter("plano",plano)
	m.set_shader_parameter("altura",altura)
	jogo.iluminacao.vincular(m)
	if a!=null:PelePlex.aplicar(m,PelePlex.de(a))
	if mascara!=null:
		m.set_shader_parameter("usar_mascara",true)
		m.set_shader_parameter("mascara",mascara)
		var caminho:=arquivo_roupa(a)
		if caminho!="res://assets/personagens/"+a.modelo+"/parado_corpo.png" and ResourceLoader.exists(caminho):
			var info:=dados_roupa(caminho,tipo(a),a.modelo)
			m.set_shader_parameter("usar_textura",true)
			m.set_shader_parameter("roupa",CatalogoPlex.textura(caminho))
			m.set_shader_parameter("camisa",info.camisa)
			m.set_shader_parameter("calca",info.calca)
			m.set_shader_parameter("manga",info.manga)
			m.set_shader_parameter("manga_frac",float(info.frac))
			if com_saia and info.saia!=null:
				m.set_shader_parameter("usar_saia",true)
				m.set_shader_parameter("saia",info.saia)
	return m

func ajustar_linha(m:ShaderMaterial,a:PersonagemPlex,d:int,plano:float) -> void:
	m.set_shader_parameter("plano",plano)
	if m.get_shader_parameter("usar_mascara")!=true:return
	var r:Dictionary=dados.retangulos[tipo(a)][d]
	m.set_shader_parameter("linha",d)
	for chave in ["tronco","perna_e","perna_d"]:
		var v:Array=r[chave]
		m.set_shader_parameter("rect_"+chave,Vector4(float(v[0]),float(v[1]),float(v[2]),float(v[3])))
	var q:Array=r.quadril
	m.set_shader_parameter("quadril_parado",Vector2(float(q[0]),float(q[1])))

static func centro_cabeca(arquivo:String,linha:int) -> Vector2:
	var chave:=arquivo+":"+str(linha)
	if not centros.has(chave):
		var imagem:=CatalogoPlex.imagem(arquivo)
		var usado:=imagem.get_region(Rect2i(0,linha*60,48,60)).get_used_rect() if imagem!=null else Rect2i()
		centros[chave]=Vector2(usado.position)+Vector2(usado.size)*.5 if usado.has_area() else Vector2(24,16)
	return centros[chave]

func sprite(textura:Texture2D,regiao:Rect2,posicao:Vector2,escala:Vector2,mat:ShaderMaterial) -> Sprite2D:
	var atlas:=AtlasTexture.new();atlas.atlas=textura;atlas.region=regiao
	var s:=Sprite2D.new();s.texture=atlas;s.centered=false;s.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	s.position=posicao;s.scale=escala;s.material=mat
	return s

func cabeca(a:PersonagemPlex,linha:int,expressao:String,mat:ShaderMaterial) -> Node2D:
	var no:=Node2D.new()
	var base:="res://assets/personagens/"+a.modelo+"/"
	var estilo:=AparenciaPlex.cabelo(a)
	var camadas:Array=[]
	var cabelo:={}
	EncaixeCabeloPlex.carregar()
	if estilo!="nenhum" and EncaixeCabeloPlex.dados.modelos.has(a.modelo):
		var centro:=centro_cabeca(base+"parado_cabeca.png",linha)
		var alvo:Array=EncaixeCabeloPlex.dados.modelos[a.modelo].parado[linha][0]
		var posicao:=centro-Vector2(float(alvo[0]),float(alvo[1])+8.0)
		var escala:=Vector2.ONE
		if not EncaixeCabeloPlex.ajustado(a.modelo,estilo):
			var adulto:="humana" if VariedadeAparenciaPlex.feminino(a) else "humano"
			var sexo:="feminino" if VariedadeAparenciaPlex.feminino(a) else "masculino"
			var referencias:Dictionary=EncaixeCabeloPlex.dados.fontes[sexo] if EncaixeCabeloPlex.dados.novos.has(estilo) else EncaixeCabeloPlex.dados.modelos[adulto]
			var fonte:Array=referencias.parado[linha][0]
			escala=Vector2(float(alvo[2])/maxf(1,float(fonte[2])),float(alvo[3])/maxf(1,float(fonte[3]))).clamp(Vector2(.7,.7),Vector2(1.15,1.15))
			posicao=centro-Vector2(float(fonte[0]),float(fonte[1])+8.0)*escala
		for nome in ["tras","frente"]:
			cabelo[nome]=sprite(CoresCabeloPlex.textura("res://assets/aparencias/cabelos/"+estilo+"/parado_"+nome+".png",CoresCabeloPlex.cor(a),a.modelo),Rect2(0,linha*68,48,68),posicao,escala,mat)
	if cabelo.has("tras"):camadas.append(cabelo.tras)
	camadas.append(sprite(CatalogoPlex.textura(base+"parado_cabeca.png"),Rect2(0,linha*60,48,60),Vector2.ZERO,Vector2.ONE,mat))
	if a.modelo in ["humano","humana"]:
		camadas.append(sprite(RostoPlex.textura(RostoPlex.olhos(str(a.visita.get("olhos","padrao"))),expressao),Rect2(0,linha*40,48,40),Vector2.ZERO,Vector2.ONE,mat))
	else:
		var opcao:=AnimacaoPlex.expressao_disponivel(a.modelo,expressao)
		for parte in ["olhos","boca"]:
			camadas.append(sprite(CatalogoPlex.textura(base+opcao+"_"+parte+".png"),Rect2(0,linha*60,48,60),Vector2.ZERO,Vector2.ONE,mat))
	if cabelo.has("frente"):camadas.append(cabelo.frente)
	var uniforme:=AparenciaPlex.roupa(a)
	var chapeu:="res://assets/aparencias/uniformes/"+uniforme+"/chapeu.png"
	if uniforme!="nenhum" and ResourceLoader.exists(chapeu):camadas.append(sprite(CatalogoPlex.textura(chapeu),Rect2(0,linha*80,48,80),Vector2(0,-20),Vector2.ONE,mat))
	for s in camadas:no.add_child(s)
	return no

func ponto(a:PersonagemPlex) -> Vector2:
	var assento:Dictionary=jogo.planta.objetos.get(a.assento,{}) if a.assento>=0 else {}
	var local:Vector2=Vector2(assento.celula) if not assento.is_empty() else a.local
	return GradePlex.projetar(local,jogo.planta.altura(Vector2i(local.round())))

func montar(a:PersonagemPlex,nome:String) -> Dictionary:
	var g:=grupo(a,nome);var t:=tipo(a)
	var info:Dictionary=dados.grupos[g][t][nome]
	var pasta:=PASTA+g+"/"+t+"/"+nome+"/"
	var pivo:=Node2D.new();jogo.mundo.add_child(pivo)
	pivo.position=ponto(a)
	var altura:float=jogo.planta.altura(a.celula)+4.0
	var no:=Node2D.new();no.scale=a.animacao.scale;pivo.add_child(no)
	var mascara:=CatalogoPlex.textura(pasta+"mascara.png")
	var mat_corpo:=material(a,pivo.position.y,altura,mascara,true)
	var mat_frente:=material(a,pivo.position.y,altura,mascara)
	var mat_simples:=material(a,pivo.position.y,altura,null)
	for camada in ["corpo","cabeca","objeto","frente"]:
		if camada=="cabeca":
			var cab:=Node2D.new();cab.name="cabeca";no.add_child(cab);continue
		if not camada in info.camadas:continue
		var s:=sprite(CatalogoPlex.textura(pasta+camada+".png"),Rect2(0,0,48,60),Vector2(-24,-55),Vector2.ONE,mat_corpo if camada=="corpo" else mat_frente if camada=="frente" else mat_simples)
		s.name=camada;no.add_child(s)
	return {"nome":nome,"grupo":g,"tipo":t,"info":info,"pivo":pivo,"no":no,"tempo":0.0,"fase":"inicio","mat":mat_corpo,"frente":mat_frente,"simples":mat_simples}

func quadro_atual(e:Dictionary) -> int:
	var info:Dictionary=e.info;var fps:=float(info.fps)
	var n:=floori(float(e.tempo)*fps)
	match str(e.fase):
		"inicio":return int(info.inicio[0])+n
		"loop":
			var tamanho:=maxi(1,int(info.loop[1])-int(info.loop[0]))
			return int(info.loop[0])+posmod(n,tamanho)
		_:return int(info.fim[0])+n

func desenhar(a:PersonagemPlex,e:Dictionary) -> void:
	var d:=GradePlex.direcao_visual(a.direcao)
	var q:=clampi(quadro_atual(e),0,int(e.info.quadros)-1)
	e.pivo.position=ponto(a)
	var plano:float=e.pivo.position.y+(24.0 if a.assento>=0 else 0.0)
	ajustar_linha(e.mat,a,d,plano);ajustar_linha(e.frente,a,d,plano);ajustar_linha(e.simples,a,d,plano)
	var quadris:Array=dados.quadris[e.grupo][e.tipo][e.nome][d]
	var qa:Array=quadris[mini(q,quadris.size()-1)]
	for mat in [e.mat,e.frente]:
		(mat as ShaderMaterial).set_shader_parameter("celula",Vector2(float(q*48),float(d*60)))
		(mat as ShaderMaterial).set_shader_parameter("quadril",Vector3(float(qa[0]),float(qa[1]),float(qa[2])))
	for filho in e.no.get_children():
		if filho is Sprite2D:((filho as Sprite2D).texture as AtlasTexture).region=Rect2(q*48,d*60,48,60)
	var lista:Array=dados.cabecas[e.grupo][e.tipo][e.nome][d]
	var dado:Array=lista[mini(q,lista.size()-1)]
	var chave:=str(dado)+":"+str(d)
	var cab:Node2D=e.no.get_node("cabeca")
	if str(cab.get_meta("dado",""))==chave:return
	cab.set_meta("dado",chave)
	for filho in cab.get_children():filho.queue_free()
	var n0:Array=dados.pescoco[e.tipo]
	var pivo_cab:=Node2D.new()
	pivo_cab.position=Vector2(float(n0[0])+float(dado[2])-24.0,float(n0[1])+float(dado[3])-55.0)
	pivo_cab.rotation=-float(dado[1])*PI*.5
	var montada:=cabeca(a,int(dado[0]),str(EXPRESSOES.get(e.nome,"neutro")),e.simples)
	montada.position=Vector2(-float(n0[0]),-float(n0[1]))
	pivo_cab.add_child(montada);cab.add_child(pivo_cab)

func soltar(a:PersonagemPlex) -> void:
	var e:Dictionary=ativos.get(a.identificador,{})
	if not e.is_empty() and is_instance_valid(e.pivo):e.pivo.queue_free()
	ativos.erase(a.identificador)
	if is_instance_valid(a):a.visita.erase("em_animacao")

func atualizar(delta:float) -> void:
	carregar()
	for a in jogo.personagens:
		if not TIPOS.has(a.modelo):continue
		var desejada:=escolher(a)
		if not desejada.is_empty() and grupo(a,desejada).is_empty():desejada=""
		var e:Dictionary=ativos.get(a.identificador,{})
		if e.is_empty():
			a.visita.erase("em_animacao")
			if desejada.is_empty():continue
			e=montar(a,desejada);ativos[a.identificador]=e;a.visita.em_animacao=desejada
		e.tempo=float(e.tempo)+delta
		var fps:=float(e.info.fps)
		match str(e.fase):
			"inicio":
				if desejada!=e.nome:e.fase="fim";e.tempo=0.0
				elif e.tempo*fps>=float(int(e.info.inicio[1])-int(e.info.inicio[0])):e.fase="loop";e.tempo=0.0
			"loop":
				if desejada!=e.nome:e.fase="fim";e.tempo=0.0
			"fim":
				if e.tempo*fps>=float(int(e.info.fim[1])-int(e.info.fim[0])):
					soltar(a)
					if not desejada.is_empty():
						e=montar(a,desejada);ativos[a.identificador]=e;a.visita.em_animacao=desejada
					else:continue
		desenhar(a,e)
	for id in ativos.keys():
		var a:PersonagemPlex=jogo.clientes.ator(int(id))
		if not is_instance_valid(a) or not jogo.personagens.has(a):
			var e:Dictionary=ativos[id]
			if is_instance_valid(e.pivo):e.pivo.queue_free()
			ativos.erase(id)
