/* Pure mission engine. Snapshot data is copied; unresolved events stay private. */
(function(root){'use strict';const L=root.LNS=root.LNS||{};
const MODES={easy:{stages:4,size:2,food:12,battery:28,fuel:0,goal:6},medium:{stages:7,size:4,food:18,battery:22,fuel:7,goal:18},hard:{stages:7,size:4,food:12,battery:16,fuel:5,goal:30}};
const TITLES=['Establish the base','Grow and investigate','Prepare for darkness','Sunset','Protect the crew','Maintain the outpost','Reach sunrise'];
const copy=x=>JSON.parse(JSON.stringify(x));
L.createMission=function(mode='medium',seed=Date.now(),data=L.NASA){
 if(!MODES[mode])throw Error('Unknown difficulty');const cfg=MODES[mode],total=cfg.stages*cfg.size;let rng=seed>>>0;
 const rand=()=>{rng=(Math.imul(rng,1664525)+1013904223)>>>0;return rng/4294967296;};
 const shuffle=a=>{a=a.slice();for(let i=a.length-1;i>0;i--){let j=Math.floor(rand()*(i+1));[a[i],a[j]]=[a[j],a[i]];}return a;};
 const template=['samples','relay','garden'][Math.floor(rand()*3)];
 const chosen=shuffle(data.bundles.filter(b=>b.hit)).slice(0,3).concat(shuffle(data.bundles.filter(b=>!b.hit)).slice(0,mode==='easy'?2:5)).sort((a,b)=>a.start.localeCompare(b.start));
 if(chosen.filter(b=>b.hit).length!==3)throw Error('NASA training dataset needs three hit clusters');
 const slots=shuffle(Array.from({length:total-cfg.size},(_,i)=>i+cfg.size+1)).slice(0,chosen.length).sort((a,b)=>a-b);
 const events=new Map(chosen.map((b,i)=>[slots[i],b]));
 let s={mode,seed:seed>>>0,template,shift:1,stage:1,total,stageSize:cfg.size,phase:'playing',battery:cfg.battery,food:cfg.food,air:60,fuel:cfg.fuel,risk:0,shield:0,shieldWork:0,repair:0,primary:0,analysis:0,bonus:0,crop:null,history:[],notice:'',reason:null};let checkpoint=copy(s);
 const day=()=>s.shift<=total/2,warning=()=>events.get(s.shift),fault=()=>mode!=='easy'&&s.shift>cfg.size*2&&s.repair<12;
 const objective=()=>({samples:['Collect Moon samples','Collect samples','Analyse samples'],relay:['Restore the communications relay','Repair relay modules','Calibrate the relay'],garden:['Study lunar greenhouse growth','Gather soil samples','Analyse plant growth']}[template]);
 function achievements(){const awards=[{title:'Safe return',done:s.phase==='won'}, {title:objective()[1],done:s.primary>=cfg.goal},{title:objective()[2],done:s.analysis>=cfg.goal},{title:'Repair the cooling system',done:s.repair>=12},{title:'Extra discovery',done:s.bonus>=6},{title:'Careful exposure: finish below 40 risk',done:s.phase==='won'&&s.risk<40},{title:'Prepared return: 8 battery and 2 food',done:s.phase==='won'&&s.battery>=8&&s.food>=2}];return mode==='easy'?awards.slice(0,3):awards;}
 function state(){return {...copy(s),isDay:day(),title:mode==='easy'?['First steps','Prepare','Night watch','Return'][s.stage-1]:TITLES[s.stage-1],goal:cfg.goal,objective:objective()[0],achievements:achievements(),background:0.5};}
 function alert(){const b=warning();if(!b)return null;return {classType:b.flares[0].classType,date:b.flares[0].peakTime.slice(0,10),baseRisk:[68,50,34][s.shield],shelterRisk:1.5};}
 function tasks(shelter=false){
 const out=[
  {id:'charge',name:'Charge battery',crew:1,energy:6,description:'+4.8 stored energy; sunlight only.',blocked:!day()?'No sunlight':s.battery>=90?'Battery full':''},
  {id:'fuel',name:'Run backup generator',crew:1,energy:0,description:'Use 1 fuel to add 5 energy before this shift.',blocked:s.fuel<1?'No fuel left':s.battery>=90?'Battery full':''},
  {id:'grow',name:'Start a food crop',crew:1,energy:day()?1:2,description:'Harvest 6 food automatically in two shifts.',blocked:s.crop?'A crop is already growing':s.shift+2>total?'Too late to harvest':''},
  {id:'shield',name:'Build passive shielding',crew:2,energy:3,outdoor:true,description:`${s.shieldWork}/6 work toward next layer. +3 per shift; works next shift.`,blocked:s.shield>=2?'Both layers complete':''},
  {id:'repair',name:'Repair cooling: outside',crew:1,energy:1,outdoor:true,repair:true,description:`${s.repair}/12 repaired. +3 work; prevents extra energy drain.`,blocked:s.repair>=12?'Repair complete':''},
  {id:'remote',name:'Repair cooling: robot',crew:1,energy:2,repair:true,description:`${s.repair}/12 repaired. +2 work; indoor alternative.`,blocked:s.repair>=12?'Repair complete':''},
  {id:'primary',name:objective()[1],crew:mode==='easy'?1:2,energy:2,outdoor:true,description:`${s.primary}/${cfg.goal} work. +3 per shift. ${Math.ceil((cfg.goal-s.primary)/3)} shifts remaining. Collect before risk reaches 40.`,blocked:s.primary>=cfg.goal?'Subtask complete':''},
  {id:'analyse',name:objective()[2],crew:1,energy:1,safe:true,description:`${s.analysis}/${cfg.goal} work. +3 per shift. Available in shelter.`,blocked:s.primary<=s.analysis?'Collect more material first':s.analysis>=cfg.goal?'Objective complete':''},
  {id:'bonus',name:'Time-sensitive discovery',crew:2,energy:2,outdoor:true,description:`${s.bonus}/6 work. +3 per shift. Deadline: shift ${mode==='easy'?total-2:total/2}.`,blocked:s.bonus>=6?'Discovery complete':s.shift>(mode==='easy'?total-2:total/2)?'Deadline passed':''}
 ];
 return out.filter(t=>mode!=='easy'||!['fuel','repair','remote','bonus'].includes(t.id)).map(t=>({...t,blocked:t.blocked||(['repair','remote','bonus'].includes(t.id)&&s.stage===1?'Introduced in stage 2':t.outdoor&&s.risk>=40?'Mission Control: outdoor work restricted':shelter&&!t.safe?'Paused during sheltering':'')}));
 }
 function preview(plan){
 const ids=plan.tasks||[],shelter=!!plan.shelter,all=tasks(shelter);let error='';
 if(s.phase!=='playing')error='This stage has ended.';
 if(!Array.isArray(ids)||new Set(ids).size!==ids.length)return {error:'Choose each task once.'};
 const selected=ids.map(id=>all.find(t=>t.id===id));
 if(selected.some(t=>!t))return {error:'Unknown task.'};
 if(shelter&&!warning())error='Quiet shift.';
 if(selected.some(t=>t.blocked))error=selected.find(t=>t.blocked).blocked;
 if(ids.includes('repair')&&ids.includes('remote'))error='Choose one method for the cooling repair.';
 const crew=selected.reduce((a,t)=>a+t.crew,0)+(shelter?1:0);
 const energy=selected.reduce((a,t)=>a+t.energy,0)+2+(fault()?1:0)+(shelter?1:0);
 const available=(day()?10:s.battery)+(ids.includes('fuel')?5:0);
 if(crew>3)error='Only three crew are available.';
 if(energy>available+1e-9)error=mode==='easy'?'Not enough energy. Remove a task.':'Not enough energy. Remove a task or use the generator.';
 return {error,crew,energy,available,baseline:2+(fault()?1:0),interrupted:selected.filter(t=>t.outdoor).map(t=>t.name)};
 }
 function take(plan){const v=preview(plan);if(v.error)return {status:'invalid',message:v.error};
 const before=copy(s),ids=plan.tasks||[],shelter=!!plan.shelter,b=warning();let messages=[];
 if(ids.includes('fuel')){s.fuel--;s.battery=Math.min(90,s.battery+5);}
 if(!day())s.battery-=v.energy;else s.battery-=Math.max(0,v.energy-10);
 // In daylight the generator adds storage; sunlight pays task costs.
 const delta=0.5+(b&&b.hit?(shelter?1.5:[68,50,34][s.shield]):0);s.risk+=delta;
 let failed=s.risk>=100;
 if(s.crop&&s.crop.ready===s.shift){s.food+=6;s.crop=null;messages.push('Harvest arrived: +6 food.');}
 s.food--;failed=failed||s.food<0;
 for(const id of ids){const t=tasks(false).find(t=>t.id===id);if(failed)break;if(t.outdoor&&s.risk>=40){messages.push(t.name+' stopped: safety restriction.');continue;}
  if(id==='charge')s.battery=Math.min(90,s.battery+4.8);
  if(id==='grow')s.crop={ready:s.shift+2};
  if(id==='shield'){s.shieldWork+=3;if(s.shieldWork>=6){s.shield++;s.shieldWork=0;}}
  if(id==='repair')s.repair=Math.min(12,s.repair+3);
  if(id==='remote')s.repair=Math.min(12,s.repair+2);
  if(id==='primary')s.primary=Math.min(cfg.goal,s.primary+3);
  if(id==='analyse')s.analysis=Math.min(s.primary,cfg.goal,s.analysis+3);
  if(id==='bonus')s.bonus=Math.min(6,s.bonus+3);
 }
 if(failed){s.phase='lost';s.reason=s.risk>=100?'Radiation risk reached the mission limit.':'Food ran out.';}
 const record=b?{id:b.id,hit:b.hit,flares:copy(b.flares),seps:copy(b.seps),originalStart:b.start,sheltered:shelter}:null;
 messages.push(b?(b.hit?`Storm: risk +${delta-0.5}.`:'No storm hit.'):'Quiet shift.');
 s.history.push({shift:s.shift,stage:s.stage,risk:s.risk,battery:s.battery,food:s.food,plan:copy(plan),event:record});
 s.notice=messages.join(' ');
 if(s.phase!=='lost'){
  if(s.shift===total)s.phase='won';
  else if(s.shift%cfg.size===0&&mode==='easy')s.phase='stageComplete';
  else if(s.shift%cfg.size===0){
   const remaining=total-s.shift,foodReserve=s.crop?Math.max(0,s.crop.ready-s.shift-1):2;
   const nightReserve=remaining*4+2*Math.ceil(Math.max(0,remaining-s.food-(s.crop?6:0))/6);
   if(s.food<foodReserve||s.food+(s.crop?6:0)<cfg.size){s.phase='lost';s.reason='Stage reserve check: keep food for the next stage, or a crop arriving before supplies run out.';}
   else if(s.shift>=total/2&&(s.battery+s.fuel*5<nightReserve||s.battery<Math.min(cfg.size,remaining)*4)){s.phase='lost';s.reason='Stage reserve check: more stored energy or backup fuel is needed for a recoverable night. Retry this stage.';}
   else if(s.risk+remaining*0.5+4.5>=100){s.phase='lost';s.reason='Stage reserve check: leave room for background exposure and protected storm responses.';}
   else s.phase='stageComplete';
  }
  else s.shift++;
 }
 // Empty battery with no generator means no future life support. End this stage rather than accept an invalid plan forever.
 if(s.phase==='playing'&&!day()&&s.battery<2+(fault()?1:0)&&s.fuel===0){s.phase='lost';s.reason='Not enough stored energy for life support.';}
 return {status:s.phase,notice:s.notice};
 }
 function next(){if(s.phase!=='stageComplete')return;s.stage++;s.shift++;s.phase='playing';if(mode==='easy'){s.battery=Math.min(90,s.battery+4);s.food+=2;s.notice='Stage supplies: +4 battery, +2 food.';}checkpoint=copy(s);}
 function retry(){s=copy(checkpoint);}
 function debrief(){return copy(s.history);}
 return {state,alert,tasks,preview,take,next,retry,debrief};
};
})(globalThis);
