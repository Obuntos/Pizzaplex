class_name ObjetoCidadePlex
extends Node2D

var bairro: Node2D
var registro: Array
var definicao: Dictionary
var ancora := Vector2.ZERO
var indice := 0

func configurar(cidade: Node2D, item: Array, numero: int) -> void:
	bairro=cidade;registro=item;indice=numero
	definicao=bairro.catalogo[str(item[0])]
	atualizar()

func atualizar(_completo: bool = false) -> void:
	ancora=bairro.ancora(registro)
	position=GradePlex.projetar(ancora)
	modulate=Color.WHITE*clampf(bairro.jogo.iluminacao.ambiente_diurno+.2,.25,1.0)
	modulate.a=1.0
	queue_redraw()

func _draw() -> void:
	if bairro==null: return
	var fontes: Array=bairro.ancoras_fumaca.get(str(registro[0]),[])
	for origem in fontes:
		var local:=GradePlex.girar(Vector2(float(origem[0])-.5,float(origem[1])-.5),int(registro[3]))
		var p:=GradePlex.projetar(ancora+local,float(origem[2]))-position
		for i in 5:
			var vida:=fposmod(bairro.tempo*.18+float(i)*.2+indice*.19,1.0)
			var raio:=1.0+floorf(vida*3)
			var v:=Vector2(roundf(vida*13.0+sin(vida*5)*2),-roundf(vida*44))
			draw_rect(Rect2((p+v-Vector2.ONE*raio).round(),Vector2.ONE*(raio*2+1)),Color(.7,.74,.71,(1.0-vida)*.35))
