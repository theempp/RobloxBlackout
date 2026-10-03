"""Measure natural tyre envelopes and a single axis-aligned fit; no mesh edits."""
import sys, json
from pathlib import Path
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE/'.deps'))
import numpy as np
from scipy.optimize import least_squares
from scipy.spatial import cKDTree
v=np.load(HERE/'raw_vertices.npz')['vertices']
centers=[]; wheels=[]
for axle,seed in [('F',-.505),('R',.63)]:
    for side,sign in [('L',-1),('R',1)]:
        # Raw Y becomes kart X; wheels lie on the outer flanks.
        distance=np.linalg.norm(v[:,[0,2]]-[seed,-.063],axis=1)
        p=v[(v[:,1]*sign>.33)&(v[:,1]*sign<.37)&(distance<.17)&(v[:,2]<-.075)]
        c=np.array([seed,-.06]); radius=.15
        # Fit lower 240 degrees of tyre outline, avoiding the fused upper arch.
        for _ in range(5):
            rel=p[:,[0,2]]-c; angle=np.arctan2(rel[:,1],rel[:,0]); r=np.linalg.norm(rel,axis=1)
            samples=[]
            for a in np.linspace(-2.5,-.64,45):
                mask=(abs(angle-a)<.035)
                if mask.sum()>5:
                    ids=np.flatnonzero(mask); samples.append(p[ids[np.argmin(abs(r[ids]-np.quantile(r[ids],.97)))]][[0,2]])
            samples=np.array(samples)
            fit=least_squares(lambda t: np.linalg.norm(samples-t[:2],axis=1)-t[2],[*c,radius],loss='soft_l1',f_scale=.002)
            c=fit.x[:2];radius=fit.x[2]
        # Thickness from exposed lower tread, clear of body/suspension.
        q=v[(abs(v[:,0]-c[0])<radius*.65)&(v[:,2]<c[1]-radius*.7)&(v[:,1]*sign>.25)]
        inner,outer=np.quantile(q[:,1]*sign,[.01,.99])
        center=[float(c[0]),float(sign*(inner+outer)/2),float(c[1])]
        centers.append(center)
        wheels.append(dict(name='Wheel_'+axle+side,raw_center=center,raw_radius=float(radius),raw_width=float(outer-inner),outline_rms=float(np.sqrt(np.mean(fit.fun**2)))))
c=np.array(centers)
# Raw -> Blender: (raw_y, -raw_x, raw_z); -> Roblox (raw_y, raw_z, raw_x).
targets=np.array([[-1.925,.92,-3.4],[1.925,.92,-3.4],[-1.925,.92,3.6],[1.925,.92,3.6]])
raw_rb=c[:,[1,2,0]]
scale=[];offset=[]
for i in [0,1,2]:
    if i==1:
        s=.92/np.mean([w['raw_radius'] for w in wheels]); b=.92-s*raw_rb[:,i].mean()
    else:
        s,b=np.linalg.lstsq(np.column_stack([raw_rb[:,i],np.ones(4)]),targets[:,i],rcond=None)[0]
    scale.append(float(s));offset.append(float(b))
fitted=raw_rb*np.array(scale)+offset
for i,w in enumerate(wheels):
    w['fitted_center_rb']=fitted[i].tolist();w['hub_error']=float(np.linalg.norm(fitted[i]-targets[i]))
    w['fitted_radius_vertical']=w['raw_radius']*scale[1]
    w['fitted_radius_longitudinal']=w['raw_radius']*scale[2]
    w['fitted_width']=w['raw_width']*scale[0]
mirror=v.copy(); mirror[:,1]=v[:,1].min()+v[:,1].max()-mirror[:,1]
d=cKDTree(v).query(mirror,workers=-1)[0]
report=dict(raw_axis='X longitudinal, nose -X; Y lateral; Z up',
    symmetry_raw_nearest_vertex=dict(mean=float(d.mean()),p95=float(np.quantile(d,.95)),maximum=float(d.max())),
    fit_scale_rb=scale,fit_offset_rb=offset,wheels=wheels, hub_tolerance=.15,
    hub_fit_pass=bool(max(w['hub_error'] for w in wheels)<=.15))
(HERE/'fit_measurements.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
assert report['hub_fit_pass'], 'STOP: natural wheel centres cannot satisfy hub tolerance'
