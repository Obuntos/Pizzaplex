class_name EquipePlex
extends RefCounted

const NOMES = {"geral":"Geral", "cozinha":"Cozinha", "atendimento":"Atendimento", "limpeza":"Limpeza", "estoque":"Estoque", "manutencao":"Manutenção"}
const FUNCOES = ["cozinha","atendimento","limpeza","estoque","manutencao"]

static func prioridades(ator: PersonagemPlex) -> Array:
	if ator.cargo != "funcionario" or ator.robo: return []
	if ator.funcao == "geral": return FUNCOES.duplicate()
	var resultado: Array = [ator.funcao] if FUNCOES.has(ator.funcao) else []
	for funcao in ator.funcoes_secundarias:
		if FUNCOES.has(funcao) and not resultado.has(funcao): resultado.append(funcao)
	return resultado

static func permite(ator: PersonagemPlex, funcao: String) -> bool:
	return prioridades(ator).has(funcao)

static func definir(ator: PersonagemPlex, principal: String, secundarias: Array) -> void:
	if not NOMES.has(principal) or ator.cargo != "funcionario" or ator.robo: return
	ator.funcao = principal
	ator.funcoes_secundarias = secundarias.filter(func(f): return FUNCOES.has(f) and f != principal)
