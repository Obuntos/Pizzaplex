class_name FuncoesSalaPlex
extends RefCounted

const COMPATIVEIS = ["salao", "salao_festas", "recepcao", "apresentacoes", "jogos"]
const ORDEM = ["cozinha", "banheiro", "oficina", "limpeza", "vestiario", "salao_festas", "salao", "jogos", "recepcao", "apresentacoes", "deposito"]

static func possui(planta: PlantaPlex, ambiente: Dictionary, requisitos: Dictionary) -> bool:
	for tipo in requisitos:
		var total := 0
		for id in ambiente.objetos:
			if CatalogoPlex.base(planta.objetos.get(id, {}).get("tipo", "")) == tipo: total += 1
		if total < int(requisitos[tipo]): return false
	return true

static func classificar(planta: PlantaPlex, ambiente: Dictionary, definicoes: Dictionary) -> void:
	var marcas: Array = ambiente.get("marcas", [])
	var compativel := not marcas.is_empty() and marcas.all(func(tipo): return tipo in COMPATIVEIS)
	ambiente.conflito = marcas.size() > 1 and not compativel
	if marcas.is_empty():
		ambiente.tipo = "livre"
		for tipo in ORDEM:
			if possui(planta, ambiente, definicoes[tipo].requisitos):
				ambiente.tipo = tipo
				break
	elif compativel:
		var festa := "salao_festas" in marcas or ("salao" in marcas and "apresentacoes" in marcas)
		festa = festa or ("salao" in marcas and possui(planta, ambiente, definicoes.salao_festas.requisitos))
		ambiente.tipo = "salao_festas" if festa else ("salao" if "salao" in marcas else marcas[0])
	else:
		ambiente.tipo = marcas[0]
	ambiente.funcoes = [ambiente.tipo]
	if ambiente.tipo in COMPATIVEIS:
		for tipo in ["salao", "apresentacoes", "recepcao", "jogos"]:
			if tipo not in ambiente.funcoes and possui(planta, ambiente, definicoes[tipo].requisitos): ambiente.funcoes.append(tipo)
	if ambiente.tipo == "vestiario": ambiente.funcoes.append("descanso")

static func aceita(ambiente: Dictionary, tipos: Array) -> bool:
	return tipos.is_empty() or tipos.any(func(tipo): return tipo in ambiente.get("funcoes", [ambiente.tipo]))

