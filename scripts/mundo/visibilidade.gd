class_name VisibilidadeMundoPlex
extends RefCounted

var area:=Rect2()
var visiveis:=0
var distantes:=0

func atualizar(camera: Camera2D, viewport: Viewport) -> void:
	var tela:=viewport.get_visible_rect()
	var inversa:=camera.get_canvas_transform().affine_inverse()
	area=Rect2(inversa*tela.position,Vector2.ZERO)
	for canto in [Vector2(tela.end.x,tela.position.y),tela.end,Vector2(tela.position.x,tela.end.y)]: area=area.expand(inversa*canto)
	area=area.grow(120.0)
	visiveis=0;distantes=0

func personagem(a: PersonagemPlex) -> bool:
	var ponto:=GradePlex.projetar(a.local,a.altura)
	var limite:=area.grow(200.0) if a.visita.get("lanterna_equipada",false) else area
	var mostrar:bool=(limite.has_point(ponto) or limite.has_point(ponto-Vector2(0,110))) and not a.visita.get("escondido_armario",false)
	if mostrar: visiveis+=1
	else: distantes+=1
	a.set_meta("visivel_cena",mostrar)
	return mostrar

