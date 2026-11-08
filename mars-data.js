(() => {
  const form = document.getElementById('searchForm');
  const input = document.getElementById('query');
  const state = document.getElementById('searchState');
  const results = document.getElementById('results');
  const button = document.getElementById('searchBtn');
  const API = 'https://pds.nasa.gov/api/search/1/products';
  const safe = (v) => typeof v === 'string' ? v : (v == null ? '' : JSON.stringify(v));
  const first = (...values) => values.map(safe).find(v => v && v !== '[]' && v !== '{}') || '';
  function pick(obj, keys) {
    for (const key of keys) if (obj && obj[key] != null) return safe(obj[key]);
    return '';
  }
  function render(items) {
    results.replaceChildren();
    if (!items.length) {
      state.textContent = 'The archive returned no matching products for this query. Try another instrument or mission name.';
      return;
    }
    state.textContent = 'Returned ' + items.length + ' product record(s) from the NASA PDS Search API. Open each record at its source for complete labels and files.';
    items.forEach((item) => {
      const card = document.createElement('article'); card.className = 'result';
      const title = first(pick(item,['title','pds:Identification_Area.pds:title','name']),pick(item,['lidvid','lid','id'])) || 'PDS product record';
      const id = first(pick(item,['lidvid','lid','id']),pick(item,['@id']));
      const time = first(pick(item,['start_date_time','pds:Time_Coordinates.pds:start_date_time']),pick(item,['stop_date_time','pds:Time_Coordinates.pds:stop_date_time']));
      const label = document.createElement('span'); label.className='pill'; label.textContent='ARCHIVE METADATA';
      const strong=document.createElement('strong'); strong.textContent=title;
      const detail=document.createElement('div'); detail.className='hint'; detail.textContent=[id,time].filter(Boolean).join(' · ') || 'Product identifier/time not exposed in this response shape';
      card.append(label,strong,detail);
      const pre=document.createElement('pre'); pre.textContent=JSON.stringify(item,null,2); card.append(pre);
      results.append(card);
    });
  }
  form.addEventListener('submit', async (event) => {
    event.preventDefault();
    const keyword=input.value.trim();
    if (!keyword) { state.textContent='Enter a keyword first.'; return; }
    button.disabled=true; button.textContent='Searching…'; results.replaceChildren();
    state.textContent='Requesting current metadata from NASA PDS…';
    try {
      const url=new URL(API); url.searchParams.set('limit','12'); url.searchParams.set('keywords',keyword);
      const response=await fetch(url.toString(),{headers:{Accept:'application/json'}});
      if (!response.ok) throw new Error('PDS API returned HTTP '+response.status);
      const payload=await response.json();
      const items=Array.isArray(payload) ? payload : (payload.data || payload.products || payload.results || payload['products'] || []);
      if (!Array.isArray(items)) throw new Error('Unexpected PDS response format');
      render(items);
    } catch(error) {
      state.textContent='Live API request unavailable: '+error.message+'. Use the official archive links above; no synthetic records have been substituted.';
    } finally { button.disabled=false; button.textContent='Search archive'; }
  });
})();