class_name AcessosConstrucaoPlex
extends RefCounted

const FIXOS=["forno","geladeira","pia","bancada_preparo","bancada","balcao","suporte","armario_limpeza","armario_ferramentas","armario_utensilios","armario_funcionarios","estante","estante_compacta","prateleira_suspensa","maquina_fliperama","vaso_sanitario","pia_banheiro","cadeira","banco_espera","terminal_ibm","registradora","mesa","mesa_longa","mesa_longa_arredondada","lixeira","lixeira_salao"]
var assinatura:=-1
var resultado: Dictionary={}

static func exige_uso(item:Dictionary) -> bool:
	var dados:=MobiliaPlex.dados(item)
	return CatalogoPlex.base(str(item.tipo)) in FIXOS or item.tipo=="area_montagem_atracao" or MontagemAtracoesPlex.bancada(item) or FornoPlex.eh(item) or str(dados.get("uso","")) in ["diagnostico","carregar","ponto","reservas","energia","estudo","piscina"] or MobiliaPlex.visual(item) in ["amb_carregador_oficina","amb_painel_diagnostico","amb_livro_reservas","amb_quadro_energia","amb_relogio_ponto","amb_telefone_disco","amb_interruptor_antigo","amb_maquina_fichas","amb_maquina_premios","amb_balcao_tickets","amb_carrinho_louca","amb_escorredor_louca"]
static func pontos(planta: PlantaPlex, item: Dictionary) -> Array[Vector2i]:
	if item.tipo=="cadeira":
		return PontosUsoPlex.acessos_cadeira(planta,item)
	if LugaresPlex.mesa(item.tipo):
		var lugares: Array[Vector2i]=[]
		for lugar in LugaresPlex.posicoes(item):
			var cadeira: Dictionary=planta.em(lugar.celula)
			var sentavel: bool=cadeira.get("tipo","")=="cadeira" and GradePlex.frente(cadeira.rotacao)==lugar.frente
			if sentavel or (planta.transitavel(lugar.celula) and is_zero_approx(planta.altura(lugar.celula))): lugares.append(lugar.celula)
		return lugares
	if item.tipo=="registradora": return CaixaPlex.postos(planta,item,true)
	if FornoPlex.eh(item): return FornoPlex.acessos(planta,item.id)
	if item.tipo=="geladeira": return planta.interacoes_estado(item.id,"aberta")
	return planta.interacoes(item.id)

func avaliar(editor: EditorPlex, celula: Vector2i) -> Dictionary:
	if editor.item_movendo>=0: return MoverItensPlex.avaliar(editor,celula)
	var tipo:=editor.ferramenta
	var chave:=hash([editor.planta.get_instance_id(),editor.planta.revisao,tipo,celula,editor.rotacao,editor.estado_visual])
	if chave==assinatura: return resultado
	assinatura=chave
	resultado={"pontos":[],"reservas":[],"permitido":true,"motivo":""}
	if not CatalogoPlex.objetos.has(tipo) or CatalogoPlex.objetos[tipo].get("piso",false): return resultado
	var p:=PlantaPlex.new()
	p.objetos=editor.planta.objetos.duplicate()
	for id in p.objetos:
		var embalagem: Dictionary=p.objetos[id]
		if not EmbalagensMoveisPlex.eh(embalagem): continue
		var final: Dictionary=embalagem.conteudo_movel.duplicate(true)
		for campo in ["id","celula","rotacao","sobre","slot"]: final[campo]=embalagem[campo]
		p.objetos[id]=final
	p.ocupacao=editor.planta.ocupacao.duplicate()
	p.reservas_abertura=editor.planta.reservas_abertura.duplicate()
	p.cabines_por_celula=editor.planta.cabines_por_celula
	p.area_construcao=editor.planta.area_construcao
	p.terrenos_adquiridos=editor.planta.terrenos_adquiridos.duplicate()
	p.bairro_ativo=editor.planta.bairro_ativo
	p.lote_restaurante=editor.planta.lote_restaurante
	var rotacao:=PortasPlex.rotacao_para(editor.planta,tipo,celula,editor.rotacao) if PortasPlex.ajusta(str(tipo)) else editor.rotacao
	var item: Dictionary={"id":-1000,"tipo":tipo,"celula":celula,"rotacao":rotacao,"estado":editor.estado_visual,"sobre":-1,"carregada_por":0}
	if ApoiosPlex.superficie(tipo) or ApoiosPlex.decoracao_mesa(tipo):
		var apoio:=ApoiosPlex.encontrar(editor.planta,celula,tipo)
		if apoio.is_empty(): return resultado
		item.sobre=apoio.pai;item.slot=apoio.slot
	MobiliaPlex.preparar(item,tipo)
	p.objetos[item.id]=item
	var ocupadas: Array[Vector2i]=[]
	if p.ocupa(item):
		ocupadas=p.celulas(item.tipo,celula,rotacao)
		for c in ocupadas: p.ocupacao[c]=item.id
	if exige_uso(item):
		var vazia:=PlantaPlex.new()
		vazia.objetos=p.objetos
		vazia.area_construcao=p.area_construcao
		vazia.terrenos_adquiridos=p.terrenos_adquiridos.duplicate()
		vazia.bairro_ativo=p.bairro_ativo
		vazia.lote_restaurante=p.lote_restaurante
		if p.ocupa(item):
			for c in ocupadas: vazia.ocupacao[c]=item.id
		elif item.get("sobre",-1)>=0:
			var pai: Dictionary=p.objetos.get(ApoiosPlex.raiz(p,item.id),{})
			if not pai.is_empty():
				for c in p.celulas(pai.tipo,pai.celula,pai.rotacao): vazia.ocupacao[c]=pai.id
		if item.tipo=="cadeira":
			var mesa:=p.em(item.celula+GradePlex.frente(item.rotacao))
			if LugaresPlex.mesa(str(mesa.get("tipo",""))):
				for c in p.celulas(mesa.tipo,mesa.celula,mesa.rotacao):vazia.ocupacao[c]=mesa.id
		var candidatos:=pontos(vazia,item)
		var livres:=pontos(p,item).filter(func(c): return TerrenoPlex.contem(p,c) and not TerrenoPlex.borda(p,c))
		if item.tipo=="cadeira" and not livres.is_empty():candidatos.assign(livres)
		for c in candidatos: resultado.pontos.append({"celula":c,"livre":livres.has(c),"altura":p.altura(c)})
		if livres.is_empty(): resultado.permitido=false;resultado.motivo="Deixe livre pelo menos um ponto de uso do móvel."
		if item.tipo=="registradora" and CaixaPlex.postos(p,item,false).filter(func(c): return TerrenoPlex.contem(p,c) and not TerrenoPlex.borda(p,c)).is_empty():
			resultado.permitido=false
			resultado.motivo="Deixe acesso para o caixista e para os clientes nos dois lados da registradora."
	ApoiosPlex.carregar()
	if ApoiosPlex.definicoes.has(item.tipo):
		var info: Dictionary=ApoiosPlex.definicoes[item.tipo]
		var estado: String="aberto" if item.tipo=="forno" else "aberta" if item.tipo=="geladeira" else str(item.estado)
		var vista:Dictionary={"reserva":[]}
		var vistas:Variant=info.estados.get(estado,info.estados.values()[0] if not info.estados.is_empty() else [])
		if vistas is Array and not vistas.is_empty():vista=vistas[posmod(int(item.rotacao),vistas.size())]
		var centro:=ApoiosPlex.posicao(p,item)
		for r in vista.reserva:
			var c:=Vector2i(roundi(centro.x+r.u),roundi(centro.y+r.v))
			var livre: bool=GradePlex.dentro(c) and p.em(c).is_empty()
			resultado.reservas.append({"celula":c,"livre":livre,"altura":0.0})
			resultado.reservas[-1].abertura=true
			if not livre: resultado.permitido=false;resultado.motivo="Deixe espaço livre para abrir e utilizar o equipamento."
	if not ocupadas.is_empty():
		for outro in p.objetos.values():
			if outro.id==item.id or outro.id==editor.planta.ocupacao.get(celula,-1) or not exige_uso(outro) or Vector2(outro.celula-celula).length_squared()>36: continue
			var anterior:=PlantaPlex.new()
			anterior.objetos=p.objetos.duplicate();anterior.objetos.erase(item.id)
			anterior.ocupacao=editor.planta.ocupacao;anterior.reservas_abertura=editor.planta.reservas_abertura
			var antes:=pontos(anterior,outro)
			if antes.is_empty(): continue
			var depois:=pontos(p,outro)
			if depois.is_empty():
				resultado.permitido=false
				resultado.motivo="Essa posição bloqueia o acesso a "+str(MobiliaPlex.dados(outro).nome)+"."
				for c in antes: resultado.pontos.append({"celula":c,"livre":false,"altura":p.altura(c)})
	resultado.acessivel=resultado.permitido
	resultado.permitido=true
	if item.tipo=="cadeira": resultado.pontos.clear()
	return resultado

static func desenhar(cursor: CursorPlex, dados: Dictionary) -> void:
	for grupo in ["reservas","pontos"]:
		for ponto in dados[grupo]:
			var p:=GradePlex.projetar(Vector2(ponto.celula),float(ponto.altura))
			var cor:=Color("9edbb4") if ponto.livre else Color("ed796c")
			var forma:=GradePlex.poligono(p)
			if grupo=="reservas" and dados.pontos.any(func(outro): return outro.celula==ponto.celula): continue
			if grupo=="reservas" and ponto.livre:
				cursor.draw_polyline(forma+PackedVector2Array([forma[0]]),Color("c6ac76"),1.0)
				continue
			cursor.draw_colored_polygon(forma,Color(cor,.16))
			cursor.draw_polyline(forma+PackedVector2Array([forma[0]]),cor,1.0)

