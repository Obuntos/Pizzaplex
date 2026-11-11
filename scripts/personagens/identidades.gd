class_name IdentidadesPlex
extends RefCounted

static var banco: Dictionary = {}
static var usados: Dictionary = {}
static var rng := RandomNumberGenerator.new()

static func carregar() -> void:
	if not banco.is_empty(): return
	banco = JSON.parse_string(FileAccess.get_file_as_string("res://dados/nomes_1960.json"))
	rng.randomize()

static func escolher(lista: Array) -> String:
	return str(lista[rng.randi_range(0,lista.size()-1)])

static func normalizar(valor: String) -> String:
	for par in [["á","a"],["à","a"],["â","a"],["ã","a"],["é","e"],["ê","e"],["í","i"],["ó","o"],["ô","o"],["õ","o"],["ú","u"],["ç","c"]]: valor = valor.to_lower().replace(par[0],par[1])
	return valor.to_lower()

static func garantir(ator: PersonagemPlex) -> void:
	if not ator.identidade.is_empty(): return
	carregar()
	if ator.robo:
		ator.identidade = {"nome":CatalogoMontagemPlex.nome(ator.modelo),"sobrenome":"","apelido":"","idade":0,"sexo":"maquina"}
		return
	var feminino := ator.modelo in ["humana","adolescente_feminina"] or (ator.cargo=="crianca" and rng.randf()<.5)
	var nome := escolher(banco.femininos if feminino else banco.masculinos)
	var sobrenome := escolher(banco.sobrenomes)
	for tentativa in 20:
		if not usados.has(nome+" "+sobrenome): break
		nome = escolher(banco.femininos if feminino else banco.masculinos)
		sobrenome = escolher(banco.sobrenomes)
	usados[nome+" "+sobrenome] = true
	var opcoes: Array = []
	for item in banco.apelidos_femininos if feminino else banco.apelidos_masculinos:
		if item.origens.is_empty() or item.origens.any(func(n): return normalizar(n)==normalizar(nome)): opcoes.append(item.nome)
	var apelido := escolher(opcoes) if not opcoes.is_empty() and rng.randf()<.35 else ""
	if apelido.is_empty() and ator.cargo!="crianca" and rng.randf()<.12:
		var alcunhas: Array = banco.alcunhas.filter(func(a): return a.origens.is_empty() or (feminino and a.nome=="Broto"))
		if not alcunhas.is_empty(): apelido = str(alcunhas[rng.randi_range(0,alcunhas.size()-1)].nome)
	ator.identidade = {"nome":nome,"sobrenome":sobrenome,"apelido":apelido,"idade":rng.randi_range(6,12) if ator.cargo=="crianca" else rng.randi_range(13,17) if ator.cargo=="adolescente" else rng.randi_range(24,56),"sexo":"feminino" if feminino else "masculino"}

static func familiar(filho: PersonagemPlex, adulta: PersonagemPlex) -> void:
	garantir(filho)
	garantir(adulta)
	filho.identidade.sobrenome = adulta.identidade.sobrenome
	adulta.identidade.idade = maxi(int(adulta.identidade.idade),int(filho.identidade.idade)+18)

static func completo(ator: PersonagemPlex) -> String:
	garantir(ator)
	if ator.robo:
		var nome := str(ator.identidade.get("nome_robotico", "")).strip_edges()
		return nome if not nome.is_empty() else CatalogoMontagemPlex.nome(ator.modelo)+" · "+str(ator.identificador).pad_zeros(3)
	return (str(ator.identidade.nome)+" "+str(ator.identidade.sobrenome)).strip_edges()

static func curto(ator: PersonagemPlex) -> String:
	garantir(ator)
	return completo(ator) if ator.robo else str(ator.identidade.apelido if not str(ator.identidade.apelido).is_empty() else ator.identidade.nome)


