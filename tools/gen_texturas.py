import numpy as np, sys
from PIL import Image
from scipy.ndimage import zoom, gaussian_filter, distance_transform_edt
N=512
def pn(freq,seed):
    r=np.random.RandomState(seed); g=r.rand(freq,freq)
    return zoom(g,N/freq,order=3,mode='grid-wrap')[:N,:N]
def fbm(base,oct,seed,aniso=(1,1)):
    t=np.zeros((N,N));a=1;s=0
    for o in range(oct):
        f=base*2**o
        r=np.random.RandomState(seed+o*17);g=r.rand(max(2,int(f*aniso[0])),max(2,int(f*aniso[1])))
        z=zoom(g,(N/g.shape[0],N/g.shape[1]),order=3,mode='grid-wrap')[:N,:N]
        t+=z*a;s+=a;a*=.5
    t/=s;t=(t-t.min())/(t.max()-t.min()+1e-9);return t
def col(h):h=h.lstrip('#');return np.array([int(h[i:i+2],16) for i in(0,2,4)],float)/255
def img(a):return Image.fromarray((np.clip(a,0,1)*255).astype(np.uint8))
def cracks(seed,n=6,w=1.2,length=140):
    r=np.random.RandomState(seed);m=np.zeros((N,N))
    for _ in range(n):
        x,y=r.rand()*N,r.rand()*N;a=r.rand()*6.28
        for k in range(length):
            a+=r.randn()*.12;x+=np.cos(a)*2.2;y+=np.sin(a)*2.2
            xi,yi=int(x)%N,int(y)%N;m[yi,xi]=1
            if r.rand()<.03:
                bx,by,ba=x,y,a+r.choice([-1,1])*.8
                for j in range(40):
                    ba+=r.randn()*.12;bx+=np.cos(ba)*2;by+=np.sin(ba)*2;m[int(by)%N,int(bx)%N]=1
    m=gaussian_filter(m,w);return np.clip(m*4,0,1)
def paint(name,base,under,seed,peel=.45,stain=.5,crack=5,rough=.5):
    b=col(base);u=col(under)
    n1=fbm(3,5,seed);n2=fbm(8,4,seed+1);streak=fbm(2,3,seed+2,aniso=(1,6))
    c=b[None,None,:]*np.ones((N,N,1))
    c*=(0.9+.2*n2)[:,:,None]*(0.94+.1*streak)[:,:,None]
    # humedad / manchas
    st=np.clip((fbm(2,4,seed+3,aniso=(1,3))-.45)*3,0,1)*stain
    c*=(1-.55*st)[:,:,None];c+= (np.array([.0,-.02,-.03]))[None,None,:]*st[:,:,None]
    # descascarado
    pm=fbm(4,5,seed+4);mask=(pm>1-peel*.28).astype(float)
    mk=gaussian_filter(mask,1.2);edge=np.clip(mk*(1-mk)*4,0,1)
    under_t=u[None,None,:]*(0.8+.35*fbm(10,4,seed+5))[:,:,None]
    c=c*(1-mk[:,:,None])+under_t*mk[:,:,None]
    c*=(1-.35*edge)[:,:,None]
    cr=cracks(seed+6,max(1,crack//3),.8);c*=(1-.4*cr)[:,:,None]
    g=(np.random.RandomState(seed).rand(N,N)-.5)*.05*rough;c+=g[:,:,None]
    return c
def tiles(seed,base,grout,n=8,var=.1,wear=.5,checker=None,crack=3):
    b=col(base);gr=col(grout);t=N//n
    c=np.zeros((N,N,3));r=np.random.RandomState(seed)
    for j in range(n):
        for i in range(n):
            tc=b if checker is None else (b if (i+j)%2==0 else col(checker))
            tc=tc*(1+r.randn()*var)
            c[j*t:(j+1)*t,i*t:(i+1)*t]=tc
    gm=np.zeros((N,N));gw=3
    for k in range(n):
        gm[k*t:k*t+gw,:]=1;gm[:,k*t:k*t+gw]=1
    gm=gaussian_filter(gm,.7)
    nz=fbm(6,5,seed+1);c*=(0.85+.3*nz)[:,:,None]
    dirt=np.clip((fbm(3,4,seed+2)-.5)*2.5,0,1)*wear;c*=(1-.5*dirt)[:,:,None]
    c=c*(1-gm[:,:,None])+gr[None,None,:]*(0.8+.3*nz)[:,:,None]*gm[:,:,None]
    cr=cracks(seed+3,crack,length=90);c*=(1-.75*cr)[:,:,None]
    c+= (r.rand(N,N)-.5)[:,:,None]*.04
    return c
def parquet(seed,base,dark,plank=64):
    r=np.random.RandomState(seed);c=np.zeros((N,N,3));b=col(base);d=col(dark)
    grain=fbm(3,4,seed,aniso=(8,1))
    rows=N//plank
    for j in range(rows):
        x=-int(r.rand()*200)
        while x<N:
            L=int(r.choice([160,256,320]));tint=1+r.randn()*.1
            for xx in range(x,min(N,x+L)):
                pass
            xs=np.arange(max(0,x),min(N,x+L))
            if len(xs)==0:
                x+=L;continue
            cc=(b*(1-.5*0)+ (d-b)*r.rand()*.35)*tint
            g=(grain[j*plank:(j+1)*plank][:,xs%N])
            c[j*plank:(j+1)*plank,xs]=cc[None,None,:]*(0.8+.35*g)[:,:,None]
            c[j*plank:(j+1)*plank,xs[0]:xs[0]+2]*=.35
            x+=L
        c[j*plank:j*plank+2,:]*=.35
    nz=fbm(4,4,seed+9);c*=(0.8+.3*nz)[:,:,None]
    dirt=np.clip((fbm(3,4,seed+2)-.5)*2.5,0,1);c*=(1-.4*dirt)[:,:,None]
    return c
def cement(seed,base,joints=True):
    b=col(base);nz=fbm(5,6,seed);fine=fbm(40,2,seed+1)
    c=b[None,None,:]*(0.8+.35*nz)[:,:,None]*(0.93+.1*fine)[:,:,None]
    pits=(np.random.RandomState(seed).rand(N,N)>.9985).astype(float);pits=gaussian_filter(pits,1.3)*6
    c*=(1-np.clip(pits,0,.6))[:,:,None]
    st=np.clip((fbm(2,4,seed+3,aniso=(2,2))-.5)*3,0,1);c*=(1-.45*st)[:,:,None]
    if joints:
        for k in(0,N//2):
            c[k:k+3,:]*=.4;c[:,k:k+3]*=.4
    cr=cracks(seed+4,4);c*=(1-.7*cr)[:,:,None]
    return c
OUT={}
OUT['pint_verde']=('walls',paint('v','#6f8f6a','#c9b891',101,.5,.55,4),3)
OUT['pint_celeste2']=('walls',paint('c','#7fb0c9','#c8b79a',111,.35,.5,3),3)
OUT['pint_amarillo']=('walls',paint('a','#d9b94a','#b9966a',121,.5,.5,5),3)
OUT['pint_rosa']=('walls',paint('r','#d4a0a0','#c9b9a0',131,.45,.4,4),3)
OUT['pint_ocre']=('walls',paint('o','#b5793c','#8a5a3a',141,.6,.6,6),3)
OUT['pint_blanco']=('walls',paint('b','#d8d4c8','#b8a888',151,.35,.7,4),3)
OUT['pint_azul']=('walls',paint('z','#4f6f94','#b8b0a0',161,.4,.55,3),3)
OUT['pint_bordo']=('walls',paint('d','#7a3a3a','#a89478',171,.5,.5,5),3)
OUT['f_baldosa_gris']=('floors',tiles(201,'#8a8a86','#3a3a38',8,.06,.6),2)
OUT['f_damero']=('floors',tiles(211,'#d8d4c4','#4a4a46',8,.05,.6,checker='#3a3f45'),2)
OUT['f_ceramica_beige']=('floors',tiles(221,'#c9b48a','#5a5040',6,.07,.5),2)
OUT['f_parquet']=('floors',parquet(231,'#a8794a','#6a4426'),2)
OUT['f_cemento']=('floors',cement(241,'#8d8a83'),2.5)
OUT['f_lino_verde']=('floors',tiles(251,'#7a9a78','#3a4a3a',4,.04,.7),2)
import json,os
meta={}
for k,(d,a,sz) in OUT.items():
    os.makedirs(f'out/{d}',exist_ok=True);img(a).save(f'out/{d}/{k}.jpg',quality=88);meta[k]=(d,sz)
json.dump(meta,open('out/meta1.json','w'))
from PIL import Image as I
ks=list(OUT);m=I.new('RGB',(256*5,256*3))
for i,k in enumerate(ks):m.paste(I.open(f'out/{OUT[k][0]}/{k}.jpg').resize((256,256)),((i%5)*256,(i//5)*256))
m.save('sheet1.jpg')
