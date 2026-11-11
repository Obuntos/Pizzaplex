class_name UsoFantasiaUrsoPlex
extends RefCounted

static var dados: Dictionary={}
static var mascaras: Dictionary={}
static var escadas_recentes: Array[String]=[]

static func carregar(modelo: String) -> Dictionary:
	if not dados.has(modelo): dados[modelo]=JSON.parse_string(FileAccess.get_file_as_string("res://dados/"+modelo+".json"))
	return dados[modelo]

static func categoria(item: Dictionary) -> String:
	var tipo:=str(item.get("tipo",""))
	if tipo=="dinheiro": return "dinheiro"
	if tipo in ["copo_bebida","guarana_copo","guarana_tampa"]: return "item"
	var valor:=ItensPlex.categoria(tipo)
	return valor if valor in ["prato","caixa","balde","vassoura"] else "prato" if tipo.begins_with("festa_bolo") else "item"

static func ancora_compativel(ancora: Array, item: Dictionary) -> bool:
	match str(ancora[4]):
		"box": return categoria(item)=="caixa" and CaixasVisuaisPlex.eh(str(item.get("tipo","")))
		"plate": return categoria(item)=="prato"
		"soda": return str(item.get("tipo","")) in ["copo_bebida","guarana_copo","guarana_tampa"]
		"broom": return str(item.get("tipo",""))=="vassoura"
	return false

static func acao(ator: PersonagemPlex, andando: bool) -> String:
	if ator.visita.get("faca_equipada",false) and ator.visita.get("controle_manual",false):
		return "matar" if ator.trabalho=="montar" and ator.visita.get("gesto_manual","")=="atacar" else "levar_faca" if andando else "carregar_faca"
	if int(ator.visita.get("corpo_carregado",-1))>0: return "carregar"
	var item: Dictionary=ator.planta_visual.objetos.get(ator.carga_item,{}) if ator.planta_visual!=null else {}
	var trabalho:=ator.trabalho
	if trabalho=="reparar": trabalho="montar"
	if trabalho in ["descartar_prato","depositar_dinheiro"]: return "colocar"
	if trabalho=="animar_visitantes" and not andando and not ator.ocupado(): return "falar"
	if not andando and trabalho in ["preparar","lavar","varrer","esfregar","usar_caixa","montar","colocar"]: return trabalho
	if item.is_empty() and ator.carregando: return "carregar"
	if not item.is_empty():
		var tipo:=categoria(item)
		if not ator.carga_extra.is_empty():
			if tipo=="prato": tipo="dois_pratos"
			elif tipo=="item": tipo="dois_itens"
		return ("levar_" if andando else "segurar_")+tipo
	if ator.assento>=0 and trabalho in ["sentar_mesa","sentar_banco","descansar","aguardar_vestiario","caixa_sentado"]: return "sentar"
	return "andar" if andando else "parado"

static func quadro(ator: PersonagemPlex, movimento: String) -> int:
	var total:=int(carregar(ator.modelo).get("frames",12))
	if movimento=="matar": return clampi(floori(ator.progresso_acao*total),0,total-1)
	return posmod(floori((ator.fase if movimento.begins_with("levar_") or movimento in ["andar","carregar"] else ator.relogio/(9.0 if movimento in ["varrer","esfregar","segurar_vassoura","falar"] else 2.5))*total),total)

static func registro(ator: PersonagemPlex, movimento: String) -> Dictionary:
	var pose:=carregar(ator.modelo)
	if ator.em_degraus:
		var escala:=ator.movimento.escala
		var variante:=movimento if pose.get("escadas",{}).get(escala.sentido,{}).has(movimento) else "carregar" if ator.carregando else "andar"
		var trilha: Array=pose.get("escadas",{}).get(escala.sentido,{}).get(variante,[])
		if not trilha.is_empty():
			var r:=GradePlex.rotacao_visual(escala.rotacao)
			return trilha[r][clampi(escala.quadro,0,trilha[r].size()-1)]
	var d:=GradePlex.direcao_visual(ator.direcao)
	var f:=quadro(ator,movimento)
	return {"maos":pose.poses.get(movimento,pose.poses.parado)[d][f],"itens":pose.get("itens",{}).get(movimento,pose.get("itens",{}).get("parado",[]))[d][f]}

static func ponto(ator: PersonagemPlex, movimento: String, lado: int=-1) -> Vector3:
	var maos: Array=registro(ator,movimento).maos
	var p:=Vector3.ZERO
	if lado>=0:
		var v: Array=maos[lado]
		p=Vector3(v[0],v[1],v[2])
	else:
		for v in maos: p+=Vector3(v[0],v[1],v[2])*.5
	return p*Vector3(ator.animacao.scale.x,ator.animacao.scale.y,ator.animacao.scale.y)

static func limitar_escadas(caminho: String) -> void:
	escadas_recentes.erase(caminho);escadas_recentes.append(caminho)
	while escadas_recentes.size()>8:
		var anterior: String=escadas_recentes.pop_front()
		var normal:=anterior.replace("/personagens/","/iluminacao/personagens/")
		var dedos:=anterior.replace(".png","_dedos.png")
		for arquivo in [anterior,normal,normal.replace(".png","_material.png"),dedos]:
			CatalogoPlex.texturas.erase(arquivo);CatalogoPlex.texturas.erase("iluminada:"+arquivo);CatalogoPlex.imagens.erase(arquivo)
		mascaras.erase(dedos)

static func escada(ator: PersonagemPlex, movimento: String) -> void:
	var escala:=ator.movimento.escala
	var pose:=carregar(ator.modelo)
	var variante:=movimento if pose.get("escadas",{}).get(escala.sentido,{}).has(movimento) else "carregar" if ator.carregando else "andar"
	var caminho: String="res://assets/personagens/"+ator.modelo+"/escadas_autorais_4/"+escala.sentido+"_"+variante+"/"+CatalogoPlex.DIRECOES[GradePlex.rotacao_visual(escala.rotacao)]+".png"
	if not ResourceLoader.exists(caminho): return
	limitar_escadas(caminho)
	ator.animacao.atlases.modelo.atlas=CatalogoPlex.textura_iluminada(caminho)
	ator.animacao.arquivos.modelo=caminho
	ator.animacao.atlases.modelo.region=Rect2((escala.quadro%16)*64,floori(float(escala.quadro)/16)*100,64,100)

static func carga(manuseio: ManuseioPlex, ator: PersonagemPlex, planta: PlantaPlex, id: int, extra: bool, virtual: Dictionary={}) -> void:
	var item: Dictionary=virtual if not virtual.is_empty() else planta.objetos.get(id,{})
	if item.is_empty(): return
	var sprite:=manuseio.objeto_extra if extra else manuseio.objeto
	var mat:=manuseio.uniforme_extra if extra else manuseio.uniforme
	var componentes: Array=[]
	if virtual.is_empty(): manuseio.componentes(planta,id,ApoiosPlex.posicao(planta,item),componentes)
	else: componentes.append({"volume":EncaixeCargaPlex.volume_carga(str(item.tipo),0),"posicao":Vector3.ZERO})
	var tipo:=categoria(item)
	var lado:=1 if ator.carga_extra.is_empty() else 1 if extra else 0
	var ancora: Array=registro(ator,manuseio.movimento).itens[lado]
	var nativa:=ancora_compativel(ancora,item)
	var chave:=str(componentes.map(func(c): return [c.volume.image,c.posicao,c.volume.get("origin",[])]))+str(id)
	if nativa: chave+=str([ator.animacao.scale,GradePlex.direcao_visual(ator.direcao),ancora[4],ancora[5] if str(ancora[4])=="broom" else ancora[5].get("size",{})])
	if (manuseio.assinatura_extra if extra else manuseio.assinatura)!=chave:
		if extra: manuseio.assinatura_extra=chave
		else: manuseio.assinatura=chave
		var imagem:=AncorasFantasiaPlex.compor(componentes,ancora,ator.animacao.scale,GradePlex.direcao_visual(ator.direcao),str(item.tipo)) if nativa else ItensPlex.compor(componentes)
		sprite.texture=imagem.textura
		sprite.set_meta("limites_fantasia",imagem.textura.get_image().get_used_rect())
		mat.set_shader_parameter("profundidade_item",imagem.profundidade)
		mat.set_shader_parameter("superficies_item",imagem.normais)
	var origem:=ponto(ator,manuseio.movimento,-1 if tipo=="caixa" else lado)
	if nativa:
		origem=Vector3(ancora[0]*ator.animacao.scale.x,ancora[1]*ator.animacao.scale.y,ancora[2]*ator.animacao.scale.y)
	elif item.tipo=="saco_lixo" or tipo=="caixa": origem-=EncaixeCargaPlex.encaixe(item.tipo,GradePlex.rotacao_visual(int(item.rotacao)),str(item.get("estado","")))
	elif tipo=="balde": origem-=Vector3(0,-5,ItensPlex.altura(str(item.tipo))*.85)
	elif tipo=="vassoura": origem-=Vector3(0,-25,25)
	var atras: bool=GradePlex.direcao_visual(ator.direcao) in [3,4,5] if str(ancora[4]) in ["box","broom"] else GradePlex.direcao_visual(ator.direcao) in [3,4,5] and absf(float(ancora[0]))<14.0
	sprite.set_meta("ordem_fantasia",-1 if atras else 6)
	sprite.show();sprite.scale=Vector2.ONE
	EncaixeCargaPlex.aplicar(sprite,mat,ator,origem)

static func atualizar(manuseio: ManuseioPlex, ator: PersonagemPlex, planta: PlantaPlex, andando: bool) -> void:
	manuseio.maos.hide();manuseio.pernas.hide();manuseio.objeto.hide();manuseio.objeto_extra.hide();manuseio.integrado=true
	var mat:=ator.material as ShaderMaterial
	if mat!=null: mat.set_shader_parameter("usar_bracos",false)
	manuseio.movimento=acao(ator,andando)
	if ator.em_degraus and ator.modelo=="fantasia_coelho": escada(ator,manuseio.movimento)
	if not ator.em_degraus and not str(ator.animacao.arquivos.get("modelo","")).ends_with("/"+manuseio.movimento+".png"): manuseio.hide();return
	manuseio.carga_apoiada=true
	manuseio.carga_na_frente=GradePlex.direcao_visual(ator.direcao) not in [3,4,5]
	if planta==null: manuseio.hide();return
	var item: Dictionary=planta.objetos.get(ator.carga_item,{})
	var virtual: Dictionary={}
	if item.is_empty() and ator.carregando:
		virtual={"tipo":ator.caixa_tipo,"id":-1,"rotacao":0}
		item=virtual
	if item.is_empty(): manuseio.hide();return
	manuseio.show();manuseio.integrado=false
	carga(manuseio,ator,planta,ator.carga_item,false,virtual)
	if not ator.carga_extra.is_empty(): carga(manuseio,ator,planta,ator.carga_extra[0],true)
