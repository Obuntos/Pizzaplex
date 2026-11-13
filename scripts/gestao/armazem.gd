class_name ArmazemRobosPlex
extends RefCounted

const PAR={"novo_coelho_detalhes":"vi_toy_orelhitas","vi_toy_orelhitas":"novo_coelho_detalhes","vi_patitas":"vi_toy_patitas","vi_toy_patitas":"vi_patitas"}
const DEITADOS=["vi_toy_orelhitas_quebrado"]
const ANTIGOS=["novo_coelho_detalhes","vi_patitas"]
const QUEBRADO={"novo_coelho_detalhes":"vi_orelhitas_quebrado","vi_toy_orelhitas":"vi_toy_orelhitas_quebrado","vi_patitas":"vi_patitas_quebrado","vi_toy_patitas":"vi_toy_patitas_quebrado"}
const INTEIRO={"vi_orelhitas_quebrado":"novo_coelho_detalhes","vi_toy_orelhitas_quebrado":"vi_toy_orelhitas","vi_patitas_quebrado":"vi_patitas","vi_toy_patitas_quebrado":"vi_toy_patitas"}
var jogo:Node
var escolhendo:=-1
var lugar:=-1
var espera:=0.0
const PASSOS:=52
const TEMPO_PASSO:=1.2

func _init(cena:Node) -> void:jogo=cena
func ator(id:int) -> PersonagemPlex:return jogo.clientes.ator(id)
func custo() -> float:
	var p:Dictionary=MontagemAtracoesPlex.PRECOS
	return (float(p.endo)+float(p.plastico)+float(p.carcaca))*.5
func aviso(texto:String) -> void:jogo.painel.mensagem(texto)
func existe(modelo:String) -> bool:return jogo.personagens.any(func(p):return p.robo and p.modelo==modelo)
func celula_armazem() -> Vector2i:
	for p in jogo.personagens:
		if p.robo and p.robotica.has("armazem"):
			var c:Array=p.robotica.armazem
			if jogo.ambientes.em(Vector2i(int(c[0]),int(c[1]))).get("fechada",false):return Vector2i(int(c[0]),int(c[1]))
	return Vector2i(-1,-1)
func sala_vazia(sala:Dictionary) -> bool:
	if not sala.get("fechada",false) or sala.get("celulas",{}).is_empty():return false
	for o in jogo.planta.objetos.values():
		var tipo:=str(o.tipo)
		if tipo in SalasPlex.ESTRUTURA or tipo in CatalogoPlex.PORTAS or LuminariasPlex.eh(tipo) or MobiliaPlex.dados(o).get("piso",false):continue
		if sala.celulas.has(o.celula):return false
	return true
func livre(celula:Vector2i,r:PersonagemPlex) -> Vector2i:
	var sala:Dictionary=jogo.ambientes.em(celula)
	var lista:Array=sala.get("celulas",{}).keys()
	lista.sort_custom(func(x,y):return Vector2i(x).distance_squared_to(celula)<Vector2i(y).distance_squared_to(celula))
	for c in lista:
		var alvo:Vector2i=c
		if not jogo.planta.transitavel(alvo) or ocupada(alvo,r):continue
		if alvo==r.celula or not jogo.rotas.caminho(r.origem_rota(),alvo).is_empty():return alvo
	return Vector2i(-1,-1)

func opcao_atualizar(menu:CanvasLayer,r:PersonagemPlex) -> void:
	if r.robotica.get("armazenado",false) or r.visita.has("troca_toy") or r.visita.has("toy_em_montagem") or not PAR.has(r.modelo) or r.modelo not in ANTIGOS or jogo.controle_robo.controlado(r):return
	if existe(PAR[r.modelo]) or existe(QUEBRADO[PAR[r.modelo]]):return
	menu.adicionar("Atualizar · Toy (US$ %.0f)"%custo(),func():iniciar(r))
func iniciar(r:PersonagemPlex) -> void:
	if jogo.servicos.saldo<custo():aviso("Saldo insuficiente. A atualização custa US$ %.0f (50%% das peças, reaproveitando o antigo)."%custo());return
	var destino:Dictionary=jogo.oficina.vaga(r,true)
	if destino.is_empty():aviso("Para atualizar é preciso uma base de montagem livre com bancada de conserto acessível.");return
	var nova:=base_nova(int(destino.base))
	if nova<0:aviso("Coloque outra base de montagem livre: uma recebe o original e a outra, o endo novo do Toy.");return
	jogo.servicos.saldo=snappedf(jogo.servicos.saldo-custo(),.01)
	var pose:=r.pose if r.pose>=0 else int(r.visita.get("palco_anterior",r.robotica.get("pose_palco",-1)))
	jogo.oficina.liberar_palco(r)
	jogo.planta.objetos[int(destino.base)].robo_reserva=r.identificador
	jogo.planta.objetos[int(destino.mesa)].reparo_reserva=r.identificador
	jogo.planta.objetos[nova].robo_reserva=r.identificador
	r.visita.troca_toy={"etapa":"indo","base":int(destino.base),"mesa":int(destino.mesa),"base_nova":nova,"novo":-1,"progresso":0.0,"ator":-1,"pose":pose,"modelo":str(PAR[r.modelo])}
	r.automatico=false;r.trabalho="ir_oficina_robo";r.andar(destino.rota)
	aviso("O "+IdentidadesPlex.completo(r)+" vai para a bancada. As peças dele vão para o Toy.")
func base_nova(ocupada_id:int) -> int:
	var lista:Array=jogo.planta.objetos.values().filter(func(p):return int(p.id)!=ocupada_id and jogo.oficina.base_livre(p))
	if lista.is_empty():return -1
	var origem:Vector2=Vector2(jogo.planta.objetos[ocupada_id].celula)
	lista.sort_custom(func(a,b):return Vector2(a.celula).distance_squared_to(origem)<Vector2(b.celula).distance_squared_to(origem))
	return int(lista[0].id)
func clicar(celula:Vector2i) -> bool:
	if escolhendo<0:return false
	var r:=ator(escolhendo);escolhendo=-1
	if not is_instance_valid(r):return true
	if not sala_vazia(jogo.ambientes.em(celula)):aviso("Essa sala não serve. O armazém precisa ser uma sala fechada e sem itens.");return true
	confirmar(r,celula);return true
func cancelar() -> bool:
	if lugar>=0:
		lugar=-1;jogo.escolher_ferramenta("selecionar");aviso("Escolha do lugar cancelada. Clique no animatrônico quebrado para escolher depois.");return true
	if escolhendo<0:return false
	escolhendo=-1;aviso("Escolha do armazém cancelada.");return true
func confirmar(r:PersonagemPlex,celula:Vector2i) -> void:
	var destino:=livre(celula,r)
	if destino.x<0:aviso("O animatrônico não tem caminho até o armazém.");return
	jogo.servicos.saldo=snappedf(jogo.servicos.saldo-custo(),.01)
	var pose:=r.pose if r.pose>=0 else int(r.visita.get("palco_anterior",r.robotica.get("pose_palco",-1)))
	jogo.oficina.liberar_palco(r)
	r.robotica.armazem=[celula.x,celula.y];r.robotica.troca={"novo":PAR[r.modelo],"pose":pose}
	marcar_sala(celula)
	mandar(r,destino)
	aviso("O "+IdentidadesPlex.completo(r)+" está indo para o armazém. As peças dele vão para o Toy.")
func mandar(r:PersonagemPlex,destino:Vector2i) -> void:
	r.automatico=false;r.visita.indo_armazem=true;r.trabalho="ir_armazem"
	if destino==r.celula:return
	r.andar(jogo.rotas.caminho(r.origem_rota(),destino))
func guardar(r:PersonagemPlex) -> void:
	var c:Array=r.robotica.get("armazem",[r.celula.x,r.celula.y])
	var destino:=livre(Vector2i(int(c[0]),int(c[1])),r)
	if destino.x>=0:mandar(r,destino)
	else:desligar(r)

func trocar(r:PersonagemPlex,modelo:String) -> PersonagemPlex:
	var n:PersonagemPlex=jogo.criar_personagem(modelo,r.celula,r.cargo,true,{})
	if not is_instance_valid(n):return null
	n.robotica=r.robotica.duplicate(true);n.identidade=r.identidade.duplicate(true);n.identidade.erase("nome");n.direcao=r.direcao
	IdentidadesPlex.garantir(n)
	jogo.despawn(r)
	return n
func desligar(r:PersonagemPlex) -> void:
	r.robotica.armazenado=true;r.robotica.bateria=0.0;r.robotica.desligado_manual=true;r.robotica.erase("pose_dia")
	r.automatico=false;r.pose=-1;r.trabalho="armazenado";r.movimento.cancelar();AnimatronicosPlex.mudar(r,"desligado")
	deitar(r)
func segunda(p:PersonagemPlex) -> Vector2i:
	if p.modelo not in DEITADOS or not p.robotica.has("deitado"):return Vector2i(-1,-1)
	var d:Array=p.robotica.deitado
	if Vector2i(int(d[0]),int(d[1]))!=p.celula:return Vector2i(-1,-1)
	return Vector2i(int(d[2]),int(d[3]))
func ocupada(c:Vector2i,r:PersonagemPlex=null) -> bool:
	return jogo.personagens.any(func(p):return p!=r and (p.celula==c or p.robo and segunda(p)==c))
func deitar(r:PersonagemPlex) -> bool:
	if r.modelo not in DEITADOS:return true
	for passo in [Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0),Vector2i(0,-1)]:
		var atras:Vector2i=r.celula-passo
		if GradePlex.projetar_vetor(Vector2(-passo)).y>=0.0 or not jogo.planta.transitavel(atras) or ocupada(atras,r):continue
		jogo.tarefas.orientar(r,r.local+Vector2(passo))
		r.robotica.deitado=[r.celula.x,r.celula.y,atras.x,atras.y]
		return true
	r.robotica.erase("deitado")
	return false
func ativar(n:PersonagemPlex,pose:int,celula:Array) -> void:
	n.robotica.erase("armazenado");n.robotica.bateria=100.0;n.robotica.desligado_manual=false;n.robotica.armazem=celula;n.trabalho=""
	AnimatronicosPlex.garantir(n)
	if pose<0:pose=int(n.robotica.get("pose_palco",-1))
	if pose>=0 and jogo.planta.objetos.has(pose) and jogo.atracoes.definir_pose(n.identificador,pose):return
	n.visita.palco_anterior=pose
	aviso("O lugar no palco está ocupado ou sem acesso. Use Redefinir lugar no "+IdentidadesPlex.completo(n)+".")

func chegou(r:PersonagemPlex) -> void:
	r.visita.erase("indo_armazem")
	var troca:Dictionary=r.robotica.get("troca",{})
	r.robotica.erase("troca")
	if troca.is_empty() or not QUEBRADO.has(r.modelo):desligar(r);return
	var celula:Array=r.robotica.get("armazem",[r.celula.x,r.celula.y])
	var novo_modelo:=str(troca.novo);var pose:=int(troca.get("pose",-1))
	var carcaca:PersonagemPlex=null
	for p in jogo.personagens:
		if p.robo and p.modelo==str(QUEBRADO.get(novo_modelo,"")) and p.robotica.get("armazenado",false):carcaca=p
	var velho:=trocar(r,str(QUEBRADO[r.modelo]))
	if is_instance_valid(velho):desligar(velho)
	var novo:PersonagemPlex
	if is_instance_valid(carcaca):
		var vaga:Vector2i=carcaca.celula
		novo=trocar(carcaca,novo_modelo)
		if is_instance_valid(novo):novo.celula=vaga;novo.local=Vector2(vaga)
	else:
		var c:=livre(Vector2i(int(celula[0]),int(celula[1])),velho if is_instance_valid(velho) else r)
		if c.x<0:c=Vector2i(int(celula[0]),int(celula[1]))
		novo=jogo.criar_personagem(novo_modelo,c,"atracao",true,{})
		if is_instance_valid(novo):novo.robotica.assombrado=false
	if not is_instance_valid(novo):aviso("Não foi possível montar o novo animatrônico.");return
	ativar(novo,pose,celula)
	aviso(IdentidadesPlex.completo(novo)+" está pronto e indo para o palco. A carcaça antiga ficou no armazém.")

func opcoes(menu:CanvasLayer,r:PersonagemPlex) -> bool:
	if r.visita.has("toy_em_montagem"):return true
	if r.visita.has("troca_toy"):
		if str(r.visita.troca_toy.etapa)=="posicionar":menu.adicionar("Escolher lugar",func():pedir_lugar(r))
		return true
	if not r.robotica.get("armazenado",false):return false
	if not INTEIRO.has(r.modelo):return true
	var inteiro:=str(INTEIRO[r.modelo])
	if not existe(inteiro):menu.adicionar("Reconstruir (US$ %.0f)"%custo()+(" · quebra o Toy" if inteiro in ANTIGOS else " · quebra o antigo"),func():reconstruir(r))
	return true
func reconstruir(carcaca:PersonagemPlex) -> void:
	if jogo.servicos.saldo<custo():aviso("Saldo insuficiente. A reconstrução custa US$ %.0f."%custo());return
	var inteiro:=str(INTEIRO[carcaca.modelo])
	var ativo:PersonagemPlex=null
	for p in jogo.personagens:
		if p.robo and p.modelo==str(PAR.get(inteiro,"")) and not p.robotica.get("armazenado",false):ativo=p
	var celula:Array=carcaca.robotica.get("armazem",[carcaca.celula.x,carcaca.celula.y])
	jogo.servicos.saldo=snappedf(jogo.servicos.saldo-custo(),.01)
	if not is_instance_valid(ativo):
		var palco_antigo:=int(carcaca.visita.get("palco_anterior",-1))
		var n:=trocar(carcaca,inteiro)
		if is_instance_valid(n):ativar(n,palco_antigo,celula)
		return
	if jogo.controle_robo.controlado(ativo):jogo.controle_robo.soltar(false)
	var destino:=livre(Vector2i(int(celula[0]),int(celula[1])),ativo)
	if destino.x<0:aviso("O "+IdentidadesPlex.completo(ativo)+" não tem caminho até o armazém.");jogo.servicos.saldo=snappedf(jogo.servicos.saldo+custo(),.01);return
	var pose:=ativo.pose if ativo.pose>=0 else int(ativo.visita.get("palco_anterior",ativo.robotica.get("pose_palco",-1)))
	jogo.oficina.liberar_palco(ativo)
	ativo.robotica.armazem=celula;ativo.robotica.troca={"novo":inteiro,"pose":pose}
	mandar(ativo,destino)
	aviso("O "+IdentidadesPlex.completo(ativo)+" vai para o armazém e será desmontado para o antigo voltar.")

func marcar_sala(celula:Vector2i) -> void:
	var sala:Dictionary=jogo.ambientes.em(celula)
	if not sala.get("fechada",false) or str(sala.get("tipo",""))=="armazem_robos":return
	jogo.ambientes.definir(celula,"armazem_robos")
	aviso("A sala virou o Armazém de animatrônicos.")
func base(modelo:String) -> String:return str(INTEIRO.get(modelo,modelo))
func encaixar(novo:PersonagemPlex) -> void:
	var familia:=base(novo.modelo)
	for p in jogo.personagens.duplicate():
		if p!=novo and p.robo and base(p.modelo)==familia:jogo.despawn(p)
	if not PAR.has(familia):return
	var par:=str(PAR[familia])
	var quebrado:=INTEIRO.has(novo.modelo)
	for p in jogo.personagens.duplicate():
		if p==novo or not p.robo or base(p.modelo)!=par:continue
		if not quebrado and p.modelo==par:
			var q:=trocar(p,str(QUEBRADO[par]))
			if is_instance_valid(q):guardar_aqui(q)
		elif quebrado and p.modelo!=par:
			var n:=trocar(p,par)
			if is_instance_valid(n):n.robotica.erase("armazenado");n.robotica.bateria=100.0;n.trabalho="";n.automatico=false;n.robotica.desligado_manual=true;AnimatronicosPlex.mudar(n,"desligado")
func guardar_aqui(r:PersonagemPlex) -> void:
	if not r.robotica.has("armazem"):r.robotica.armazem=[r.celula.x,r.celula.y]
	desligar(r)
	var c:Array=r.robotica.armazem
	marcar_sala(Vector2i(int(c[0]),int(c[1])))
func atualizar(delta:float) -> void:
	espera+=delta
	if espera<.4:return
	var dt:=espera;espera=0.0
	for r in jogo.personagens.duplicate():
		if not r.robo:continue
		if r.visita.has("troca_toy"):atualizar_troca(r,dt);continue
		if r.visita.get("indo_armazem",false):
			if not r.ocupado():chegou(r)
		elif INTEIRO.has(r.modelo) and not r.robotica.get("armazenado",false) and not jogo.controle_robo.controlado(r):guardar_aqui(r)
func atualizar_troca(r:PersonagemPlex,dt:float) -> void:
	var d:Dictionary=r.visita.troca_toy
	var base:Dictionary=jogo.planta.objetos.get(int(d.base),{})
	var mesa:Dictionary=jogo.planta.objetos.get(int(d.mesa),{})
	var nova:Dictionary=jogo.planta.objetos.get(int(d.base_nova),{})
	match str(d.etapa):
		"indo":
			if r.ocupado() or base.is_empty() or nova.is_empty():return
			if r.celula!=base.celula:
				var rota:Array[Vector2i]=jogo.rotas.caminho(r.origem_rota(),base.celula)
				if not rota.is_empty():r.andar(rota)
				return
			r.trabalho="armazenado";r.robotica.bateria=100.0;r.direcao=GradePlex.direcao_suporte(int(base.rotacao));AnimatronicosPlex.mudar(r,"desligado")
			var n:PersonagemPlex=jogo.criar_personagem(str(d.modelo),nova.celula,"atracao",true,{})
			if not is_instance_valid(n):return
			n.robotica.assombrado=false;n.automatico=false;n.visita.montando_atracao=true;n.visita.montagem_passos=0;n.visita.toy_em_montagem=r.identificador
			jogo.atracoes.posicionar_na_bancada(n,nova);nova.robo_reserva=n.identificador
			d.novo=n.identificador;d.etapa="transferir"
		"transferir":
			var n:=ator(int(d.novo))
			if not is_instance_valid(n) or nova.is_empty() or base.is_empty():return
			var progresso:=float(d.progresso)
			var alvo:=int(d.base) if posmod(floori(progresso/6.0),2)==0 else int(d.base_nova)
			var a:PersonagemPlex=jogo.oficina.operario(d,alvo)
			if not is_instance_valid(a) or a.ocupado():return
			if not jogo.planta.interacoes(alvo).has(a.celula):
				var rota:Array[Vector2i]=jogo.rotas.aproximar(a.origem_rota(),alvo)
				if not rota.is_empty():a.andar(rota);a.trabalho="ir_montar_atracao"
				return
			var peca:PersonagemPlex=r if alvo==int(d.base) else n
			jogo.tarefas.orientar(a,peca.local);jogo.tarefas.orientar_cardinal(peca,a.local)
			progresso+=dt*HabilidadesEquipePlex.fator(a,"manutencao")/TEMPO_PASSO
			d.progresso=progresso;a.trabalho="montar";a.progresso_acao=fposmod(progresso,1.0)
			n.visita.montagem_passos=mini(floori(progresso),34)
			if progresso>=18.0 and not d.get("fantasia",false):d.fantasia=true;jogo.oficina.sentar_fantasia(r,d)
			if progresso>=26.0 and not d.get("quebrou",false):
				d.quebrou=true
				var velho:=trocar(r,str(QUEBRADO[r.modelo]))
				if not is_instance_valid(velho):return
				velho.visita.troca_toy=d;velho.automatico=false;velho.trabalho="armazenado";velho.local=Vector2(base.celula);velho.celula=base.celula
				AnimatronicosPlex.mudar(velho,"desligado")
				base.robo_reserva=velho.identificador;mesa.reparo_reserva=velho.identificador;n.visita.toy_em_montagem=velho.identificador
				if mesa.has("fantasia_robo"):mesa.fantasia_robo=velho.identificador
				return
			if progresso<PASSOS:return
			jogo.oficina.liberar_operario(d)
			for chave in ["montando_atracao","montagem_passos","toy_em_montagem","bancada_montagem","montagem_olhar_jogador","montagem_rotacao","montagem_altura"]:n.visita.erase(chave)
			nova.erase("robo_reserva");mesa.erase("fantasia_bancada");mesa.erase("fantasia_robo")
			ativar(n,int(d.pose),[nova.celula.x,nova.celula.y])
			d.etapa="posicionar";jogo.planta.alterada.emit()
			aviso(IdentidadesPlex.completo(n)+" está pronto e indo para o palco.")
			pedir_lugar(r)
		"indo_lugar":
			if r.ocupado():return
			var c:Array=d.lugar;var celula:=Vector2i(int(c[0]),int(c[1]))
			if r.celula!=celula:
				var rota:Array[Vector2i]=jogo.rotas.caminho(r.origem_rota(),celula)
				if rota.is_empty():d.etapa="posicionar";aviso("O "+IdentidadesPlex.completo(r)+" não alcança o lugar escolhido. Escolha outro.");return
				r.andar(rota);return
			r.visita.erase("troca_toy");r.robotica.armazem=[celula.x,celula.y]
			desligar(r)
			var frente:=GradePlex.frente(int(c[2]))
			jogo.tarefas.orientar(r,r.local+Vector2(frente))
			if r.modelo in DEITADOS:
				var atras:=celula-frente
				r.robotica.deitado=[celula.x,celula.y,atras.x,atras.y]
			jogo.planta.alterada.emit()
func pedir_lugar(r:PersonagemPlex) -> void:
	lugar=r.identificador
	jogo.escolher_ferramenta("pose_quebrado")
	aviso("Escolha onde o "+IdentidadesPlex.completo(r)+" vai ficar. A seta mostra para onde ele olha; R gira. Botão direito cancela.")
func posicionar(celula:Vector2i,rotacao:int) -> void:
	var r:=ator(lugar)
	if not is_instance_valid(r) or not r.visita.has("troca_toy"):lugar=-1;return
	if not GradePlex.dentro(celula) or not jogo.planta.transitavel(celula) or not jogo.planta.em(celula).is_empty() or not is_zero_approx(jogo.planta.altura(celula)) or ocupada(celula,r):aviso("Escolha um tile livre no chão.");return
	if r.modelo in DEITADOS:
		var atras:=celula-GradePlex.frente(rotacao)
		if not GradePlex.dentro(atras) or not jogo.planta.transitavel(atras) or not jogo.planta.em(atras).is_empty() or ocupada(atras,r):aviso("Deitado, ele ocupa 2 tiles: o da seta e o de trás. Os dois precisam estar livres e sem parede.");return
	if celula!=r.celula and jogo.rotas.caminho(r.origem_rota(),celula).is_empty():aviso("Sem caminho até esse lugar.");return
	var d:Dictionary=r.visita.troca_toy
	for id in [int(d.base),int(d.mesa)]:
		var p:Dictionary=jogo.planta.objetos.get(id,{})
		p.erase("robo_reserva");p.erase("reparo_reserva")
	d.lugar=[celula.x,celula.y,posmod(rotacao,4)];d.etapa="indo_lugar"
	lugar=-1;jogo.escolher_ferramenta("selecionar")

