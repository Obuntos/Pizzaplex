class_name AvisosClicaveisPlex
extends RefCounted

const DURACAO:=10.0
const T=preload("res://scripts/interface/tema_hud.gd")
var jogo:Node
var camada:CanvasLayer
var botao:Button
var alvo:=Vector2.ZERO
var restante:=0.0

func _init(cena:Node) -> void:jogo=cena

func preparar() -> void:
	if camada!=null:return
	camada=CanvasLayer.new();camada.layer=95;jogo.add_child(camada)
	botao=Button.new();botao.theme=T.criar();botao.custom_minimum_size=Vector2(420,34);botao.hide()
	botao.add_theme_font_size_override("font_size",14)
	camada.add_child(botao);botao.pressed.connect(ir)

func marcar(local:Vector2,texto:String="") -> void:
	preparar()
	alvo=local;restante=DURACAO
	var frase:=texto if not texto.is_empty() else str(jogo.painel.status.text)
	botao.text="📍 "+frase+"  ·  clique para ver"
	botao.reset_size()
	var tela:=jogo.get_viewport().get_visible_rect().size
	botao.position=Vector2((tela.x-botao.size.x)*.5,tela.y-150.0)
	botao.show()

func ir() -> void:
	var c:=Vector2i(alvo.round())
	jogo.camera.position=GradePlex.projetar(alvo,jogo.planta.altura(c))
	jogo.camera.force_update_scroll()
	botao.hide();restante=0.0

func atualizar(delta:float) -> void:
	if restante<=0.0:return
	restante-=delta
	if restante<=0.0 and botao!=null:botao.hide()
