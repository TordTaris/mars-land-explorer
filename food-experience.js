(()=>{'use strict';
const groups=[
{name:'Thai & Southeast Asian',items:[['🍛','Thai basil rice'],['🍜','Pad Thai'],['🥗','Som tam'],['🍲','Tom yum'],['🍚','Green curry']]},
{name:'Japanese',items:[['🍣','Sushi'],['🍜','Ramen'],['🍱','Bento'],['🍤','Tempura']]},
{name:'Chinese',items:[['🥟','Dim sum'],['🍜','Chow mein'],['🥡','Fried rice'],['🍲','Hot pot']]},
{name:'Korean',items:[['🍗','Korean fried chicken'],['🍲','Kimchi stew'],['🍚','Bibimbap']]},
{name:'Indian',items:[['🍛','Butter chicken'],['🫓','Naan & curry'],['🍚','Biryani']]},
{name:'Western & American',items:[['🍔','Burger'],['🍕','Pizza'],['🥪','Sandwich'],['🥩','Steak']]},
{name:'Italian',items:[['🍝','Pasta'],['🍕','Neapolitan pizza'],['🥘','Risotto']]},
{name:'Mexican & Latin',items:[['🌮','Tacos'],['🌯','Burrito'],['🫔','Quesadilla']]},
{name:'Middle Eastern',items:[['🥙','Shawarma'],['🧆','Falafel'],['🍢','Kebab']]},
{name:'European & African',items:[['🥐','Croissant'],['🥘','Paella'],['🍲','Jollof rice']]},
{name:'Vegetarian & Vegan',items:[['🥗','Plant-based bowl'],['🍄','Mushroom steak'],['🥑','Avocado toast']]},
{name:'Seafood',items:[['🦐','Grilled prawns'],['🐟','Fish and chips'],['🍣','Poke bowl']]},
{name:'Bakery & Desserts',items:[['🍰','Cake'],['🍩','Doughnut'],['🍨','Ice cream'],['🥞','Pancakes']]},
{name:'Drinks & Smoothies',items:[['🧋','Bubble tea'],['☕','Coffee'],['🥤','Smoothie'],['🍵','Matcha']]},
{name:'Breakfast & Brunch',items:[['🍳','Breakfast plate'],['🥣','Oatmeal'],['🧇','Waffles']]}
];
const ingredients=['Vegetables','Mushrooms','Tofu / plant protein','Chicken','Beef','Seafood','Egg','Cheese','Herbs','Chili','Garlic','Extra sauce'];
const methods=['Chef’s choice','Grilled','Steamed','Stir-fried','Baked','Boiled / simmered','Fresh / no-cook'];
const el=(tag,attrs={},txt)=>{const n=document.createElement(tag);Object.entries(attrs).forEach(([k,v])=>n.setAttribute(k,v));if(txt!==undefined)n.textContent=txt;return n};
const style=el('style');style.textContent="#foodStudio{margin:26px 0;padding:18px;border:1px solid #d9b87866;border-radius:18px;background:linear-gradient(145deg,#142333,#09121d)}#foodStudio .fsgrid{display:grid;grid-template-columns:1fr 1fr;gap:14px;margin-top:14px}#foodStudio .fscard{padding:14px;border:1px solid #ffffff20;border-radius:12px;background:#0b1521;min-width:0}#foodStudio label{display:block;margin:10px 0 5px;color:#e8d4ad;font-size:11px}#foodStudio select{width:100%;padding:10px;border:1px solid #405064;border-radius:8px;background:#07101a;color:#fff}#foodStudio .checks{display:grid;grid-template-columns:1fr 1fr;gap:6px}#foodStudio .checks label{margin:0;padding:7px;background:#101d2b;border-radius:7px}#foodStudio .preview{display:grid;place-items:center;min-height:160px;border-radius:12px;background:radial-gradient(circle,#58402d,#182535);font-size:70px;animation:fsfloat 2.5s ease-in-out infinite}@keyframes fsfloat{50%{transform:translateY(-5px)}}#foodStudio .summary{padding:10px;margin-top:10px;background:#07101a;border-radius:9px;font-size:11px;line-height:1.6;min-height:65px}#foodStudio button{font-size:11px;margin:8px 5px 0 0}#foodStudio .basketrow{display:flex;justify-content:space-between;padding:7px 0;border-bottom:1px solid #ffffff18;font-size:11px}@media(max-width:650px){#foodStudio .fsgrid{grid-template-columns:1fr}}";
document.head.append(style);
const root=el('section',{id:'foodStudio'});root.innerHTML=[
'<div style="font-size:10px;letter-spacing:2px;color:#d9b878;font-weight:800">ALL CUISINES · INTERACTIVE FOOD EXPERIENCE</div>',
'<h2>Build your own meal</h2><p style="color:#aebbc8;font-size:12px">Choose food from around the world, customize ingredients and cooking style, and see your dish preview update instantly.</p>',
'<div class="fsgrid"><div class="fscard"><label for="fsCuisine">Cuisine / category</label><select id="fsCuisine"></select>',
'<label for="fsDish">Dish</label><select id="fsDish"></select><label>Ingredients & toppings</label><div class="checks" id="fsIngredients"></div>',
'<label for="fsMethod">Cooking style</label><select id="fsMethod"></select><label for="fsSpice">Spice level</label><select id="fsSpice"><option>None</option><option>Mild</option><option selected>Medium</option><option>Hot</option><option>Extra hot</option></select>',
'<label for="fsPortion">Portion</label><select id="fsPortion"><option>Regular</option><option>Small</option><option>Large</option><option>Sharing size</option></select>',
'<button class="primary" id="fsAdd">＋ Add customized dish</button><button id="fsReset">Reset</button></div>',
'<div class="fscard"><div style="font-size:10px;color:#d9b878;letter-spacing:2px">LIVE DISH PREVIEW</div><div class="preview" id="fsEmoji">🍛</div><b id="fsName">Thai basil rice</b><div class="summary" id="fsSummary" aria-live="polite"></div>',
'<div style="margin-top:14px"><b>My virtual food tray</b><div id="fsBasket" style="margin-top:8px;color:#aebbc8;font-size:11px">No customized dishes added yet.</div></div>',
'<p style="color:#91a0af;font-size:10px">Free virtual experience. No MLC, payment, kitchen order or physical delivery.</p></div></div>'
].join('');
const grid=document.getElementById('foods');if(grid)grid.insertAdjacentElement('afterend',root);
const cuisine=document.getElementById('fsCuisine'),dish=document.getElementById('fsDish'),checks=document.getElementById('fsIngredients'),method=document.getElementById('fsMethod');
groups.forEach((g,i)=>cuisine.add(new Option(g.name,String(i))));methods.forEach(x=>method.add(new Option(x,x)));
ingredients.forEach((x,i)=>{const label=el('label'),input=el('input',{type:'checkbox',value:x});if([0,2,8].includes(i))input.checked=true;label.append(input,document.createTextNode(' '+x));checks.append(label)});
let basket=[];
function selected(){const g=groups[Number(cuisine.value)]||groups[0],d=g.items[Number(dish.value)]||g.items[0];return {group:g.name,emoji:d[0],name:d[1],ingredients:[...checks.querySelectorAll('input:checked')].map(x=>x.value),method:method.value,spice:document.getElementById('fsSpice').value,portion:document.getElementById('fsPortion').value}}
function update(){const x=selected();document.getElementById('fsEmoji').textContent=x.emoji;document.getElementById('fsName').textContent=x.name;document.getElementById('fsSummary').textContent=x.group+' · '+x.ingredients.join(', ')+' · '+x.method+' · '+x.spice+' spice · '+x.portion+' · FREE'}
function fill(){dish.replaceChildren();(groups[Number(cuisine.value)]||groups[0]).items.forEach((x,i)=>dish.add(new Option(x[1],String(i))));update()}
function draw(){const b=document.getElementById('fsBasket');b.replaceChildren();if(!basket.length){b.textContent='No customized dishes added yet.';return}basket.forEach((x,i)=>{const row=el('div',{class:'basketrow'});row.append(el('span',{},x.emoji+' '+x.name+' · '+x.portion),el('button',{type:'button','data-remove':String(i)},'Remove'));b.append(row)});b.append(el('div',{},basket.length+' dish(es) · FREE'))}
cuisine.addEventListener('change',fill);[dish,checks,method,document.getElementById('fsSpice'),document.getElementById('fsPortion')].forEach(x=>x.addEventListener('change',update));
document.getElementById('fsAdd').addEventListener('click',()=>{basket.push(selected());draw()});
document.getElementById('fsReset').addEventListener('click',()=>{checks.querySelectorAll('input').forEach((x,i)=>x.checked=[0,2,8].includes(i));method.selectedIndex=0;document.getElementById('fsSpice').value='Medium';document.getElementById('fsPortion').value='Regular';update()});
document.getElementById('fsBasket').addEventListener('click',e=>{const b=e.target.closest('[data-remove]');if(!b)return;basket.splice(Number(b.dataset.remove),1);draw()});
fill();draw();
})();