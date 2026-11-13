class_name AtaquesOrelhitasPlex
extends RefCounted

const VERSOES={"novo_coelho_detalhes":"normal","vi_toy_orelhitas":"toy","vi_orelhitas_quebrado":"quebrado","vi_toy_orelhitas_quebrado":"toyquebrado"}
const PASTA:="res://assets/sistemas/ataques/"
const ESCALA_HUMANO:=1.375
static var dados:Dictionary={}
var jogo:Node
var ativos:Array=[]
var corpos:Dictionary={}
var espera:=0.0

func _init(cena:Node) -> void:jogo=cena

static func carregar() -> void:
	if dados.is_empty():dados=JSON.parse_string(FileAccess.get_file_as_string("res://dados/ataques_orelhitas.json"))

static func sexo(v:PersonagemPlex) -> String:return "adulto_feminino" if v.modelo=="humana" else "adulto_masculino"

func suporta(r:PersonagemPlex,v:PersonagemPlex) -> bool:
	return VERSOES.has(r.modelo) and v.modelo in ["humano","humana"]

func material(plano:float,altura:float,mascara:Texture2D,v:PersonagemPlex,roupa:Dictionary,deitado:bool) -> ShaderMaterial:
	var m:=ShaderMaterial.new()
	m.shader=preload("res://shaders/ataque.gdshader")
	m.set_shader_parameter("profundidade_cena",jogo.composicao.profundidade)
	m.set_shader_parameter("origem",Vector2(CenaPlex.ORIGEM))
	m.set_shader_parameter("tamanho",Vector2(CenaPlex.TAMANHO))
	m.set_shader_parameter("plano",plano)
	m.set_shader_parameter("altura",altura)
	m.set_shader_parameter("deitado",deitado)
	jogo.iluminacao.vincular(m)
	if v!=null:PelePlex.aplicar(m,PelePlex.de(v))
	if mascara!=null:
		m.set_shader_parameter("usar_mascara",true)
		m.set_shader_parameter("mascara",mascara)
		for chave in ["camisa","calca","sapato"]:m.set_shader_parameter(chave,roupa.get(chave,Color(0,0,0,0)))
	return m

func folha(caminho:String,largura:int,altura_quadro:int,material_sprite:ShaderMaterial,posicao:Vector2,escala:Vector2) -> Sprite2D:
	var s:=Sprite2D.new()
	var atlas:=AtlasTexture.new()
	atlas.atlas=CatalogoPlex.textura(caminho)
	atlas.region=Rect2(0,0,largura,altura_quadro)
	s.texture=atlas;s.centered=false;s.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	s.material=material_sprite;s.position=posicao;s.scale=escala
	return s

static func cores_roupa(v:PersonagemPlex,faixas:Array=[["camisa",31,40,12,36],["calca",43,51,12,36],["sapato",52,56,12,36]]) -> Dictionary:
	var parado:=AparenciaPlex.vestir(v,"res://assets/personagens/"+v.modelo+"/parado_corpo.png")
	if not ResourceLoader.exists(parado):return {}
	var imagem:=CatalogoPlex.imagem(parado)
	if imagem==null or imagem.is_empty():return {}
	var tipo:=str(AnimacoesNpcPlex.TIPOS.get(v.modelo,""))
	if not tipo.is_empty() and parado!="res://assets/personagens/"+v.modelo+"/parado_corpo.png":
		AnimacoesNpcPlex.carregar()
		var info:=AnimacoesNpcPlex.dados_roupa(parado,tipo,v.modelo)
		var perna:Array=AnimacoesNpcPlex.dados.retangulos[tipo][0].perna_e
		var cores:={"camisa":info.camisa,"calca":info.calca,"sapato":AnimacoesNpcPlex.cor_dominante(imagem,Rect2i(int(perna[0])-5,int(perna[1])+int(perna[3])-4,int(perna[2])+10,4))}
		var saida:={}
		for chave in cores:
			if (cores[chave] as Color).a>.5:saida[chave]=cores[chave]
		if saida.size()==3:return saida
	PelePlex.carregar()
	var pele:Dictionary=PelePlex.dados.mapas.get("branco",{})
	var tons:Array[Color]=[]
	for hexa in pele:tons.append(Color("#"+str(hexa)))
	var resultado:={}
	for faixa in faixas:
		var contagem:={};var total_pele:=0
		for y in range(int(faixa[1]),int(faixa[2])):
			for x in range(int(faixa[3]),int(faixa[4])):
				if x>=imagem.get_width() or y>=imagem.get_height():continue
				var c:=imagem.get_pixel(x,y)
				if c.a<.5 or c.get_luminance()<.1:continue
				var hexa:=c.to_html(false)
				if pele.has(hexa) or tons.any(func(t:Color):return absf(t.r-c.r)+absf(t.g-c.g)+absf(t.b-c.b)<.12):total_pele+=1;continue
				contagem[hexa]=int(contagem.get(hexa,0))+1
		var ordem:Array=contagem.keys()
		ordem.sort_custom(func(x,y):return int(contagem[x])>int(contagem[y]))
		var melhor:=""
		for hexa in ordem.slice(0,3):
			if melhor.is_empty() or Color("#"+str(hexa)).get_luminance()>Color("#"+melhor).get_luminance():melhor=str(hexa)
		var soma:=0
		for hexa in contagem:soma+=int(contagem[hexa])
		if soma>=6 and soma>=total_pele:resultado[faixa[0]]=Color("#"+melhor)
	return resultado

func cabeca(v:PersonagemPlex,sx:String,dado:Array,material_cabeca:ShaderMaterial) -> Node2D:
	var n0:Array=dados.pescoco[sx]
	var pivo:=Node2D.new()
	pivo.position=Vector2(float(n0[0])+float(dado[2])-56.0,float(n0[1])+float(dado[3])-80.0)
	pivo.rotation=-float(dado[1])*PI*.5
	AnimacoesNpcPlex.carregar()
	var montada:Node2D=jogo.sistemas.npc.cabeca(v,int(dado[0]),"pavor",material_cabeca)
	montada.position=Vector2(32.0-float(n0[0]),25.0-float(n0[1]))
	pivo.add_child(montada)
	return pivo

func montar_humano(v:PersonagemPlex,versao:String,parte:String,linha:int,roupa:Dictionary,plano:float,altura:float,deitado:bool) -> Node2D:
	var sx:=sexo(v)
	var info:Dictionary=dados.ataques[versao]
	var pasta:=PASTA+versao+"/humano/"+sx+"/"+parte+"/"
	var mascara:=CatalogoPlex.textura(pasta+"mascara.png")
	var no:=Node2D.new();no.scale=Vector2.ONE*ESCALA_HUMANO
	var mat_corpo:=material(plano,altura,mascara,v,roupa,deitado)
	var camadas:Array=info.camadas_humano if parte=="ataque" else info.get("camadas_corpo",info.camadas_humano)
	for nome in ["corpo","cabeca","objeto","frente"]:
		if nome=="cabeca":
			var cab:=Node2D.new();cab.name="cabeca";no.add_child(cab)
			continue
		if not nome in camadas:continue
		var s:=folha(pasta+nome+".png",112,110,mat_corpo if nome!="objeto" else material(plano,altura,null,null,{},deitado),Vector2(-56,-80),Vector2.ONE)
		s.name=nome;no.add_child(s)
	no.set_meta("linha",linha);no.set_meta("sx",sx)
	return no

func trocar_quadro(no:Node2D,v:PersonagemPlex,versao:String,parte:String,quadro:int) -> void:
	var linha:=int(no.get_meta("linha"));var sx:=str(no.get_meta("sx"))
	for filho in no.get_children():
		if filho is Sprite2D:((filho as Sprite2D).texture as AtlasTexture).region=Rect2(quadro*112,linha*110,112,110)
	var lista:Array=dados.cabecas[versao][sx][parte][linha]
	var dado:Array=lista[mini(quadro,lista.size()-1)]
	var chave:=str(dado)
	var cab:Node2D=no.get_node("cabeca")
	if str(cab.get_meta("dado","")) ==chave:return
	cab.set_meta("dado",chave)
	for filho in cab.get_children():filho.queue_free()
	var corpo_sprite:Sprite2D=no.get_node_or_null("corpo")
	var mat_corpo:ShaderMaterial=corpo_sprite.material as ShaderMaterial if corpo_sprite!=null else null
	var mat:ShaderMaterial=material(float(mat_corpo.get_shader_parameter("plano")) if mat_corpo!=null else 0.0,float(mat_corpo.get_shader_parameter("altura")) if mat_corpo!=null else 4.0,null,v,{},parte=="corpo_no_chao")
	cab.add_child(cabeca(v,sx,dado,mat))

func iniciar(r:PersonagemPlex,v:PersonagemPlex,violencia:int) -> void:
	carregar()
	var versao:=str(VERSOES[r.modelo]);var info:Dictionary=dados.ataques[versao]
	var d:=GradePlex.direcao_visual(r.direcao);var linha:=posmod(d+4,8)
	var deslocamento:=Vector2(float(info.deslocamento[d][0]),float(info.deslocamento[d][1]))
	var roupa:=cores_roupa(v)
	for nome in ["camisa","calca","sapato"]:
		if roupa.has(nome):roupa[nome]=Color(roupa[nome],1.0)
	var pivo:=Node2D.new();jogo.mundo.add_child(pivo)
	pivo.position=GradePlex.projetar(r.local,r.altura)
	var altura:=r.altura+4.0
	var mat_robo:=material(pivo.position.y,altura,null,null,{},false)
	var longe:=folha(PASTA+versao+"/animatronico/longe.png",160,130,mat_robo,Vector2(-80*1.2,-92),Vector2(1.2,1.0))
	var resto:=folha(PASTA+versao+"/animatronico/resto.png",160,130,mat_robo,Vector2(-80*1.2,-92),Vector2(1.2,1.0))
	var humano:=montar_humano(v,versao,"ataque",linha,roupa,pivo.position.y+deslocamento.y,altura,false)
	humano.position=deslocamento
	var ordem:Array=[longe,resto,humano] if deslocamento.y>3.0 else [humano,longe,resto] if deslocamento.y<-3.0 else [longe,humano,resto]
	for no in ordem:pivo.add_child(no)
	v.movimento.cancelar();r.movimento.cancelar()
	v.visita.em_ataque=true;r.visita.em_ataque=true;v.visita.morto=true
	v.visible=false;v.set_meta("visivel_cena",false)
	v.local=r.local+GradePlex.inverter_vetor(deslocamento);v.celula=Vector2i(v.local.round())
	v.visita.morte_orelhitas={"versao":versao,"linha":linha,"camisa":roupa.get("camisa",Color(0,0,0,0)).to_html(),"calca":roupa.get("calca",Color(0,0,0,0)).to_html(),"sapato":roupa.get("sapato",Color(0,0,0,0)).to_html(),"roupa":roupa.keys()}
	ativos.append({"robo":r.identificador,"vitima":v.identificador,"versao":versao,"pivo":pivo,"longe":longe,"resto":resto,"humano":humano,"tempo":0.0,"violencia":violencia,"direcao":d})
	trocar_quadro(humano,v,versao,"ataque",0)

func encerrar(a:Dictionary) -> void:
	var r:PersonagemPlex=jogo.clientes.ator(int(a.robo))
	var v:PersonagemPlex=jogo.clientes.ator(int(a.vitima))
	if is_instance_valid(a.pivo):a.pivo.queue_free()
	if is_instance_valid(r):
		r.visita.erase("em_ataque")
		GorePlex.espalhar(jogo,v.celula if is_instance_valid(v) else r.celula,int(a.violencia),posmod(roundi(float(r.direcao)/2.0),4))
	if is_instance_valid(v):v.visita.erase("em_ataque")
	jogo.planta.alterada.emit()

static func roupa_salva(m:Dictionary) -> Dictionary:
	var r:={}
	for chave in m.get("roupa",[]):r[chave]=Color(str(m.get(chave,"00000000")))
	return r

func corpo(v:PersonagemPlex) -> Node2D:
	var m:Dictionary=v.visita.morte_orelhitas
	var pivo:=Node2D.new();jogo.mundo.add_child(pivo)
	pivo.position=GradePlex.projetar(v.local,v.altura)
	var no:=montar_humano(v,str(m.versao),"corpo_no_chao",int(m.linha),roupa_salva(m),pivo.position.y,v.altura+4.0,true)
	pivo.add_child(no)
	trocar_quadro(no,v,str(m.versao),"corpo_no_chao",0)
	pivo.set_meta("no",no);pivo.set_meta("visao",GradePlex.visao)
	return pivo

func atualizar(delta:float) -> void:
	if dados.is_empty() and ativos.is_empty() and corpos.is_empty():
		espera+=delta
		if espera<1.0:return
		espera=0.0
	carregar()
	for a in ativos.duplicate():
		a.tempo=float(a.tempo)+delta
		var info:Dictionary=dados.ataques[a.versao]
		var quadro:=floori(float(a.tempo)*float(dados.fps))
		if quadro>=int(info.quadros):
			ativos.erase(a);encerrar(a);continue
		var regiao:=Rect2(quadro*160,int(a.direcao)*130,160,130)
		(a.longe.texture as AtlasTexture).region=regiao;(a.resto.texture as AtlasTexture).region=regiao
		var v:PersonagemPlex=jogo.clientes.ator(int(a.vitima))
		if is_instance_valid(v):trocar_quadro(a.humano,v,a.versao,"ataque",quadro)
	var presentes:={}
	for v in jogo.personagens:
		if not v.visita.has("morte_orelhitas") or not v.visita.get("morto",false):
			if v.visita.get("em_ataque",false) and not ativos.any(func(a):return int(a.robo)==v.identificador or int(a.vitima)==v.identificador):v.visita.erase("em_ataque")
			continue
		if v.visita.get("em_ataque",false):
			if not ativos.any(func(a):return int(a.vitima)==v.identificador):v.visita.erase("em_ataque")
			else:continue
		if int(v.visita.get("carregado_por",-1))>0 or int(v.visita.get("oculto_em",-1))>0:continue
		presentes[v.identificador]=true
		var p:Node2D=corpos.get(v.identificador)
		if is_instance_valid(p) and int(p.get_meta("visao"))!=GradePlex.visao:p.queue_free();p=null
		if not is_instance_valid(p):p=corpo(v);corpos[v.identificador]=p
		p.position=GradePlex.projetar(v.local,v.altura)
	for id in corpos.keys():
		if not presentes.has(id):
			if is_instance_valid(corpos[id]):corpos[id].queue_free()
			corpos.erase(id)

func ocultar_padrao(a:PersonagemPlex) -> bool:
	return a.visita.has("morte_orelhitas") and int(a.visita.get("carregado_por",-1))<=0 and int(a.visita.get("oculto_em",-1))<=0
