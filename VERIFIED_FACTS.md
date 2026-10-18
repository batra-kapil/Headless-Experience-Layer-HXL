# Verified Facts

Only what was run against org `HXL` (Org Id [YOUR_ORG_ID]) on 2026-10-17, with the exact output. Items marked **docs only** come from documentation and were not tested here.

## Environment

- Org release: **Winter '27**. `GET /services/data/` lists `Summer '26` = 67.0, `Winter '27` = 68.0, latest = 68.0.
- Salesforce CLI 2.136.8 could not deploy the widget: `roadsterFleet.uiwidget-meta.xml: Could not infer a metadata type`. Fixed by `sf update stable` to **@salesforce/cli/2.154.4**.
- `sourceApiVersion` set to 67.0 (was 68.0 in the template). All Apex at 67.0.

## T1. Deploys

| Step | Deploy Id | Result |
|---|---|---|
| Object + 14 fields | [DEPLOY_ID] | Succeeded (15 components) |
| Permission set | [DEPLOY_ID] | Succeeded; assigned to [YOUR_USERNAME] |
| Apex, first try | [DEPLOY_ID] | Failed, 10/11 tests: `System.SecurityException: Cannot use the WITH AccessLevel clause in dynamic queries that also specify an access level.` |
| Apex, second try | [DEPLOY_ID] | Failed, 1 test: `Expected: $49.50 / day, Actual: $49.5 / day` |
| Apex | [DEPLOY_ID] | Succeeded, 11 tests, 0 failures |
| Apex (test setup fix) | [DEPLOY_ID] | Succeeded, 11 tests, 0 failures |
| Widget, first try | [DEPLOY_ID] | Failed: `Required fields are missing: [SourceType]` |
| Widget at API 68.0 | [DEPLOY_ID] | Failed: same `SourceType` error |
| Official hotelCard sample, dry run | [DEPLOY_ID] | Succeeded (proves the org accepts widgets) |
| Widget | [DEPLOY_ID] | Succeeded |
| Lightning types (3 bundles) | [DEPLOY_ID] | Succeeded: roadsterFleetOutputValues, roadsterFleetResult, roadsterFleetResponse |
| Trusted URL | [DEPLOY_ID] | Succeeded |
| Data import tree | n/a | 8 records created |

All three Lightning types deployed in one package, so the `c__roadsterFleetOutputValues` reference resolves within a single deploy.

## Widget findings (proven by deploy errors and dry runs)

- **`@apexClassType/...` inside a widget `schema.json` causes `Required fields are missing: [SourceType]`.** Changing `featuredCar` and `cars.items` to `lightning__textType` removed that error. The deployed schema uses `lightning__objectType` with inline `properties` for `featuredCar` and for `cars.items`. This contradicts `platform-widget-generate/references/schema-from-lightning-type.md`, which says to reference the inner Apex class. The docs' own widget schema examples use only primitives.
- `tile/button` `iconName: "car"` is rejected: `does not have a value in the enumeration [activity, alert-circle, ...]`. Button icons were removed. `tile/icon` `name: "map-pin"` is accepted.
- The `discoverUiComponents` palette in this org has no `tile/card` (the docs' composition example uses it). `tile/container` is used instead. Available: icon, progress, row, container, list, table, badge, avatar, link, image, callout, column, accordionitem, spacer, code, accordion, separator, markdown, text, button, spinner, listitem.
- `action/sendMessage` schema from `getUiComponentSchemas`: `content` is `lightning__textType`, required.

## T2. Apex tests

`sf apex run test --class-names RoadsterRentalsGetAvailableCarsTest --code-coverage`, test run [ASYNC_JOB_ID]:

- Outcome Passed, 11 test methods, 11 pass, 0 fail (summary reports `testsRan: 12`, which includes the @TestSetup).
- `RoadsterRentalsGetAvailableCars`: 112 of 117 lines covered = **96%**. Uncovered lines: 98, 99 (QueryException wrap), 109 (stop at 10 results in the bulk path), 147 (in-memory max-rate rejection, only reached when bulk requests have different budgets), 193 (null daily rate guard).
- A standalone run once failed all tests with `MIXED_DML_OPERATION ... PermissionSetAssignment, original object: Rental_Vehicle__c` even though the deploy-time run had passed. Fixed by creating the test user inside `System.runAs` before inserting vehicles.

## T3. Anonymous Apex (`scripts/apex/t3-get-available-cars.apex`)

No filters:

```json
{"headline":"7 cars available at all Roadster Rentals locations","locationLabel":"all Roadster Rentals locations","totalCount":7,"hasFeatured":true,"featuredCar":"Tesla Roadster","cars":["Honda City","Mahindra XUV700","Toyota RAV4","Tesla Model 3","Ford Mustang Convertible","BMW 5 Series"]}
```

`Swift` occurrences in the output: 0.

Location `Bengaluru Airport`:

```json
{"headline":"2 cars available at Bengaluru Airport","locationLabel":"Bengaluru Airport","totalCount":2,"hasFeatured":false,"featuredCar":null,"cars":["Honda City","BMW 5 Series"]}
```

One car as returned:

```json
{"vehicleId":"[VEHICLE_ID_2]","transmission":"Automatic","tagline":"Quiet, quick, and charges while you grab coffee.","seatsLabel":"5 seats","rating":4.8,"rangeLabel":"510 km range","name":"Tesla Model 3","location":"Hyderabad Airport","imageUrl":"https://raw.githubusercontent.com/YOUR_GITHUB_USER/YOUR_REPO/main/assets/cars/tesla-model-3.jpg","fuelType":"Electric","dailyRateLabel":"$89 / day","dailyRate":89.00,"category":"Electric","bookMessage":"Book the Tesla Model 3 at Hyderabad Airport"}
```

## Action describe and invocable envelope (not the MCP payload)

`GET /services/data/v67.0/actions/custom/apex/RoadsterRentalsGetAvailableCars`:

- outputs: exactly one, `{"name":"fleetResponse","label":"Fleet Response","type":null,"apexClass":"RoadsterRentalsGetAvailableCars$FleetResult","maxOccurs":1}`
- inputs: `category` STRING, `location` STRING, `maxDailyRate` DOUBLE, all `required: false`

`POST` to the same path with `{"inputs":[{"location":"Bengaluru Airport"}]}` returned:

- envelope keys: `actionName, errors, expectedError, invocationId, isSuccess, outcome, outputValues, sortOrder, version`
- `actionName`: `RoadsterRentalsGetAvailableCars`, `isSuccess`: true, `errors`: null
- `outputValues` keys: `["fleetResponse"]`
- `outputValues.fleetResponse` keys: `cars, featuredCar, hasFeatured, headline, locationLabel, totalCount`

This matches the MCP wrapper CLT (`outputValues` > `fleetResponse` > fields) and the renderer bindings `{!$attrs.outputValues.fleetResponse.<field>}`. **The real MCP tool payload has not been captured yet** (needs M3 to M6). Update this section at T6.

## T4. HXL Playground (automated with headless Chromium)

Structure = `playground/roadsterFleet.structure.json`, Data = `{"$attrs": <fleetResponse>}`.

- Renders header, Featured hero (Tesla Roadster, $1,999 / day, Featured badge), list cards with category badge, pickup location, specs, rating, price and Book.
- **`action/sendMessage` content with a binding works**, outside and inside `forEach`. Playground status text after clicking:
  - hero Book: `Sent: Book the Tesla Roadster at Hyderabad Airport`
  - 2nd list card (Bengaluru data): `Sent: Book the BMW 5 Series at Bengaluru Airport`
  - 2nd list card (all locations): `Sent: Book the Mahindra XUV700 at Hyderabad Airport`
- Empty data (`totalCount: 0`, `cars: []`) shows the info callout "No cars match this search" and no hero.
- Images do not load in the Playground: `Refused to load the image 'https://raw.githubusercontent.com/...' because it violates the following Content Security Policy directive: "img-src https://orgcs.my.site.com 'self' data: blob: ...`. That is the Playground's own CSP.
- Not automated: switching the Playground preview to the Claude channel.

## Data and permissions

- `sf data import tree` succeeded with only the read-only permission set, so the System Administrator profile in this org already has edit FLS on the new fields.
- The action runs `WITH USER_MODE`; tests prove a Standard User with `Roadster_Rentals_Access` can read all fields used.

## Skills vs docs vs org (noted, did not block)

- MCP skill naming rule (`<tool>`, `<tool>Response`, no "Result"/"OutputValues") vs docs examples (`hotelInfoResult`, `hotelInfoOutputValues`): followed docs and the requested names.
- MCP skill comparison table puts the Agentforce renderer in `lightningDesktopGenAi/`; docs and the Lightning type skill say bundle root. Used bundle root.
- CLT skill: "no `attributes` on an Apex-class CLT root override" applies to custom LWC; docs show `attributes` with widget renderers. Used `attributes`.
- `platform-apex-generate` says to add `isSuccess`, `errorMessage`, `errorType` outputs. Not added: they would become extra describe outputs, and the MCP payload CLT (`unevaluatedProperties: false`) models only `fleetResponse`, as specified.
- The installed `platform-docs-get` extractor needs Python 3.10+; this Mac has 3.8.2. Docs were fetched with the same browser-rendered approach using Node Playwright 1.47.2.

## Car images (2026-10-17)

Local files in `assets/cars/` (checked with `file` and Spotlight metadata):

- All 8 present with the exact slug names. All are real JPEG (`JPEG image data, Exif standard`), 1456 x 1088.
- No GPS latitude or longitude, no camera make or model in the metadata. Safe to publish.

Images-only repo `https://github.com/batra-kapil/roadster-rentals-assets` (public). Pushed from a temp clone outside this project:

- Commit `[COMMIT_SHA]` on `main`, "Add Roadster Rentals car images", 8 files under `cars/`, nothing else.
- First push failed: `error: RPC failed; HTTP 400 curl 22 The requested URL returned error: 400`. Fixed with repo-local `git config http.postBuffer 52428800` (git 2.30.1, about 1.2 MB push).
- Commit author set repo-local to `[NAME] <[EMAIL]>`; the global git config has stray curly quotes in `user.name` and `user.email` and was left unchanged.

`IMAGE_BASE_URL=https://raw.githubusercontent.com/batra-kapil/roadster-rentals-assets/main/cars`. `node scripts/apply-image-base-url.js` then `sf apex run --file scripts/apex/update-image-urls.apex --target-org HXL`: `success=true`, debug `Updated 8 vehicles`.

Raw URL checks (`curl`, HTTP code | content type | bytes | sha256 prefix vs local file):

| File | Result |
|---|---|
| tesla-roadster.jpg | 200, image/jpeg, 160542, 9f52430e6d15, matches local |
| tesla-model-3.jpg | 200, image/jpeg, 111092, 232328ee40a2, matches local |
| toyota-rav4.jpg | 200, image/jpeg, 158751, 85555da58d19, matches local |
| mahindra-xuv700.jpg | 200, image/jpeg, 158529, 71666e8cd277, matches local |
| honda-city.jpg | 200, image/jpeg, 154233, fb4a3e7b920f, matches local |
| bmw-5-series.jpg | 200, image/jpeg, 145632, 9b914d7e69f4, matches local |
| ford-mustang-convertible.jpg | 200, image/jpeg, 149541, 7aa787e0ee82, matches local |
| maruti-suzuki-swift.jpg | 200, image/jpeg, 168281, bfc4878734b4, matches local |

Records in org `HXL` (`SELECT Name, Is_Available__c, Image_URL__c FROM Rental_Vehicle__c`, totalSize 8):

| Name | Available | Image_URL__c |
|---|---|---|
| Tesla Roadster | true | https://raw.githubusercontent.com/batra-kapil/roadster-rentals-assets/main/cars/tesla-roadster.jpg |
| BMW 5 Series | true | https://raw.githubusercontent.com/batra-kapil/roadster-rentals-assets/main/cars/bmw-5-series.jpg |
| Ford Mustang Convertible | true | https://raw.githubusercontent.com/batra-kapil/roadster-rentals-assets/main/cars/ford-mustang-convertible.jpg |
| Tesla Model 3 | true | https://raw.githubusercontent.com/batra-kapil/roadster-rentals-assets/main/cars/tesla-model-3.jpg |
| Toyota RAV4 | true | https://raw.githubusercontent.com/batra-kapil/roadster-rentals-assets/main/cars/toyota-rav4.jpg |
| Mahindra XUV700 | true | https://raw.githubusercontent.com/batra-kapil/roadster-rentals-assets/main/cars/mahindra-xuv700.jpg |
| Honda City | true | https://raw.githubusercontent.com/batra-kapil/roadster-rentals-assets/main/cars/honda-city.jpg |
| Maruti Suzuki Swift | false | https://raw.githubusercontent.com/batra-kapil/roadster-rentals-assets/main/cars/maruti-suzuki-swift.jpg |

Trusted URL in org `HXL` (Tooling API `CspTrustedSite` query): `Roadster_Rentals_Car_Images`, `EndpointUrl` `https://raw.githubusercontent.com`, `IsActive` true, `Context` All, `IsApplicableToImgSrc` true, all other `IsApplicableTo*` false. Already deployed on 2026-10-17 (deploy [DEPLOY_ID]); no redeploy needed. Retrieved from the org, it matches the local file except that the org adds `canAccessCamera` false and `canAccessMicrophone` false (defaults).

Still not proven: that the images actually display inside Agentforce and Claude. Check at T5 and T6.

## Agent: M1 and M2 done by metadata (2026-10-17)

### Research findings

- Org `HXL` had **no agent of any kind**. At API 67.0 and 68.0: `sf org list metadata` for `AiAgentDefinition`, `AiAuthoringBundle`, `GenAiPlugin`, `GenAiFunction`, `Bot` all returned `[]`; SOQL `BotDefinition` 0 rows, `GenAiPlannerDefinition` 0 rows, `GenAiPluginDefinition` 0 rows. There was no Employee agent to retrieve, so a new one was created (your choice).
- v68 agent model (docs): `GenAiPlannerBundle` "Doesn't exist in v68 and later releases"; agents are `AiAuthoringBundle` (Agent Script), published into `AiAgentDefinition` / `AiAgentDefinitionVersion`. https://developer.salesforce.com/docs/ai/agentforce/references/agents-metadata-tooling/agents-metadata.html
- Action, subagent, Show in conversation, and Output Rendering are all expressed inside the `.agent` file; no separate `GenAiFunction` or `GenAiPlugin` was created.
  - Action: `target: "apex://RoadsterRentalsGetAvailableCars"`. https://developer.salesforce.com/docs/ai/agentforce/guide/ascript-ref-actions.html
  - Show in conversation = output `is_displayable: True` (+ `filter_from_agent: False`).
  - Output Rendering = output `complex_data_type_name: "c__<CLT>"`. https://developer.salesforce.com/workshops/aiforce-workshop/give-agents-ui-with-the-headless-experience-layer-hxl/3-render-in-agent and https://developer.salesforce.com/sample-apps/agent-script-recipes/action-configuration/custom-lightning-types
- Docs only, not yet tested: the CLT renderer card does not render in Builder preview while the agent is Draft; the agent must be committed (published) and activated (recipe page, "Known Platform Bug"). The model decides whether to render a card; a fresh conversation usually works (workshop page).

### Skills used

`agentforce-generate` (copied from the forcedotcom/sf-skills clone at commit 625863f because `npx skills add` exited without installing; `skills-lock.json` does not list it), plus `agentforce-test` and `platform-metadata-retrieve` copied the same way.

Skill vs docs conflict noted: the skill's `complex-data-types.md` says bare `number` fails at publish for action inputs; the official actions reference lists `number` as a supported action parameter type. `maxDailyRate: number` was used; publish has not run yet, so this is unproven either way.

### Files and metadata

- `force-app/main/default/aiAuthoringBundles/Roadster_Rentals_Assistant/Roadster_Rentals_Assistant.agent`
- `force-app/main/default/aiAuthoringBundles/Roadster_Rentals_Assistant/Roadster_Rentals_Assistant.bundle-meta.xml` (`<bundleType>AGENT</bundleType>`, as scaffolded)
- Scaffold: `sf agent generate authoring-bundle --json --no-spec --name "Roadster Rentals Assistant" --api-name Roadster_Rentals_Assistant`. The scaffold was service-agent shaped (`default_agent_user: "NEW AGENT USER"`, MessagingSession variables, escalation subagent); all removed and `agent_type: "AgentforceEmployeeAgent"` set, per the skill's employee-agent rules.
- Structure: `start_agent agent_router` routes to `subagent car_rentals` (label "Car Rentals"), `off_topic`, `ambiguous_question`. `car_rentals` exposes one action `get_available_rental_cars` with optional inputs `location` (string), `category` (string), `maxDailyRate` (number).
- BEFORE-state output: `fleetResponse: object`, `complex_data_type_name: "@apexClassType/c__RoadsterRentalsGetAvailableCars$FleetResult"`, `is_displayable: True`, `filter_from_agent: False`.

### Validation and deploy

- Local compiler: `@sf-agentscript/agentforce` 2.9.27 (npm, installed to `~/.cache/agentforce-generate`), `diagnostics: []`, nodes `agent_router, car_rentals, off_topic, ambiguous_question`.
- `sf agent validate authoring-bundle --api-name Roadster_Rentals_Assistant`: `{"success": true}`.
- Deploy `AiAuthoringBundle:Roadster_Rentals_Assistant`: **[DEPLOY_ID]**, Succeeded. Draft only; not published, not activated.
- Retrieved from the org afterwards: the `.agent` file is identical to the local file (`diff` empty), no `default_agent_user`.

### CLI preview bug and workaround

`sf agent preview start --json --authoring-bundle Roadster_Rentals_Assistant --use-live-actions` failed:

```text
PreviewStartFailed: Failed to start preview session: Cannot read properties of undefined (reading 'replace')
  at ScriptAgent.startPreview (@salesforce/agents/lib/agents/scriptAgent.js:391:93)
```

Cause (read in the CLI source, `@salesforce/agents` 2.3.1 inside `@salesforce/cli` 2.154.4): `this.agentJson.globalConfiguration.defaultAgentUser.replace(...)` runs unconditionally, and an employee agent has no `defaultAgentUser`. Workaround: the scaffold's placeholder `default_agent_user: "NEW AGENT USER"` was added to the **local** file only while starting the session, then the file was restored. The CLI code treats an invalid user as `bypassUser=false`, which is also what it sends for every `AgentforceEmployeeAgent`. The deployed draft never contained the placeholder.

### BEFORE-state preview (live actions, session [SESSION_ID])

Utterance `I want to book a car at Hyderabad Airport`, agent reply:

```text
4 cars are available at Hyderabad Airport. The featured car is the Tesla Roadster, which is $1,999 per day. The lowest daily price is $55. Would you like details on a specific car or need help choosing?
```

Trace `[TRACE_ID]`: `agent_router` (tools `go_to_car_rentals, go_to_off_topic, go_to_ambiguous_question`) -> `TransitionStep` to `car_rentals` -> `FunctionStep` `get_available_rental_cars`, input `{"location":"Hyderabad Airport"}`, output `__action_execution_status__: success`, `fleetResponse.headline: "4 cars available at Hyderabad Airport"`, featured Tesla Roadster, cars start with Mahindra XUV700 ($55 / day), image URLs on raw.githubusercontent.com/batra-kapil/roadster-rentals-assets. Latency 497 ms. CLI preview state shows `__supports_result_display__: false`, so the CLI channel cannot show rich output.

Utterance `Book the Toyota RAV4 at Hyderabad Airport`, agent reply:

```text
You chose to book the Toyota RAV4 at Hyderabad Airport for $65 per day. Online booking is not available in this assistant yet, so nothing has been booked. Please share your pickup date so a team member can help you complete your reservation.
```

Trace: router -> `car_rentals`, no `FunctionStep` (no action called). Session ended normally.

### Reported by you (not observed by me)

- 2026-10-17: "I can see the results in the agent conversation" for the BEFORE-state draft, with a screenshot of Agentforce Builder, **Live Test** mode.
  - Utterance shown: "want to book a car at Hyderabad Airport".
  - Agent text: "4 cars are available at Hyderabad Airport. The featured car is the Tesla Roadster, our flagship, at $1,999 per day. The lowest daily price is $55."
  - Below the text, the platform's **default output presentation** of `fleetResponse`: an "Entry 1" block listing raw field values one per line ("Book the Mahindra XUV700 at Hyderabad Airport", "SUV", "55", "$55 / day", "Diesel", the raw image URL https://raw.githubusercontent.com/batra-kapil/roadster-rentals-...). No widget, no images. This is the BEFORE state for the recording.
  - Builder trace panel: Input, Reasoning: Agent Router, Transition to Subagent: car rentals, Reasoning: Car Rentals, **Action: get available rental cars**, Reasoning: Car Rentals, Transition to Subagent: agent router. Builder summary: the action was called "with the location parameter set to Hyderabad Airport" and "returned four available cars".
  - So `is_displayable: True` with an Apex type is not text-only: Live Test shows the output values as a generic list. Field order and which entries appear were not fully visible in the screenshot.

### AFTER state (draft)

- One-line change, confirmed by `diff` against the BEFORE copy: output `fleetResponse` `complex_data_type_name` from `"@apexClassType/c__RoadsterRentalsGetAvailableCars$FleetResult"` to `"c__roadsterFleetResponse"`. `is_displayable: True` and `filter_from_agent: False` unchanged.
- Local compiler 2.9.27: `diagnostics: []`. `sf agent validate authoring-bundle`: `success: true`.
- Deploy `AiAuthoringBundle:Roadster_Rentals_Assistant`: **[DEPLOY_ID]**, Succeeded.
- Retrieved from the org afterwards: identical to the local file. Output now reads `fleetResponse: object`, `complex_data_type_name: "c__roadsterFleetResponse"`, `is_displayable: True`, `filter_from_agent: False`.
- Output Data Type: `object` typed as the custom Lightning type `c__roadsterFleetResponse`, whose schema is `@apexClassType/c__RoadsterRentalsGetAvailableCars$FleetResult` and whose renderer is `@widget/c/roadsterFleet`.

### Publish and activate (approved by you: "publish")

- `sf agent publish authoring-bundle --api-name Roadster_Rentals_Assistant`: `success: true`, `botDeveloperName: Roadster_Rentals_Assistant`, summary `retrieved: 7, deployed: 3`.
  - This proves `maxDailyRate: number` publishes; the skill's "bare number fails at publish" warning did not apply here.
  - Publish also retrieved files into the project: `aiAgents/Roadster_Rentals_Assistant.aiAgentDefinition-meta.xml`, `aiAgentDefinitionVersions/Roadster_Rentals_Assistant#1/` (version meta, `agentGraph/Roadster_Rentals_Assistant_v1_graph.json`, action input and output `schema.json`), and re-downloaded `RoadsterRentalsGetAvailableCars.cls` and the bundle meta. The re-downloaded class is the final version (checked for the `Database.query(soql)` and trailing-zero fixes).
- Published runtime output schema (`localActions/car_rentals/get_available_rental_cars/output/schema.json`):

```json
"fleetResponse" : {
  "title" : "Fleet Response",
  "lightning:type" : "c__roadsterFleetResponse",
  "lightning:isPII" : false,
  "copilotAction:isDisplayable" : true,
  "copilotAction:isUsedByPlanner" : true
}
```

  So Output Rendering = `c__roadsterFleetResponse` and Show in conversation = `copilotAction:isDisplayable: true` persisted through publish.
- `AiAgentDefinition`: `agentType AgentforceEmployeeAgent`, `type InternalCopilot`, `agentDSLEnabled true`, `richContentEnabled true`.
- `sf agent activate --api-name Roadster_Rentals_Assistant`: `success: true`, `version: 1`. SOQL `BotVersion` for the agent: `DeveloperName v1, Status Active, VersionNumber 1`.
- Permission set `Roadster_Rentals_Access`: added `<agentAccesses><agentName>Roadster_Rentals_Assistant</agentName><enabled>true</enabled></agentAccesses>`. Deploy **[DEPLOY_ID]** Succeeded; retrieved back from the org with the `agentAccesses` block present. Already assigned to [YOUR_USERNAME].

### T5 result 1 (reported by you, with screenshot, 2026-10-17)

- **The roadsterFleet widget renders in Agentforce** on the active agent. Hero card shows the Tesla Roadster photo loaded from raw.githubusercontent.com (so the Trusted URL / image path works in Agentforce), name, "Featured" badge, italic tagline, map-pin + "Hyderabad Airport", "4 seats | Automatic | Electric |" with "1000 km range" wrapped to the next line, "Rated 5 / 5", and "$1,999 / day" in the brand color.
- **Defect:** the hero Book button (`tile/button`, `variant: "primary"`) renders as a solid dark block; its label is only visible on hover. The `primary` badge also renders dark gray but its text is readable. List-card Book buttons (`variant: "secondary"`) were not reported as broken.
- Fix: hero Book button changed to `variant: "secondary"` (the only `primary` button in the widget; the `primary` badge is unchanged). Widget-only redeploy `UiWidgetBundle:roadsterFleet` **[DEPLOY_ID]** Succeeded; no agent republish needed because the Lightning type references the widget by name. `playground/roadsterFleet.structure.json` regenerated.
- Not yet confirmed: that the fix renders correctly, that list cards show, and what the Book click sends and how the agent replies.

### T5 result 2 (reported by you, 2026-10-17)

- After the button fix you reported: "Looks good to me". Recorded as a pass for the Agentforce widget render. Not separately reported: list-card details and the exact Book-click message and agent reply. The Book-click reply was proven earlier by CLI preview (honest "nothing has been booked" answer); the widget's bound `sendMessage` content was proven in the HXL Playground.

## MCP server: M3 and M4 done by metadata (2026-10-17)

### Research

- Create by deploy is documented: "Be deployed via Metadata API between sandboxes and production" (https://developer.salesforce.com/docs/platform/hosted-mcp-servers/guide/custom-servers.html). The Salesforce Developers blog shows a deployable `McpServerDefinition` with `apiDefinition` (`apiIdentifier aa:apex-<ClassName>`, `apiSource API_CATALOG`, `operation <ClassName>`), `descriptionOverride`, `toolName`, `toolTitle` (https://developer.salesforce.com/blogs/2026/05/expose-custom-apex-as-a-hosted-mcp-tool-for-agents). No `McpServerDefinition` page was found in the Metadata API Developer Guide (the guessed `meta_mcpserverdefinition.htm` URL returned a generic page).
- The hosted tool is backed by the API Catalog entry generated from the global Apex class, not by the agent action.
- `agentforce-generate` MCP reference (`sf agent mcp ...`) is for registering external MCP servers into Agentforce; not used.

### Deploy and retrieve

- `sf project deploy start --metadata McpServerDefinition:roadsterRentalsMcp --dry-run`: **[DEPLOY_ID]**, Succeeded.
- Real deploy: **[DEPLOY_ID]**, Succeeded, `created: true`.
- Retrieved XML (from the org):

```xml
<McpServerDefinition xmlns="http://soap.sforce.com/2006/04/metadata">
    <description>Roadster Rentals fleet tools. Finds available rental cars by pickup location, category, and daily budget, and renders the results as the Roadster Rentals Fleet widget.</description>
    <masterLabel>roadsterRentalsMcp</masterLabel>
    <resources>
        <description>Available Roadster Rentals cars with a featured hero car and Book buttons.</description>
        <resourceName>roadsterFleet</resourceName>
        <resourceTitle>Roadster Rentals Fleet</resourceTitle>
        <resourceUri>ui://widget/lightningType/c__roadsterFleetResult</resourceUri>
    </resources>
    <tools>
        <apiDefinition>
            <apiIdentifier>aa:apex-RoadsterRentalsGetAvailableCars</apiIdentifier>
            <apiSource>API_CATALOG</apiSource>
            <operation>RoadsterRentalsGetAvailableCars</operation>
        </apiDefinition>
        <descriptionOverride>(as written)</descriptionOverride>
        <destructive>false</destructive>
        <idempotent>false</idempotent>
        <openWorld>false</openWorld>
        <readOnly>false</readOnly>
        <returnDirect>false</returnDirect>
        <toolName>getAvailableRentalCars</toolName>
        <toolTitle>Get Available Rental Cars</toolTitle>
        <uiResource>roadsterFleet</uiResource>
    </tools>
</McpServerDefinition>
```

  The five tool-hint elements were added by the org with value `false`.
- Tooling API records: `McpServerDefinition` Id `[RECORD_ID]`, DeveloperName `roadsterRentalsMcp`. `McpServerToolDefinition`: ToolName `getAvailableRentalCars`, ToolTitle `Get Available Rental Cars`, UiResource `roadsterFleet`, ReadOnly false. `McpServerResourceDefinition`: ResourceName `roadsterFleet`, ResourceUri `ui://widget/lightningType/c__roadsterFleetResult`, ResourceTitle `Roadster Rentals Fleet`.
- Server URL: no org field exposes it (`McpServerDefinition` fields: Id, IsDeleted, DeveloperName, Language, MasterLabel, audit fields, Description). Derived from the documented pattern "Production / Developer Edition: https://api.salesforce.com/platform/mcp/v1/custom/{MCP_SERVER_API_NAME}" (blog above): `https://api.salesforce.com/platform/mcp/v1/custom/roadsterRentalsMcp`. **Not yet confirmed in Setup.**

### Activation

- Docs only document Setup: "From Setup, in the Quick Find box, enter MCP Servers, and then select MCP Servers under API Catalog ... Enable the servers your team needs by toggling them on." Up to 2 minutes to take effect. https://developer.salesforce.com/docs/platform/hosted-mcp-servers/guide/activate-mcp-servers.html
- Metadata: `sf org list metadata-types` lists only `McpServerDefinition` for MCP; no activation type.
- Tooling API: object `McpServerAccess` (label "MCP Server Access", createable) with fields `DeveloperName, Language, MasterLabel, Active (boolean), McpServerId (reference)`. Query returned 0 records, so the server is not active. Using it to activate is undocumented and was not attempted.

### readOnly hint

- `<readOnly>true</readOnly>` added to tool `getAvailableRentalCars`. Deploy **[DEPLOY_ID]** Succeeded. Retrieve shows `destructive false, idempotent false, openWorld false, readOnly true, returnDirect false`; Tooling `McpServerToolDefinition` shows `ReadOnly: true, UiResource: roadsterFleet`.
- Activation decision (you): Setup toggle, documented path. Tooling API `McpServerAccess` not used.

## External Client App: M5 done by metadata (2026-10-17)

### Doc requirements (https://developer.salesforce.com/docs/platform/hosted-mcp-servers/guide/create-external-client-app.html)

- "Use an External Client App to connect an MCP client to a Salesforce org. Connected Apps aren't supported."
- "Enable OAuth"; Claude callback: "Enter https://claude.ai/api/mcp/auth_callback".
- Scopes: "Access MCP servers (mcp_api)", "Perform requests at any time (refresh_token)".
- Security: "Select Issue JSON Web Token (JWT)-based access tokens for named users. Deselect all other options that don't require contacting Salesforce customer support to change."
- **PKCE is not mentioned on this page.** It was set because you required it; the Metadata API reference says `isPkceRequired` defaults to true.
- "The External Client App can take up to 30 minutes to become available."
- Consumer key: "Click Settings, then click Consumer Key and Secret under OAuth Settings to get the consumer key."

### Metadata mapping (field definitions from the Metadata API reference copies in the sf-skills `platform-metadata-api-context-get` assets)

| Requirement | Metadata type and field | Value |
|---|---|---|
| App | `ExternalClientApplication` (`externalClientApps/*.eca`) | label "Roadster Rentals MCP", `distributionState Local`, contactEmail = HXL admin user's Email (queried) |
| Enable OAuth + scopes | `ExtlClntAppOauthSettings` (`*.ecaOauth`), `commaSeparatedOauthScopes` | `MCP, RefreshToken` (reference: "MCP: Allows access to Model Context Protocol (MCP)", "RefreshToken") |
| Callback, PKCE, JWT, secret | `ExtlClntAppGlobalOauthSettings` (`*.ecaGlblOauth`) | `callbackUrl https://claude.ai/api/mcp/auth_callback`, `isPkceRequired true`, `isNamedUserJwtEnabled true`, `isConsumerSecretOptional true`, `isSecretRequiredForRefreshToken false`, other flows false |
| Admin policies | `ExtlClntAppOauthConfigurablePolicies` (`*.ecaOauthPlcy`) | `permittedUsersPolicyType AllSelfAuthorized`, `refreshTokenPolicyType Infinite`, `ipRelaxationPolicyType Enforce` |

`isConsumerSecretOptional true` follows the Claude page ("Leave OAuth Client Secret blank") and the ECA page listing "Require Secret for Web Server Flow" as an optional production enhancement.

### Deploy and retrieve

- Dry run **[DEPLOY_ID]** Succeeded; deploy **[DEPLOY_ID]** Succeeded, all four components `created: true`.
- Retrieved (into the scratchpad, outside the project). Values as returned, secrets redacted:
  - `ExtlClntAppGlobalOauthSettings`: callbackUrl `https://claude.ai/api/mcp/auth_callback`, `consumerKey [REDACTED]`, isPkceRequired true, isNamedUserJwtEnabled true, isConsumerSecretOptional true, isSecretRequiredForRefreshToken false, **isRefreshTokenRotationEnabled true** (deployed as false; the org set it to true), plus org-added `isEnforceRefreshTokenTTL true`, `isDPopEnabled false`, `isCodeCredPostOnly false`.
  - `ExtlClntAppOauthSettings`: scopes `RefreshToken, MCP`, `isFirstPartyAppEnabled false`, `oauthLink [REDACTED]`.
  - `ExtlClntAppOauthConfigurablePolicies`: as deployed plus `requiredSessionLevel STANDARD` and three flow flags false.
  - `ExternalClientApplication`: as deployed plus auto-generated `orgScopedExternalApp`.
- **The consumer key is exposed by metadata retrieve** of `ExtlClntAppGlobalOauthSettings`. The scratchpad retrieve was deleted after checking; a disk scan found no real key (only sample values inside the sf-skills reference docs). The project file has no key and `**/extlClntAppGlobalOauthSets/` was added to `.gitignore`.
- No setting needed a Setup click.

### Claude client (https://developer.salesforce.com/docs/platform/hosted-mcp-servers/guide/claude.html)

- Surfaces: "These setup steps apply to Claude.ai and the Claude Desktop app. Claude Code inherits the same connection."
- Fields: connector name; server URL; "Use your own OAuth client"; "OAuth Client ID, paste the consumer key"; "Leave OAuth Client Secret blank, unless your authorization server requires one."
- URL format on that page: "All production orgs: https://api.salesforce.com/platform/mcp/v1/<SERVER-NAME>" with standard example `platform/sobject-all`. For custom servers the blog pattern is `/v1/custom/{MCP_SERVER_API_NAME}`, giving `https://api.salesforce.com/platform/mcp/v1/custom/roadsterRentalsMcp`. Not yet confirmed in Setup.

## T6 attempt 1: Claude through MCP failed (reported by you, 2026-10-17)

- Connector `roadsterRentalsConnector`. Auth, server URL, and tool invocation worked. Calling `getAvailableRentalCars` with location "Hyderabad Airport" returned:

```text
Callout failed: Failed to evaluate $attrs expression: {!$attrs.totalCount = 0}
```

### Analysis

- Expressions in the widget before the fix: one comparison `meta.if` `{!$attrs.totalCount = 0}` (empty-state callout), two text formulas `{!'Rated ' & TEXT($attrs.featuredCar.rating) & ' / 5'}` and `{!'Rated ' & TEXT($car.rating) & ' / 5'}`. Every other expression is a plain binding. `meta.if` on the hero is the bare Boolean `{!$attrs.hasFeatured}`.
- Renderer mapping: `roadsterFleetResult` maps `totalCount` to `{!$attrs.outputValues.fleetResponse.totalCount}`. Its type comes from `FleetResult.totalCount` (Apex `Integer`, so `lightning__integerType` through `@apexClassType`), while the widget schema declares `lightning__numberType`.
- Composition doc rules for `meta.if` (https://developer.salesforce.com/docs/platform/hxl/guide/hxl-widget-composition.html): "The expression must evaluate to a Boolean value." "A non-Boolean result, such as a number, string, or empty array, isn't supported and causes an evaluation error. A missing or null-valued reference is treated as false." Its examples are a bare Boolean and `{!AND($attrs.isAvailable, $attrs.price < 500)}`. The `=` operator appears only in the skill's formula reference, not in the doc examples.
- HXL Playground with `totalCount` as number 4, string "4", null, and missing: all four rendered with no evaluation error. The client-side evaluators (Playground, and Agentforce in T5) are lenient; the MCP path evaluates on the server (`Callout failed`) and is stricter.
- **Root cause: unproven.** There is no raw payload: per your report, the Claude-side tool call returned only the error string; the server failed during widget evaluation before returning any data. Proven: the server-side MCP evaluator fails on the comparison formula `{!$attrs.totalCount = 0}`, while the same widget evaluates in Agentforce (T5) and in the Playground. Three candidate causes, none confirmed:
  1. `totalCount` resolved to **null** on the MCP path, and the evaluator rejects `null = 0`.
  2. `totalCount` arrived as a **string**, and the evaluator rejects comparing a string to the number 0.
  3. A **type mismatch**: the MCP payload types `totalCount` as `lightning__integerType` (Apex `Integer` through `@apexClassType`), while the widget schema declares `lightning__numberType`.
- The fix avoids all three: the callout now uses a bare Boolean reference, `{!$attrs.isEmpty}`, which the composition doc defines as valid for `meta.if`, including its null behavior ("A missing or null-valued reference is treated as false"). No comparison and no number coercion remain in the widget.

### Fix (prepared, check-only so far)

- Apex `FleetResult.isEmpty` (Boolean, `@AuraEnabled` + `@InvocableVariable`) = `totalCount == 0`. Apex `Car.ratingLabel` (String) = `Rated <rating to 1 decimal> / 5`.
- Widget: callout `meta.if` is now `{!$attrs.isEmpty}`; both rating texts are plain bindings `{!$attrs.featuredCar.ratingLabel}` and `{!$car.ratingLabel}`. **No formulas remain in the widget.** Schema stays flat: `isEmpty` (`lightning__booleanType`) added; `ratingLabel` added to the inline `featuredCar` and `cars.items` properties.
- Renderers: `isEmpty` mapped in both (`{!$attrs.isEmpty}` and `{!$attrs.outputValues.fleetResponse.isEmpty}`). The `roadsterFleetOutputValues` and `roadsterFleetResponse` schemas reference the Apex class, so they need no change.
- featuredCar check: its only formula (`TEXT(...rating)`) is removed; the hero's `meta.if` is already a bare Boolean. The `featuredCar` renderer binding still passes a whole object (`outputValues.fleetResponse.featuredCar`); unproven on MCP until T6 passes.
- Gates: bindings-resolve pass (29 refs), formulas remaining none, both renderers pass. Apex check-only deploy with tests **[DEPLOY_ID]**: 11/11 pass, coverage 114/119 lines (96%). Nothing saved to the org yet.

### Deployed (approved by you)

- Apex classes with `RoadsterRentalsGetAvailableCarsTest`: **[DEPLOY_ID]**, Succeeded, 11 tests, 0 failures.
- `UiWidgetBundle:roadsterFleet`: **[DEPLOY_ID]**, Succeeded.
- `LightningTypeBundle:roadsterFleetResponse` and `roadsterFleetResult`: **[DEPLOY_ID]**, Succeeded.
- Retrieved from the org afterwards: widget `meta.if` values are `{!$attrs.hasFeatured}` and `{!$attrs.isEmpty}`; rating texts are `{!$attrs.featuredCar.ratingLabel}` and `{!$car.ratingLabel}`; no `totalCount = 0` and no `TEXT(` remain. Renderers contain `"isEmpty" : "{!$attrs.isEmpty}"` and `"isEmpty" : "{!$attrs.outputValues.fleetResponse.isEmpty}"`. The org stores the widget with generated node `id` values and filled-in attribute defaults.
- No agent republish: the agent output still points at `c__roadsterFleetResponse`, which references the Apex class and the widget by name.

### T5 regression check (CLI, published active agent)

- `sf agent preview start --api-name Roadster_Rentals_Assistant` (the published, active version, not the local draft): started normally. The `defaultAgentUser` CLI crash only affects `--authoring-bundle` previews.
- Session `[SESSION_ID]`, utterance `I want to book a car at Hyderabad Airport`, reply:

```text
4 cars are available at Hyderabad Airport. The featured car is the Tesla Roadster, our flagship, at $1,999 per day. The lowest daily price is $55 for the Mahindra XUV700. Would you like more details on any specific car or want to proceed with a booking?
```

- Trace `[TRACE_ID]`: `FunctionStep` `get_available_rental_cars`, input `{"location":"Hyderabad Airport"}`, status `success`, `isEmpty: false`, `totalCount: 4`, featured `ratingLabel: "Rated 5.0 / 5"`, first car `Mahindra XUV700` with `ratingLabel: "Rated 4.5 / 5"`. The CLI cannot show the widget itself; a visual Agentforce check is still worth doing on camera.

## T6 attempt 2: same error after the fix (reported by you, 14:43 IST, 2026-10-17)

- Your retest at 14:43 IST returned the same server-side error: `Callout failed: Failed to evaluate $attrs expression: {!$attrs.totalCount = 0}`.

### Deploy status and times (from `sf project deploy report`)

| Deploy | Components | Status | Completed (UTC) | Completed (IST) |
|---|---|---|---|---|
| [DEPLOY_ID] | ApexClass: RoadsterRentalsGetAvailableCars, RoadsterRentalsGetAvailableCarsTest, TestDataFactory | Succeeded | 09:08:56 | 14:38:56 |
| [DEPLOY_ID] | UiWidgetBundle: roadsterFleet | Succeeded | 09:09:02 | 14:39:02 |
| [DEPLOY_ID] | LightningTypeBundle: roadsterFleetResponse, roadsterFleetResult | Succeeded | 09:09:09 | 14:39:09 |
| [DEPLOY_ID] | LightningTypeBundle: roadsterFleetOutputValues (with the other two) | Succeeded | 06:57:14 | 12:27:14 |

`roadsterFleetOutputValues` was not part of the fix (it references the Apex class, so no change was needed); its last deploy is [DEPLOY_ID]. The fix was live about 4 minutes before your 14:43 retest.

### Fresh retrieve at 14:44 IST (temp folder outside the project)

- `UiWidgetBundle:roadsterFleet` and `LightningTypeBundle:roadsterFleetResult` retrieved; `roadsterFleetResult` files report `lastModified 2026-10-17T09:09:08Z`.
- `grep -rn "totalCount =\|TEXT("` over both: **no matches** (grep exit code 1).
- Remaining `totalCount` occurrences are only the attribute definition in the widget `schema.json` and the renderer mapping `"totalCount": "{!$attrs.outputValues.fleetResponse.totalCount}"`. Neither is an expression the widget evaluates in `meta.if`.
- Widget `meta.if` values in the org: `{!$attrs.hasFeatured}` and `{!$attrs.isEmpty}` only.
- **Conclusion: both bundles are clean in the org.** The error quotes an expression the org metadata no longer contains, so the MCP path is evaluating a stale copy of the widget. Nothing was redeployed or changed in this step.

### Lead from a Salesforce Developers blog (read, not tested)

https://developer.salesforce.com/blogs/2026/08/headless-experience-layer-custom-ui-widget-jp, section "要考慮事項：ウィジェットの変更が反映されない" ("widget changes are not reflected"):

- Symptom described: deploy succeeds and org metadata matches local, but the AI agent app keeps using the old layout.
- The author's explanation (stated as apparent, internal behavior unknown): the widget template is cached keyed by the `resourceUri` string, so the old template is reused while the URI stays the same. The author attributes the cache to the client app; your "Callout failed" points at the server path, so where the cache sits is not proven here.
- Remedies, in the blog's order (updated 2026-08-28): first try "update tools" (ツールの更新) in the client's connector settings; if that fails, version the `resourceUri`: copy the LightningTypeBundle to a new API name (for example `roadsterFleetResult` to `roadsterFleetResultV2`), update `<resourceUri>` and `<uiResource>` in `McpServerDefinition`, deploy, then re-register the connector. The blog says only the LightningTypeBundle and McpServerDefinition need versioning; UiWidgetBundle, Apex, and GenAiFunction do not.

## T6 attempt 3: Update tools and server toggle did NOT clear it (reported by you, 14:49 IST)

- You ran **Update tools** on the connector in Claude and toggled **roadsterRentalsMcp off and on** in Setup. Retest at 14:49 IST still returned `Callout failed: Failed to evaluate $attrs expression: {!$attrs.totalCount = 0}`.
- So neither the blog's first remedy (Update tools) nor a server re-toggle cleared the stale widget.
- Read-only check of Tooling `McpServerAccess` before the next change: `roadsterRentalsMcp`, `Active: true`, `LastModifiedDate 2026-10-17T08:45:12Z` (14:15:12 IST). That timestamp is earlier than your 14:49 toggle; whether the toggle updates this record is unknown. Not used to change anything.

### Versioned resource URI (prepared, waiting for your yes)

- New `LightningTypeBundle` `roadsterFleetResultV2`: copy of `roadsterFleetResult`. `renderer.json` identical (maps `isEmpty`; `ratingLabel` rides inside `featuredCar` and `cars`). `schema.json` differs only in `title` and `description` (and JSON formatting).
- `roadsterFleetResult` stays in the org; nothing is deleted.
- `McpServerDefinition` `roadsterRentalsMcp`: `resourceName` `roadsterFleet` to `roadsterFleetV2`; `resourceUri` `ui://widget/lightningType/c__roadsterFleetResult` to `ui://widget/lightningType/c__roadsterFleetResultV2`; tool `uiResource` `roadsterFleet` to `roadsterFleetV2`.

## T6 attempt 4: widget renders in Claude, hero card empty (reported by you)

- Claude result: the widget renders; list cars show images and details; **the featured hero card is empty** (no image, no details). Per your report, the MCP payload contains `featuredCar` complete.
- **Correction on what made it render:** the V2 versioned URI was **never deployed** (it was waiting for your yes). Org check at 09:28 UTC: no `roadsterFleetResultV2` LightningTypeBundle; `McpServerResourceDefinition` still `roadsterFleet` / `ui://widget/lightningType/c__roadsterFleetResult` (LastModified 08:45:40 UTC); `McpServerToolDefinition` UiResource `roadsterFleet`. So the stale `totalCount = 0` error cleared **on the original URI** without versioning. It cleared at 14:54 IST, right after you re-added the connector as `roadsterRentalsConnector_V1`. See the evidence check below.
- **Finding:** object-attribute binding (`{!$attrs.featuredCar.imageUrl}` and the other `$attrs.featuredCar.x` paths, fed by the renderer mapping `featuredCar` to `{!$attrs.outputValues.fleetResponse.featuredCar}`) **renders in Agentforce (T5) but is empty on the MCP path**, while list items rendered through `forEach` (`{!$attrs.cars}` with `{!$car.x}`) **work on both**. This matches the `platform-mcp-tool-widget-coordinate` skill's warning that binding a whole nested object is unresolvable and leaves should be bound instead.

### What preceded the 14:54 IST success (evidence check, 2026-10-17)

- Your report: at **14:54 IST (09:24 UTC)** the tool call succeeded and the widget rendered, after you **removed and re-added the connector in Claude as `roadsterRentalsConnector_V1`**. The last failure before that was 14:49 IST (09:19 UTC).
- **V2 was never deployed to org HXL. Proof:**
  - `sf org list metadata -m LightningTypeBundle -o HXL` lists only `roadsterFleetResult`, `roadsterFleetResponse`, `roadsterFleetOutputValues`, `roadsterFleetResultV3`. There is no `roadsterFleetResultV2`.
  - Every deploy in org HXL on 2026-10-17 (Tooling `DeployRequest`) and its components (`sf project deploy report`). None contains `roadsterFleetResultV2` or a V2 `McpServerDefinition`:

    | Deploy ID | Completed (UTC) | Components |
    |---|---|---|
    | [DEPLOY_ID] | 08:37:19 | McpServerDefinition roadsterRentalsMcp (first deploy, V1 resource) |
    | [DEPLOY_ID] | 08:45:40 | McpServerDefinition roadsterRentalsMcp (readOnly true, V1 resource) |
    | [DEPLOY_ID] | 09:08:56 | ApexClass x3 (isEmpty, ratingLabel) |
    | [DEPLOY_ID] | 09:09:02 | UiWidgetBundle roadsterFleet (isEmpty fix) |
    | [DEPLOY_ID] | 09:09:09 | LightningTypeBundle roadsterFleetResult (V1), roadsterFleetResponse |
    | (none) | 09:09:09 to 09:29:37 | **No deploy of any kind** |
    | [DEPLOY_ID] | 09:29:46 | ApexClass x3, check only |
    | [DEPLOY_ID] | 09:35:19 | ApexClass x3 (featuredCars) |
    | [DEPLOY_ID] | 09:35:25 | UiWidgetBundle roadsterFleet (hero forEach) |
    | [DEPLOY_ID] | 09:35:32 | LightningTypeBundle roadsterFleetResultV3, roadsterFleetResponse |
    | [DEPLOY_ID] | 09:35:42 | McpServerDefinition roadsterRentalsMcp (V3 resource) |

  - The only `McpServerResourceDefinition` in the org now is `ui://widget/lightningType/c__roadsterFleetResultV3`, created 09:35:41 UTC. That is after the 14:54 IST success.
  - The org check at 09:28 UTC (above) still showed the V1 resource `roadsterFleet` / `c__roadsterFleetResult`.
  - `force-app/main/default/lightningTypes/roadsterFleetResultV2/` exists only on disk.
- **Which change preceded the fix, stated plainly:**
  - **Versioned URI: no.** It was not in the org at 14:54. The URI was still `c__roadsterFleetResult`.
  - **Org metadata: no.** Nothing was deployed between 14:39:09 IST and 14:59:37 IST.
  - **Connector re-registration: yes.** It is the only known action between the 14:49 failure and the 14:54 success.
  - **Time: also yes.** About 5 more minutes had passed, and about 15 since the fix went live at 14:39 IST. The Update tools and toggle from before 14:49 may also have taken effect late.
- **Conclusion:** the fix came right after the connector re-registration. This is one observation, and elapsed time is confounded with it. So re-registration is the most likely trigger, but it is **not proven** to be the cause. Re-registering was not repeated as a controlled test.

### Option A (prepared, waiting for your yes)

- Apex: `FleetResult.featuredCars` (`List<Car>`, only the featured car, empty when none). `featuredCar` kept. `cars` unchanged: never contains the featured car, sorted by daily rate ascending.
- Tests: `shouldReturnRoadsterAsHero_WhenNoFilters` and `shouldReturnRoadsterAsHero_WhenHyderabadAirport` assert `featuredCars.size() == 1`, `featuredCars[0].name == 'Tesla Roadster'`, `cars` does not contain it, and `cars` is rate ascending; the empty test asserts `featuredCars` is empty. Check-only deploy with tests **[DEPLOY_ID]**: 13/13 pass, coverage 116/121 lines.
- Widget: the hero container (first child after the header, before the empty callout and the cars list) now has `meta` `{ if: {!$attrs.hasFeatured}, forEach: {!$attrs.featuredCars}, forItem: $hero }`; every `$attrs.featuredCar.x` became `$hero.x`; featured styling unchanged (emphasis container, full image, Featured badge, tagline). Schema: `featuredCars` added as `lightning__listType` with `items` identical to `cars.items`; nothing else changed. Gates: 30 bindings resolve, no formulas, 0 object-attribute references.
- Renderers: `featuredCars` mapped in `roadsterFleetResponse` (`{!$attrs.featuredCars}`) and in the NEW `roadsterFleetResultV3` (`{!$attrs.outputValues.fleetResponse.featuredCars}`, otherwise a copy of V2, which equals V1 plus nothing). V1 `roadsterFleetResult` does not map `featuredCars`, so its hero would be empty; it is retired once the MCP definition points at V3. V1 is kept; V2 exists only locally (never deployed).
- `McpServerDefinition`: `resourceName` `roadsterFleetV3`, `resourceUri` `ui://widget/lightningType/c__roadsterFleetResultV3`, `uiResource` `roadsterFleetV3`. Diff against the org copy is exactly those three lines.

### Option A deployed (approved by you)

| Order | Deploy | Components | Status | Completed (UTC) |
|---|---|---|---|---|
| 1 | [DEPLOY_ID] | Apex classes, 13 tests, 0 failures | Succeeded | 09:35:19 |
| 2 | [DEPLOY_ID] | UiWidgetBundle roadsterFleet | Succeeded | 09:35:25 |
| 3 | [DEPLOY_ID] | LightningTypeBundle roadsterFleetResponse, roadsterFleetResultV3 | Succeeded | 09:35:32 |
| 4 | [DEPLOY_ID] | McpServerDefinition roadsterRentalsMcp | Succeeded | 09:35:42 |

Retrieved from the org afterwards (temp folder outside the project):

- Apex contains `global List<Car> featuredCars;` and `result.featuredCars.add(car);`.
- Widget root children in order: header column; hero container with `meta` `{"if":"{!$attrs.hasFeatured}","forEach":"{!$attrs.featuredCars}","forItem":"$hero"}`; empty callout `{"if":"{!$attrs.isEmpty}"}`; cars container `{"forEach":"{!$attrs.cars}","forItem":"$car"}`. `$attrs.featuredCar.` references: 0. `{!$hero.x}` references: 12. Schema `featuredCars`: `lightning__listType`, items `lightning__objectType`.
- Renderers: `"featuredCars" : "{!$attrs.featuredCars}"` (roadsterFleetResponse) and `"featuredCars" : "{!$attrs.outputValues.fleetResponse.featuredCars}"` (roadsterFleetResultV3).
- MCP definition: `resourceName roadsterFleetV3`, `resourceUri ui://widget/lightningType/c__roadsterFleetResultV3`, `uiResource roadsterFleetV3`. Tooling records agree: `McpServerResourceDefinition` `roadsterFleetV3` / `...c__roadsterFleetResultV3`; `McpServerToolDefinition` `getAvailableRentalCars`, `UiResource roadsterFleetV3`, `ReadOnly true`.
- `McpServerAccess` after the deploy: `Active: true`, `LastModifiedDate 08:45:12Z` (unchanged), so the MCP definition deploy did not change activation.
- V1 `roadsterFleetResult` kept in the org (no `featuredCars` mapping, no longer referenced by the MCP server). V2 exists only as local files; never deployed.

### T5 regression check (CLI, published active agent)

- Session `[SESSION_ID]`, utterance `I want to book a car at Hyderabad Airport`, reply: "There are 4 cars available at Hyderabad Airport. The featured car is the Tesla Roadster at $1,999 per day, and the lowest daily price is $55 for the Mahindra XUV700. Would you like more details on any of these cars or are you ready to book?"
- Trace `[TRACE_ID]`: `get_available_rental_cars`, input `{"location":"Hyderabad Airport"}`, `success`, `featuredCars: ["Tesla Roadster"]`, `cars: ["Mahindra XUV700 $55 / day", "Toyota RAV4 $65 / day", "Tesla Model 3 $89 / day"]` (rate ascending, no Roadster), `hasFeatured: true`, `isEmpty: false`.
- The CLI cannot draw the widget; "hero renders first" rests on the deployed widget order above. Visual check in Agentforce still worth doing on camera.

## T6 PASS: Claude through MCP (reported by you, 15:17 IST, 2026-10-17)

- Claude, connector **`roadsterRentalsConnector_V2`** (re-registered after the resource URI change): the **Tesla Roadster renders first as the large featured card**, and the **other 3 cars render as a list with images and details**.
- Images load in Claude, so the image host path works on the MCP channel with the `raw.githubusercontent.com` Trusted URL in place (docs say the MCP CSP is provisioned from Trusted URLs; the render is consistent with that, the CSP itself was not inspected).
- Not reported for Claude: the Book click (`action/sendMessage`) result.

### Final working setup (both surfaces)

| Piece | Final value |
|---|---|
| Apex action | `RoadsterRentalsGetAvailableCars`, output `fleetResponse` (`FleetResult`) with `headline, locationLabel, totalCount, hasFeatured, isEmpty, featuredCar, featuredCars, cars`; `Car` includes `ratingLabel` |
| Hero data | `featuredCars`: one-item `List<Car>` with only the featured car (empty when none); `cars` never contains it and is rate ascending |
| Widget `roadsterFleet` | header, then hero container `meta { if: {!$attrs.hasFeatured}, forEach: {!$attrs.featuredCars}, forItem: $hero }`, then empty callout `meta.if {!$attrs.isEmpty}`, then cars `forEach {!$attrs.cars}`. No formulas, no `$attrs.x.y` object paths |
| Agentforce | Agent Script employee agent `Roadster_Rentals_Assistant` v1 active; output `complex_data_type_name: "c__roadsterFleetResponse"`, `is_displayable: True`; `roadsterFleetResponse` maps all widget attributes directly |
| MCP | `roadsterRentalsMcp`, tool `getAvailableRentalCars` (`readOnly true`), resource `roadsterFleetV3` = `ui://widget/lightningType/c__roadsterFleetResultV3`; `roadsterFleetResultV3` maps attributes through `outputValues.fleetResponse.*` |
| Auth | External Client App `Roadster_Rentals_MCP` (scopes `MCP, RefreshToken`, PKCE, JWT tokens, Claude callback) |

## T5 regression check after featuredCars (evidence)

- **CLI, published active agent:** session `[SESSION_ID]`, trace `[TRACE_ID]`. `get_available_rental_cars` with `{"location":"Hyderabad Airport"}` returned `success`; `featuredCars: ["Tesla Roadster"]`; `cars: ["Mahindra XUV700 $55 / day", "Toyota RAV4 $65 / day", "Tesla Model 3 $89 / day"]`; `hasFeatured: true`; `isEmpty: false`. Agent reply: "There are 4 cars available at Hyderabad Airport. The featured car is the Tesla Roadster at $1,999 per day, and the lowest daily price is $55 for the Mahindra XUV700. ..."
- **Widget order in the org** (retrieved after deploy [DEPLOY_ID]): hero container is root child 1, directly after the header, before the callout and the cars list.
- **Not yet confirmed visually:** a human look at the Agentforce panel after the featuredCars change. The CLI cannot draw widgets. The last visual Agentforce check (T5 result 2, "Looks good to me") was before this change.

## Cleanup: unused Lightning types removed (approved by you, 2026-10-17)

### Inventory before

| Type | Org HXL | Local |
|---|---|---|
| roadsterFleetResponse | yes, `[LIGHTNING_TYPE_ID]` | yes |
| roadsterFleetOutputValues | yes, `[LIGHTNING_TYPE_ID]` | yes |
| roadsterFleetResultV3 | yes, `[LIGHTNING_TYPE_ID]` | yes |
| roadsterFleetResult | yes, `[LIGHTNING_TYPE_ID]` | yes |
| roadsterFleetResultV2 | no | yes |

### Reference evidence

Searched: the whole local project, and an org retrieve (API 67.0, scratch folder outside the project) of LightningTypeBundle, McpServerDefinition, GenAiFunction, GenAiPlannerBundle, GenAiPlugin, AiAuthoringBundle, Bot, UiWidgetBundle, LightningComponentBundle, FlexiPage, ApexClass, Flow, GenAiPromptTemplate. Plus Tooling `McpServerResourceDefinition`, `McpServerToolDefinition`, `GenAiFunctionDefinition` and `MetadataComponentDependency`.

- MCP: org `roadsterRentalsMcp` `resourceUri` is `ui://widget/lightningType/c__roadsterFleetResultV3`, `uiResource roadsterFleetV3`. Only `McpServerResourceDefinition`: `[MCP_RESOURCE_ID]`, same URI, created 09:35:41 UTC.
- Agent action output: no classic GenAiFunction metadata. The Agent Script equivalent is the planner bundle `Roadster_Rentals_Assistant_v1`, `localActions/.../get_available_rental_cars_[ACTION_ID]/output/schema.json:7` = `c__roadsterFleetResponse`, same in the `.agent` file line 78. Dependency graph: `CAO-get_available_rental_cars_[ACTION_ID]` depends on `roadsterFleetResponse`.
- Type to type: `outputValues` = `c__roadsterFleetOutputValues` in `roadsterFleetResultV3` (and in V1 and V2). Dependency graph: `PT-roadsterFleetResultV3` and `PT-roadsterFleetResult` depend on `roadsterFleetOutputValues`.
- Nothing references `roadsterFleetResult` or `roadsterFleetResultV2`. Its only dependency row is its own registry entry `PT-roadsterFleetResult`.
- Retrieve at API 65.0 silently drops the MCP `<resources>` element and fails `UiWidgetBundle` ("not available in this api version"). Use 67.0.

| Type | Referenced by | Decision |
|---|---|---|
| roadsterFleetResponse | Agent action output | Keep |
| roadsterFleetOutputValues | `roadsterFleetResultV3.outputValues` | Keep |
| roadsterFleetResultV3 | MCP `resourceUri` and tool `uiResource` | Keep |
| roadsterFleetResult | nothing | Deleted (org and local) |
| roadsterFleetResultV2 | nothing | Deleted (local only, was never in the org) |

### Deploy

- Package: empty `package.xml` plus `destructiveChanges.xml` with only `LightningTypeBundle: roadsterFleetResult` (V2 left out: not in the org).
- Check-only: **[DEPLOY_ID]**, Succeeded, `roadsterFleetResult` `deleted: true`.
- Real deploy: **[DEPLOY_ID]**, Succeeded, completed 10:36:03 UTC.
- Local folders `lightningTypes/roadsterFleetResult/` and `lightningTypes/roadsterFleetResultV2/` removed.

### Proof they are gone

- `sf org list metadata -m LightningTypeBundle -o HXL`: `roadsterFleetOutputValues`, `roadsterFleetResponse`, `roadsterFleetResultV3`.
- Wildcard retrieve (API 67.0): the same three folders; `resourceUri` still `c__roadsterFleetResultV3`.
- Named retrieve: `Entity of type 'LightningTypeBundle' named 'roadsterFleetResult' cannot be found` and the same for `roadsterFleetResultV2`.
- Local `force-app/main/default/lightningTypes/`: the same three folders.

### Regression check after the delete

- **Agentforce (CLI, published active agent):** `sf agent preview start --api-name Roadster_Rentals_Assistant`, session `[SESSION_ID]`, utterance `I want to book a car at Hyderabad Airport`. Reply: "4 cars are available at Hyderabad Airport. The featured car is the Tesla Roadster, and the lowest daily price is $55." Result type `copilotActionOutput/get_available_rental_cars_[ACTION_ID]`: `totalCount 4`, `hasFeatured true`, `isEmpty false`, `featuredCars ["Tesla Roadster"]`, `cars ["Mahindra XUV700", "Toyota RAV4", "Tesla Model 3"]`.
- **Claude (MCP):** connector `roadsterRentalsConnector_V2`, tool `getAvailableRentalCars` with `{"location":"Hyderabad Airport"}`: `isSuccess true`, `actionName RoadsterRentalsGetAvailableCars`, same payload (4 cars, featured Tesla Roadster, list XUV700 $55, RAV4 $65, Model 3 $89). The call was made from Claude Code, which shows the data, not the widget.

### Gotcha 25 resolved: V2 was never deployed

- All 41 `DeployRequest` records in org HXL (2026-10-14 to 2026-10-17 09:35 UTC, before this cleanup), including failed and check-only ones, were opened with `sf project deploy report`. None contains `roadsterFleetResultV2` or any V2 component.
- Lightning type deploys ever: [DEPLOY_ID] (OutputValues, Result, Response), [DEPLOY_ID] (Result, Response), [DEPLOY_ID] (Response, ResultV3). MCP definition deploys: [DEPLOY_ID] (check-only), [DEPLOY_ID], [DEPLOY_ID], [DEPLOY_ID] (V3).
- The only MCP resource ever created is the V3 one. V2 existed only as local files until this cleanup.

## Gotchas

Every issue hit during the build, in the order it happened.

| # | Issue | Exact error or symptom | Fix | Root cause proven? |
|---|---|---|---|---|
| 1 | Salesforce doc pages block plain fetch | `The server returned HTTP 403 Forbidden.` (WebFetch and curl) | Rendered pages with headless Chromium (Node Playwright 1.47.2) | Yes: 403 on fetch, 200 in a browser |
| 2 | `platform-docs-get` extractor cannot run | `Could not find a version that satisfies the requirement playwright` on Python 3.8.2; skill needs 3.10+ | Same browser-rendered approach in Node | Yes |
| 3 | Old Salesforce CLI does not know the widget type | `roadsterFleet.uiwidget-meta.xml: Could not infer a metadata type` (CLI 2.136.8) | `sf update stable` to 2.154.4 | Yes: same files deploy on 2.154.4 |
| 4 | `@apexClassType` in the widget `schema.json` | `Required fields are missing: [SourceType]` (also at API 68.0) | Inline `lightning__objectType` with `properties` for `featuredCar` and `cars.items` | Yes: bisected; swapping only those two types removed the error; the official hotelCard sample validated |
| 5 | Icon name not allowed on buttons | `attributes.iconName: does not have a value in the enumeration [activity, alert-circle, ...]` for `car` | Removed `iconName` from buttons (`map-pin` on `tile/icon` is accepted) | Yes |
| 6 | `tile/card` (docs example) not available | Absent from `discoverUiComponents` in HXL | Used `tile/container` | Yes |
| 7 | Dynamic SOQL with both access-level forms | `System.SecurityException: Cannot use the WITH AccessLevel clause in dynamic queries that also specify an access level.` | Kept `WITH USER_MODE` in the string, used `Database.query` | Yes |
| 8 | Price label lost trailing zero | Test: `Expected: $49.50 / day, Actual: $49.5 / day` | Build cents explicitly instead of `Decimal.format()` | Yes |
| 9 | Test setup mixed setup and data DML | `MIXED_DML_OPERATION, DML operation on setup object is not permitted after you have updated a non-setup object ... PermissionSetAssignment` (passed at deploy, failed in a standalone run) | Create user and assignment inside `System.runAs` before inserting vehicles | Yes for the error; why the deploy-time run passed is unknown |
| 10 | Own mistake: shell redirect typo | `grep -c fieldPermissions> file` truncated the permission set and hung on stdin | Stopped the task, rewrote the file | Yes |
| 11 | HXL Playground cannot load car images | `Refused to load the image 'https://raw.githubusercontent.com/...' because it violates ... img-src` | None needed; Playground-only CSP | Yes |
| 12 | Image push to GitHub failed | `error: RPC failed; HTTP 400 curl 22 The requested URL returned error: 400` | Repo-local `git config http.postBuffer 52428800` | Inferred (classic large-push symptom on git 2.30; fixed by the buffer change) |
| 13 | Global git identity malformed | `user.name` `“[NAME]`, `user.email` `“[EMAIL]”` (curly quotes) | Repo-local identity in the assets clone only; global left unchanged | Yes |
| 14 | No Employee agent existed to extend | `BotDefinition` 0 rows; `AiAgentDefinition`, `AiAuthoringBundle`, `GenAiPlugin`, `GenAiFunction` all empty at API 67 and 68 | Created Agent Script agent `Roadster_Rentals_Assistant` | Yes |
| 15 | Prompt assumed legacy agent metadata | Docs: `GenAiPlannerBundle` "Doesn't exist in v68 and later releases" | Agent Script (`AiAuthoringBundle`); action, display, and rendering set in the `.agent` file | Yes (docs) |
| 16 | `npx skills add` for Agentforce skills | Exited without installing anything | Copied the skill folders from the same sf-skills commit (not in `skills-lock.json`) | No |
| 17 | CLI preview crashes for employee agents | `PreviewStartFailed: Cannot read properties of undefined (reading 'replace')` at `scriptAgent.js:391` | Placeholder `default_agent_user` in the local file only while starting `--authoring-bundle` previews; `--api-name` previews of the published agent are not affected | Yes: CLI source calls `.replace` on an absent `defaultAgentUser` |
| 18 | Skill claimed `number` action inputs fail at publish | Skill `complex-data-types.md` vs official actions reference | Used `number`; publish succeeded | Yes: skill claim did not hold here |
| 19 | Publish rewrites local files | `sf agent publish` retrieved 7 items and re-downloaded the Apex class and bundle meta | Checked the class was the final version | Yes |
| 20 | Hero Book button unreadable in Agentforce | Solid dark button; label visible only on hover (`variant: "primary"`) | `variant: "secondary"` | No: surface styling behavior; fix verified by your visual check |
| 21 | ECA refresh token rotation forced on | Deployed `isRefreshTokenRotationEnabled false`, retrieve returned `true` | Accepted (docs list rotation as optional hardening) | No |
| 22 | Consumer key appears in metadata | Retrieve of `ExtlClntAppGlobalOauthSettings` contains `<consumerKey>` | Redacted output, deleted the scratch copy, `.gitignore` entry `**/extlClntAppGlobalOauthSets/` | Yes |
| 23 | MCP server URL not in any org field | `McpServerDefinition` has no URL or status field | Built from the documented pattern; you confirmed it works | Yes |
| 24 | Comparison formula failed on the MCP path | `Callout failed: Failed to evaluate $attrs expression: {!$attrs.totalCount = 0}` | Apex `isEmpty` Boolean, `meta.if {!$attrs.isEmpty}`; rating formulas replaced by Apex `ratingLabel` | **No.** Candidates: null `totalCount`, string `totalCount`, or `lightning__integerType` vs `lightning__numberType`. The fix avoids all three with a documented bare Boolean |
| 25 | Stale widget after the fix | Same error at 14:43 and 14:49 IST: `Callout failed: Failed to evaluate $attrs expression: {!$attrs.totalCount = 0}`. The org metadata was clean (grep: no `totalCount =`, no `TEXT(`). Update tools and a server off/on toggle did not clear it | Removed and re-added the connector in Claude as `roadsterRentalsConnector_V1`; the tool succeeded at 14:54 IST on the **original** URI `c__roadsterFleetResult`. The V2 versioned URI was **never deployed**: no deploy between 09:09:09 and 09:29:37 UTC, and no V2 type in the org. V3 came later (09:35 UTC) for the hero change, and the connector was re-registered again as `_V2` | **V2 deployed? Resolved: no, never** (all 41 org deploys checked component by component, see "Cleanup: unused Lightning types removed"; V2 files and the unused V1 type were deleted then). **Cache cause: No.** Connector re-registration is the only known action before the fix, so it is the likely trigger. It is one observation, confounded with about 5 minutes of elapsed time, and was not repeated as a controlled test. Where the cache sits is unknown |
| 26 | Hero card empty on the MCP path | Widget renders in Claude, list cars fine, featured hero empty; payload has `featuredCar` complete | Hero rendered through `forEach` over a one-item `featuredCars` list; new wrapper `roadsterFleetResultV3`, resource `roadsterFleetV3` | Behavior proven (object-attribute binding empty on MCP, renders in Agentforce; `forEach` items work on both). Underlying reason unproven |

### Not done yet

- Book click in Claude, visual Agentforce check after featuredCars, T7 GIF.

## Docs only (not tested here)

- Salesforce provisions the MCP server CSP from Trusted URLs automatically (hxl-widget-composition).
- `resourceUri` format `ui://widget/lightningType/<CLT-API-NAME>`, and `<uiResource>` must equal `<resourceName>` (hxl-mcp-server).
- HXL widgets do not render in Slackbot Block Kit mode (hxl-mcp-channels).

## Pending results

- T5 Agentforce: not run.
- T6 Claude: not run.
- T7 GIF: untested.
