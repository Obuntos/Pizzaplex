from pathlib import Path
import json,math,shutil,sys
import numpy as np
from PIL import Image

raiz=Path(__file__).resolve().parents[1]
fonte=Path(sys.argv[1])
volumes=json.loads((raiz/'dados/volumes.json').read_text())
novos={}
funcoes={}
direcoes=['frente','direita','costas','esquerda']

def rasterizar(volume,imagem):
 w,h=imagem.size
 depth=np.full((h,w),-10000,dtype=np.float32)
 normais=np.zeros((h,w,4),dtype=np.uint8)
 for face in volume['faces']:
  pts=np.array([[(p['u']-p['v'])*32+96,(p['u']+p['v'])*16-p['z']+144,(p['u']+p['v'])*32+p['z']] for p in face['points']],dtype=float)
  n=face['normal'];normal=np.array([(n[0]-n[1])/math.sqrt(2),(n[0]+n[1])/math.sqrt(2),n[2]],dtype=float);normal/=max(.001,np.linalg.norm(normal))
  rgba=np.array([*np.rint((normal*.5+.5)*255),32],dtype=np.uint8)
  for k in range(1,len(pts)-1):
   a,b,c=pts[[0,k,k+1]];u=b[:2]-a[:2];v=c[:2]-a[:2];area=u[0]*v[1]-u[1]*v[0]
   if abs(area)<1e-8:continue
   x0=max(0,int(np.floor(min(a[0],b[0],c[0])))-1);x1=min(w,int(np.ceil(max(a[0],b[0],c[0])))+1)
   y0=max(0,int(np.floor(min(a[1],b[1],c[1])))-1);y1=min(h,int(np.ceil(max(a[1],b[1],c[1])))+1)
   yy,xx=np.mgrid[y0:y1,x0:x1];dx=xx+.5-a[0];dy=yy+.5-a[1]
   s=(dx*v[1]-dy*v[0])/area;t=(u[0]*dy-u[1]*dx)/area
   dentro=(s>=-.018)&(t>=-.018)&(s+t<=1.018)
   d=a[2]+(b[2]-a[2])*s+(c[2]-a[2])*t
   reg=depth[y0:y1,x0:x1];sel=dentro&(d>=reg)
   reg[sel]=d[sel];normais[y0:y1,x0:x1][sel]=rgba
 alpha=np.array(imagem)[:,:,3]>0
 for _ in range(4):
  vazios=alpha&(depth<-9999)
  if not vazios.any():break
  anterior=depth.copy();an=normais.copy()
  for dy,dx in [(0,1),(0,-1),(1,0),(-1,0)]:
   d=np.roll(anterior,(dy,dx),(0,1));n=np.roll(an,(dy,dx),(0,1));sel=vazios&(d>-9999)
   depth[sel]=d[sel]+(-2*dy if abs(n[:,:,2].astype(int)-255).max()==0 else 0)
   normais[sel]=n[sel];vazios[sel]=False
 if (alpha&(depth<-9999)).any():raise RuntimeError('Geometria não cobre o sprite')
 depth[~alpha]=-10000;normais[~alpha]=0
 return depth,normais

for arq in sorted((fonte/'itens').glob('*/asset.json')):
 dados=json.loads(arq.read_text())
 for item in dados['assets']:
  nome=item['id'].replace('-','_');pasta=raiz/'assets/objetos/novos'/nome;(pasta/'sprites').mkdir(parents=True,exist_ok=True)
  estados=[s['id'] for s in item['states']]
  novos[nome]={'nome':item['name'],'pasta':'res://'+pasta.relative_to(raiz).as_posix(),'largura':max(1,math.ceil(item['footprint']['width'])),'profundidade':max(1,math.ceil(item['footprint']['depth'])),'altura':item['height'],'pivo':[96,144],'estados':estados,'estado_padrao':estados[0],'sobreposto':item['placement']=='surface' or item['walkable'],'apoio':item['placement']=='surface','transitavel':item['walkable'],'original':item['id']}
  func={'id':nome,'grupo':arq.parent.name,'nome':item['name'],'superficie':item.get('surfaceHeight'),'apoio':item['placement']=='surface','categoria':'utensilio' if nome in ['prato','bandeja'] else nome,'estados':{}}
  for state in item['states']:
   func['estados'][state['id']]=[]
   for r,view in enumerate(state['directions']):
    png=arq.parent/view['sprite'];v=json.loads((arq.parent/view['volume']).read_text());im=Image.open(png).convert('RGBA');target=pasta/'sprites'/state['id'];target.mkdir(exist_ok=True)
    shutil.copyfile(png,target/(direcoes[r]+'.png'))
    shutil.copyfile(arq.parent/view['volume'],target/(direcoes[r]+'.volume.json'))
    dep,n=rasterizar(v,im);dep.tofile(target/(direcoes[r]+'.bin'));Image.fromarray(n).save(target/(direcoes[r]+'.normal.png'))
    prefix='res://'+target.relative_to(raiz).as_posix()+'/'+direcoes[r]
    volumes[f'{nome}:{r}:4:0:0:{state["id"]}']={'image':prefix+'.png','depth':prefix+'.bin','normal':prefix+'.normal.png','origin':[-96,-144]}
    if state['id']==estados[0]:volumes[f'{nome}:{r}:4:0:0:']=volumes[f'{nome}:{r}:4:0:0:{state["id"]}']
    func['estados'][state['id']].append({'interacao':view['interaction'],'apoios':view['supports'],'reserva':view['reservedFloorCells']})
  funcoes[nome]=func
for nome,titulo,conteudo,qtd in [('caixa_ingredientes','Caixa de ingredientes','ingredientes',8),('caixa_utensilios','Caixa de utensílios','utensilios',6)]:
 base=json.loads((raiz/'dados/objetos.json').read_text())['caixa'].copy();base.update(nome=titulo,origem_volume='caixa',recurso=conteudo,quantidade=qtd);novos[nome]=base
(raiz/'dados/assets_salas.json').write_text(json.dumps(novos,ensure_ascii=False,indent=2)+'\n')
(raiz/'dados/funcoes_objetos.json').write_text(json.dumps(funcoes,ensure_ascii=False,indent=2)+'\n')
(raiz/'dados/volumes.json').write_text(json.dumps(volumes,ensure_ascii=False,separators=(',',':')))
print('Importados',len(novos),'objetos,',sum(len(f['estados']) for f in funcoes.values()),'estados com quatro direções')
