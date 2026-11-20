(() => {
const query = new URL(location.href).searchParams;
const defect = query.get('defect');
if (query.has('unsupported-dark')) {
  const match = window.matchMedia.bind(window);
  window.matchMedia = media => match(media === '(prefers-color-scheme: dark)' ? 'not all' : media);
}
window.fixtureFires=0;
class Demo extends HTMLElement {
  connectedCallback() {
    this.trigger=this.querySelector('#trigger');this.popup=this.querySelector('#popup');
    this.click=()=>this.toggle();this.trigger.addEventListener('click',this.click);
    this.key=e=>{const items=[...this.querySelectorAll('[role=menuitem]')];let i=items.indexOf(document.activeElement);
      if(e.key==='ArrowDown'||e.key==='ArrowUp'){e.preventDefault();this.popup.hidden=false;this.trigger.setAttribute('aria-expanded','true');items[(i+(e.key==='ArrowUp'?-1:1)+items.length)%items.length].focus();}
      if(e.key==='Home'&&defect!=='keyboard'){e.preventDefault();items[0].focus();}
      if(e.key==='End'){e.preventDefault();items[items.length-1].focus();}
      if(e.key==='Escape'){this.close();this.trigger.focus();}
      if(e.key==='Tab')this.close();
    };this.addEventListener('keydown',this.key);
    if(defect==='listeners')document.addEventListener('fixture-leak',()=>{});
    if(defect==='double-fire')document.addEventListener('fixture-probe',()=>window.fixtureFires++);
  }
  toggle(){this.popup.hidden=!this.popup.hidden;this.trigger.setAttribute('aria-expanded',String(!this.popup.hidden));}
  close(){this.popup.hidden=true;this.trigger.setAttribute('aria-expanded','false');}
  disconnectedCallback(){this.trigger.removeEventListener('click',this.click);this.removeEventListener('keydown',this.key);}
}
customElements.define('gate-demo',Demo);
document.addEventListener('htmx:beforeHistorySave',()=>{if(defect!=='stale')document.querySelector('gate-demo')?.close();});
document.getElementById('probe')?.addEventListener('click',()=>{window.fixtureFires++;document.dispatchEvent(new Event('fixture-probe'));document.getElementById('fires').value=String(window.fixtureFires);});
document.getElementById('mutate')?.addEventListener('click',()=>{
  if(defect==='label')document.getElementById('trigger').textContent='';
  if(defect==='style-interaction')document.getElementById('trigger').setAttribute('style','color:red');
});
if(defect==='external'){const image=new Image();image.src='https://example.invalid/gate.png';document.body.append(image);}
if(defect==='fine')document.getElementById('probe').classList.add('tiny');
if(defect==='coarse')document.getElementById('probe').classList.add('small');
if(defect==='wrong-region') {
  const other=document.createElement('div');other.id='wrong-region';document.body.append(other);
  document.getElementById('swap').setAttribute('hx-target','#wrong-region');
}
if(defect==='background-focus')document.getElementById('name').addEventListener('focus',()=>{
  if(window.fixtureBackgrounded)return;window.fixtureBackgrounded=true;
  let frame=0;const background=()=>{if(++frame<6)requestAnimationFrame(background);
    else window.fixtureOther=window.open('/next.html','focus-contender');};
  requestAnimationFrame(background);
});
// Native focus recovery can fire focus again while the first sequence is settling.
if(defect==='late-outline')document.getElementById('name').addEventListener('focus',()=>{
  let frame=0;const input=document.getElementById('name');
  const advance=()=>{input.setAttribute('data-outline-step',String(++frame));if(frame<24)requestAnimationFrame(advance);};
  requestAnimationFrame(advance);
},{once:true});
if(defect)document.documentElement.classList.add('defect-'+defect);
})();
