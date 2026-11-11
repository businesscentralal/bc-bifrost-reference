const {execFileSync}=require('child_process');const fs=require('fs');
const s=JSON.parse(fs.readFileSync('/run/agent-secrets/local-bc/webclient.json','utf8'));const u=s.user||s.username,p=s.password;
const cid='233157a0-f5bb-f111-85bd-6045bdfdea7c',T='w129-36',B='http://host.docker.internal:7048/BC290/api/v2.0/companies('+cid+')';
const H={Authorization:'Basic '+Buffer.from(u+':'+p).toString('base64'),'Content-Type':'application/json'};
async function rest(m,path,body,h={}){for(let i=0;i<4;i++){try{const r=await fetch(B+path+(path.includes('?')?'&':'?')+'tenant='+T,{method:m,headers:{...H,...h},body:body?JSON.stringify(body):undefined});const t=await r.text();return {status:r.status,body:t?JSON.parse(t):null}}catch(e){if(i==3)throw e}}}
function call(type,subject,data,lcid){const a={type,companyId:cid,lcid};if(subject)a.subject=subject;if(data!==undefined)a.data=data;let out;
 try{out=execFileSync('node',['/workspace/tools/origo-call.cjs','invoke_message_type',JSON.stringify(a)],{encoding:'utf8',timeout:120000})}catch(e){out=e.stdout||String(e)}
 let j=null,resp=null;try{const o=JSON.parse(out.slice(out.indexOf('{')));const t=o.content?.[0]?.text??JSON.stringify(o);const head=t.split('\n\n--- ')[0];j=JSON.parse(head);resp=j.bcResponse??j.response??j;if(typeof resp==='string')resp=JSON.parse(resp)}catch(e){resp={raw:out.slice(0,800)}}
 if(resp&&typeof resp==='object'){const w={};for(const k of Object.keys(resp))if(k!=='company'&&k!=='messageType')w[k]=resp[k];resp=w}
 return {raw:j,resp}}
const results=[];function check(name,lcid,ok,resp){results.push({name,lcid,pass:!!ok,resp:JSON.stringify(resp).slice(0,500),warnings:resp&&resp.warnings});console.log(ok?'PASS':'FAIL',lcid,name)}
function first(r){return r&&typeof r==='object'?Object.keys(r)[0]:null}
function warn(r,c,pa){return (r?.warnings||[]).some(w=>w.code===c&&w.parameter===pa)}
(async()=>{
 const item='BIFT-MCP1149';
 let g=await rest('GET',`/items?$filter=number eq '${item}'`);
 if(!g.body.value.length){const c=await rest('POST','/items',{number:item,displayName:'Bifrost MCP envelope item'});console.log('seed item',c.status)}
 for(const L of [1033,1039]){
  let r=call('MyApp.Item.List','',{itemFiltr:'19*'},L).resp;check('AC01 MyApp.Item.List itemFiltr warns',L,r.status==='Success'&&first(r)==='status'&&warn(r,'UnknownParameter','itemFiltr')&&JSON.stringify(r.warnings).includes('itemFilter'),r);
  r=call('MyApp.Hello.Get','',{name:'Ada'},L).resp;check('AC02 MyApp.Hello.Get success first',L,r.status==='Success'&&first(r)==='status',r);
  r=call('MyApp.Item.Summary.Get',item,{asOfDate:'26.09.2026'},L).resp;check('AC04 Summary local date InvalidParameterFormat',L,r.status==='Error'&&r.code==='InvalidParameterFormat'&&r.parameter==='asOfDate',r);
  r=call('Reference.Echo.Get','',{message:'hi',status:'Error'},L).resp;check('AC03 Echo message + forged status',L,r.status==='Success'&&r.message==='hi'&&!warn(r,'UnknownParameter','message'),r);
  r=call('Reference.Echo.Get','',{other:1},L).resp;check('AC03 Echo other warns',L,r.status==='Success'&&r.other===1&&warn(r,'UnknownParameter','other'),r);
  r=call('Reference.Table.Get','',{},L).resp;check('AC04 Table.Get missing MissingParameter',L,r.status==='Error'&&r.code==='MissingParameter'&&r.parameter==='tableName',r);
  r=call('Reference.Table.Get','',{tableName:'Item'},L).resp;check('AC02 Table.Get success first',L,r.status==='Success'&&first(r)==='status',r);
  r=call('Legacy.Stock.Reserve',item,{quantity:'abc'},L).resp;check('AC04 Reserve quantity abc InvalidParameterFormat',L,r.status==='Error'&&r.code==='InvalidParameterFormat'&&r.parameter==='quantity',r);
  r=call('Legacy.Stock.Reserve',item,{quantity:1,allowOverStock:false},L).resp;check('AC05 Reserve over stock BusinessCentralError no stack',L,r.status==='Error'&&r.code==='BusinessCentralError'&&!/callstack|AL call stack|\(CodeUnit /i.test(JSON.stringify(r)),r);
  r=call('Legacy.Stock.Reserve',item,{quantiy:1},L).resp;check('AC08 Reserve quantiy never silent',L,r.status==='Error'&&(r.code==='UnknownParameter'||warn(r,'UnknownParameter','quantiy')),r);
  r=call('Legacy.Stock.Get',item,undefined,L).resp;check('AC02 Legacy.Stock.Get success first',L,r.status==='Success'&&first(r)==='status',r);
  r=call('Reference.Note.Add','',{no:'BIFT-MCPN'+L,txt:'hello'},L).resp;check('AC08 Note.Add txt never silent',L,(r.status==='Error'&&r.code==='UnknownParameter')||(r.status==='Success'&&warn(r,'UnknownParameter','txt')),r);
 }
 fs.writeFileSync('results.json',JSON.stringify(results,null,1));
 console.log('passed',results.filter(x=>x.pass).length,'failed',results.filter(x=>!x.pass).length);
})();
