class_name DialogoAutoridadePlex
extends CanvasLayer

const T=preload("res://scripts/interface/tema_hud.gd")
var gestor:SegurancaBairroPlex
var evento:=-1
var folha:=PanelContainer.new()
func configurar(g:SegurancaBairroPlex,id:int,prisao:bool) -> void:
	gestor=g;evento=id;layer=180;gestor.jogo.pausar("autoridade:"+str(get_instance_id()))
	var raiz:=Control.new();raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);raiz.theme=T.criar();add_child(raiz)
	var sombra:=ColorRect.new();sombra.color=Color(0,0,0,.7);sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);raiz.add_child(sombra)
	raiz.add_child(folha);folha.add_theme_stylebox_override("panel",T.caixa(T.FUNDO,T.LINHA,24))
	var c:=VBoxContainer.new();c.add_theme_constant_override("separation",16);folha.add_child(c)
	var lista:Array=gestor.eventos.filter(func(registro):return int(registro.id)==id)
	if lista.is_empty():queue_free();return
	var e:Dictionary=lista[0]
	T.texto(c,"VOCÊ FOI PRESO" if prisao else "INVESTIGADOR · PERGUNTA %d / 3"%(int(e.pergunta)+1),22,T.PAPEL)
	var perguntas:Array=["Quando você viu "+str(e.nome)+" pela última vez?","Em que lugar essa pessoa foi vista?","Você percebeu algo fora do comum durante a visita?"]
	var pergunta:=T.texto(c,"A polícia apresentou os motivos da prisão e levou o administrador à delegacia." if prisao else str(perguntas[clampi(int(e.pergunta),0,2)]),18,T.PAPEL);pergunta.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;pergunta.custom_minimum_size.x=480
	if prisao:
		T.botao(c,"Voltar ao menu",func():get_tree().change_scene_to_file("res://cenas/interface/inicio.tscn"))
	else:
		var respostas:Array=[["Na última visita ao restaurante.","Não me lembro do horário."],["No salão do restaurante.","Não sei informar."],["Não percebi nada.","Posso procurar nos registros."]]
		for texto in respostas[clampi(int(e.pergunta),0,2)]:
			var valor:String=texto;T.botao(c,valor,func():gestor.responder(evento,valor))
	get_viewport().size_changed.connect(posicionar);posicionar()
func _exit_tree() -> void:gestor.jogo.retomar("autoridade:"+str(get_instance_id()))
func posicionar() -> void:
	var tela:=get_viewport().get_visible_rect().size;folha.size=Vector2(560,300);var fator:=minf(1.0,minf((tela.x-24)/560.0,(tela.y-24)/300.0));folha.scale=Vector2.ONE*fator;folha.position=((tela-folha.size*fator)*.5).round()
