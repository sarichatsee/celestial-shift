"""Refresh public DONKI data and a classic-script offline bundle. Python stdlib only."""
import json, urllib.request, hashlib, datetime, pathlib, sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
BASE='https://ccmc.gsfc.nasa.gov/DONKI-API/get/'
URLS={
 'flr':BASE+'FLR?startDate=2024-05-01&endDate=2024-06-15&catalog=M2M_CATALOG&version=Latest',
 'sep':BASE+'SEP?startDate=2024-04-25&endDate=2024-06-15&catalog=M2M_CATALOG&version=Latest'}
def latest(rows,key):
 out={}
 for row in rows:
  if row[key] not in out or row.get('versionId',0)>out[row[key]].get('versionId',0):out[row[key]]=row
 return list(out.values())
def links(row):return {x['activityID'] for x in row.get('linkedEvents') or []}
def stamp(t):return datetime.datetime.fromisoformat(t.replace('Z','+00:00'))
def build():
 meta=[]; raw={}
 for key,url in URLS.items():
  p=ROOT/'data'/f'{key}.json'
  if '--offline' not in sys.argv:
   payload=urllib.request.urlopen(url,timeout=45).read()
   rows=json.loads(payload)
   if not isinstance(rows,list):raise ValueError('Expected array from '+url)
   p.write_bytes(payload)
  raw[key]=json.loads(p.read_bytes())
  meta.append({'url':url,'file':f'data/{key}.json','sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'count':len(raw[key])})
 fs=latest(raw['flr'],'flrID');ss=latest(raw['sep'],'sepID')
 # Conservative training clusters: join by shared flare OR observations within 48h.
 # This is bounded educational aggregation, not an independent physical-storm catalogue.
 groups=[]
 for s in sorted(ss,key=lambda s:s['eventTime']):
  fl=[f for f in fs if s['sepID'] in links(f) or f['flrID'] in links(s)]
  if not fl:continue
  matches=[g for g in groups if set(x['flrID'] for x in g['flares'])&set(x['flrID'] for x in fl) or abs((stamp(s['eventTime'])-stamp(g['end'])).total_seconds())<=48*3600]
  if matches:
   g=matches[0]
   for other in matches[1:]:g['flares']+=other['flares'];g['seps']+=other['seps'];groups.remove(other)
   g['flares']+=fl;g['seps'].append(s);g['end']=s['eventTime']
  else:groups.append({'start':s['eventTime'],'end':s['eventTime'],'flares':fl,'seps':[s]})
 bundles=[];used=set()
 for i,g in enumerate(groups):
  fl=latest(g['flares'],'flrID');used.update(f['flrID'] for f in fl)
  bundles.append({'id':'cluster-'+str(i),'hit':True,'flares':fl,'seps':latest(g['seps'],'sepID'),'start':g['start'],'end':g['end']})
 for f in fs:
  if f['flrID'] not in used and f['classType'].startswith(('M','X')) and not any('-SEP-' in x for x in links(f)):
   bundles.append({'id':f['flrID'],'hit':False,'flares':[f],'seps':[],'start':f['beginTime'],'end':f['endTime'] or f['peakTime']})
 assert sum(b['hit'] for b in bundles)>=3,'Need three distinct training clusters'
 result={'retrievedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'sources':meta,'aggregation':'Shared flare associations or adjacent SEP observations within 48h; training clusters, not independent physical storms. Missing linkage is not proof of no hazard.','bundles':bundles}
 (ROOT/'nasa-data.js').write_text('globalThis.LNS=globalThis.LNS||{};\nLNS.NASA='+json.dumps(result,ensure_ascii=False)+';\n',encoding='utf-8')
 (ROOT/'data'/'provenance.json').write_text(json.dumps({k:v for k,v in result.items() if k!='bundles'},indent=2),encoding='utf-8')
 print('Retrieved',len(fs),'flares,',len(ss),'SEP records;',sum(b['hit'] for b in bundles),'training hit clusters;',sum(not b['hit'] for b in bundles),'unlinked flare candidates')
if __name__=='__main__':build()
