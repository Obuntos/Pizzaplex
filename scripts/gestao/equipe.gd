class_name EquipePlex
extends RefCounted

const NOMES = {"administrador":"Administrador", "geral":"Geral", "cozinha":"Cozinha", "atendimento":"Atendimento", "limpeza":"Limpeza", "estoque":"Estoque", "manutencao":"Manutenção", "caixa":"Caixa", "seguranca":"Segurança"}
const FUNCOES = ["cozinha","atendimento","limpeza","estoque","manutencao"]

static func prioridades(ator: PersonagemPlex) -> Array:
	if ator.cargo != "funcionario" or ator.robo: return []
	if AdministradorPlex.eh(ator):
		var livres: Array = []
		for funcao in FUNCOES+["caixa"]:
			if not ator.equipe.any(func(outro): return outro!=ator and outro.cargo=="funcionario" and not outro.robo and not AdministradorPlex.eh(outro) and (outro.funcao==funcao or outro.funcoes_secundarias.has(funcao) or outro.funcao=="geral")):
				livres.append(funcao)
		return livres
	if ator.funcao == "geral": return FUNCOES.duplicate()
	var resultado: Array = [ator.funcao] if NOMES.has(ator.funcao) else []
	for funcao in ator.funcoes_secundarias:
		if FUNCOES.has(funcao) and not resultado.has(funcao): resultado.append(funcao)
	return resultado

static func permite(ator: PersonagemPlex, funcao: String) -> bool:
	return prioridades(ator).has(funcao)

static func definir(ator: PersonagemPlex, principal: String, secundarias: Array) -> void:
	if AdministradorPlex.eh(ator): return
	if not NOMES.has(principal) or ator.cargo != "funcionario" or ator.robo: return
	ator.funcao = principal
	ator.funcoes_secundarias = secundarias.filter(func(f): return FUNCOES.has(f) and f != principal)


static func em_comando(ator: PersonagemPlex) -> bool:
	if not ator.visita.has("comando_manual_ate"): return false
	if ator.ocupado() or ator.relogio<float(ator.visita.comando_manual_ate): return true
	ator.visita.erase("comando_manual_ate")
	return false
