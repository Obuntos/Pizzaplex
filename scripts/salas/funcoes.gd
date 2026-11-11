class_name FuncoesSalaPlex
extends RefCounted

const COMPATIVEIS=["salao","salao_festas","recepcao","apresentacoes","jogos"]
const ABERTAS=["cozinha","limpeza","deposito","escritorio","vestiario","descanso","oficina","salao","salao_festas","recepcao","apresentacoes","jogos","circulacao"]
const ORDEM=["banheiro","descanso","cozinha","oficina","vestiario","escritorio","recepcao","salao_festas","salao","apresentacoes","jogos","limpeza","deposito"]
static func corresponde(item:Dictionary,tipo:String) -> bool:
	if item.is_empty():return false
	if tipo=="cadeira":return CatalogoPlex.base(str(item.tipo))=="cadeira" or MobiliaPlex.logico(MobiliaPlex.visual(item))=="cadeira"
	if tipo=="forno":return FornoPlex.eh(item)
	var visual:=MobiliaPlex.visual(item)
	if tipo=="armario_funcionarios":return TurnosEquipePlex.eh_armario(item)
	if tipo=="bancada_montagem_coelho":return visual in [MontagemAtracoesPlex.BANCADA,"oficina_bancada_trabalho"]
	if tipo=="mesa_desenho_inclinada":return visual=="mesa_desenho_inclinada"
	return str(item.tipo)==tipo or CatalogoPlex.base(str(item.tipo))==tipo or CatalogoPlex.base(visual)==tipo or MobiliaPlex.logico(visual)==tipo
static func contar(planta:PlantaPlex,ambiente:Dictionary,tipo:String) -> int:
	var total:=0
	for id in ambiente.get("objetos",[]):
		var item:Dictionary=planta.objetos.get(id,{})
		if int(item.get("carregada_por",0))==0 and corresponde(item,tipo):total+=1
	return total
static func possui(planta:PlantaPlex,ambiente:Dictionary,requisitos:Dictionary) -> bool:
	for tipo in requisitos:
		if contar(planta,ambiente,tipo)<int(requisitos[tipo]):return false
	return true
static func classificar(planta:PlantaPlex,ambiente:Dictionary,definicoes:Dictionary) -> void:
	var contagens:Dictionary={}
	for tipo in ["forno","geladeira","bancada_preparo","vaso_sanitario","pia_banheiro","mesa","cadeira","bancada_montagem_coelho","area_montagem_atracao","mesa_desenho_inclinada","terminal_ibm","armario_funcionarios","armario_limpeza","armario_utensilios","registradora","palco","maquina_fliperama","estante"]:contagens[tipo]=contar(planta,ambiente,tipo)
	var pesos:Dictionary={}
	var cadeiras_refeicao:=0
	var equipe:=0
	var relogios:=0
	var armarios:=int(contagens.armario_funcionarios)
	var mesas_trabalho:=0
	for id in ambiente.get("objetos",[]):
		var item:Dictionary=planta.objetos.get(id,{})
		if LugaresPlex.cadeira_refeicao(item):cadeiras_refeicao+=1
		var visual:=MobiliaPlex.visual(item) if not item.is_empty() else ""
		if visual.begins_with("oficina_vestiario_") or visual.begins_with("oficina_armario_metal_"):equipe+=1
		if visual=="amb_relogio_ponto":equipe+=1;relogios+=1
		if visual=="terminal_ibm" and int(item.get("sobre",-1))>=0 and corresponde(planta.objetos.get(ApoiosPlex.raiz(planta,int(item.id)),{}),"mesa"):mesas_trabalho+=1
	equipe+=armarios+int(contagens.terminal_ibm)
	contagens.mesa=maxi(0,int(contagens.mesa)-mesas_trabalho)
	if int(contagens.cadeira)>0 and (ambiente.get("marcas",[]).has("descanso") or armarios>0):pesos.descanso=45
	if int(contagens.vaso_sanitario)>0:pesos.banheiro=50+contagens.vaso_sanitario
	if int(contagens.forno)>0 or int(contagens.geladeira)>0 and int(contagens.bancada_preparo)>0:pesos.cozinha=35+contagens.forno*3+contagens.geladeira
	if int(contagens.bancada_montagem_coelho)>0 or int(contagens.mesa_desenho_inclinada)>0 or int(contagens.area_montagem_atracao)>0:pesos.oficina=38+contagens.bancada_montagem_coelho+contagens.mesa_desenho_inclinada
	if armarios>0:pesos.vestiario=(65 if int(contagens.forno)==0 and int(contagens.geladeira)==0 and int(contagens.bancada_preparo)==0 else 25)+armarios
	if int(contagens.terminal_ibm)>0:pesos.escritorio=20+contagens.terminal_ibm+(25 if relogios>0 or equipe>int(contagens.terminal_ibm) else 0)
	if int(contagens.registradora)>0:pesos.recepcao=26+contagens.registradora
	if int(contagens.mesa)>0 and cadeiras_refeicao>0 and (equipe==0 or int(contagens.mesa)>=3):pesos.salao=30+mini(12,int(contagens.mesa)*2)
	if equipe>0 and int(contagens.cadeira)>0 and not pesos.has("vestiario"):pesos.descanso=maxi(int(pesos.get("descanso",0)),40)
	if pesos.has("salao") and int(contagens.palco)>0:pesos.salao_festas=int(pesos.salao)+5
	elif int(contagens.palco)>0:pesos.apresentacoes=24+contagens.palco
	if int(contagens.maquina_fliperama)>0:pesos.jogos=25+contagens.maquina_fliperama
	if int(contagens.armario_limpeza)>0:pesos.limpeza=16+contagens.armario_limpeza
	if int(contagens.estante)>0:pesos.deposito=12+mini(6,int(contagens.estante))
	var utilitaria:=not pesos.has("cozinha") and not pesos.has("oficina") and not pesos.has("banheiro")
	if utilitaria and int(contagens.estante)>0 and int(contagens.armario_utensilios)+int(contagens.armario_limpeza)>0:pesos.deposito=70
	if utilitaria and int(contagens.armario_limpeza)>0 and int(contagens.estante)+int(contagens.armario_utensilios)>0:pesos.limpeza=72
	var inferida:="livre";var maior:=0
	for tipo in ORDEM:
		if int(pesos.get(tipo,0))>maior:inferida=tipo;maior=int(pesos[tipo])
	var marcas:Array=ambiente.get("marcas",[]);var explicitas:Array=marcas.filter(func(t):return definicoes.has(t))
	ambiente.tipo=inferida
	if explicitas.size()==1 and (inferida=="livre" or int(pesos.get(explicitas[0],0))>=maior):ambiente.tipo=explicitas[0]
	ambiente.conflito=explicitas.size()>1 and not explicitas.all(func(t):return t in ABERTAS)
	ambiente.funcoes=[ambiente.tipo]
	for tipo in ORDEM:
		if tipo!=ambiente.tipo and pesos.has(tipo) and not ambiente.funcoes.has(tipo):ambiente.funcoes.append(tipo)
	if ambiente.tipo in ["descanso","vestiario","banheiro","oficina","escritorio"]:
		ambiente.funcoes.erase("salao");ambiente.funcoes.erase("salao_festas")
	if ambiente.tipo=="vestiario" and int(contagens.cadeira)>0:ambiente.funcoes.append("descanso")
	var zona:=str(ambiente.get("zona",""))
	if zona!="" and definicoes.has(zona):
		ambiente.tipo=zona
		ambiente.funcoes=[zona]
		if zona=="salao":
			for tipo in COMPATIVEIS:
				if tipo!=zona and pesos.has(tipo) and not ambiente.funcoes.has(tipo):ambiente.funcoes.append(tipo)
static func aceita(ambiente:Dictionary,tipos:Array) -> bool:
	return tipos.is_empty() or tipos.any(func(tipo):return tipo in ambiente.get("funcoes",[ambiente.get("tipo","livre")]))
