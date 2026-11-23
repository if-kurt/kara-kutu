import sys
a=open(sys.argv[1],'rb').read(); b=open(sys.argv[2],'rb').read()
B=4096; ch=[i for i in range(0,len(a),B) if a[i:i+B]!=b[i:i+B]]
runs=[]
for i in ch:
    if runs and runs[-1][1]==i: runs[-1][1]=i+B
    else: runs.append([i,i+B])
print(sys.argv[2], 'changed blocks', len(ch), 'runs', [(hex(s),hex(e)) for s,e in runs][:40])
