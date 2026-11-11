class_name FamiliasVisitantesPlex
extends RefCounted

const PRESETS = {
	"adulto_crianca":{"adultos":1,"criancas":1,"adolescentes":0},
	"adulto_tres_criancas":{"adultos":1,"criancas":3,"adolescentes":0},
	"adulto_criancas":{"adultos":1,"criancas":2,"adolescentes":0},
	"dupla_criancas":{"adultos":2,"criancas":2,"adolescentes":0},
	"dupla_mista":{"adultos":2,"criancas":1,"adolescentes":1},
	"adulto_adolescente":{"adultos":1,"criancas":0,"adolescentes":1},
	"casal":{"adultos":2,"criancas":0,"adolescentes":0},
	"adulto":{"adultos":1,"criancas":0,"adolescentes":0}
}

static func adultos(grupo: Dictionary) -> Array[int]:
	var ids: Array[int] = []
	for valor in grupo.get("adultos",[grupo.adulta]):
		var id:=int(valor)
		if not ids.has(id): ids.append(id)
	return ids

static func membros(grupo: Dictionary) -> Array[int]:
	var ids:=adultos(grupo)
	for campo in ["criancas","adolescentes"]:
		for valor in grupo.get(campo,[]):
			var id:=int(valor)
			if not ids.has(id): ids.append(id)
	return ids

static func criar(clientes: ClientesPlex, local: Vector2i, total_adultos: int, total_criancas: int, total_jovens: int, modelo: String = "", cadastros: Array = []) -> bool:
	if "operacao" in clientes.jogo and not clientes.jogo.operacao.aberto:
		clientes.jogo.painel.mensagem("Abra o restaurante para receber novas visitas.")
		return false
	var total:=total_adultos+total_criancas+total_jovens
	var mesa:=clientes.recepcao.mesa_livre(total)
	if mesa<0:
		clientes.jogo.painel.mensagem("Restaurante cheio: aguarde uma mesa livre com lugares para toda a família.")
		return false
	if total_adultos<1 or total_adultos>2 or total_criancas<0 or total_criancas>3 or total_jovens<0 or total_jovens>2 or total>6 or not clientes.chao(local):
		clientes.jogo.painel.mensagem("Escolha um tile de chão livre para a família.")
		return false
	local=EntradaVisitantesPlex.origem(clientes,local) if cadastros.is_empty() else local
	var entrada:=EntradaVisitantesPlex.escolher(clientes,local)
	if local.x<0 or entrada.is_empty():
		clientes.jogo.painel.mensagem("Adicione uma porta principal com acesso livre para os visitantes.")
		return false
	var destino:=clientes.saida(local)
	var locais:=clientes.vagas(local,total,4,true)
	if destino.x<0 or locais.size()<total:
		clientes.jogo.painel.mensagem("A família precisa de espaço livre e de uma saída alcançável.")
		return false
	var id:=clientes.proximo_grupo
	clientes.proximo_grupo+=1
	var grupo: Dictionary={"id":id,"adulta":-1,"adultos":[],"criancas":[],"adolescentes":[],"espera_acesso":0.0,"acesso":false,"mesa":-1,"slot":-1,"cadeira":-1,"pedido":-1,"estado":"visita","tempo":0.0,"pago":false,"saida":[destino.x,destino.y]}
	clientes.grupos[id]=grupo
	grupo.estado="recepcao"
	grupo.fase_recepcao="fila"
	grupo.mesa=mesa
	clientes.jogo.planta.objetos[mesa].familia_cliente=id
	var indice:=0
	for n in total_adultos:
		var aparencia:=modelo
		if n>0: aparencia="humana" if clientes.ator(grupo.adulta).modelo=="humano" else "humano"
		elif aparencia not in ["humano","humana"]: aparencia="humano" if id%2==0 else "humana"
		var pessoa:=novo(clientes,aparencia,locais[indice],"cliente",cadastros,indice)
		indice+=1
		pessoa.familia=id
		pessoa.visita.merge({"etapa":"chegada","banheiro":false,"higiene":false,"comeu":false},true)
		EntradaVisitantesPlex.configurar(clientes,pessoa,entrada)
		grupo.adultos.append(pessoa.identificador)
		if n==0: grupo.adulta=pessoa.identificador
	var responsavel:=clientes.ator(grupo.adulta)
	for n in total_criancas+total_jovens:
		var adolescente:=n>=total_criancas
		var aparencia: String=("adolescente_feminina" if (id+n)%2==0 else "adolescente") if adolescente else "crianca"
		var filho:=novo(clientes,aparencia,locais[indice],"adolescente" if adolescente else "crianca",cadastros,indice)
		indice+=1
		filho.familia=id
		filho.responsavel=responsavel.identificador
		if cadastros.is_empty(): IdentidadesPlex.familiar(filho,responsavel)
		filho.visita={"etapa":"arcade" if adolescente else "jogar","jogou":false,"assistiu":false,"tempo":0.0,"partidas":0,"espera_jogo":0.0,"comeu":false,"solo":false}
		EntradaVisitantesPlex.configurar(clientes,filho,entrada)
		if adolescente:
			filho.cabelo="camadas" if filho.modelo=="adolescente_feminina" else "curto"
			filho.uniforme="nenhum"
			grupo.adolescentes.append(filho.identificador)
		else: grupo.criancas.append(filho.identificador)
	if not cadastros.is_empty():
		clientes.jogo.populacao.visitas.vincular(grupo,cadastros)
		return true
	for adulto_id in grupo.adultos:
		var adulto:=clientes.ator(int(adulto_id))
		for filho_id in grupo.criancas+grupo.adolescentes:
			adulto.identidade.idade=maxi(int(adulto.identidade.idade),int(clientes.ator(int(filho_id)).identidade.idade)+18)
	clientes.jogo.selecionar(responsavel)
	clientes.jogo.painel.mensagem("Família: "+str(total_adultos)+" adulto(s), "+str(total_criancas)+" criança(s) e "+str(total_jovens)+" adolescente(s).")
	return true

static func preset(clientes: ClientesPlex, local: Vector2i, id: String) -> bool:
	if id=="variada": id=str(PRESETS.keys()[randi()%PRESETS.size()])
	if not PRESETS.has(id): return false
	var p: Dictionary=PRESETS[id]
	return criar(clientes,local,int(p.adultos),int(p.criancas),int(p.adolescentes))

static func novo(clientes: ClientesPlex, modelo: String, local: Vector2i, cargo: String, cadastros: Array, indice: int) -> PersonagemPlex:
	if cadastros.is_empty(): return clientes.jogo.spawn(modelo,local,cargo)
	var bairro: PopulacaoBairroPlex=clientes.jogo.populacao
	var id:=str(cadastros[indice])
	var origem:=Vector2i(bairro.posicao(bairro.estados[id]).round())
	return bairro.atores.adquirir(id,origem,cargo)

