# LOCAL MARS — Living Civilization
## Project brief for external review

**Applicant:** Individual project owner  
**Project type:** Browser-based interactive planetary-settlement simulation and STEM learning prototype  
**Repository:** https://github.com/TordTaris/mars-land-explorer  
**Public demo:** https://tordtaris.github.io/mars-land-explorer/  
**Release line recorded in repository:** LOCAL MARS 4.0

### 1. Executive summary
LOCAL MARS is a browser-based simulation that lets users explore a Mars-settlement concept, select parcels, and experiment with constructing a settlement. Its purpose is to make the systems thinking behind off-world habitation more understandable through interactive, game-like learning.

The proposed next development step is a **Mission Habitat Trainer**: a clearly labelled educational scenario in which learners compare trade-offs among power availability, food production, life-support reserves, radiation protection, and habitat capacity. The trainer will use cited public scientific datasets where available and will distinguish sourced measurements from simplified game assumptions.

### 2. Existing prototype — repository-described scope
The project README and application source describe:
- Planet Explorer interface and interactive planetary/parcel exploration.
- City Builder with settlement construction features.
- Underground Base 24 and M-003 as fictional simulation areas.
- English and Thai localization resources.
- Progressive Web App manifest, icon, and service-worker assets.
- A deployment workflow that validates routes, assets, localization, PWA files, and JavaScript syntax before GitHub Pages publication.

The project is a software simulation, not a physical habitat, flight system, life-support controller, or validated engineering model.

### 3. Online and transaction boundaries
The repository documentation explicitly states that GitHub Pages serves the static application; it does not itself host PostgreSQL or enable Supabase. Shared accounts, realtime world synchronization, wallet-ledger functions, and marketplace operations require the relevant Supabase migrations and configuration to be applied and tested.

MLC is documented as a closed-loop simulated in-app currency. It is not cash, cryptocurrency, a deposit, a redeemable financial asset, or legal ownership of land on Mars. Parcel ownership is represented only inside the simulation. THB display references and any checkout flow must not be presented as a live investment or real-world land sale.

### 4. Innovation proposition
The differentiator proposed for external evaluation is the combination of:
1. An approachable interactive Mars-settlement environment.
2. Construction and resource-management decisions presented visually.
3. A planned evidence-linked learning mode that exposes the source, date, unit, and uncertainty of each scientific input.
4. A planned scenario comparison that shows how changing assumptions affects settlement resilience.

These are product-development goals, not claims that the current prototype already contains a validated scientific decision-support model.

### 5. Intended users and impact
- Students and educators introducing planetary science, systems thinking, and STEM.
- Space enthusiasts exploring the constraints of long-duration habitation.
- Designers and researchers seeking a lightweight concept-visualization environment.

Expected impact must be measured through usability testing, learning outcomes, and reproducible scenario results. Do not claim mission readiness or operational suitability.

### 6. Evidence and validation plan
Before any scientific or institutional claim is made:
- Link every real-world input to an authoritative source, dataset version, unit, and access date.
- Separate measured data from assumptions and game balancing values.
- Add transparent model equations and limitations.
- Test reproducibility using documented scenarios.
- Conduct usability testing with learners/educators and record methods and results.
- Verify the public deployment and all online functions independently.

### 7. Institutional relationship statement
LOCAL MARS is independently developed. No affiliation, endorsement, certification, funding, data partnership, or collaboration with NASA, SpaceX, ESA, or any space agency is claimed unless separately documented in a signed or official public record.
