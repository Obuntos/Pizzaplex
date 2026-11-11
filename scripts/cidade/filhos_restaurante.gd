class_name FilhosRestaurantePlex
extends RefCounted

static func grupo(bairro: PopulacaoBairroPlex, responsavel: String) -> Dictionary:
	var adulto: PersonagemPlex=bairro.atores.ativos.get(responsavel)
	if not is_instance_valid(adulto): return {}
	return bairro.jogo.clientes.grupos.get(adulto.familia,{})

static func enviar(bairro: PopulacaoBairroPlex, escola: Dictionary) -> bool:
	var visita:=grupo(bairro,str(escola.responsavel))
	if visita.is_empty(): return false
	if not visita.has("filhos_pendentes"): visita.filhos_pendentes=[]
	for valor in escola.alunos:
		var id:=str(valor)
		var estado: Dictionary=bairro.estados.get(id,{})
		if estado.is_empty() or estado.get("morto",false) or estado.get("restaurante",false): continue
		if not visita.filhos_pendentes.has(id): visita.filhos_pendentes.append(id)
	var terminou:=true
	for valor in visita.filhos_pendentes.duplicate():
		var id:=str(valor)
		if not bairro.perfis.has(id): visita.filhos_pendentes.erase(id);continue
		var perfil: Dictionary=bairro.perfis[id]
		var estado: Dictionary=bairro.estados[id]
		if estado.get("morto",false): visita.filhos_pendentes.erase(id);continue
		if not bairro.atores.pronto(id): terminou=false;continue
		var origem:=bairro.locais.ponto("escola",perfil)
		if origem.x<0: terminou=false;continue
		estado.posicao=[origem.x,origem.y];estado.rota=[]
		if bairro.atores.ativos.size()>=int(bairro.limites.ativos):
			for outro in bairro.atores.ativos.keys():
				if bairro.atores.ativos[outro].cargo=="morador":
					bairro.atores.ocultar(outro)
					if bairro.atores.ativos.size()<int(bairro.limites.ativos): break
		var a:=bairro.atores.adquirir(id,origem,"adolescente" if perfil.grupo=="adolescente" else "crianca")
		if not is_instance_valid(a): terminou=false;continue
		a.familia=int(visita.id);a.responsavel=int(visita.adulta)
		a.visita.merge({"morador_id":id,"etapa":"refeicao","solo":false,"tempo":0.0,"jogou":false,"assistiu":false,"comeu":false,"partidas":0,"espera_jogo":0.0},true)
		var entrada:=EntradaVisitantesPlex.escolher(bairro.jogo.clientes,origem)
		EntradaVisitantesPlex.configurar(bairro.jogo.clientes,a,entrada)
		if a.cargo=="adolescente":
			if not visita.adolescentes.has(a.identificador): visita.adolescentes.append(a.identificador)
		elif not visita.criancas.has(a.identificador): visita.criancas.append(a.identificador)
		for chave in ["escola_grupo","escola_acompanha","escola_busca"]: estado.erase(chave)
		estado.restaurante=true;estado.local="restaurante";estado.atividade="Indo encontrar a família na pizzaria";estado.modo="visita"
		estado.ultima_visita=bairro.jogo.calendario.dias
		bairro.fila_rotas.erase(id)
		visita.filhos_pendentes.erase(id)
		visita.estado="visita";visita.acesso=true
		if visita.get("pago",false): visita.pago=false
		var mesa: Dictionary=bairro.jogo.planta.objetos.get(int(visita.mesa),{})
		if not mesa.is_empty(): mesa.familia_cliente=visita.id
		bairro.versao+=1
	if terminou:
		var adulto: Dictionary=bairro.estados[escola.responsavel]
		adulto.erase("escola_busca");adulto.erase("escola_grupo");adulto.erase("escola_acompanha")
	return terminou and visita.filhos_pendentes.is_empty()
