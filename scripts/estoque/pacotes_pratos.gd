class_name PacotesPratosPlex
extends RefCounted

static var cache: Dictionary={}
const DESENHOS=["festa_prato_papel_liso","festa_prato_papel_estrela"]
const CORES=["coral","amarelo","azul","verde","rosa","lilas","branco"]

static func eh(item: Dictionary) -> bool:
	return item.get("tipo","")=="caixa_utensilios"

static func guardado(item: Dictionary) -> bool:
	return eh(item) and bool(item.get("pratos_guardados",false))

static func preparar(item: Dictionary) -> void:
	if not eh(item): return
	if not item.has("desenhos_pratos"):
		var opcoes: Array=[]
		for desenho in DESENHOS:
			for cor in CORES: opcoes.append({"visual_prato":desenho,"cor_prato":cor})
		var sorteio:=RandomNumberGenerator.new()
		sorteio.seed=hash([item.id,item.get("compra",0),item.get("material_prato","ceramica")])
		for i in range(opcoes.size()-1,0,-1):
			var j:=sorteio.randi_range(0,i)
			var troca: Dictionary=opcoes[i];opcoes[i]=opcoes[j];opcoes[j]=troca
		var conteudo: Array=[]
		for i in maxi(0,int(item.get("quantidade",1))):
			conteudo.append(opcoes[i%opcoes.size()].duplicate() if item.get("material_prato","")=="papel" else {"visual_prato":"festa_prato_ceramica_raso","cor_prato":"padrao"})
		item.desenhos_pratos=conteudo
	item.quantidade=item.desenhos_pratos.size()
	item.erase("variante");item.erase("estado_visual")
	item.estado=CatalogoPlex.objetos.caixa_utensilios.get("estado_padrao","")

static func retirar(inventario: InventarioPlex, id: int, celula: Vector2i, avulso: bool=false) -> int:
	var caixa: Dictionary=inventario.planta.objetos.get(id,{})
	if not eh(caixa) or not guardado(caixa) and not avulso: return -1
	preparar(caixa)
	if int(caixa.quantidade)<=0: return -1
	var ficha: Dictionary=caixa.desenhos_pratos.pop_front()
	ficha=ficha.duplicate(true)
	ficha.material_prato=caixa.get("material_prato","ceramica")
	var prato:=PratosPlex.criar(inventario,ficha,celula)
	inventario.planta.objetos[prato].pacote_origem=id
	caixa.quantidade=caixa.desenhos_pratos.size()
	if caixa.quantidade==0 and (ficha.material_prato=="papel" or not guardado(caixa)): inventario.planta.remover(id)
	else: inventario.planta.alterada.emit()
	return prato

static func receber_passo(servico: ServicosPlex, ator: PersonagemPlex, passo: Dictionary, trabalho: Dictionary) -> bool:
	var caixa: Dictionary=servico.planta.objetos.get(passo.alvo,{})
	if not eh(caixa) or int(caixa.get("quantidade",0))<=0: return false
	if ator.carga_item>=0 and (not ator.carga_extra.is_empty() or servico.planta.objetos.get(ator.carga_item,{}).get("tipo","")!="prato"): return false
	var id:=retirar(servico.inventario,passo.alvo,ator.celula,true)
	if id<0: return false
	if not servico.inventario.pegar(ator,id): return false
	servico.planta.objetos[id].reserva=ator.identificador
	trabalho.reservas.append(id)
	for proximo in trabalho.passos:
		if int(proximo.dados.get("indice_prato",-1))==int(passo.dados.indice_prato): proximo.dados.prato=id
	var pedido:=servico.pedido_por_id(int(passo.dados.pedido))
	if not pedido.is_empty(): pedido.prato=id
	return true

static func destino(planta: PlantaPlex, prato: Dictionary) -> Dictionary:
	var pacote: Dictionary=planta.objetos.get(int(prato.get("pacote_origem",-1)),{})
	if not guardado(pacote) or prato.get("material_prato","")!="ceramica" or int(pacote.get("carregada_por",0))>0: return {}
	if int(pacote.get("quantidade",0))>=6:return {}
	var pai:=int(pacote.get("sobre",-1))
	if CatalogoPlex.base(planta.objetos.get(pai,{}).get("tipo","")) not in ["estante","armario_utensilios"]: return {}
	return {"pai":pai,"slot":int(pacote.slot)}

static func devolver(inventario: InventarioPlex, ator: PersonagemPlex, id: int, pai: int, slot: int) -> bool:
	var prato: Dictionary=inventario.planta.objetos.get(id,{})
	if prato.get("tipo","")!="prato" or prato.get("sujo",false) or not ApoiosPlex.filhos(inventario.planta,id).is_empty(): return false
	var retorno:=destino(inventario.planta,prato)
	if retorno.is_empty() or retorno.pai!=pai or retorno.slot!=slot: return false
	var pacote: Dictionary=inventario.planta.objetos[int(prato.pacote_origem)]
	preparar(pacote)
	if int(pacote.quantidade)>=6:return false
	pacote.desenhos_pratos.append({"visual_prato":MobiliaPlex.visual(prato),"cor_prato":MobiliaPlex.estado(prato)})
	pacote.quantidade=pacote.desenhos_pratos.size()
	if ator.carga_item==id: ator.carga_item=ator.carga_extra.pop_front() if not ator.carga_extra.is_empty() else -1
	else: ator.carga_extra.erase(id)
	inventario.planta.remover(id)
	return true

static func volume(item: Dictionary, rotacao: int) -> Dictionary:
	preparar(item)
	var chave:=str([rotacao,item.desenhos_pratos])
	if cache.has(chave): return cache[chave]
	var pontos:=PackedVector3Array()
	var cores:=PackedColorArray()
	var faces:=PackedColorArray()
	var n:=mini(10,item.desenhos_pratos.size())
	for i in n:
		var ficha: Dictionary=item.desenhos_pratos[i]
		var v:=GeometriaPlex.obter(str(ficha.visual_prato),rotacao,4,0,false,str(ficha.cor_prato))
		var elevacao:=i*.55
		for k in v.pontos.size():
			var p: Vector3=v.pontos[k]
			var z: float=(p.z-p.y*2.0)/3.0+elevacao
			p.y=roundf(p.y-elevacao);p.z=p.y*2.0+z*3.0
			pontos.append(p);cores.append(v.cores[k]);faces.append(v.superficies[k])
	var resultado: Dictionary={"pontos":pontos,"cores":cores,"superficies":faces,"origin":[-96,-144],"image":"pilha:"+str(hash(chave))}
	resultado.textura=ItensPlex.compor([{"volume":resultado}]).textura
	if cache.size()>=64: cache.erase(cache.keys()[0])
	cache[chave]=resultado
	return resultado

static func parcial(planta:PlantaPlex,material:String,pai:int=-1) -> Dictionary:
	if material!="ceramica":return {}
	for item in planta.objetos.values():
		if not guardado(item) or str(item.get("material_prato","ceramica"))!=material or int(item.get("quantidade",0))>=6 or int(item.get("carregada_por",0))>0:continue
		var estante:=int(item.get("sobre",-1))
		if pai>=0 and estante!=pai:continue
		if CatalogoPlex.base(str(planta.objetos.get(estante,{}).get("tipo",""))) in ["estante","armario_utensilios"]:return item
	return {}
static func unir(planta:PlantaPlex,id:int,pai:int) -> bool:
	var item:Dictionary=planta.objetos.get(id,{})
	if not eh(item) or str(item.get("material_prato","ceramica"))!="ceramica":return false
	var pilha_destino:=parcial(planta,"ceramica",pai)
	if pilha_destino.is_empty() or int(pilha_destino.id)==id:return false
	preparar(item);preparar(pilha_destino)
	if int(item.quantidade)>6-int(pilha_destino.quantidade):return false
	pilha_destino.desenhos_pratos.append_array(item.desenhos_pratos);pilha_destino.quantidade=pilha_destino.desenhos_pratos.size();planta.objetos.erase(id)
	planta.reindexar();planta.alterada.emit();return true
static func compactar(planta:PlantaPlex) -> void:
	var grupos:Dictionary={};var mudou:=false
	for pacote in planta.objetos.values():
		if not guardado(pacote) or str(pacote.get("material_prato","ceramica"))!="ceramica":continue
		var pai:=int(pacote.get("sobre",-1))
		if pai<0:continue
		preparar(pacote)
		if not grupos.has(pai):grupos[pai]=[]
		grupos[pai].append(pacote)
	for lista in grupos.values():
		for i in lista.size():
			var pilha_destino:Dictionary=lista[i]
			if not planta.objetos.has(pilha_destino.id):continue
			for j in range(i+1,lista.size()):
				var outro:Dictionary=lista[j]
				if not planta.objetos.has(outro.id):continue
				while int(pilha_destino.quantidade)<6 and not outro.desenhos_pratos.is_empty():
					pilha_destino.desenhos_pratos.append(outro.desenhos_pratos.pop_front());pilha_destino.quantidade=pilha_destino.desenhos_pratos.size();outro.quantidade=outro.desenhos_pratos.size();mudou=true
				if int(outro.quantidade)==0:planta.objetos.erase(outro.id)
	if mudou:planta.reindexar();planta.alterada.emit()
