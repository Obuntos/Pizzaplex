class_name TutorialBonnieCorrigidoPlex
extends "res://scripts/interface/tutorial_bonnie.gd"

const META_LIMPEZA=3
var residuos_inicio:Array[int]=[]
var camera_livre:=false
var arrastando_camera:=false
var mostrar_parede_apos_limpeza:=false
var bonus_entregue:=false

func limpar() -> void:
	residuos_inicio.clear()
	camera_livre=false
	arrastando_camera=false
	mostrar_parede_apos_limpeza=false
	bonus_entregue=false
	super.limpar()

func focar() -> void:
	if camera_livre:return
	if fase=="entrada" and tempo>1.0:
		camera_livre=true
		return
	super.focar()

func focar_objeto(item:Dictionary) -> void:
	if camera_livre:return
	super.focar_objeto(item)

func ajustar_fala_genero(linha:String) -> String:
	if IdiomaPlex.idioma_atual()=="en":return linha
	var trocas:Dictionary={
		"dona de restaurante":"dono de restaurante",
		"Dona de restaurante":"Dono de restaurante",
		"estou pronta":"estou pronto",
		"Estou pronta":"Estou pronto",
		"estou cansada":"estou cansado",
		"Estou cansada":"Estou cansado",
		"obrigada":"obrigado",
		"Obrigada":"Obrigado",
		"esquecida":"esquecido",
		"Esquecida":"Esquecido"
	}
	for feminina in trocas:
		linha=linha.replace(str(feminina),str(trocas[feminina]))
	return linha

func paginar(linhas:Array) -> Array:
	var masculinas:Array=[]
	for linha in linhas:masculinas.append(ajustar_fala_genero(str(linha)))
	return super.paginar(masculinas)

func mostrar_fala() -> void:
	camera_livre=true
	for i in falas.size():falas[i]=ajustar_fala_genero(str(falas[i]))
	super.mostrar_fala()

func mudar_etapa(valor:String,modo:String="guiado") -> void:
	if valor=="limpar_primeiro" and etapa!="limpar_primeiro":
		residuos_inicio.clear()
		for item in tarefas.residuos():
			residuos_inicio.append(int(item.id))
	super.mudar_etapa(valor,modo)
	if modo=="cena":
		destaque.hide()
		if destaque.pausa_do_destaque:
			destaque.pausa_do_destaque=false
			if is_zero_approx(jogo.velocidade_tempo):
				jogo.velocidade_tempo=destaque.velocidade_anterior

func entrada_evento(e:InputEvent) -> bool:
	if assunto=="intro" and not intro_concluida and e is InputEventKey and e.keycode==KEY_CTRL:
		return true
	if assunto=="intro" and fase not in ["","aguardando","saindo"]:
		if e is InputEventMouseButton:
			var mouse:=e as InputEventMouseButton
			if mouse.button_index in [MOUSE_BUTTON_RIGHT,MOUSE_BUTTON_MIDDLE]:
				if not camera_livre:return true
				if mouse.pressed and painel.visible and painel.get_global_rect().has_point(mouse.position):return super.entrada_evento(e)
				arrastando_camera=mouse.pressed
				return true
			if mouse.pressed and mouse.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and camera_livre:
				if painel.visible and painel.get_global_rect().has_point(mouse.position):return super.entrada_evento(e)
				if jogo.painel.bloqueia_mouse(mouse.position):return super.entrada_evento(e)
				var fator:=1.1 if mouse.button_index==MOUSE_BUTTON_WHEEL_UP else 1.0/1.1
				jogo.visor.automatico=false
				jogo.camera.zoom=Vector2.ONE*clampf(jogo.camera.zoom.x*fator,0.30,3.5)
				jogo.camera.force_update_scroll()
				return true
		if e is InputEventMouseMotion and arrastando_camera and camera_livre:
			var movimento:=e as InputEventMouseMotion
			jogo.visor.automatico=false
			jogo.camera.position-=movimento.relative/jogo.camera.zoom
			jogo.camera.force_update_scroll()
			return true
	return super.entrada_evento(e)

func _process(delta:float) -> void:
	super._process(delta)
	if not camera_livre or fase not in ["fala","escolha","entrada"]:return
	if not jogo.atividade_janela.em_foco:return
	if get_viewport().gui_get_focus_owner() is LineEdit:return
	var comando:=Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
	if comando.is_zero_approx():return
	jogo.visor.automatico=false
	jogo.camera.position+=comando.normalized()*400.0*minf(delta,.05)/jogo.camera.zoom.x
	jogo.camera.force_update_scroll()

func quantidade_limpa() -> int:
	var limpos:=0
	for id in residuos_inicio:
		if not jogo.planta.objetos.has(id):limpos+=1
	return limpos

func atualizar_guia(delta:float) -> void:
	if etapa=="limpar_primeiro" and assunto=="intro":
		var a:=admin()
		var b:=bonnie()
		if not is_instance_valid(a) or not is_instance_valid(b):return
		var limpos:=quantidade_limpa()
		if limpos>=META_LIMPEZA or (residuos_inicio.size()<META_LIMPEZA and limpos==residuos_inicio.size()):
			mostrar_parede_apos_limpeza=true
			iniciar_parede()
			if parede_alvo.is_empty():
				terminar_fala(["Já limpamos algumas coisas! Mas há uma parte isolada com muito lixo. Vamos abrir passagem quebrando a parede que bloqueia o acesso."],"demolir","muito_feliz")
			return
		var ajudou:=tarefas.limpar(b,true)
		var trabalhou:=tarefas.limpar(a,false)
		if ajudou or trabalhou or tarefas.ocupados([a,b]):tempo_etapa=0.0
		return
	if etapa=="parede_andar" and mostrar_parede_apos_limpeza:
		var b:=bonnie()
		if not is_instance_valid(b):return
		if b.ocupado() and tempo_etapa<7.0:return
		if b.ocupado():b.movimento.cancelar()
		if parede_alvo.has("celula"):
			jogo.tarefas.orientar(b,Vector2(parede_alvo.celula))
		b.emocao.exibir("festa")
		definir_humor("muito_feliz")
		terminar_fala(["Já limpamos três coisas! Mas ainda há lixo atrás dessas paredes. Vamos quebrar uma delas para abrir passagem e continuar a limpeza."],"demolir","muito_feliz")
		mostrar_parede_apos_limpeza=false
		return
	super.atualizar_guia(delta)

func gravar() -> Dictionary:
	var dados:Dictionary=super.gravar()
	dados["bonus_tutorial"]=bonus_entregue
	var guia:Dictionary=dados.get("guia",{})
	if not guia.is_empty():
		guia["residuos_inicio"]=residuos_inicio.duplicate()
		guia["camera_livre"]=camera_livre
		guia["parede_apos_limpeza"]=mostrar_parede_apos_limpeza
	return dados

func restaurar(d:Dictionary) -> void:
	super.restaurar(d)
	bonus_entregue=bool(d.get("bonus_tutorial",d.get("intro",false)))

func retomar_guia() -> void:
	var dados:Dictionary=retomada.duplicate(true)
	super.retomar_guia()
	if not retomada.is_empty():return
	residuos_inicio.clear()
	for id in dados.get("residuos_inicio",[]):residuos_inicio.append(int(id))
	camera_livre=bool(dados.get("camera_livre",true))
	mostrar_parede_apos_limpeza=bool(dados.get("parede_apos_limpeza",false))

func terminar() -> void:
	var camera_final:Vector2=jogo.camera.position
	var zoom_final:Vector2=jogo.camera.zoom
	var assunto_original:=assunto
	var dar_bonus:=assunto_original=="intro" and not intro_concluida and not bonus_entregue
	super.terminar()
	if dar_bonus:
		bonus_entregue=true
		jogo.servicos.receber(500.0)
		jogo.painel.hud.atualizar(1.0)
	if camera_livre and assunto_original!="faca":
		jogo.camera.position=camera_final
		jogo.camera.zoom=zoom_final
		jogo.camera.force_update_scroll()
	arrastando_camera=false
