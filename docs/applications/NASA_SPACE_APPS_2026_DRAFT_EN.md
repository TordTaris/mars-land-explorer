# Draft — NASA Space Apps Challenge 2026
## Proposed project: LOCAL MARS — Mission Habitat Trainer

**Applicant format:** Individual participant; join or form a team if additional skills are needed.  
**Proposed official challenge:** Build a Junior Astronaut Mission Trainer  
**Event dates:** 14–15 November 2026  
**Status:** Draft only; not submitted. NASA's global page says registration remains open through the event close, but the Thailand online organizer currently marks local registration as closed. Ask the organizer about late entry or use the official NASA Virtual Universal Event route if available.

### Project summary (submission-ready draft)
LOCAL MARS is an interactive browser-based Mars settlement simulation that turns the challenges of building an off-world outpost into a visual learning experience. For the NASA Space Apps Challenge, we propose a focused Mission Habitat Trainer mode in which learners make a sequence of settlement decisions and observe the trade-offs between power, food production, life-support reserves, radiation protection, and habitat capacity.

The current LOCAL MARS prototype provides a planetary exploration interface and settlement-construction experience. A first standalone Mission Trainer page has also been implemented: a 10-day resource-management scenario covering oxygen, water, power, food, and system integrity, with one operation per day, a mission log, score, and local browser save. The next development step is to document assumptions and connect selected inputs to traceable NASA or other authoritative open datasets where suitable. The experience will explain why a settlement decision helps or harms mission resilience rather than presenting a single unexplained score.

This is an educational simulation, not a certified engineering tool. The current prototype uses simplified game values and does not yet integrate NASA datasets. Any future scientific data will be cited with units, source links, and retrieval dates.

### Problem
A young learner may see a Mars base as a collection of buildings without understanding the interdependence of its systems. A shortage of power can affect water processing and food production; additional shielding can consume mass and construction resources; expanding a habitat can increase life-support demand. Learners need an accessible way to explore these connected decisions.

### Proposed solution
A short, browser-based scenario with:
1. **Mission setup:** select crew size and mission duration.
2. **Build phase:** place a habitat, power source, greenhouse, and protective structure.
3. **Resource trade-offs:** allocate limited power, mass, water, and construction capacity.
4. **Scenario events:** explore clearly labelled hypothetical dust, power, or supply disruptions.
5. **Outcome explanation:** show which constraints were breached, what assumptions drove the result, and what could be changed.
6. **Learning references:** link each factual input to its source; mark game assumptions separately.

### What exists vs. what will be built
**Existing prototype (repository-described):** Planet Explorer, City Builder, construction/parcel simulation, English and Thai localization, PWA assets, and GitHub Pages deployment workflow.

**Hackathon deliverable to build:** a bounded Mission Habitat Trainer scenario, a transparent parameter panel, at least three reproducible scenarios, source citations for any real data used, and a short demonstration video or walkthrough.

**Not claimed:** validated life-support engineering, radiation-dose prediction, real mission planning, physical testing, or NASA endorsement.

### Data plan
Use only datasets that are relevant to the selected challenge and can be traced to an official source. Candidate sources to investigate during the event include NASA planetary and Mars mission data portals, NASA Mars climate/atmospheric resources, and other official open-data products. The final submission must name the exact dataset/product, version or observation period, units, source URL, and access date actually used. Do not claim a dataset has been integrated until it is implemented and tested.

### Success criteria for the hackathon
- A reviewer can launch the demo in a standard browser.
- A learner can complete one scenario without external instructions.
- At least three scenario configurations can be repeated and compared.
- Each factual input has a source and unit; each game assumption is labelled.
- The result screen explains trade-offs and limitations.
- The team submits the project through its registered Space Apps team page before the official deadline.

### 48-hour execution plan
**Before the event**
- Register for the 2026 challenge and select the Thailand online event or Virtual Universal Event as applicable.
- Review the official challenge statement and permitted submission requirements.
- Prepare a clean demo branch and a short project walkthrough.

**Day 1**
- Confirm the challenge interpretation and narrow the learning objective.
- Build the scenario state model and parameter panel.
- Add source/assumption labels and the first playable scenario.

**Day 2**
- Add two more scenarios and comparison explanations.
- Test the demo on desktop and mobile browsers.
- Record a short walkthrough, write the final project description, and submit before the portal closes.

### 90-second pitch
“LOCAL MARS makes the systems challenges of living on Mars easier to explore. Our Mission Habitat Trainer turns a settlement into a set of connected decisions: power, food, life support, shielding, and habitat capacity. Instead of showing a base as a static collection of buildings, learners change one decision and see the consequences across the whole outpost. We are building on an existing browser-based Mars settlement prototype and adding a transparent learning mode that separates authoritative data from simplified assumptions. The goal is not to replace engineering analysis, but to help the next generation understand why designing a sustainable off-world habitat is a systems problem.”

### Submission checklist
- [ ] Register/login at the official NASA Space Apps website.
- [ ] Choose Thailand online event if available; otherwise choose Virtual Universal Event.
- [ ] Join or create a team (the global site states a maximum of six members).
- [ ] Confirm the final challenge statement and submission rules.
- [ ] Complete and test the Mission Habitat Trainer.
- [ ] Verify every dataset citation and distinguish assumptions.
- [ ] Submit the project page, demo link, and required media before 11:59 PM local time on 15 November 2026 (confirm the portal's displayed deadline).

### Important distinction
NASA Space Apps is a hackathon and recognition pathway. Participation or a participant certificate is not a NASA technical certification, grant, contract, endorsement, or partnership. Global judging is competitive and is not guaranteed.
