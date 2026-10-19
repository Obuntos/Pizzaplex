class_name AdministradorPlex
extends RefCounted

static func eh(ator: PersonagemPlex) -> bool:
	return ator.funcao=="administrador" or bool(ator.visita.get("administrador",false))

static func reservar_cabelo(jogo: Node) -> void:
	var reservado := str(jogo.operacao.criacao.get("cabelo","nenhum"))
	for ator in jogo.personagens:
		ator.set_meta("cabelo_reservado",reservado)
		if eh(ator) or reservado=="nenhum" or not AparenciaPlex.permitida(ator): continue
		if AparenciaPlex.cabelo(ator)==reservado or ator.cabelo==reservado:
			ator.cabelo = alternativa(ator,reservado)

static func alternativa(ator: PersonagemPlex, reservado: String) -> String:
	AparenciaPlex.carregar()
	var opcoes: Array = AparenciaPlex.dados.cabelos.filter(func(c): return c.id!=reservado)
	return str(opcoes[posmod(ator.identificador,opcoes.size())].id) if not opcoes.is_empty() else "nenhum"

static func criar(jogo: Node) -> PersonagemPlex:
	var d: Dictionary = jogo.operacao.criacao
	var local := Vector2i(30,25)
	if jogo.operacao.debug: local = Vector2i(45,13)
	for c in jogo.clientes.vagas(local,1,6):
		local=c
		break
	var a: PersonagemPlex = jogo.spawn(str(d.get("modelo","humano")),local)
	a.funcao = "administrador"
	a.visita.administrador = true
	a.necessidades.turno = true
	a.uniforme = str(d.get("uniforme","administrador_masculino_1"))
	a.cabelo = str(d.get("cabelo","curto"))
	a.identidade = {"nome":str(d.get("nome","Administrador")).strip_edges().left(40),"sobrenome":"","apelido":"","idade":30,"sexo":"feminino" if a.modelo=="humana" else "masculino"}
	jogo.operacao.administrador = a.identificador
	reservar_cabelo(jogo)
	a.atualizar_visual(false)
	jogo.selecionar(a)
	jogo.painel.mensagem("Modo debug · Construção e compras gratuitas." if jogo.operacao.debug else "Bem-vindo à "+jogo.operacao.nome+". Abra o catálogo para começar a reforma.")
	return a

static func contratar(jogo: Node, funcao: String) -> PersonagemPlex:
	var admin: PersonagemPlex = jogo.clientes.ator(jogo.operacao.administrador)
	var origem := admin.celula if is_instance_valid(admin) else Vector2i(30,25)
	var vagas: Array = jogo.clientes.vagas(origem,1,6)
	if vagas.is_empty(): return null
	var a: PersonagemPlex = jogo.spawn("humana" if randi()%2==0 else "humano",vagas[0])
	EquipePlex.definir(a,funcao,[])
	a.necessidades.turno = true
	reservar_cabelo(jogo)
	jogo.painel.mensagem(IdentidadesPlex.completo(a)+" contratado para "+str(EquipePlex.NOMES.get(funcao,funcao))+".")
	return a
