class_name ClipesPlex
extends RefCounted

static var modelos: Dictionary = {}

static func carregar() -> void:
	if modelos.is_empty(): AtracoesCatalogoPlex.registrar_clipes(modelos)

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

static func quadro(modelo: String, acao: String, direcao: int, fase: float, tempo: float, _desgaste: float = 0.0) -> Dictionary:
	carregar()
	var falando := acao=="falar"
	if falando: acao="cantar"
	var d: Dictionary=modelos[modelo]
	var c: Dictionary=d.clipes[acao]
	if c.has("repetir_desde") and tempo>=float(c.duracao):
		var inicio:=float(clampi(int(c.repetir_desde),0,int(c.frames)-1))*float(c.duracao)/float(c.frames)
		tempo=inicio+fposmod(tempo-float(c.duracao),float(c.duracao)-inicio)
	var instante: float
	if acao in ["andar","andar_possuido"]: instante=fposmod(fase,1.0)
	elif c.get("unico",false): instante=clampf(tempo/float(c.duracao),0.0,.999999)
	elif acao in ["cantar","dancar"] and not c.has("repetir_desde") and not c.get("loop_fechado",false):
		var ida:=fposmod(tempo/maxf(.01,float(c.duracao)),2.0)
		instante=smoothstep(0.0,1.0,1.0-absf(1.0-ida))
	else:
		var relogio:=tempo if c.get("linear",false) else tempo_mecanico(tempo,d.get("mecanica",{}))
		instante=fposmod(relogio/float(c.duracao),1.0)
	var indice:=mini(int(c.frames)-1,int(floor(instante*int(c.frames))))
	if falando and not AtracoesCatalogoPlex.permitido(modelo) and not modelo.begins_with("novo_") and modelo!="fantasia_coelho":
		var fala: Array=[0,1,2,3,2,1,0,0]
		indice=mini(int(c.frames)-1,int(fala[int(floor(tempo*4.0))%fala.size()]))
	var fisico: int=c.get("mapa_quadros",{}).get(str(posmod(direcao,8)),[])[indice] if c.has("mapa_quadros") else indice
	return {"arquivo":c.pasta+"/"+str(posmod(direcao,8))+".png","regiao":Rect2((fisico%int(c.columns))*int(d.width),floori(float(fisico)/int(c.columns))*int(d.height),int(d.width),int(d.height)),"indice":indice,"deslocamento":Vector2(0,float(c.get("deslocamentos",[])[indice]) if c.get("deslocamentos",[]).size()>indice else 0.0)}



static func pronto(caminho: String) -> bool:
	var normal:=caminho.replace("res://assets/personagens/","res://assets/iluminacao/personagens/").replace("res://assets/sistemas/","res://assets/iluminacao/sistemas/")
	var pronto_base:=true
	for arquivo in [caminho,normal,normal.replace(".png","_material.png")]:
		if not ResourceLoader.exists(arquivo): continue
		if not TexturasPosesPlex.recurso_pronto(arquivo): pronto_base=false
	return pronto_base
