class_name FestasRestaurantePlex
extends RefCounted

var jogo: Node
var espera:=0.0
var popup: ConfirmationDialog
var presente_atual: Dictionary={}
var referencia_ui: ReferenciaBairroPlex
static var volumes_bolo: Dictionary={}

func _init(cena: Node) -> void:
	jogo=cena

static func pendente(grupo: Dictionary) -> bool:
	return grupo.get("pedido_bolo",false) and grupo.get("festa_estado","")!="concluido"

func pedir(id: int, aniversario: bool=false) -> bool:
	var grupo: Dictionary=jogo.clientes.grupos.get(id,{})
	if grupo.is_empty() or grupo.estado!="visita" or int(grupo.get("mesa",-1))<0 or grupo.get("pedido_bolo",false): return false
	if aniversario and not ReputacaoClientesPlex.lugares(jogo,grupo):
		jogo.painel.mensagem("Reserve mesas e cadeiras suficientes para todos antes de comprar o bolo.")
		return false
	var preco:=12
	if jogo.servicos.saldo<preco:
		jogo.painel.mensagem("Saldo insuficiente para encomendar o bolo: $ 12.")
		return false
	jogo.servicos.saldo-=preco
	for pedido in jogo.servicos.aniversarios:
		if int(pedido.grupo)==id: pedido.estado="comprado"
	grupo.merge({"pedido_bolo":true,"aniversario":aniversario,"festa_estado":"pedido","bolo":-1,"bolo_ator":-1,"tempo_parabens":0.0,"sobremesas":{}},true)
	jogo.painel.mensagem("Aniversário registrado. O bolo será servido na mesa da família." if aniversario else "Pedido de bolo registrado para esta mesa.")
	return true

static func atribuir(servico: ServicosPlex, ator: PersonagemPlex) -> bool:
	if servico.recepcao==null or not (EquipePlex.permite(ator,"atendimento") or EquipePlex.permite(ator,"cozinha")): return false
	for grupo in servico.recepcao.clientes.grupos.values():
		if not pendente(grupo) or grupo.get("festa_estado","")!="pedido" or not servico.livre(int(grupo.mesa)): continue
		var slot:=ApoiosPlex.livre(servico.planta,int(grupo.mesa),"festa_bolo_aniversario")
		if slot<0: continue
		var dados: Dictionary={"familia":int(grupo.id),"slot":slot}
		var bolo: Dictionary=servico.planta.objetos.get(int(grupo.get("bolo",-1)),{})
		if not bolo.is_empty() and servico.livre(bolo.id):
			if servico.iniciar(ator,"Servir bolo",[servico.etapa(bolo.id,"pegar"),servico.etapa(int(grupo.mesa),"servir_bolo",.8,dados)],[bolo.id,int(grupo.mesa)]):
				grupo.festa_estado="preparando";grupo.bolo_ator=ator.identificador
				return true
		for bancada in servico.encontrar("bancada_preparo",["cozinha"]):
			if servico.iniciar(ator,"Preparar e servir bolo",[servico.etapa(bancada,"preparar_bolo",3.0,dados),servico.etapa(int(grupo.mesa),"servir_bolo",.8,dados)],[bancada,int(grupo.mesa)]):
				grupo.festa_estado="preparando";grupo.bolo_ator=ator.identificador
				return true
	return false

static func executar(servico: ServicosPlex, ator: PersonagemPlex, passo: Dictionary) -> bool:
	var grupo: Dictionary=servico.recepcao.clientes.grupos.get(int(passo.dados.familia),{}) if servico.recepcao!=null else {}
	if grupo.is_empty(): return false
	if passo.acao=="preparar_bolo":
		var tipo:="festa_bolo_aniversario" if grupo.get("aniversario",false) else "festa_bolo_redondo"
		var id:=servico.inventario.criar(tipo,ator.celula)
		servico.planta.objetos[id].festa_familia=int(grupo.id)
		grupo.bolo=id
		return servico.inventario.pegar(ator,id)
	if passo.acao=="servir_bolo":
		var id:=int(grupo.get("bolo",-1))
		if not servico.inventario.apoiar_item(ator,id,int(grupo.mesa),int(passo.dados.slot)): return false
		var bolo: Dictionary=servico.planta.objetos[id]
		bolo.porcoes=maxi(1,servico.recepcao.clientes.membros(grupo).size())
		bolo.porcoes_total=bolo.porcoes
		grupo.festa_estado="aguardando"
		return true
	return false

func prato(_pessoa: PersonagemPlex, mesa: int, slot: int) -> int:
	var p: PlantaPlex=jogo.planta
	for item in ApoiosPlex.filhos(p,mesa,slot):
		if item.tipo=="prato" and int(item.get("carregada_por",0))==0:
			for filho in ApoiosPlex.filhos(p,item.id):
				if filho.tipo=="restos_mesa": p.remover(filho.id)
			if ApoiosPlex.filhos(p,item.id).is_empty(): return int(item.id)
	for estante in jogo.servicos.estantes():
		for item in ApoiosPlex.filhos(p,estante):
			if item.tipo!="prato" or item.get("sujo",false) or not jogo.servicos.livre(item.id) or not ApoiosPlex.filhos(p,item.id).is_empty(): continue
			if ApoiosPlex.fixar(p,item.id,mesa,slot): return int(item.id)
	for estante in jogo.servicos.estantes():
		for item in ApoiosPlex.filhos(p,estante):
			if not PacotesPratosPlex.guardado(item) or int(item.get("quantidade",0))<=0 or not jogo.servicos.livre(item.id): continue
			var id:=PacotesPratosPlex.retirar(jogo.servicos.inventario,item.id,p.objetos[mesa].celula)
			if id>=0 and ApoiosPlex.fixar(p,id,mesa,slot): return id
	return -1

func confetes(grupo: Dictionary) -> void:
	var p: PlantaPlex=jogo.planta
	var mesa: Dictionary=p.objetos.get(int(grupo.mesa),{})
	if mesa.is_empty(): return
	var ocupadas:Array[Vector2i]=p.celulas(mesa.tipo,mesa.celula,mesa.rotacao)
	var candidatos:Array[Vector2i]=[]
	for c in ocupadas:
		for deslocamento in [Vector2i(-2,-1),Vector2i(2,1),Vector2i(-1,2),Vector2i(1,-2),Vector2i(-2,2),Vector2i(2,-2)]:
			var chao:Vector2i=c+deslocamento
			if candidatos.has(chao) or ocupadas.has(chao) or not TerrenoPlex.contem(p,chao) or not p.em(chao).is_empty():continue
			candidatos.append(chao)
	for c in candidatos.slice(0,8):
		var id:int=jogo.servicos.inventario.criar("festa_confetes_leves",c)
		p.objetos[id].solto=true;p.objetos[id].estado="colorido";p.objetos[id].festa_confete=true;p.objetos[id].limpeza_apos=jogo.servicos.tempo_servico+60.0
	p.alterada.emit()

func atualizar(delta: float) -> void:
	espera+=delta
	if espera<.5: return
	var dt:=espera
	espera=0.0
	for grupo in jogo.clientes.grupos.values():
		if grupo.get("aniversario_solicitado",false) and not grupo.get("pedido_bolo",false) and grupo.estado=="visita":
			grupo.espera_aniversario=float(grupo.get("espera_aniversario",0.0))+dt*CalendarioPlex.MINUTOS_POR_SEGUNDO
			if float(grupo.espera_aniversario)>120.0:recusar(int(grupo.id))
		if not grupo.get("desenho_avaliado",false) and grupo.get("estado","")=="visita":
			var criancas: Array=grupo.get("criancas",[])
			if not criancas.is_empty() and criancas.all(func(id): return is_instance_valid(jogo.clientes.ator(int(id))) and jogo.clientes.ator(int(id)).visita.get("comeu",false)):
				grupo.desenho_avaliado=true
				if posmod(int(grupo.id)+jogo.calendario.dias,3)==1:
					jogo.servicos.recompensas.append({"tipo":["festa_desenho_coelho","festa_desenho_casa","festa_desenho_estrelas"][posmod(int(grupo.id),3)]})
		if not pendente(grupo): continue
		if grupo.festa_estado=="preparando":
			if not jogo.servicos.trabalhos.has(int(grupo.get("bolo_ator",-1))): grupo.festa_estado="pedido"
			continue
		if grupo.festa_estado=="pedido": continue
		var bolo: Dictionary=jogo.planta.objetos.get(int(grupo.get("bolo",-1)),{})
		if bolo.is_empty(): grupo.festa_estado="pedido";continue
		var pessoas: Array=[]
		var prontos:=true
		for id in jogo.clientes.membros(grupo):
			var a: PersonagemPlex=jogo.clientes.ator(int(id))
			if not is_instance_valid(a): continue
			pessoas.append(a)
			var refeicao: Dictionary=jogo.servicos.pedido_por_id(int(a.visita.get("pedido",-1)))
			if refeicao.get("estado","")!="consumido": prontos=false;continue
			if jogo.servicos.trabalhos.has(a.identificador): prontos=false;continue
			var lugar:=AcompanhamentoVisitantesPlex.lugar(jogo.clientes,a,grupo)
			if lugar.is_empty() or not jogo.clientes.sentar(a,lugar): prontos=false
		if not prontos or pessoas.is_empty(): continue
		grupo.tempo_parabens=float(grupo.get("tempo_parabens",0.0))+dt
		if grupo.get("aniversario",false) and not grupo.get("confetes_criados",false):
			grupo.confetes_criados=true
			for a in pessoas:a.visita.humor_cliente="muito_feliz";a.emocao.exibir("confete");jogo.sistemas.baloes.exibir(a,"Parabéns!",3)
			confetes(grupo)
		if grupo.get("aniversario",false) and grupo.tempo_parabens>=4.0 and not grupo.get("repetiu_confetes",false):
			grupo.repetiu_confetes=true
			for a in pessoas:a.emocao.exibir("confete")
		if grupo.get("aniversario",false) and grupo.tempo_parabens<8.0:
			grupo.festa_estado="parabens"
			continue
		grupo.festa_estado="comendo"
		var todos:=true
		for a in pessoas:
			var chave:=str(a.identificador)
			var sobremesa: Dictionary=grupo.sobremesas.get(chave,{})
			if sobremesa.get("comeu",false): continue
			todos=false
			if sobremesa.is_empty():
				var lugar:=AcompanhamentoVisitantesPlex.lugar(jogo.clientes,a,grupo)
				if lugar.is_empty(): continue
				var base:=prato(a,int(lugar.mesa),int(lugar.slot))
				if base<0: continue
				var fatia: int=jogo.servicos.inventario.criar("festa_fatia_bolo_simples",a.celula)
				var slot_fatia:=ApoiosPlex.livre(jogo.planta,base,"festa_fatia_bolo_simples")
				if slot_fatia<0 or not ApoiosPlex.fixar(jogo.planta,fatia,base,slot_fatia): jogo.planta.remover(fatia);continue
				bolo.porcoes=maxi(0,int(bolo.porcoes)-1)
				jogo.planta.alterada.emit()
				grupo.sobremesas[chave]={"fatia":fatia,"prato":base,"tempo":4.0,"comeu":false}
			else:
				sobremesa.tempo=float(sobremesa.tempo)-dt
				if sobremesa.tempo<=0:
					jogo.planta.remover(int(sobremesa.fatia))
					var base: Dictionary=jogo.planta.objetos.get(int(sobremesa.prato),{})
					if not base.is_empty():
						base.sujo=true
						var restos: int=jogo.servicos.inventario.criar("restos_mesa",a.celula)
						if not ApoiosPlex.fixar(jogo.planta,restos,int(base.id),0): jogo.planta.remover(restos)
						elif grupo.get("debug_evento",false):jogo.planta.objetos[restos].debug_evento=true
					sobremesa.comeu=true
		if todos:
			for pedido in jogo.servicos.aniversarios:
				if int(pedido.grupo)==int(grupo.id):pedido.estado="encerrado"
			grupo.festa_estado="concluido"
			jogo.planta.remover(int(bolo.id))
	if not jogo.servicos.recompensas.is_empty() and not is_instance_valid(popup) and not jogo.terminal_ui.aberto(): mostrar_presente()

func mostrar_presente() -> void:
	presente_atual=jogo.servicos.recompensas[0]
	popup=ConfirmationDialog.new()
	popup.title="Um presente para o restaurante"
	popup.dialog_text="Você ganhou desenho! Deseja pendurar?"
	popup.ok_button_text="Sim"
	popup.cancel_button_text="Não"
	popup.theme=preload("res://scripts/interface/tema_hud.gd").criar()
	jogo.add_child(popup)
	popup.confirmed.connect(func(): responder(true))
	popup.canceled.connect(func(): responder(false))
	popup.close_requested.connect(func(): responder(false))
	popup.popup_centered(Vector2i(410,170))

func responder(aceitar: bool) -> void:
	if presente_atual.is_empty(): return
	var tipo:=str(presente_atual.tipo)
	jogo.servicos.recompensas.pop_front()
	presente_atual={}
	popup.queue_free()
	if aceitar:
		jogo.servicos.presentes.append(tipo)
		jogo.escolher_ferramenta(tipo)
		jogo.painel.mensagem("Escolha uma parede interna para pendurar. R gira; botão direito cancela. O desenho continua guardado nos pedidos.")

static func reservar_prato(servico: ServicosPlex, item_prato: Dictionary) -> bool:
	if servico.recepcao==null: return false
	var mesa:=int(item_prato.get("sobre",-1))
	return servico.recepcao.clientes.grupos.values().any(func(g): return pendente(g) and (int(g.get("mesa",-1))==mesa or g.get("mesas_extras",[]).has(mesa)))

static func recortar_bolo(volume: Dictionary, item: Dictionary) -> Dictionary:
	var total:=maxi(1,int(item.get("porcoes_total",1)))
	var porcoes:=clampi(int(item.get("porcoes",total)),0,total)
	if porcoes==total: return volume
	var chave:=str([volume.image,porcoes,total])
	if volumes_bolo.has(chave): return volumes_bolo[chave]
	var novo:=volume.duplicate()
	var pontos:=PackedVector3Array()
	var cores:=PackedColorArray()
	var faces:=PackedColorArray()
	var fracao:=float(porcoes)/float(total)
	for i in volume.pontos.size():
		var p: Vector3=volume.pontos[i]
		var z: float=(p.z-p.y*2.0)/3.0
		var u: float=(p.x+p.y+z)/64.0
		var v: float=(p.y+z-p.x)/64.0
		var angulo:=fposmod(atan2(v,u)+PI*.25,TAU)/TAU
		if porcoes==0 or angulo>=fracao: continue
		pontos.append(p);cores.append(volume.cores[i]);faces.append(volume.superficies[i])
	novo.pontos=pontos;novo.cores=cores;novo.superficies=faces
	volumes_bolo[chave]=novo
	return novo

func aberto() -> bool:
	return is_instance_valid(referencia_ui) and not referencia_ui.is_queued_for_deletion()

func abrir_referencia(tipo: String="") -> void:
	if aberto():referencia_ui.queue_free()
	referencia_ui=ReferenciaBairroPlex.new()
	jogo.add_child(referencia_ui)
	referencia_ui.configurar(jogo,tipo)
	jogo.arrastando=false

func solicitar_aniversario(grupo: Dictionary, convidados: int) -> void:
	var familia:=str(grupo.get("familia_bairro",""))
	var nome:=str(jogo.populacao.familias.get(familia,{}).get("nome","Família"))
	grupo.aniversario_solicitado=true;grupo.espera_aniversario=0.0
	jogo.servicos.aniversarios.append({"grupo":int(grupo.id),"nome":nome,"familia":familia,"convidados":convidados,"estado":"solicitado"})
	jogo.painel.mensagem("A família "+nome+" quer comemorar um aniversário! Consulte o livro de reservas ou abra Referência e satisfação em um prédio.")

func reservar(id: int) -> bool:
	var grupo: Dictionary=jogo.clientes.grupos.get(id,{})
	if grupo.is_empty() or grupo.estado!="visita" or not ReputacaoClientesPlex.lugares(jogo,grupo):
		jogo.painel.mensagem("Aguarde a família chegar à mesa e verifique os lugares para todos.")
		return false
	for pedido in jogo.servicos.aniversarios:
		if int(pedido.grupo)==id and pedido.estado=="solicitado":
			pedido.estado="reservado";grupo.espera_aniversario=0.0
			return true
	return false

func recusar(id: int) -> void:
	var grupo: Dictionary=jogo.clientes.grupos.get(id,{})
	if grupo.get("pedido_bolo",false):return
	grupo.aniversario_solicitado=false
	for pedido in jogo.servicos.aniversarios:
		if int(pedido.grupo)==id:pedido.estado="recusado"
