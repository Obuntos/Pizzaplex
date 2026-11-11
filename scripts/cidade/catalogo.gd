class_name CatalogoCidadePlex
extends RefCounted

static var dados: Dictionary = {}
static var estado := "padrao"
static var neve := 0.0
static var versao := 0

static func carregar() -> void:
	CatalogoPlex.carregar()
	if dados.is_empty(): dados=JSON.parse_string(FileAccess.get_file_as_string("res://dados/cidade/assets.json"))
	for tipo in dados:
		if CatalogoPlex.objetos.has(tipo): continue
		var info: Dictionary=dados[tipo]
		var origens: Dictionary={}
		for r in 4: origens[CatalogoPlex.DIRECOES[r]]=info.sprites.padrao[r].origem
		CatalogoPlex.objetos[tipo]={"nome":info.nome,"pasta":"res://assets/cidade/mapa/"+tipo,"largura":int(info.w),"profundidade":int(info.h),"altura":0 if info.decalque else int(info.altura),"pivo":[96,144],"estados":["padrao"],"estado_padrao":"padrao","bairro":true,"piso":false,"sobreposto":false,"origem_celula":bool(info.origemCelula),"origens":origens,"categoria":"Cenário","preco":0,"conforto":0,"decalque":bool(info.decalque)}

static func ambiente(valor: String, cobertura: float) -> bool:
	var nova:=clampf(cobertura,0.0,1.0)
	if estado==valor and is_equal_approx(neve,nova): return false
	estado=valor;neve=nova;versao+=1
	return true

static func quadro(tipo: String, r: int, camada: String="sprites", variante: String="") -> Dictionary:
	if not dados.has(tipo): return {}
	var opcoes: Dictionary=dados[tipo].get(camada,{})
	if opcoes.is_empty(): return {}
	var atual:=estado if variante.is_empty() else variante
	if atual=="neve": atual="padrao"
	var alternativa: String="chuva" if atual=="outono_chuva" and opcoes.has("chuva") else "padrao"
	return opcoes.get(atual,opcoes.get(alternativa,opcoes.values()[0]))[posmod(r,4)]

static func solido(tipo: String) -> bool:
	if tipo in ["banco_espera","lixeira_salao","cidade_poste_de_luz"]: return true
	var info: Dictionary=dados.get(tipo,{})
	return info.get("grupo","")=="predios" or tipo.contains("arvore") or tipo.contains("pedra_grande") or tipo.contains("cerca_viva")

static func sinal(material: ShaderMaterial, estado_sinal: String, r: int) -> void:
	var caminho:="res://assets/cidade/integracao/sinais/"+estado_sinal+"/"+str(posmod(r,4))+".png"
	material.set_shader_parameter("tem_emissao",true)
	material.set_shader_parameter("emissao_continua",true)
	material.set_shader_parameter("janelas_agrupadas",false)
	material.set_shader_parameter("nivel_emissao",1.0)
	material.set_shader_parameter("mascara_emissao",CatalogoPlex.textura(caminho))
	var cor: Color={"verde":Color("63db60"),"amarelo":Color("ffd77b"),"vermelho":Color("ef6253")}.get(estado_sinal,Color.WHITE)
	material.set_shader_parameter("cor_emissao",Vector3(cor.r,cor.g,cor.b))
