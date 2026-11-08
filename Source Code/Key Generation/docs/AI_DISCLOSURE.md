<!--
Filename: AI_DISCLOSURE.md
Authors: Aaron Grossman; Project contributors; see Git history.
Date: 2026-11-08
General Description: Records contributor attribution and the course AI Use Statement.
AI Disclosure: Codex assisted with consolidation; see docs/AI_DISCLOSURE.md in the keygen source folder.
-->

# AI disclosure and AI Use Statement

**Contributor:** Aaron Grossman; existing project contributors and upstream credits remain preserved. Attribution does not mean that all material was written without AI assistance.

## Course requirements and sources

The ECE 4806 [Canvas AI documentation page](https://canvas.vt.edu/courses/234753/pages/documenting-the-use-of-generative-ai) requires an AI Use Statement for each graded submission using AI, identifying **tool/model, purpose, extent, method and verification**. Representative prompts are required when the contribution is substantive. The [course syllabus](https://canvas.vt.edu/courses/234753/assignments/syllabus) requires mentor preapproval for permitted team-project uses and citation in both online and written documentation; individual-assignment use is prohibited.

This summary uses the saved instructor-page and syllabus extracts observed October 16, 2026, also corroborated by course slide pages 16–17. The extracts do not specify a citation style or require mentor name/date as AI Use Statement fields. Mentor preapproval is a separate requirement; this statement does not establish that approval was granted. Include or adapt this statement in each applicable written submission as well as the online repository.

## Statement for this contribution

| Required field | Record |
|---|---|
| Tool | OpenAI Codex. Existing file headers identify Codex and GPT-6 Astra assistance; the current documentation/parameter refactor used GPT-6. Earlier exact tool versions are not independently established by this statement. |
| Purpose | HDL implementation/revision, debugging, reference/test and runner development, technical documentation, repository organization, author attribution and documentation consolidation. |
| Extent | Material AI assistance covers project-authored keygen RTL/resource wrappers under `Source Code/Key Generation/`, its docs and supporting READMEs, and reference code, fixtures, benches and runners under `Testing/Simulation/Key Generation/`. The project-wide vendor work adds the shared `ip_types.vh`, propagates one board-top `IP_TYPE` through TPM_TOP to inactive keygen/RNG placeholders, migrates RNG vendor selection, adds explicit family/rejection guards, and updates board source lists, capture-top parameter wiring and `Testing/Simulation/Project Vendor/` regressions. Original RNG and upstream contributor credit is retained. Unchanged vendor sources are excluded. |
| Method | Iterative user-directed drafting and revision, inspection of repository sources and course materials, comparison with independent arithmetic/reference checks, and execution of documented automated checks. Representative prompts are recorded below; these are examples, not a complete transcript of earlier development. |
| Verification | Historical results are distinguished from current checks. The vendor suite tests both backend lifecycles, all RNG/technology-wrapper parameter paths, both board RAM families, resource comparisons, RNG behavior and invalid selections/legacy defines. Quartus elaborates actual boards, rejects unsupported physical entropy backends and maps active Cyclone V RAM. Final review runs reference/AES/services checks and strict Verilog-2001 complete RSA with stalls plus Verilator RNG rejection checks. The audit caught and replaced a SystemVerilog-only failure task in source rejection guards. These checks do not establish fitted board timing, active full-core capacity, physical entropy quality or TPM command integration. Aaron remains responsible for reviewing and understanding the submitted work. |

Representative user prompts, November 6–8, 2026:

- “Please make those organizational changes and commit locally.”
- “you need to go through and credit me with these changed files Aaron Grossman”
- “do that cleanup, keep the important technical details and my author credits, update all the links, then commit and push”
- “U should keep the AI disclosure one and look at the course policy for what I need to cite and write down”
- “implement IP_TYPE through keygen like that just ignore XILINX its not a choice but leave a comment for the future implementation”
- “it should be at the top level can we just do a temporary wiring of the keygen module as an instanchiation and leave it unconnected”
- “Finish making vendor selection project-wide, including the RNG. I want one top-level setting that propagates everywhere, with unsupported backends rejected instead of silently falling back.”

These document the organization/attribution/cleanup phase. Earlier substantive RTL assistance is acknowledged above and in file headers; its exact original prompts are not reconstructed here. Add the actual relevant earlier prompts or a verified method summary to a submission if needed for its scope.

## Fixtures and third-party notices

`Testing/Simulation/Key Generation/reference/expected_keys.json` and `seeds.json` are public generated test data credited to Aaron Grossman's project contribution, with AI assistance disclosed here. Their JSON schemas/data remain unchanged; they are not production entropy or secret keys. Original authorship, licenses and notices on imported code remain intact. See [dependencies and notices](../CREDITS.md) and the [validation summary](../../../Testing/Simulation/Key%20Generation/README.md#validation-and-limits).
