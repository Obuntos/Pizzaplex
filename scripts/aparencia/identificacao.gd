class_name IdentificacaoPlex
extends Node2D

const CORES = {"administrador":"f0cd80","geral":"d5dcd1","cozinha":"f2dfaf","atendimento":"efb6a7","limpeza":"acd6d4","estoque":"c2d49e","manutencao":"b8c8e3","caixa":"e1c79c","seguranca":"b5bad6"}
var texto := Label.new()
var assinatura := ""

func _init() -> void:
	z_index = 60
	texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texto.add_theme_font_override("font",load("res://assets/interface/fontes/interface.ttf"))
	texto.add_theme_font_size_override("font_size",10)
	texto.add_theme_color_override("font_outline_color",Color("182621"))
	texto.add_theme_constant_override("outline_size",4)
	add_child(texto)

func atualizar(ator: PersonagemPlex) -> void:
	visible = ator.cargo=="funcionario" and not ator.robo
	if not visible: return
	var nova := IdentidadesPlex.curto(ator)
	if assinatura!=nova:
		assinatura = nova
		texto.text = nova
		texto.add_theme_color_override("font_color",Color(CORES.get(ator.funcao,"d5dcd1")))
		texto.reset_size()
	position = Vector2(-texto.get_minimum_size().x*.5,ator.visual.position.y-84)

