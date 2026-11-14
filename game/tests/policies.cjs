const fs=require('fs'),vm=require('vm'),path=require('path');
function load(){const c=vm.createContext({});for(const f of ['nasa-data.js','game.js'])vm.runInContext(fs.readFileSync(path.resolve(__dirname,'..',f),'utf8'),c);return c.LNS;}
function choose(E,policy='safe'){
 const s=E.state(),a=E.alert();let shelter=!!a&&policy!=='passive'&&policy!=='fortress';
 if(policy==='selective'&&a)shelter=s.risk+0.5+a.baseRisk>=40||s.shift>s.total/2;
 const tasks=[];const add=id=>{const p={tasks:tasks.concat(id),shelter};if(!E.preview(p).error){tasks.push(id);return true;}return false;};
 if(shelter){add('analyse');return {tasks,shelter};}
 if(policy==='fortress'&&s.shield<2&&s.risk<40)add('shield');
 if(s.food<=s.total-s.shift+1&&!s.crop)add('grow');
 if(s.isDay&&s.battery<Math.min(75,(s.total/2)*3+12))add('charge');
 if(!s.isDay&&s.battery<32)add('fuel');
 if(policy==='passive'&&s.shield<2&&s.risk<40)add('shield');
 if(s.repair<12)add(s.risk<40?'repair':'remote');
 if(s.primary<s.goal)add('primary');
 if(s.analysis<s.goal)add('analyse');
 if(s.bonus<6)add('bonus');
 if(s.battery<85&&s.isDay)add('charge');
 return {tasks,shelter};
}
function run(L,mode,seed,policy='safe'){const E=L.createMission(mode,seed);let result;
 for(let i=0;i<60;i++){const p=choose(E,policy);result=E.take(p);if(result.status==='invalid')return {error:result.message,s:E.state(),plan:p};if(result.status==='stageComplete')E.next();else if(result.status!=='playing')break;}
 return E.state();
}
module.exports={load,choose,run};
if(require.main===module){const L=load();for(const mode of ['easy','medium','hard'])for(const policy of ['safe','passive','selective']){const rows=Array.from({length:100},(_,i)=>run(L,mode,i*2654435761>>>0,policy));console.log(mode,policy,rows.filter(r=>r.phase==='won').length,rows.filter(r=>r.error).length,rows.find(r=>r.error||r.phase!=='won')?.reason||rows.find(r=>r.error)?.error);if(rows.some(r=>r.error))console.log(JSON.stringify(rows.find(r=>r.error)));}}

