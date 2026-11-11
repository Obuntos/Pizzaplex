class_name ReputacaoClientesPlex
extends RefCounted

static var cache:Dictionary={}
static func ambiente(s:ServicosPlex) -> float:
	var chave:=s.get_instance_id()
	var robos:int=s.personagens.filter(func(a):return a.robo and a.pose>=0 and not a.robotica.get("avariado",false) and not CatalogoMontagemPlex.quebrado(a.modelo)).size()
	var agora:=Time.get_ticks_msec()
	var salvo:Dictionary=cache.get(chave,{})
	if salvo.get("revisao",-1)==s.planta.revisao and salvo.get("robos",-1)==robos and agora-int(salvo.get("tempo",0))<2000:return float(salvo.nota)
	var paredes:=0;var velhas:=0;var sujeira:=0;var decoracao:=0.0;var luzes:=0;var mesas:=0;var jogos:=0
	for item in s.planta.objetos.values():
		if not TerrenoPlex.contem(s.planta,item.celula) or int(item.get("carregada_por",0))>0:continue
		var tipo:=str(item.tipo);var visual:=MobiliaPlex.visual(item);var info:=MobiliaPlex.dados(item)
		if tipo in SalasPlex.ESTRUTURA:
			paredes+=1
			if visual.begins_with("antigo_"):velhas+=1
		if LimpezaAmbientesPlex.eh(item) or tipo=="prato" and item.get("sujo",false):sujeira+=1
		if info.get("categoria","")=="Decoração" and not info.get("entulho",false):decoracao+=maxf(0.0,float(info.get("conforto",0)))*.35
		if LuminariasPlex.eh(tipo) and item.get("ligada",true):luzes+=1
		if LugaresPlex.mesa(tipo) and LugaresPlex.total(s.planta,item.id)>0:mesas+=1
		if CatalogoPlex.base(tipo)=="maquina_fliperama":jogos+=1
	var deterioracao:=float(velhas)/maxf(1.0,paredes)
	var valor:=28.0+minf(15.0,decoracao)+minf(25.0,robos*16.0)+minf(5.0,mesas*1.5)+minf(5.0,jogos*2.5)+minf(4.0,luzes)-deterioracao*24.0-minf(32.0,sujeira*2.5)
	valor=clampf(valor,5.0,100.0)
	if cache.size()>32:cache.clear()
	cache[chave]={"revisao":s.planta.revisao,"robos":robos,"tempo":agora,"nota":valor}
	return valor

static func nota(s: ServicosPlex, familia: String="geral") -> float:
	var condicao:=ambiente(s)
	var registro:Dictionary=s.reputacao.get(familia,{})
	if int(registro.get("visitas",0))<=0:return condicao
	return clampf(condicao*.65+float(registro.get("nota",condicao))*.35,0.0,minf(100.0,condicao+8.0))

static func registrar(jogo: Node, grupo: Dictionary) -> void:
	if grupo.get("avaliacao_registrada",false): return
	grupo.avaliacao_registrada=true
	var s: ServicosPlex=jogo.servicos
	var valor:=25.0 if grupo.get("irritado",false) else 90.0
	if not grupo.get("pago",false) and not jogo.clientes.acompanhantes_servidos(grupo): valor=minf(valor,45.0)
	if grupo.get("festa_estado","")=="concluido": valor=100.0
	valor=minf(valor,ambiente(s)+10.0)
	for chave in ["geral",str(grupo.get("familia_bairro","visita:"+str(grupo.id)))]:
		var r: Dictionary=s.reputacao.get(chave,{"nota":ambiente(s),"visitas":0,"ultima_festa":-10})
		r.nota=clampf(float(r.nota)*.65+valor*.35,0,100)
		r.visitas=int(r.visitas)+1
		if grupo.get("aniversario",false) and grupo.get("festa_estado","")=="concluido":r.ultima_festa=jogo.calendario.dias
		s.reputacao[chave]=r

static func quer_festa(jogo: Node, familia: String) -> bool:
	var r: Dictionary=jogo.servicos.reputacao.get(familia,{})
	var livro:bool=jogo.equipamentos.livro_perto()
	return int(r.get("visitas",0))>0 and nota(jogo.servicos,familia)>=(65.0 if livro else 75.0) and jogo.calendario.dias-int(r.get("ultima_festa",-10))>=7 and posmod(hash([familia,jogo.calendario.dias,"aniversario"]),3)<(2 if livro else 1)

static func lugares(jogo: Node, grupo: Dictionary) -> bool:
	var mesas: Array[int]=MesasVisitasPlex.mesas(jogo.clientes,grupo)
	var total:=0
	for id in mesas:
		var mesa: Dictionary=jogo.planta.objetos.get(id,{})
		if mesa.is_empty() or int(mesa.get("familia_cliente",-1)) not in [-1,int(grupo.id)]: continue
		total+=LugaresPlex.total(jogo.planta,id)
	return total>=FamiliasVisitantesPlex.membros(grupo).size()
