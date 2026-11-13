class_name OficinaRobosPlex
extends RefCounted

var jogo:Node
var espera:=0.0
static var imagens:Dictionary={}
static var volumes:Dictionary={}
func _init(cena:Node) -> void:jogo=cena
static func funcional(r:PersonagemPlex) -> int:return clampi(roundi((1.0-float(r.robotica.get("desgaste",0))*.5)*100),0,100)
static func controlado(r:PersonagemPlex) -> bool:return r.visita.has("controle_animatronico") or r.visita.has("controle_largado") or r.visita.has("mec_noturno") or r.visita.has("oficina_robo") or r.visita.has("diagnostico_animacao") or r.visita.has("diagnostico_rota") or float(r.robotica.get("bateria",100))<=0
func base_livre(p:Dictionary,r:PersonagemPlex=null) -> bool:
	if p.get("tipo","")!="area_montagem_atracao" or not TerrenoPlex.contem(jogo.planta,p.celula) or not jogo.planta.transitavel(p.celula):return false
	var id:=r.identificador if is_instance_valid(r) else -1
	var reserva:=int(p.get("robo_reserva",-1))
	if reserva>0 and reserva!=id and is_instance_valid(jogo.clientes.ator(reserva)):return false
	if jogo.atracoes.fila.any(func(o):return int(o.ponto)==int(p.id) and int(o.get("robo",-2))!=id):return false
	return not jogo.personagens.any(func(a):return a!=r and a.local.distance_to(Vector2(p.celula))<.75)
func vaga(r:PersonagemPlex,com_mesa:bool=false,com_carga:bool=false) -> Dictionary:
	jogo.ambientes.atualizar();jogo.rotas.reconstruir()
	var lista:Array=jogo.planta.objetos.values().filter(func(p):return base_livre(p,r))
	lista.sort_custom(func(a,b):return Vector2(a.celula).distance_squared_to(r.local)<Vector2(b.celula).distance_squared_to(r.local))
	for p in lista:
		if com_carga and carregador(p).is_empty():continue
		var mesa:=mesa_ajuste(r,p) if com_mesa else -1
		if com_mesa and mesa<0:continue
		var rota:Array[Vector2i]=jogo.rotas.caminho(r.origem_rota(),p.celula)
		if not rota.is_empty():return {"base":p.id,"mesa":mesa,"rota":rota}
	return {}
func mesa_ajuste(r:PersonagemPlex,base:Dictionary) -> int:
	var sala:Dictionary=jogo.ambientes.do_objeto(int(base.id))
	var lista:Array=jogo.planta.objetos.values().filter(func(p):return p.tipo in [MontagemAtracoesPlex.BANCADA,"oficina_bancada_trabalho"] and jogo.atracoes.ordem(int(p.id)).is_empty() and int(p.get("reparo_reserva",r.identificador))==r.identificador and ApoiosPlex.filhos(jogo.planta,int(p.id)).is_empty())
	lista.sort_custom(func(a,b):return Vector2(a.celula).distance_squared_to(Vector2(base.celula))<Vector2(b.celula).distance_squared_to(Vector2(base.celula)))
	for p in lista:
		if jogo.ambientes.do_objeto(int(p.id)).get("id",-1)!=sala.get("id",-2) or jogo.rotas.aproximar(base.celula,int(p.id)).is_empty():continue
		return int(p.id)
	return -1
func liberar_palco(r:PersonagemPlex) -> void:
	if r.pose>=0:r.visita.palco_anterior=r.pose
	var p:Dictionary=jogo.planta.objetos.get(r.pose,{})
	if int(p.get("dono",-1))==r.identificador:p.dono=-1
	for ordem in jogo.atracoes.fila.duplicate():
		if int(ordem.get("robo",-1))==r.identificador and ordem.fase in ["seta","caminhando"]:jogo.atracoes.fila.erase(ordem)
	for chave in ["aguarda_seta","montagem_olhar_jogador","montagem_rotacao","bancada_montagem","recolhendo_deposito","destino_deposito"]:r.visita.erase(chave)
	r.pose=-1;r.suporte=-1;r.automatico=false;AnimatronicosPlex.garantir(r);r.robotica.desligado_manual=true
func recolher(r:PersonagemPlex,modo:String="deposito",silencioso:bool=false) -> bool:
	if not is_instance_valid(r) or not r.robo or r.visita.get("montando_atracao",false):return false
	if r.visita.has("oficina_robo"):
		if modo=="deposito":return false
		var atual:Dictionary=r.visita.oficina_robo
		if atual.get("modo","")=="deposito" and atual.get("etapa","")=="estacionado":
			var base:Dictionary=jogo.planta.objetos.get(int(atual.base),{});var mesa:=mesa_ajuste(r,base)
			if mesa<0:jogo.painel.mensagem("A bancada de ajustes precisa estar livre e acessível.");return false
			atual.modo=modo;atual.mesa=mesa;atual.etapa="espera_remover";jogo.planta.objetos[mesa].reparo_reserva=r.identificador;return true
		return false
	var reparo:=modo in ["olhos","estrutura"]
	var destino:=vaga(r,reparo,modo=="carga")
	if destino.is_empty():
		if not silencioso:jogo.painel.mensagem("Não há base cinza de construção livre e acessível"+(" com bancada de ajustes disponível." if reparo else " com carregador próximo." if modo=="carga" else "."))
		return false
	if float(r.robotica.get("bateria",100))<=0 and r.celula!=jogo.planta.objetos[int(destino.base)].celula:
		if not silencioso:jogo.painel.mensagem("O robô está sem carga para caminhar.")
		return false
	liberar_palco(r)
	jogo.planta.objetos[int(destino.base)].robo_reserva=r.identificador
	if reparo:jogo.planta.objetos[int(destino.mesa)].reparo_reserva=r.identificador
	r.visita.oficina_robo={"base":int(destino.base),"mesa":int(destino.mesa),"modo":modo,"etapa":"indo","tempo":0.0,"ator":-1,"pecas":[]}
	r.andar(destino.rota);r.trabalho="ir_oficina_robo";return true
func voltar(r:PersonagemPlex) -> bool:
	var d:Dictionary=r.visita.get("oficina_robo",{})
	if not d.is_empty() and d.get("etapa","") not in ["estacionado","indo"]:return false
	if float(r.robotica.get("bateria",100))<=0:return false
	var pose:=int(r.visita.get("palco_anterior",-1))
	if not jogo.planta.objetos.has(pose) or not jogo.poses.livre(pose,r) or jogo.rotas.caminho(r.origem_rota(),jogo.planta.objetos[pose].celula).is_empty():jogo.painel.mensagem("O lugar anterior no palco está ocupado ou sem acesso. Use Redefinir lugar.");return false
	if not jogo.atracoes.definir_pose(r.identificador,pose):return false
	liberar_reservas(r);r.visita.erase("oficina_robo");r.visita.erase("diagnostico_animacao");r.visita.erase("diagnostico_rota");return true
func liberar_reservas(r:PersonagemPlex) -> void:
	for p in jogo.planta.objetos.values():
		for campo in ["robo_reserva","reparo_reserva","carga_robo"]:
			if int(p.get(campo,-1))==r.identificador:
				if campo=="carga_robo":p.estado="enrolado"
				p.erase(campo)
func opcoes(menu:CanvasLayer,r:PersonagemPlex) -> void:
	if r.visita.get("montando_atracao",false):return
	var d:Dictionary=r.visita.get("oficina_robo",{})
	if d.is_empty() or d.get("modo","")=="deposito":menu.adicionar("Consertar",func():recolher(r,"olhos" if r.modelo==MontagemAtracoesPlex.MODELO else "estrutura"))
	if d.is_empty():menu.adicionar("Recolher ao depósito",func():recolher(r))
	elif d.get("etapa","") in ["indo","estacionado"]:menu.adicionar("Voltar ao palco",func():voltar(r))
	var etapa:=str(d.get("etapa",""))
	if etapa=="espera_remover":menu.adicionar("Remover cabeça" if d.modo=="olhos" else "Remover fantasia e plástico",func():acao_reparo(r,"remover"))
	elif etapa in ["espera_consertar","minigame_olhos"]:menu.adicionar("Consertar olhos na bancada" if d.modo=="olhos" else "Consertar estrutura na bancada",func():acao_reparo(r,"consertar"))
	elif etapa=="espera_plastico":menu.adicionar("Recolocar plástico da cabeça" if d.modo=="olhos" else "Recolocar plásticos",func():acao_reparo(r,"repor_plastico"))
	elif etapa=="espera_cabeca":menu.adicionar("Recolocar cabeça" if d.modo=="olhos" else "Recolocar fantasia",func():acao_reparo(r,"repor_cabeca"))
func carregador(base:Dictionary) -> Dictionary:
	if base.is_empty():return {}
	var sala:Dictionary=jogo.ambientes.do_objeto(int(base.id))
	for p in jogo.planta.objetos.values():
		if p.tipo!="amb_carregador_oficina" or Vector2(p.celula).distance_to(Vector2(base.celula))>2.5:continue
		if jogo.ambientes.do_objeto(int(p.id)).get("id",-1)!=sala.get("id",-2) or not VisaoNPCPlex.linha(jogo.planta,Vector2(p.celula),Vector2(base.celula)):continue
		var dono:=int(p.get("carga_robo",-1))
		if dono>0 and dono!=int(base.get("robo_reserva",-2)) and is_instance_valid(jogo.clientes.ator(dono)):continue
		return p
	return {}
func acao_reparo(r:PersonagemPlex,acao:String) -> bool:
	var d:Dictionary=r.visita.get("oficina_robo",{})
	var proximas:Dictionary={"espera_remover":"remover","espera_consertar":"consertar","minigame_olhos":"consertar","espera_plastico":"repor_plastico","espera_cabeca":"repor_cabeca"}
	if proximas.get(d.get("etapa",""),"")!=acao:return false
	if acao=="consertar" and d.get("modo","")=="olhos":
		liberar_operario(d);d.etapa="minigame_olhos"
		if not d.has("ordem_minigame"):d.ordem_minigame={"oficina_reparo":r.identificador,"modelo":r.modelo,"minigame_pendente":"olhos","minigame_estado":{}}
		jogo.atracoes.abrir_reparo_olhos(d.ordem_minigame);return true
	d.etapa=acao;d.tempo=0.0;d.ator=-1;d.manual=-1
	var admin:PersonagemPlex=jogo.controle.administrador()
	if jogo.controle.manual() and is_instance_valid(admin):
		jogo.controle.cancelar_acao();jogo.controle.interromper(admin);d.ator=admin.identificador;d.manual=admin.identificador;admin.visita.obra_atracao=true;admin.visita.oficina_trabalho=true
	return true
func concluir_olhos(o:Dictionary) -> bool:
	var r:PersonagemPlex=jogo.clientes.ator(int(o.get("oficina_reparo",-1)))
	if not is_instance_valid(r):return false
	var d:Dictionary=r.visita.get("oficina_robo",{})
	if d.get("etapa","")!="minigame_olhos" or d.get("modo","")!="olhos":return false
	d.etapa="espera_plastico";d.olhos_consertados=true;o.minigame_pendente="";o.minigame_estado={};jogo.planta.alterada.emit();return true
func operario(d:Dictionary,alvo:int) -> PersonagemPlex:
	var a:PersonagemPlex=jogo.clientes.ator(int(d.get("ator",-1)))
	if is_instance_valid(a) and (a.visita.get("fora_turno",false) or a.visita.get("morto",false) or TurnosEquipePlex.ocupado(a) or a.visita.get("controle_manual",false) and int(d.get("manual",-1))!=a.identificador):liberar_operario(d);a=null
	if is_instance_valid(a):a.visita.obra_atracao=true;a.visita.oficina_trabalho=true;return a
	for p in jogo.personagens:
		if not jogo.atracoes.disponivel(p) or jogo.rotas.aproximar(p.origem_rota(),alvo).is_empty():continue
		d.ator=p.identificador;p.visita.obra_atracao=true;p.visita.oficina_trabalho=true;return p
	return null
func liberar_operario(d:Dictionary) -> void:
	var a:PersonagemPlex=jogo.clientes.ator(int(d.get("ator",-1)))
	if is_instance_valid(a):a.visita.erase("obra_atracao");a.visita.erase("oficina_trabalho");a.trabalho="";a.progresso_acao=0.0
	d.ator=-1
func remover(r:PersonagemPlex) -> void:
	levantar_fantasia(r)
	var d:Dictionary=r.visita.get("oficina_robo",{})
	if not d.is_empty():
		liberar_operario(d)
		for id in d.get("pecas",[]):
			if int(jogo.planta.objetos.get(int(id),{}).get("reparo_robo",-1))==r.identificador:jogo.planta.remover(int(id))
	liberar_reservas(r)
static func estado_bancada(r:PersonagemPlex) -> String:
	var nome:="patitas" if r.modelo.contains("patitas") else "orelhitas"
	if r.modelo.contains("toy"):nome="toy_"+nome
	if r.robotica.get("ensanguentado",false):nome+="_quebrado"
	return nome
func sentar_fantasia(r:PersonagemPlex,d:Dictionary) -> void:
	var mesa:Dictionary=jogo.planta.objetos.get(int(d.mesa),{})
	if mesa.is_empty():return
	mesa.fantasia_bancada=estado_bancada(r);mesa.fantasia_robo=r.identificador
	jogo.planta.alterada.emit()
func levantar_fantasia(r:PersonagemPlex) -> void:
	for p in jogo.planta.objetos.values():
		if int(p.get("fantasia_robo",-1))==r.identificador:p.erase("fantasia_bancada");p.erase("fantasia_robo")
	jogo.planta.alterada.emit()
func ataque_bancada(r:PersonagemPlex,a:PersonagemPlex) -> void:
	r.robotica.ensanguentado=true
	jogo.sistemas.cartazes.morte(a.celula)
	jogo.sistemas.investigacao.registrar_incidente(a)
	jogo.sistemas.jornal.noticiar("Funcionário da pizzaria desaparece na oficina.")
	jogo.painel.mensagem("O animatrônico quebrado atacou "+IdentidadesPlex.completo(a)+" na oficina. Só restou o sangue na fantasia.")
	for p in jogo.planta.objetos.values():
		if int(p.get("fantasia_robo",-1))==r.identificador:p.fantasia_bancada=estado_bancada(r)
	a.visita.erase("obra_atracao");a.visita.erase("oficina_trabalho")
	jogo.despawn(a)
	jogo.planta.alterada.emit()
func pecas(r:PersonagemPlex,d:Dictionary) -> void:
	var mesa:Dictionary=jogo.planta.objetos.get(int(d.mesa),{})
	if d.modo=="estrutura":
		sentar_fantasia(r,d)
		return
	for i in 2:
		var tipo:="ajuste_cabeca_olhos" if i==0 else "ajuste_cabeca_plastico"
		if d.modo=="estrutura":tipo="ajuste_estrutura_fantasia" if i==0 else "ajuste_estrutura_plastico"
		var id:int=jogo.planta.inserir(tipo,mesa.celula,int(mesa.rotacao),{"pai":mesa.id,"slot":i},{"reparo_robo":r.identificador,"modelo_reparo":r.modelo})
		d.pecas.append(id)
func retirar_peca(d:Dictionary,tipo:String) -> void:
	for id in d.pecas.duplicate():
		if jogo.planta.objetos.get(int(id),{}).get("tipo","")==tipo:jogo.planta.remover(int(id));d.pecas.erase(id)
func atualizar_reparo(r:PersonagemPlex,d:Dictionary,dt:float) -> void:
	var etapa:=str(d.etapa)
	if etapa.begins_with("espera_") or etapa in ["estacionado","minigame_olhos"]:return
	var mesa:Dictionary=jogo.planta.objetos.get(int(d.mesa),{})
	var base:Dictionary=jogo.planta.objetos.get(int(d.base),{})
	if mesa.is_empty() or base.is_empty():liberar_operario(d);return
	var alvo:=int(d.mesa) if etapa=="consertar" else int(d.base)
	var a:=operario(d,alvo)
	if not is_instance_valid(a) or a.ocupado():return
	if not jogo.planta.interacoes(alvo).has(a.celula):
		var rota:Array[Vector2i]=jogo.rotas.aproximar(a.origem_rota(),alvo)
		if not rota.is_empty():a.andar(rota);a.trabalho="ir_montar_atracao"
		return
	jogo.tarefas.orientar(a,Vector2(jogo.planta.objetos[alvo].celula));jogo.tarefas.orientar_cardinal(r,a.local);a.trabalho="montar";d.tempo=float(d.tempo)+dt*HabilidadesEquipePlex.fator(a,"manutencao");a.progresso_acao=fposmod(float(d.tempo)/2.4,1)
	if CatalogoMontagemPlex.quebrado(r.modelo) and jogo.sistemas.mecanico.possuido(r) and not d.get("atacou",false) and randf()<dt*.01:
		d.atacou=true;liberar_operario(d);ataque_bancada(r,a);return
	if float(d.tempo)<(12.0 if etapa=="consertar" else 4.0):return
	liberar_operario(d);d.tempo=0.0
	match etapa:
		"remover":
			if d.modo=="estrutura":r.visita.montagem_passos=17
			else:r.visita.reparo_sem_cabeca=true
			pecas(r,d);d.etapa="espera_consertar"
		"consertar":d.etapa="espera_plastico"
		"repor_plastico":
			retirar_peca(d,"ajuste_estrutura_plastico" if d.modo=="estrutura" else "ajuste_cabeca_plastico");d.etapa="espera_cabeca"
			if d.modo=="estrutura":r.visita.montagem_passos=34
		"repor_cabeca":
			retirar_peca(d,"ajuste_estrutura_fantasia" if d.modo=="estrutura" else "ajuste_cabeca_olhos");r.visita.erase("reparo_sem_cabeca");r.visita.erase("montagem_passos");levantar_fantasia(r)
			r.robotica.desgaste=0.0;r.robotica.avariado=false;r.robotica.manutencao_solicitada=false;r.robotica.reparos=int(r.robotica.get("reparos",0))+1;d.etapa="estacionado";d.modo="deposito";r.trabalho="armazenado"
			mesa.erase("reparo_reserva")
	jogo.planta.alterada.emit()
func atualizar(delta:float) -> void:
	espera+=delta
	if espera<.2:return
	var dt:=espera;espera=0.0
	for r in jogo.personagens:
		if not r.robo or not AtracoesCatalogoPlex.permitido(r.modelo):continue
		AnimatronicosPlex.garantir(r)
		if not r.robotica.has("bateria"):r.robotica.bateria=100.0
		if r.robotica.get("armazenado",false) or r.visita.get("indo_armazem",false):continue
		var d:Dictionary=r.visita.get("oficina_robo",{})
		if r.visita.has("diagnostico_animacao") or r.visita.has("diagnostico_rota"):
			r.visita.diagnostico_tempo=float(r.visita.get("diagnostico_tempo",0))+dt
			if r.visita.has("diagnostico_rota") and not r.ocupado():
				var p:Dictionary=r.visita.diagnostico_rota;var dados:Array=p.fim if p.get("ida",true) else p.inicio;var rota:Array[Vector2i]=jogo.rotas.caminho(r.origem_rota(),Vector2i(dados[0],dados[1]))
				if not rota.is_empty():r.andar(rota);p.ida=not p.get("ida",true)
		if not r.visita.get("montando_atracao",false) and not r.visita.has("controle_animatronico") and (r.ocupado() or str(r.robotica.estado) in ["ligado","ativando"]):r.robotica.bateria=maxf(0,float(r.robotica.bateria)-dt*(.12 if r.ocupado() else .045))
		if float(r.robotica.bateria)<=0:
			r.movimento.cancelar();r.robotica.desligado_manual=true;AnimatronicosPlex.mudar(r,"desligado")
		if d.is_empty():
			if float(r.robotica.bateria)>0 and float(r.robotica.bateria)<=12 and not r.visita.get("montando_atracao",false):
				r.visita.carga_tentativa=float(r.visita.get("carga_tentativa",0))-dt
				if float(r.visita.carga_tentativa)<=0:
					r.visita.carga_tentativa=5.0
					if not recolher(r,"carga",true):r.movimento.cancelar();r.robotica.desligado_manual=true;AnimatronicosPlex.mudar(r,"desligado");r.trabalho="aguardar_carga"
			continue
		var base:Dictionary=jogo.planta.objetos.get(int(d.base),{})
		if base.is_empty():liberar_operario(d);continue
		base.robo_reserva=r.identificador
		if d.etapa=="indo":
			if r.ocupado():continue
			if r.celula!=base.celula:
				if float(r.robotica.bateria)>0:
					var rota:Array[Vector2i]=jogo.rotas.caminho(r.origem_rota(),base.celula)
					if not rota.is_empty():r.andar(rota)
				continue
			d.etapa="espera_remover" if d.modo in ["olhos","estrutura"] else "estacionado";r.trabalho="armazenado";r.direcao=GradePlex.direcao_suporte(int(base.rotacao));AnimatronicosPlex.mudar(r,"desligado")
		if d.etapa=="estacionado" and r.celula==base.celula:
			var carga:=carregador(base)
			if not carga.is_empty() and jogo.iluminacao.rede.fator>.05 and float(r.robotica.bateria)<100:
				carga.carga_robo=r.identificador;carga.estado="carregando";r.robotica.bateria=minf(100,float(r.robotica.bateria)+dt*.35);r.trabalho="carregando_bateria"
				if float(r.robotica.bateria)>=100:carga.estado="enrolado";carga.erase("carga_robo");r.trabalho="armazenado"
			elif not carga.is_empty():carga.estado="desligado";carga.erase("carga_robo")
		elif d.modo in ["olhos","estrutura"]:atualizar_reparo(r,d,dt)
static func parte_cabeca(modelo:String,tipo:String) -> Image:
	var chave:=modelo+":"+tipo
	if imagens.has(chave):return imagens[chave]
	var pasta:="res://assets/sistemas/vi/"+("patitas" if modelo=="vi_patitas" else "orelhitas")+"/"
	var fonte:=pasta+("plastico/0.png" if tipo=="plastico" else "endo/0.png" if tipo=="olhos" else "fantasia/0.png")
	var im:=CatalogoPlex.imagem(fonte).get_region(Rect2i(0,0,64,100))
	if tipo=="plastico":
		var interno:=CatalogoPlex.imagem(pasta+"endo/0.png")
		for y in im.get_height():
			for x in im.get_width():
				if im.get_pixel(x,y).is_equal_approx(interno.get_pixel(x,y)):im.set_pixel(x,y,Color.TRANSPARENT)
	for y in im.get_height():
		for x in im.get_width():
			if y>=43 or y>=39 and (x<20 or x>44):im.set_pixel(x,y,Color.TRANSPARENT)
	im=im.get_region(im.get_used_rect());imagens[chave]=im;return im
static func volume_cabeca(item:Dictionary) -> Dictionary:
	var modelo:=str(item.get("modelo_reparo",MontagemAtracoesPlex.MODELO));var estrutura:=str(item.tipo).begins_with("ajuste_estrutura_");var tipo:=str(item.tipo).trim_prefix("ajuste_estrutura_" if estrutura else "ajuste_cabeca_");var chave:=modelo+":"+tipo+str(estrutura)
	if volumes.has(chave):return volumes[chave]
	var im:=parte_cabeca(modelo,tipo)
	if estrutura:
		var pasta:="res://assets/sistemas/vi/"+("patitas" if modelo=="vi_patitas" else "orelhitas")+"/"
		im=CatalogoPlex.imagem(pasta+("plastico" if tipo=="plastico" else "fantasia")+"/0.png").duplicate()
		var interno:=CatalogoPlex.imagem(pasta+("endo" if tipo=="plastico" else "plastico")+"/0.png")
		for y in im.get_height():
			for x in im.get_width():
				if im.get_pixel(x,y).is_equal_approx(interno.get_pixel(x,y)):im.set_pixel(x,y,Color.TRANSPARENT)
		im=im.get_region(im.get_used_rect());im.resize(maxi(1,roundi(im.get_width()*.55)),maxi(1,roundi(im.get_height()*.55)),Image.INTERPOLATE_NEAREST)
	var origem:=[int(-im.get_width()/2.0),-im.get_height()];var pontos:=PackedVector3Array();var cores:=PackedColorArray();var normais:=PackedColorArray()
	for y in im.get_height():
		for x in im.get_width():
			var cor:=im.get_pixel(x,y)
			if cor.a>0:pontos.append(Vector3(x+origem[0],y+origem[1],maxf(0,im.get_height()-y)));cores.append(cor);normais.append(Color(.5,.5,1,.2))
	var d:Dictionary={"image":"ajuste_cabeca:"+chave,"origin":origem,"textura":ImageTexture.create_from_image(im),"pontos":pontos,"cores":cores,"superficies":normais};volumes[chave]=d;return d
static func visual(r:PersonagemPlex) -> bool:
	if not r.visita.get("reparo_sem_cabeca",false) or r.visita.has("montagem_passos"):return false
	var rotacao:=posmod(floori(float(GradePlex.direcao_visual(r.direcao))/2),4);var chave:=r.modelo+":sem_cabeca:"+str(rotacao)
	if not imagens.has(chave):
		var q:=ClipesPlex.quadro(r.modelo,"desligado",rotacao*2,0,0);var im:=CatalogoPlex.imagem(q.arquivo).get_region(q.regiao)
		var ox:=(im.get_width()-64)/2.0;var oy:=float(im.get_height()-100)
		for y in mini(43+roundi(oy),im.get_height()):
			for x in im.get_width():
				if y<39+oy or x>=20+ox and x<=44+ox:im.set_pixel(x,y,Color.TRANSPARENT)
		imagens[chave]=ImageTexture.create_from_image(im)
	var atlas:AtlasTexture=r.animacao.atlases.modelo;atlas.atlas=imagens[chave];atlas.region=Rect2(Vector2.ZERO,imagens[chave].get_size());r.animacao.arquivos.modelo=chave;return true
