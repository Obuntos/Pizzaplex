class_name PreparacaoRecursosPlex
extends RefCounted

var fila: Array[String]=[]
var geometrias:Array=[]
var secundarios: Array[String]=[]
var finalizados_no_quadro:=0
var ativos: Array[String]=[]
var conhecidos: Dictionary={}
var prontos:=0
var total:=0
var falhas: Array[String]=[]
var recursos: Dictionary={}
var ordem_recursos: Array[String]=[]
var bytes_recursos:=0
const LIMITE_RECURSOS=256*1024*1024

func _init() -> void:
	TexturasPosesPlex.carregador=self

func guardar(caminho: String, recurso: Texture2D) -> void:
	var tamanho:=int(recurso.get_width()*recurso.get_height())*4
	if recursos.has(caminho):
		var existente: Texture2D=recursos[caminho]
		bytes_recursos-=existente.get_width()*existente.get_height()*4
		ordem_recursos.erase(caminho)
	while not ordem_recursos.is_empty() and bytes_recursos+tamanho>LIMITE_RECURSOS:
		var antigo: String=ordem_recursos.pop_front()
		var anterior: Texture2D=recursos[antigo]
		bytes_recursos-=int(anterior.get_width()*anterior.get_height())*4
		recursos.erase(antigo)
	if tamanho>LIMITE_RECURSOS: return
	recursos[caminho]=recurso
	ordem_recursos.append(caminho)
	bytes_recursos+=tamanho

func iluminada(caminho: String) -> void:
	adicionar(caminho)
	var normal:=caminho.replace("res://assets/personagens/","res://assets/iluminacao/personagens/").replace("res://assets/aparencias/","res://assets/iluminacao/aparencias/").replace("res://assets/sistemas/","res://assets/iluminacao/sistemas/")
	adicionar(normal)
	adicionar(normal.replace(".png","_material.png"))

func adicionar(caminho: String) -> void:
	if fila.has(caminho) or ativos.has(caminho) or CatalogoPlex.texturas.has(caminho) or ResourceLoader.has_cached(caminho) or not ResourceLoader.exists(caminho): return
	conhecidos[caminho]=true
	fila.append(caminho)
	total+=1

func personagem(a: PersonagemPlex) -> void:
	if AtracoesCatalogoPlex.permitido(a.modelo):
		for acao in ["parado","andar","desligado"]:
			for direcao in 8:
				var quadro:=ClipesPlex.quadro(a.modelo,acao,direcao,0,0)
				iluminada(quadro.arquivo)
		return
	if AparenciaPlex.permitida(a):
		var estilo:=AparenciaPlex.cabelo(a)
		if estilo!="nenhum":
			for acao in ["parado","andar"]:
				for lado in ["frente","tras"]:iluminada("res://assets/aparencias/cabelos/"+estilo+"/"+acao+"_"+lado+".png")
		adicionar("res://assets/aparencias/uniformes/"+AparenciaPlex.roupa(a)+"/chapeu.png")
	elif ProfissoesBairroPlex.eh(a.modelo):
		for lado in ["frente","tras"]:iluminada("res://assets/aparencias/cabelos/curto/parado_"+lado+".png")
	if a.modelo in ["fantasia_coelho"]:
		for acao in ["parado","andar","segurar_prato","levar_prato","segurar_dois_pratos","levar_dois_pratos","segurar_item","levar_item","segurar_dois_itens","levar_dois_itens","carregar_faca","levar_faca","matar","carregar","segurar_caixa","levar_caixa","varrer","levar_vassoura"]:
			iluminada("res://assets/personagens/"+a.modelo+("/ancoras_3/" if a.modelo=="fantasia_coelho" else "/")+acao+".png")
		return
	if CatalogoPlex.personagens.get(a.modelo,{}).get("layered",false) and a.modelo not in ["humano","humana"]:
		var origem:="res://assets/personagens/"+a.modelo+"/"
		for acao in ["parado","andar","jogar","assistir"]:
			for parte in ["corpo","cabeca"]: iluminada(origem+acao+"_"+parte+".png")
		for parte in ["olhos","boca"]: iluminada(origem+"neutro_"+parte+".png")
		return
	if a.cargo in ["cliente","morador"] and a.modelo in ["humano","humana"]:
		var origem:=RoupasVisitantesPlex.pasta(a)
		for acao in ["parado","andar","sentar"]: iluminada(origem+"/"+acao+"_corpo.png")
		for acao in ["parado","andar"]: iluminada("res://assets/personagens/"+a.modelo+"/"+acao+"_cabeca.png")
		return
	if a.modelo in ["humano","humana"]:
		var uniforme:=AparenciaPlex.roupa(a)
		PosesHumanasPlex.carregar()
		if not PosesHumanasPlex.dados.uniformes.has(uniforme): uniforme="nenhum"
		var pasta:="res://assets/poses_humanas/"+uniforme+"/"+a.modelo+"/"
		var acoes: Array=["parado","andar"]
		var funcoes:=EquipePlex.prioridades(a)
		if funcoes.has("estoque") or funcoes.has("manutencao"): acoes.append("carregar")
		if funcoes.has("manutencao"): acoes.append("montar")
		if funcoes.has("cozinha"): acoes.append_array(["preparar","lavar"])
		if funcoes.has("atendimento"): acoes.append_array(["levar_prato","segurar_prato"])
		if funcoes.has("limpeza"): acoes.append_array(["levar_vassoura","varrer","levar_balde","esfregar"])
		if a.funcao=="seguranca": acoes.append("segurar_lanterna")
		var essenciais: Array=["parado","andar"]
		if funcoes.has("limpeza"): essenciais.append_array(["levar_vassoura","varrer"])
		elif funcoes.has("cozinha"): essenciais.append("preparar")
		elif funcoes.has("atendimento"): essenciais.append("levar_prato")
		for acao in acoes:
			for parte in ["corpo","bracos","maos"]:
				var caminho: String=pasta+acao+"_"+parte+".png"
				for arquivo in [caminho,TexturasPosesPlex.mapa(caminho),TexturasPosesPlex.mapa(caminho,true)]:
					if acao in ["parado","andar"]: adicionar(arquivo)
					elif not secundarios.has(arquivo): secundarios.append(arquivo)
	else:
		ClipesPlex.carregar()
		var clipes: Dictionary=ClipesPlex.modelos.get(a.modelo,{}).get("clipes",{})
		for acao in ["parado","andar","cantar","dancar","desligado"]:
			if clipes.has(acao):
				for d in 8:
					if acao in ["cantar","dancar","desligado"] and d!=GradePlex.direcao_visual(a.direcao): continue
					iluminada(str(clipes[acao].pasta)+"/"+str(d)+".png")
			else: iluminada("res://assets/personagens/"+a.modelo+"/"+acao+".png")

func cenario(planta:PlantaPlex) -> void:
	if not planta.objetos.values().any(func(o):return str(o.tipo)=="sistema_camera_parede"):return
	if AssetsSistemasPlex.volumes.is_empty():AssetsSistemasPlex.volumes=JSON.parse_string(FileAccess.get_file_as_string("res://dados/sistemas_volumes.json"))
	for o in planta.objetos.values():
		if str(o.tipo)!="sistema_camera_parede":continue
		var r:=GradePlex.rotacao_visual(int(o.rotacao))
		for i in 13:
			var estado:="ativa_"+str(i);var chave:="sistema_camera_parede:"+str(r)+":"+estado
			if conhecidos.has("volume:"+chave) or AssetsSistemasPlex.cache.has(chave):continue
			conhecidos["volume:"+chave]=true;geometrias.append({"tipo":"sistema_camera_parede","rotacao":r,"estado":estado});total+=1
			adicionar(str(AssetsSistemasPlex.volumes[chave].image))

func solicitar() -> void:
	while ativos.size()<4 and not fila.is_empty():
		var caminho: String=fila.pop_front()
		if CatalogoPlex.texturas.has(caminho) or ResourceLoader.has_cached(caminho): prontos+=1; continue
		var erro:=ResourceLoader.load_threaded_request(caminho)
		if erro==OK: ativos.append(caminho)
		else:
			falhas.append(caminho)
			prontos+=1

func atualizar(em_jogo: bool=false) -> void:
	var inicio:=Time.get_ticks_usec()
	finalizados_no_quadro=0
	if em_jogo and fila.size()<8:
		for i in mini(2,secundarios.size()):adicionar(secundarios.pop_front())
	solicitar()
	for caminho in ativos.duplicate():
		var estado:=ResourceLoader.load_threaded_get_status(caminho)
		if estado==ResourceLoader.THREAD_LOAD_IN_PROGRESS: continue
		if estado==ResourceLoader.THREAD_LOAD_LOADED:
			var recurso:=ResourceLoader.load_threaded_get(caminho)
			if recurso is Texture2D: guardar(caminho,recurso)
		else:
			falhas.append(caminho)
		ativos.erase(caminho)
		prontos+=1
		finalizados_no_quadro+=1
		if finalizados_no_quadro>=(2 if em_jogo else 6) or em_jogo and Time.get_ticks_usec()-inicio>1800: break

	for i in mini(2,geometrias.size()):
		var g:Dictionary=geometrias[0];var chave:=str(g.tipo)+":"+str(g.rotacao)+":"+str(g.estado);var caminho:String=AssetsSistemasPlex.volumes[chave].image
		if falhas.has(caminho):geometrias.pop_front();prontos+=1;continue
		if not ResourceLoader.has_cached(caminho) or ResourceLoader.load_threaded_get_status(caminho)==ResourceLoader.THREAD_LOAD_IN_PROGRESS:break
		geometrias.pop_front();AssetsSistemasPlex.obter(g.tipo,g.rotacao,g.estado);prontos+=1
		if em_jogo and Time.get_ticks_usec()-inicio>1800:break

func concluida() -> bool:
	return fila.is_empty() and ativos.is_empty() and geometrias.is_empty()

func progresso() -> float:
	return float(prontos)/maxf(1.0,total)

