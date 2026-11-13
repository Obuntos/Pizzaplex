class_name AnimacoesNpcPlex
extends RefCounted

const PASTA:="res://assets/personagens/animacoes_npc/"
const TIPOS={"humano":"adulto_masculino","humana":"adulto_feminino","adolescente":"adolescente_masculino","adolescente_feminina":"adolescente_feminino","crianca":"crianca"}
const EXPRESSOES={"em_pe_chorando":"triste","deitada_encolhida":"pavor","sentada_maos_orelhas":"medo","sentada_tampando_olhos":"medo","sentada_mao_boca":"medo","apontar_rindo":"muito_feliz","rindo":"muito_feliz","rindo_mao_barriga":"muito_feliz","bater_palmas":"feliz","pular_bracos_cima":"muito_feliz","correr_fugindo":"feliz","correr_pegador":"feliz","andar_balao":"feliz","comer_pizza":"feliz","comer_bolo":"feliz"}
static var dados:Dictionary={}
var jogo:Node
var ativos:Dictionary={}

func _init(cena:Node) -> void:jogo=cena

static func carregar() -> void:
	if dados.is_empty():dados=JSON.parse_string(FileAccess.get_file_as_string("res://dados/animacoes_npc.json"))

func tipo(a:PersonagemPlex) -> String:return str(TIPOS.get(a.modelo,""))

func grupo(a:PersonagemPlex,nome:String) -> String:
	var t:=tipo(a)
	for g in ["funcionarios","adultos_npc","adolescentes","criancas"]:
		if dados.grupos.has(g) and dados.grupos[g].has(t) and dados.grupos[g][t].has(nome):
			if g=="funcionarios" and a.cargo!="funcionario":continue
			if g=="adultos_npc" and a.cargo=="funcionario" and dados.grupos.get("funcionarios",{}).get(t,{}).has(nome):continue
			return g
	return ""

func ciclo(a:PersonagemPlex,periodo:float) -> float:return fposmod(a.relogio+float(posmod(a.identificador,13)),periodo)

func acao_servico(a:PersonagemPlex) -> String:
	var t:Dictionary=jogo.servicos.trabalhos.get(a.identificador,{})
	var passos:Array=t.get("passos",[])
	var i:=int(t.get("indice",0))
	return str(passos[i].get("acao","")) if i>=0 and i<passos.size() and passos[i] is Dictionary else ""

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
	if a.cargo=="funcionario":
		if a.trabalho=="estudar":return "estudar"
		if a.trabalho=="montar" and (a.visita.get("obra_atracao",false) or a.visita.get("oficina_trabalho",false)):
			return ["consertar_chave_fenda","consertar_martelo","consertar_fita"][floori(ciclo(a,18.0)/6.0)]
		if a.trabalho=="montar" and acao_servico(a)=="desembalar":return "desempacotar_caixa"
		if a.trabalho=="preparar":return "cozinhar"
		if a.trabalho=="lavar":return "lavar_pratos"
		if a.trabalho in ["caixa","usar_caixa"]:return "mexer_caixa"
		if a.trabalho=="vigiar_ibm":return "sentado_ibm"
		return ""
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

func faixas(a:PersonagemPlex) -> Array:
	var f:Dictionary=dados.faixas.get(tipo(a),{})
	var lista:Array=[]
	for nome in ["camisa","calca","sapato"]:
		if f.has(nome):lista.append([nome]+f[nome])
	return lista

func montar(a:PersonagemPlex,nome:String) -> Dictionary:
	var g:=grupo(a,nome);var t:=tipo(a)
	var info:Dictionary=dados.grupos[g][t][nome]
	var pasta:=PASTA+g+"/"+t+"/"+nome+"/"
	var roupa:=AtaquesOrelhitasPlex.cores_roupa(a,faixas(a))
	for chave in roupa.keys():roupa[chave]=Color(roupa[chave],1.0)
	var pivo:=Node2D.new();jogo.mundo.add_child(pivo)
	pivo.position=GradePlex.projetar(a.local,jogo.planta.altura(a.celula))
	var altura:=jogo.planta.altura(a.celula)+4.0
	var ataques:AtaquesOrelhitasPlex=jogo.sistemas.ataques
	var no:=Node2D.new();no.scale=a.animacao.scale;pivo.add_child(no)
	var mat_corpo:=ataques.material(pivo.position.y,altura,CatalogoPlex.textura(pasta+"mascara.png"),a,roupa,false)
	for camada in ["corpo","cabeca","objeto","frente"]:
		if camada=="cabeca":
			var cab:=Node2D.new();cab.name="cabeca";no.add_child(cab);continue
		if not camada in info.camadas:continue
		var s:=ataques.folha(pasta+camada+".png",48,60,mat_corpo if camada!="objeto" else ataques.material(pivo.position.y,altura,null,null,{},false),Vector2(-24,-55),Vector2.ONE)
		s.name=camada;no.add_child(s)
	return {"nome":nome,"grupo":g,"tipo":t,"info":info,"pivo":pivo,"no":no,"tempo":0.0,"fase":"inicio","proximo":"","mat":mat_corpo,"altura":altura}

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
	e.pivo.position=GradePlex.projetar(a.local,jogo.planta.altura(a.celula))
	for filho in e.no.get_children():
		if filho is Sprite2D:
			(filho.texture as AtlasTexture).region=Rect2(q*48,d*60,48,60)
			(filho.material as ShaderMaterial).set_shader_parameter("plano",e.pivo.position.y)
	var lista:Array=dados.cabecas[e.grupo][e.tipo][e.nome][d]
	var dado:Array=lista[mini(q,lista.size()-1)]
	var chave:=str(dado)+":"+str(d)
	var cab:Node2D=e.no.get_node("cabeca")
	if str(cab.get_meta("dado",""))==chave:
		for filho in cab.get_children():
			for neto in filho.get_children():(neto.material as ShaderMaterial).set_shader_parameter("plano",e.pivo.position.y)
		return
	cab.set_meta("dado",chave)
	for filho in cab.get_children():filho.queue_free()
	var n0:Array=dados.pescoco[e.tipo]
	var pivo_cab:=Node2D.new()
	pivo_cab.position=Vector2(float(n0[0])+float(dado[2])-24.0,float(n0[1])+float(dado[3])-55.0)
	pivo_cab.rotation=-float(dado[1])*PI*.5
	var s:=Sprite2D.new()
	s.texture=AtaquesOrelhitasPlex.capturar_cabeca(a,int(dado[0]),str(EXPRESSOES.get(e.nome,"neutro")))
	s.centered=false;s.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	s.material=jogo.sistemas.ataques.material(e.pivo.position.y,float(e.altura),null,a,{},false)
	s.position=Vector2(-float(n0[0]),-8.0-float(n0[1]))
	pivo_cab.add_child(s);cab.add_child(pivo_cab)

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
				if desejada!=e.nome:e.fase="fim";e.tempo=0.0;e.proximo=desejada
				elif e.tempo*fps>=float(int(e.info.inicio[1])-int(e.info.inicio[0])):e.fase="loop";e.tempo=0.0
			"loop":
				if desejada!=e.nome:e.fase="fim";e.tempo=0.0;e.proximo=desejada
			"fim":
				if e.tempo*fps>=float(int(e.info.fim[1])-int(e.info.fim[0])):
					var proximo:=desejada
					soltar(a)
					if not proximo.is_empty():
						e=montar(a,proximo);ativos[a.identificador]=e;a.visita.em_animacao=proximo
					else:continue
		desenhar(a,e)
	for id in ativos.keys():
		var a:PersonagemPlex=jogo.clientes.ator(int(id))
		if not is_instance_valid(a) or not jogo.personagens.has(a):
			var e:Dictionary=ativos[id]
			if is_instance_valid(e.pivo):e.pivo.queue_free()
			ativos.erase(id)
