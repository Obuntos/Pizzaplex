class_name ClipesPlex
extends RefCounted

static var modelos: Dictionary = {}

static func carregar() -> void:
	if modelos.is_empty(): modelos = JSON.parse_string(FileAccess.get_file_as_string("res://dados/clipes_modelos.json"))

static func possui(modelo: String, acao: String) -> bool:
	carregar()
	return modelos.get(modelo,{}).get("clipes",{}).has(acao)

static func tempo_mecanico(tempo: float, m: Dictionary) -> float:
	var local := fposmod(tempo,float(m.get("period",10.4)))
	var inicio: float = m.get("start",2.8)
	var pausa: float = m.get("hold",.28)
	if local < inicio: return tempo
	if local < inicio+pausa: return tempo-local+inicio
	return tempo-pausa*(1.0-smoothstep(0.0,float(m.get("recovery",.4)),local-inicio-pausa))

static func quadro(modelo: String, acao: String, direcao: int, fase: float, tempo: float) -> Dictionary:
	carregar()
	var d: Dictionary = modelos[modelo]
	var c: Dictionary = d.clipes[acao]
	var instante := fposmod(fase,1.0) if acao == "andar" else fposmod(tempo_mecanico(tempo,d.mecanica)/float(c.duracao),1.0)
	var indice := mini(int(c.frames)-1,int(floor(instante*int(c.frames))))
	return {"arquivo":c.pasta+"/"+str(posmod(direcao,8))+".png","regiao":Rect2((indice%int(c.columns))*int(d.width),(indice/int(c.columns))*int(d.height),int(d.width),int(d.height)),"indice":indice}
