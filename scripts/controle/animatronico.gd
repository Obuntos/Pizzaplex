class_name ControleAnimatronicoPlex
extends RefCounted

const MODELOS=["novo_coelho_detalhes","vi_toy_orelhitas","vi_orelhitas_quebrado","vi_toy_orelhitas_quebrado","vi_patitas","vi_toy_patitas","vi_patitas_quebrado","vi_toy_patitas_quebrado"]
const ESPERA_PORTA=60.0
const PORTA_QUEBRAVEL=120.0
var jogo:Node
var robo:=-1
var origem:=Vector2i(-1,-1)
var parado_porta:=0.0
var fim_canto:=0.0
var espera:=0.0

func _init(cena:Node) -> void:jogo=cena
func agora() -> float:return float(jogo.calendario.dias)*1440.0+float(jogo.calendario.minutos)
func ator() -> PersonagemPlex:
	if robo<0:return null
	return jogo.clientes.ator(robo)
func ativo() -> bool:return is_instance_valid(ator())
func controlado(r:PersonagemPlex) -> bool:return ativo() and r==ator()
func noite() -> bool:return jogo.calendario.minutos>=1380.0 or jogo.calendario.minutos<360.0
func possuido(r:PersonagemPlex) -> bool:
	return r.robo and r.modelo in MODELOS and (r.visita.get("debug_possuido",false) or r.robotica.get("assombrado",false))
func admin_em_casa() -> bool:
	var a:PersonagemPlex=jogo.controle.administrador()
	return not is_instance_valid(a) or str(a.visita.get("rotina_casa_etapa",""))=="em_casa"
func aviso(texto:String) -> void:jogo.painel.mensagem(texto)

func motivo_bloqueio(r:PersonagemPlex) -> String:
	if not noite():return "O controle só funciona entre 23:00 e 06:00."
	if not admin_em_casa():return "O administrador precisa estar em casa para controlar um animatrônico."
	if jogo.controle.manual():return "Desative o controle manual do administrador primeiro."
	if r.visita.has("mec_noturno") or r.visita.get("bloqueio_noite",false):return "O mecânico está com esse animatrônico. Controle outro."
	if r.ocupado():return "Espere o animatrônico ficar parado."
	return ""
func assumir(r:PersonagemPlex) -> void:
	var motivo:=motivo_bloqueio(r)
	if not motivo.is_empty():aviso(motivo);return
	if ativo():
		var anterior:=ator();soltar(false)
		if is_instance_valid(anterior) and anterior!=r:anterior.visita.controle_largado=true;anterior.movimento.cancelar();anterior.trabalho="largado"
	r.visita.erase("controle_largado")
	robo=r.identificador;origem=r.celula;parado_porta=0.0;fim_canto=0.0
	r.visita.erase("diagnostico_animacao");r.visita.erase("diagnostico_rota")
	r.visita.controle_animatronico=true;r.visita.controle_inicio=r.relogio;r.automatico=false;r.trabalho="controlado";r.movimento.cancelar()
	jogo.selecionar(r)
	aviso("Controle do animatrônico · Clique no chão para andar (devagar). Botão direito nele abre as ações. Às 06:00 ele volta ao palco.")
func soltar(voltar:bool=true,motivo:String="") -> void:
	var r:=ator()
	robo=-1
	if not is_instance_valid(r):return
	r.visita.erase("controle_animatronico");r.visita.erase("controle_cantando");r.visita.erase("controle_desligado");r.visita.erase("controle_pose")
	r.movimento.cancelar();r.trabalho=""
	if voltar and r.robotica.get("armazenado",false):jogo.sistemas.armazem.guardar(r)
	elif voltar:voltar_palco(r)
	if r.visita.get("debug_robo",false):r.robotica.desligado_manual=true;AnimatronicosPlex.mudar(r,"desligado")
	if not motivo.is_empty():aviso(motivo)
func voltar_palco(r:PersonagemPlex) -> void:
	var pose:=int(r.visita.get("palco_anterior",-1))
	if jogo.planta.objetos.has(pose) and jogo.poses.livre(pose,r) and jogo.atracoes.definir_pose(r.identificador,pose):return
	var destino:Vector2i=origem if origem.x>=0 else r.celula
	var rota:Array[Vector2i]=jogo.rotas.caminho(r.origem_rota(),destino)
	if not rota.is_empty():r.andar(rota);r.trabalho="voltar_palco"
func lanterna(r:PersonagemPlex) -> void:
	if controlado(r):soltar(true,"O segurança mirou a lanterna. O animatrônico foi obrigado a voltar ao palco.")

func mover(celula:Vector2i) -> bool:
	var r:=ator()
	if not is_instance_valid(r):return false
	if r.visita.get("controle_desligado",false):aviso("O animatrônico está desligado. Ligue-o pelo botão direito.");return true
	if r.relogio-float(r.visita.get("controle_inicio",-999.0))<AnimatronicosPlex.duracao_partida(r):aviso("O animatrônico ainda está ligando.");return true
	jogo.rotas.atualizar_atores(jogo.personagens)
	if jogo.rotas.solidos.has(celula) or not jogo.planta.transitavel(celula):return true
	var rota:Array[Vector2i]=jogo.rotas.caminho(r.origem_rota(),celula)
	if rota.is_empty():aviso("Sem caminho até esse tile.");return true
	r.visita.erase("controle_cantando");r.visita.erase("controle_pose");r.trabalho="controlado";r.andar(rota);parado_porta=0.0
	return true

func vizinho(r:PersonagemPlex,o:Dictionary,alcance:float=1.6) -> bool:
	for c in jogo.planta.celulas(o.tipo,o.celula,o.rotacao):
		if r.local.distance_to(Vector2(c))<=alcance:return true
	return false
func porta_trancada(r:PersonagemPlex) -> Dictionary:
	for o in jogo.planta.listar("portas"):
		if o.get("trancada",false) and vizinho(r,o):return o
	return {}
func camera_proxima(r:PersonagemPlex) -> Dictionary:
	for o in jogo.planta.listar("cameras"):
		if not o.get("camera_quebrada",false) and vizinho(r,o,2.2):return o
	return {}

func opcoes(menu:CanvasLayer,r:PersonagemPlex) -> bool:
	if controlado(r):
		var cantando:bool=r.visita.get("controle_cantando",false)
		if ClipesPlex.possui(r.modelo,"cantar"):menu.adicionar("Parar de cantar" if cantando else "Cantar",func():cantar(r,not cantando))
		poses(menu,r,"controle_pose",r.visita)
		menu.adicionar("Ligar" if r.visita.get("controle_desligado",false) else "Desligar",func():alternar_energia(r))
		var porta:=porta_trancada(r)
		if not porta.is_empty():menu.adicionar("Quebrar porta",func():quebrar_porta(r,porta))
		var camera:=camera_proxima(r)
		if not camera.is_empty():menu.adicionar("Quebrar câmera",func():quebrar_camera(r,camera))
		menu.adicionar("Voltar ao palco",func():soltar(true,"O animatrônico voltou ao palco."))
		menu.adicionar("Sair do controle",func():soltar(true,"Controle encerrado. O animatrônico volta ao palco."))
		return true
	if possuido(r) and not r.ocupado():menu.adicionar("Controlar",func():assumir(r))
	if jogo.sistemas.armazem.opcoes(menu,r):return true
	if not noite() and str(r.robotica.get("estado",""))=="ligado":poses(menu,r,"pose_dia",r.robotica)
	jogo.sistemas.armazem.opcao_atualizar(menu,r)
	return false
func poses(menu:CanvasLayer,r:PersonagemPlex,chave:String,alvo:Dictionary) -> void:
	var atual:=str(alvo.get(chave,""))
	for clipe in CacaAnimatronicosPlex.POSES:
		if ClipesPlex.possui(r.modelo,clipe) and clipe!=atual:menu.adicionar("Pose: "+str(CacaAnimatronicosPlex.POSES[clipe]),func():r.movimento.cancelar();alvo[chave]=clipe;r.visita.erase("controle_cantando"))
	if not atual.is_empty():menu.adicionar("Sair da pose",func():alvo.erase(chave))
func tocando(r:PersonagemPlex) -> bool:return r.visita.get("controle_cantando",false) or not str(r.visita.get("controle_pose","")).is_empty() or not str(r.robotica.get("pose_dia","")).is_empty()
func sufixo(r:PersonagemPlex) -> String:
	if controlado(r):return " · sob controle · fome %d/4"%floori(jogo.sistemas.caca.fome(r))
	if r.robotica.get("armazenado",false):return " · no armazém"
	return ""
func cantar(r:PersonagemPlex,ligar:bool) -> void:
	if ligar and r.visita.get("controle_desligado",false):aviso("Ligue o animatrônico antes.");return
	if ligar:r.movimento.cancelar();r.visita.erase("controle_pose");r.visita.controle_cantando=true;fim_canto=agora()+30.0
	else:r.visita.erase("controle_cantando")
func alternar_energia(r:PersonagemPlex) -> void:
	if r.visita.get("controle_desligado",false):r.visita.erase("controle_desligado");r.visita.controle_inicio=r.relogio
	else:r.movimento.cancelar();r.visita.erase("controle_cantando");r.visita.erase("controle_pose");r.visita.controle_desligado=true
func quebrar_porta(r:PersonagemPlex,porta:Dictionary) -> void:
	var trancada_ha:=agora()-float(porta.get("trancada_desde",agora()))
	if trancada_ha<PORTA_QUEBRAVEL:aviso("A porta ainda resiste. Ela precisa estar trancada há 2 horas (faltam %d min)."%ceili(PORTA_QUEBRAVEL-trancada_ha));return
	porta.trancada=false;porta.arrombada=true;porta.aberta=true;porta.erase("trancada_desde")
	jogo.tarefas.orientar(r,Vector2(porta.celula));jogo.planta.alterada.emit()
	aviso("O animatrônico arrombou a porta.")
func quebrar_camera(r:PersonagemPlex,camera:Dictionary) -> void:
	var semana:=floori(float(jogo.calendario.dias)/7.0)
	if int(r.visita.get("camera_quebrada_semana",-1))==semana:aviso("Só dá para quebrar uma câmera por semana.");return
	r.visita.camera_quebrada_semana=semana;camera.camera_quebrada=true;camera.camera_ligada=false
	jogo.tarefas.orientar(r,Vector2(camera.celula));jogo.planta.alterada.emit()
	aviso("A câmera "+str(camera.get("camera_nome","de segurança"))+" foi quebrada.")

func atualizar(delta:float) -> void:
	espera+=delta
	if espera<.5:return
	var tempo:=espera;espera=0.0
	for o in jogo.planta.listar("portas"):
		if o.get("trancada",false):
			if not o.has("trancada_desde"):o.trancada_desde=agora()
		elif o.has("trancada_desde"):o.erase("trancada_desde")
	var r:=ator()
	if not noite():
		for p in jogo.personagens:
			p.visita.erase("bloqueio_noite")
			if p.visita.has("controle_largado"):p.visita.erase("controle_largado");p.trabalho="";voltar_palco(p)
	if not is_instance_valid(r):
		robo=-1
		for p in jogo.personagens:
			if p.visita.has("controle_animatronico"):p.visita.erase("controle_animatronico")
		return
	if not noite():soltar(true,"06:00. O animatrônico voltou ao normal e retornou ao palco.");return
	if jogo.controle.manual():soltar(true,"O administrador assumiu o controle. O animatrônico voltou ao palco.");return
	if r.visita.get("controle_cantando",false) and agora()>=fim_canto:r.visita.erase("controle_cantando")
	if not r.ocupado() and not porta_trancada(r).is_empty():
		parado_porta+=tempo*CalendarioPlex.MINUTOS_POR_SEGUNDO
		if parado_porta>=ESPERA_PORTA:soltar(true,"O animatrônico ficou 1 hora diante de uma porta trancada e voltou ao palco.")
	else:parado_porta=0.0
