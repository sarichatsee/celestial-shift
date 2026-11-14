const assert=require('node:assert/strict'),{load,run,choose}=require('./policies.cjs');
const L=load();let results={},templates=new Set();
for(const mode of ['easy','medium','hard']){
 let wins=0,passiveLoss=0,min=9,max=0;
 for(let i=0;i<300;i++){
  const seed=i*2654435761>>>0,s=run(L,mode,seed,'safe'),p=run(L,mode,seed,'passive');
  assert.equal(s.phase,'won',JSON.stringify({mode,seed,reason:s.reason}));
  assert.equal(p.phase,'lost');assert.match(p.reason,/Radiation/);
  const fortress=run(L,mode,seed,'fortress');assert.equal(fortress.phase,'lost');assert.match(fortress.reason,/Radiation/);if(mode!=='easy')assert.equal(fortress.shield,2,'Strongest shield built before warnings');
  templates.add(s.template);wins++;passiveLoss++;
  const stars=s.achievements.filter(a=>a.done).length;min=Math.min(min,stars);max=Math.max(max,stars);
  if(mode==='easy'){assert.equal(s.achievements.length,3);assert.equal(stars,3,'Attentive Easy policy earns full stars');}
  const E=L.createMission(mode,seed);let entry=E.state();
  while(E.state().phase==='playing'){
   const before=E.state(),a=E.alert();if(before.stage===1)assert.equal(a,null);
   if(a){assert.ok(!('count' in a));assert.ok(!('hit' in a));assert.ok(!('seps' in a));}
   assert.equal(E.take({tasks:['bogus']}).status,'invalid');assert.deepEqual(E.state(),before);
   const r=E.take(choose(E,'safe'));
   if(r.status==='stageComplete'){
    E.retry();assert.deepEqual(E.state(),entry,'Retry restores exact stage entry');
    while(E.state().phase==='playing')E.take(choose(E,'safe'));
    const completed=E.state();E.next();entry=E.state();
    if(mode==='easy'){assert.equal(entry.food,completed.food+2);assert.equal(entry.battery,Math.min(90,completed.battery+4));assert.equal(entry.risk,completed.risk);assert.equal(entry.primary,completed.primary);assert.equal(entry.analysis,completed.analysis);assert.equal(entry.shield,completed.shield);assert.ok(E.tasks().every(t=>!['fuel','repair','remote','bonus'].includes(t.id)));E.retry();assert.deepEqual(E.state(),entry,'Retry cannot farm supply top-ups');}
   }
  }
  assert.equal(E.state().phase,'won');
 }
 results[mode]={safeWins:wins,passiveFailures:passiveLoss,achievementRange:[min,max]};
}
assert.equal(templates.size,3);
// Test private event resolution versus public metadata: changing a pending result
// must not alter the warning (after seeded selection, not regenerating the mission).
const E=L.createMission('medium',1);while(!E.alert()){E.take(choose(E));if(E.state().phase==='stageComplete')E.next();}
const a=E.alert();L.NASA.bundles.forEach(b=>b.hit=!b.hit);assert.deepEqual(E.alert(),a);L.NASA.bundles.forEach(b=>b.hit=!b.hit);
// Resource conservation on a sunny shift with generator and >10 task cost.
const G=L.createMission('medium',1);while(G.state().shift<9){G.take({tasks:[],shelter:!!G.alert()});if(G.state().phase==='stageComplete')G.next();}
const gb=G.state();assert.equal(G.preview({tasks:['fuel','charge','remote']}).error,'');G.take({tasks:['fuel','charge','remote']});assert.ok(Math.abs(G.state().battery-(gb.battery+5-1+4.8))<1e-8);
// Snapshot copies must not mutate engine state.
const st=G.state();st.risk=999;assert.notEqual(G.state().risk,999);
console.log(JSON.stringify({policyCampaigns:2700,retryCampaigns:900,results,checks:['all three templates','stage 1 quiet','max shield passive fails','no outcome metadata','invalid plan atomicity','exact checkpoint restore','daylight generator conservation','copied state']},null,2));

