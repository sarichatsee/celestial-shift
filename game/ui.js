(function(){'use strict';const $=id=>document.getElementById(id),L=globalThis.LNS;let engine,selected=[],shelter=false,choice=null,previous=[];
const node=(tag,text,cls)=>{const e=document.createElement(tag);if(text!==undefined)e.textContent=text;if(cls)e.className=cls;return e;};
function screen(id){for(const name of ['title','game','debrief','facts'])$(name).hidden=name!==id;window.scrollTo(0,0);}
function list(host,items){host.replaceChildren(...items.map(t=>node('li',t)));}
function plan(){return {tasks:selected,shelter};}
function reset(){selected=[];shelter=false;choice=null;previous=[];}
function render(){const s=engine.state(),a=engine.alert(),v=engine.preview(plan());
 $('heading').textContent=`Stage ${s.stage}: ${s.title}`;$('clock').textContent=`Earth-day shift ${s.shift} / ${s.total}`;$('phase').textContent=s.isDay?'☀ DAY':'🌙 NIGHT';$('phase').className='chip phase '+(s.isDay?'day':'night');
 $('objective').textContent='Mission: '+s.objective;$('mission-note').textContent=`Step 1: ${s.primary}/${s.goal}   →   Step 2: ${s.analysis}/${s.goal}`;
 $('stars').textContent=`Achievements: ${s.achievements.filter(a=>a.done).length} / ${s.achievements.length}`;list($('achievements'),s.achievements.map(a=>(a.done?'★ ':'☆ ')+a.title));
 $('meters').replaceChildren();for(const [key,label,value,max,icon] of [['battery','Battery',s.battery,90,'🔋'],['food','Food',s.food,30,'🥕'],['radiation','Risk',s.risk,100,'☢'],['crew','Crew used',v.crew||0,3,'🧑‍🚀']]){
  const row=node('div',undefined,'meter '+key);row.append(node('span',icon,'meter-icon'),node('span',label,'meter-name'));const bar=node('div',undefined,'bar'),fill=node('span',undefined,'bar-fill');fill.style.width=Math.max(0,Math.min(100,value/max*100))+'%';bar.append(fill);row.append(bar,node('span',Number(value.toFixed(1)).toString(),'meter-value'));$('meters').append(row);
 }$('meters').append(node('p',`🛡 Shield: ${s.shield}/2`+(s.mode==='easy'?'':` · ⛽ Fuel: ${s.fuel}`)),node('p',s.crop?`🌱 Harvest arrives on shift ${s.crop.ready}`:'🌱 No crop growing','chart-note'));
 L.Base.update({isDay:s.isDay,lifeSupportOk:true});$('report').textContent=s.notice||'Store power for night. Use the shelter during storms.';
 $('alert').hidden=!a;if(a){$('warning').textContent=`Possible risk: stay +${a.baseRisk} · shelter +${a.shelterRisk}`;$('warning-source').textContent='';
  const affected=(shelter?previous:selected).filter(id=>!engine.tasks(false).find(t=>t.id===id)?.safe).map(id=>engine.tasks(false).find(t=>t.id===id)?.name);
  $('interruptions').textContent=(shelter?'Paused: ':'Sheltering would pause: ')+(affected.join(', ')||'no selected tasks')+'. Shelter: 1 crew + 1 energy.';
 }$('shelter').setAttribute('aria-pressed',shelter?'true':'false');$('stay').setAttribute('aria-pressed',choice==='stay'?'true':'false');
 $('availability').textContent=s.risk>=40?'Outside work closed. Indoor work is available.':'Outside work closes at 40 risk.';
 const all=engine.tasks(shelter);$('cards').replaceChildren();const blocked=[];
 const groups={};for(const title of ['Your mission','Keep the base running','Protection']){const section=node('section',undefined,'task-group');section.append(node('h3',title));const grid=node('div',undefined,'control-grid');section.append(grid);$('cards').append(section);groups[title]=grid;}
 for(const t of all){if(t.blocked){blocked.push(`${t.name}: ${t.blocked}`);continue;}
  const card=node('article',undefined,'control task'+(selected.includes(t.id)?' task-selected':''));card.append(node('h3',t.name),node('p',`${t.crew} crew · ${t.energy} energy · ${t.outdoor?'outside':t.safe?'shelter-compatible':'inside'}`,'cost'),node('p',t.description));
  const b=node('button',selected.includes(t.id)?'Unassign':'Assign','btn');b.type='button';b.setAttribute('aria-label',(selected.includes(t.id)?'Unassign ':'Assign ')+t.name);b.setAttribute('aria-pressed',String(selected.includes(t.id)));b.onclick=()=>{selected=selected.includes(t.id)?selected.filter(id=>id!==t.id):selected.concat(t.id);render();};card.append(b);const group=['primary','analyse'].includes(t.id)?'Your mission':['charge','fuel','grow','repair','remote'].includes(t.id)?'Keep the base running':'Protection';groups[group].append(card);
 }list($('blocked'),blocked);$('budget').textContent=`Crew ${v.crew||0}/3 · Energy ${v.energy||0}/${Number((v.available||0).toFixed(1))} (includes life support)`;
 $('message').textContent=v.error||(a&&choice===null?'Choose shelter or stay.':s.mode==='easy'&&s.stage===1?'Start with your mission task.':'Unassigned crew rest.');$('message').className='message '+(v.error?'problem':'hint');$('end').disabled=!!v.error||!!(a&&choice===null);
}
function summary(){const s=engine.state();screen('debrief');$('result').textContent=s.phase==='lost'?'Mission Control calls you home':s.phase==='won'?'Mission complete: safe return!':'Stage complete';$('result-text').textContent=s.reason||(s.mode==='easy'&&s.phase==='stageComplete'?'Next stage: +4 battery and +2 food.':s.notice);$('score').textContent=`${s.achievements.filter(a=>a.done).length}/${s.achievements.length} achievement stars · Risk ${s.risk.toFixed(1)}/100 · ${s.analysis>=s.goal?'Mission objective complete':'Mission objective unfinished'}`;list($('result-stars'),s.achievements.map(a=>(a.done?'★ ':'☆ ')+a.title));$('continue').hidden=s.phase!=='stageComplete';$('retry').hidden=s.phase!=='lost';$('history').replaceChildren();
 for(const h of engine.debrief().filter(h=>h.stage===s.stage)){const c=node('article',undefined,'storm-card'+(h.event&&h.event.hit?' hit':''));c.append(node('h3',`Shift ${h.shift}`),node('p',`Risk ${h.risk.toFixed(1)} · Battery ${h.battery.toFixed(1)} · Food ${h.food}`),node('p',h.plan.shelter?'Crew sheltered.':`Tasks: ${h.plan.tasks.join(', ')||'rest'}`));if(h.event){c.append(node('p',h.event.hit?'Storm hit.':'No hit.'));}$('history').append(c);}
 $('result').focus();
}
 $('start').onclick=()=>{engine=L.createMission($('difficulty').value);reset();screen('game');render();$('heading').focus();};
 $('end').onclick=()=>{const r=engine.take(plan());if(r.status==='invalid')return;reset();if(r.status==='playing')render();else summary();};
 $('shelter').onclick=()=>{if(!shelter){previous=selected.slice();selected=selected.filter(id=>engine.tasks(false).find(t=>t.id===id)?.safe);}shelter=true;choice='shelter';render();};
 $('stay').onclick=()=>{shelter=false;choice='stay';render();};
 $('continue').onclick=()=>{engine.next();reset();screen('game');render();};$('retry').onclick=()=>{engine.retry();reset();screen('game');render();};$('home').onclick=()=>screen('title');$('science').onclick=()=>screen('facts');$('back').onclick=()=>screen('title');
 $('source-note').textContent='';
 for(const src of L.NASA.sources){const p=node('p',`${src.count} records · `),a=node('a','NASA API request');a.href=src.url;a.target='_blank';a.rel='noopener';p.append(a);$('sources').append(p);}L.Base.mount($('base-picture'));
})();
