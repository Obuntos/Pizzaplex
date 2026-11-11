class_name RecrutamentoPlex
extends RefCounted

static func listar(jogo:Node,funcao:String) -> Array:
	if not FolhaPagamentoPlex.SALARIOS.has(funcao):return []
	IdentidadesPlex.carregar()
	var candidatos:Array=jogo.operacao.candidatos.get(funcao,[])
	var chave:="proximo_"+funcao;var proximo:=int(jogo.operacao.candidatos.get(chave,0))
	while candidatos.size()<4:
		while candidatos.any(func(c):return str(c.id)==funcao+":"+str(proximo)):proximo+=1
		var feminino:=proximo%2==1;var nota:int=[1,2,4,5][proximo%4];var habilidades:Dictionary={}
		for f in FolhaPagamentoPlex.SALARIOS:habilidades[f]=clampi(nota-(1 if f!=funcao else 0),1,5)
		var salario:=roundi(FolhaPagamentoPlex.salario(funcao)*HabilidadesEquipePlex.multiplicador(nota))
		candidatos.append({"id":funcao+":"+str(proximo),"nome":IdentidadesPlex.escolher(IdentidadesPlex.banco.femininos if feminino else IdentidadesPlex.banco.masculinos),"sobrenome":IdentidadesPlex.escolher(IdentidadesPlex.banco.sobrenomes),"modelo":"humana" if feminino else "humano","habilidades":habilidades,"estrelas":nota,"custo":salario,"salario":salario});proximo+=1
	jogo.operacao.candidatos[funcao]=candidatos;jogo.operacao.candidatos[chave]=proximo;return candidatos
static func buscar(jogo:Node,funcao:String,id:String) -> Dictionary:
	for c in listar(jogo,funcao):
		if str(c.id)==id:return c
	return {}
static func remover(jogo:Node,funcao:String,id:String) -> void:
	if jogo.operacao.candidatos.has(funcao):jogo.operacao.candidatos[funcao]=jogo.operacao.candidatos[funcao].filter(func(c):return str(c.id)!=id)
