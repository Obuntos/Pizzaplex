class_name AtividadeJanelaPlex
extends Node

const FPS_MINIMIZADA=10
const RECUPERACAO_US=2000000
const PASSOS_MAXIMOS=3
var jogo:Node
var janela:Window
var suspenso:=false
var visual_ativo:=true
var retomada_ate_us:=0
var recuperacao_ate_us:=0
var retornos:=0
var em_foco:=true
var minimizada:=false
var limite_anterior:=0
var limite_ativo:=60
var passos_anteriores:=8
var fisica_anterior:=60
var configurado:=false
var janela_disponivel:=true

func configurar(alvo:Node) -> void:
	jogo=alvo
	janela=jogo.get_window()
	janela_disponivel=DisplayServer.get_name()!="headless"
	process_mode=Node.PROCESS_MODE_ALWAYS
	limite_anterior=Engine.max_fps
	limite_ativo=limite_anterior if limite_anterior>0 else 60
	passos_anteriores=Engine.max_physics_steps_per_frame
	fisica_anterior=Engine.physics_ticks_per_second
	Engine.max_fps=limite_ativo
	Engine.max_physics_steps_per_frame=PASSOS_MAXIMOS
	janela.focus_exited.connect(perder_foco)
	janela.focus_entered.connect(recuperar_foco)
	configurado=true
	if janela_disponivel:
		observar(janela.has_focus(),janela.mode==Window.MODE_MINIMIZED)

func permite_simular() -> bool:
	return not suspenso

func observar(foco:bool,reduzida:bool,agora_us:int=0) -> void:
	if foco==em_foco and reduzida==minimizada:return
	var voltou:=minimizada and not reduzida
	em_foco=foco
	minimizada=reduzida
	suspenso=reduzida
	if voltou:
		retomada_ate_us=(Time.get_ticks_usec() if agora_us==0 else agora_us)+50000
		recuperacao_ate_us=retomada_ate_us+RECUPERACAO_US
		retornos+=1
	else:
		retomada_ate_us=0
	if is_instance_valid(jogo):jogo.desempenho.janela(foco and not reduzida)
	Engine.max_fps=mini(limite_ativo,FPS_MINIMIZADA) if reduzida else limite_ativo
	if not foco and is_instance_valid(jogo):
		jogo.arrastando=false
		jogo.apagando=false
		jogo.traco_parede.encerrar()

func perder_foco() -> void:
	observar(false,janela.mode==Window.MODE_MINIMIZED)

func recuperar_foco() -> void:
	observar(true,janela.mode==Window.MODE_MINIMIZED)

func _process(_delta:float) -> void:
	if configurado and janela_disponivel:
		observar(janela.has_focus(),janela.mode==Window.MODE_MINIMIZED)
	if recuperacao_ate_us>0 and Time.get_ticks_usec()>=recuperacao_ate_us:
		recuperacao_ate_us=0
		if em_foco and not minimizada:Engine.max_physics_steps_per_frame=PASSOS_MAXIMOS

func _exit_tree() -> void:
	if not configurado:return
	Engine.max_fps=limite_anterior
	Engine.max_physics_steps_per_frame=passos_anteriores
	Engine.physics_ticks_per_second=fisica_anterior

func permite_desenhar() -> bool:
	return visual_ativo and not minimizada

func iniciar_quadro(_delta:float,agora_us:int=0) -> bool:
	var agora:=Time.get_ticks_usec() if agora_us==0 else agora_us
	visual_ativo=false
	if minimizada or agora<retomada_ate_us:return false
	visual_ativo=true
	return visual_ativo
