class_name ClipesPlex
extends RefCounted

static var modelos: Dictionary = {}
static var deterioracao: Dictionary = {}

static func carregar() -> void:
	if modelos.is_empty(): modelos = JSON.parse_string(FileAccess.get_file_as_string("res://dados/clipes_modelos.json"))
	if deterioracao.is_empty() and FileAccess.file_exists("res://dados/deterioracao.json"): deterioracao=JSON.parse_string(FileAccess.get_file_as_string("res://dados/deterioracao.json"))

static func possui(modelo: String, acao: String) -> bool:
	carregar()
	return modelos.get(modelo,{}).get("clipes",{}).has("cantar" if acao=="falar" else acao)

static func tempo_mecanico(tempo: float, m: Dictionary) -> float:
	var local := fposmod(tempo,float(m.get("period",10.4)))
	var inicio: float = m.get("start",2.8)
	var pausa: float = m.get("hold",.28)
	if local < inicio: return tempo
	if local < inicio+pausa: return tempo-local+inicio
	return tempo-pausa*(1.0-smoothstep(0.0,float(m.get("recovery",.4)),local-inicio-pausa))

static func quadro(modelo: String, acao: String, direcao: int, fase: float, tempo: float, desgaste: float = 0.0) -> Dictionary:
	carregar()
	var falando := acao=="falar"
	if falando: acao="cantar"
	var d: Dictionary=modelos[modelo]
	var c: Dictionary=d.clipes[acao]
	var familia:=AnimatronicosPlex.base(modelo)
	if desgaste>0.0 and deterioracao.has(familia):
		var nivel:=clampi(roundi(desgaste*10),0,20)
		var variante: Dictionary=deterioracao[familia].get(str(nivel),{})
		if variante.get("clipes",{}).has(acao):
			d=variante
			c=d.clipes[acao]
	var instante: float
	if acao=="andar": instante=fposmod(fase,1.0)
	elif c.get("unico",false): instante=clampf(tempo/float(c.duracao),0.0,.999999)
	else:
		var relogio:=tempo if c.get("linear",false) else tempo_mecanico(tempo,d.get("mecanica",{}))
		instante=fposmod(relogio/float(c.duracao),1.0)
	var indice:=mini(int(c.frames)-1,int(floor(instante*int(c.frames))))
	if falando:
		var fala: Array=[0,1,2,3,2,1,0,0]
		indice=mini(int(c.frames)-1,int(fala[int(floor(tempo*4.0))%fala.size()]))
	return {"arquivo":c.pasta+"/"+str(posmod(direcao,8))+".png","regiao":Rect2((indice%int(c.columns))*int(d.width),(indice/int(c.columns))*int(d.height),int(d.width),int(d.height)),"indice":indice,"deslocamento":Vector2(0,float(c.get("deslocamentos",[])[indice]) if c.get("deslocamentos",[]).size()>indice else 0.0)}

