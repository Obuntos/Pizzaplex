class_name AparenciasFamiliaPlex
extends RefCounted

static var dados: Dictionary = {}
static var roupas: Dictionary = {}

static func carregar() -> void:
	if dados.is_empty(): dados=JSON.parse_string(FileAccess.get_file_as_string("res://dados/aparencias_familias.json")).moradores
	RoupasVisitantesPlex.carregar()

static func especificacao(perfil: Dictionary, reservado: String = "") -> Dictionary:
	carregar()
	var registro: Dictionary=dados.get(perfil.id,{"cabelo":"curto","cor":"marrom_escuro"}).duplicate()
	if str(registro.cabelo)==reservado:
		VariedadeAparenciaPlex.carregar()
		var lista: Array=VariedadeAparenciaPlex.dados.infantis if perfil.modelo=="crianca" else VariedadeAparenciaPlex.dados.femininos if perfil.sexo=="feminino" else VariedadeAparenciaPlex.dados.masculinos
		lista=lista.filter(func(item): return str(item)!=reservado)
		if not lista.is_empty(): registro.cabelo=lista[posmod(hash(str(perfil.id)+":alternativa"),lista.size())]
	var id:=str(perfil.id)
	if not roupas.has(id):
		var base: String="humana" if perfil.sexo=="feminino" else "humano"
		var candidatas: Array=RoupasVisitantesPlex.dados.keys().filter(func(chave):
			var item: Dictionary=RoupasVisitantesPlex.dados[chave]
			return str(item.modelo)==base and item.get("pastas",{str(item.modelo):str(item.pasta)}).has(perfil.modelo))
		candidatas.sort()
		roupas[id]="" if candidatas.is_empty() else str(candidatas[posmod(hash(id+":roupa"),candidatas.size())])
	registro.roupa=roupas[id]
	return registro

static func aplicar(ator: PersonagemPlex, perfil: Dictionary) -> void:
	var visual:=especificacao(perfil,str(ator.get_meta("cabelo_reservado","")))
	ator.identidade={"nome":perfil.nome,"sobrenome":"","apelido":"","idade":perfil.idade,"sexo":perfil.sexo,"morador_id":perfil.id,"familia_bairro":perfil.familia}
	ator.cabelo=str(visual.cabelo)
	ator.visita.merge({"morador_id":perfil.id,"cor_cabelo":visual.cor,"estilo_cabelo":visual.cabelo,"roupa":visual.roupa},true)
	ator.uniforme="automatico" if perfil.grupo=="adulto" else "nenhum"

static func arquivos(perfil: Dictionary, reservado: String = "") -> Array[String]:
	var visual:=especificacao(perfil,reservado)
	var resultado: Array[String]=[]
	var origem:="res://assets/personagens/"+str(perfil.modelo)+"/"
	var roupa: Dictionary=RoupasVisitantesPlex.dados.get(visual.roupa,{})
	var pasta: String=roupa.get("pastas",{}).get(perfil.modelo,roupa.get("pasta",origem.trim_suffix("/")))
	for acao in ["parado","andar"]:
		resultado.append(pasta+"/"+acao+"_corpo.png")
		resultado.append(origem+acao+"_cabeca.png")
		var relativo:=str(perfil.modelo)+"/"+str(visual.cabelo)+"/"
		var ajustado:=ResourceLoader.exists("res://assets/aparencias/cabelos_ajustados/"+relativo+"parado_frente.png")
		for lado in ["frente","tras"]:
			var nome: String=acao+"_"+lado+".png"
			resultado.append("res://assets/aparencias/cabelos_ajustados/"+relativo+nome if ajustado else "res://assets/aparencias/cabelos/"+str(visual.cabelo)+"/"+nome)
			resultado.append("res://assets/aparencias/cabelos_cores_ajustados/"+relativo+str(visual.cor)+"/"+nome if ajustado else "res://assets/aparencias/cabelos_cores/"+str(visual.cabelo)+"/"+str(visual.cor)+"/"+nome)
	for parte in ["olhos","boca"]: resultado.append(origem+"neutro_"+parte+".png")
	var mapas: Array[String]=[]
	for arquivo in resultado:
		var mapa:=arquivo.replace("res://assets/personagens/","res://assets/iluminacao/personagens/").replace("res://assets/aparencias/","res://assets/iluminacao/aparencias/")
		mapas.append(mapa);mapas.append(mapa.replace(".png","_material.png"))
	resultado.append_array(mapas)
	return resultado.filter(func(arquivo): return ResourceLoader.exists(arquivo))
