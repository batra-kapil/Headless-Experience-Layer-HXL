# Handoff: Roadster Rentals HXL Widget

Status on 2026-10-17: **built and passing on both surfaces.** T5 Agentforce and T6 Claude pass (see VERIFIED_FACTS.md). Remaining: rehearse the Book click in Claude, optional T7 GIF.

## Final file list

```text
README.md, HANDOFF.md, VERIFIED_FACTS.md
sfdx-project.json                      (sourceApiVersion 67.0)
assets/cars/README.md                  (8 expected image names)
data/Rental_Vehicle__c.json            (8 demo cars)
playground/roadsterFleet.structure.json
playground/sample-data.all-locations.json
playground/sample-data.bengaluru.json
playground/sample-data.empty.json
scripts/apply-image-base-url.js
scripts/apex/t3-get-available-cars.apex
scripts/apex/update-image-urls.apex    (generated)
force-app/main/default/
  objects/Rental_Vehicle__c/Rental_Vehicle__c.object-meta.xml
  objects/Rental_Vehicle__c/fields/    (14 fields)
  permissionsets/Roadster_Rentals_Access.permissionset-meta.xml
  classes/RoadsterRentalsGetAvailableCars.cls (+ meta)
  classes/RoadsterRentalsGetAvailableCarsTest.cls (+ meta)
  classes/TestDataFactory.cls (+ meta)
  uiWidgets/roadsterFleet/roadsterFleet.json
  uiWidgets/roadsterFleet/schema.json
  uiWidgets/roadsterFleet/roadsterFleet.uiwidget-meta.xml
  lightningTypes/roadsterFleetResponse/schema.json, renderer.json      (Agentforce)
  lightningTypes/roadsterFleetOutputValues/schema.json                  (MCP payload)
  lightningTypes/roadsterFleetResultV3/schema.json, renderer.json      (MCP result wrapper, live)
  cspTrustedSites/Roadster_Rentals_Car_Images.cspTrustedSite-meta.xml
  aiAuthoringBundles/Roadster_Rentals_Assistant/Roadster_Rentals_Assistant.agent, .bundle-meta.xml  (Employee agent)
  mcpServerDefinitions/roadsterRentalsMcp.mcpServerDefinition-meta.xml (created by deploy)
  externalClientApps/Roadster_Rentals_MCP.eca-meta.xml
  extlClntAppOauthSettings/Roadster_Rentals_MCP.ecaOauth-meta.xml
  extlClntAppGlobalOauthSets/Roadster_Rentals_MCP.ecaGlblOauth-meta.xml  (git-ignored, never retrieve into the project)
  extlClntAppOauthPolicies/Roadster_Rentals_MCP.ecaOauthPlcy-meta.xml
.claude/skills/                        (14 Salesforce Skills)
```

## Before you start

- Images are done: served from the public images-only repo `batra-kapil/roadster-rentals-assets` (`cars/`), all 8 URLs return 200 `image/jpeg`, and all 8 records point at them. This project stays local; only the JPEGs were pushed.
- Any user who tests the agent or connects Claude needs the `Roadster_Rentals_Access` permission set (the action queries `WITH USER_MODE`). It is assigned to `[YOUR_USERNAME]`.

## Manual checklist

### M1 and M2. Agent, action and subagent (done by metadata, no Setup clicks)

The org had no agent, so I created a new Agent Script Employee agent instead of using Setup > Agentforce Assets (that UI path is for legacy actions; on v68 the action, Show in conversation and Output Rendering all live in the `.agent` file).

- Agent: **Roadster Rentals Assistant** (`Roadster_Rentals_Assistant`, `AgentforceEmployeeAgent`), file `force-app/main/default/aiAuthoringBundles/Roadster_Rentals_Assistant/Roadster_Rentals_Assistant.agent`.
- Subagent: **Car Rentals** (`car_rentals`) with the action `get_available_rental_cars` -> `apex://RoadsterRentalsGetAvailableCars`.
- Output `fleetResponse` ("Fleet Response"): Show in conversation = `is_displayable: True`. Output Rendering = `complex_data_type_name`.
- State now: **AFTER, published and active** (version 1). Output `complex_data_type_name: "c__roadsterFleetResponse"`. BEFORE draft deploy [DEPLOY_ID], AFTER draft deploy [DEPLOY_ID], permset with agent access [DEPLOY_ID]. To re-take the BEFORE shot, switch the output back to `@apexClassType/c__RoadsterRentalsGetAvailableCars$FleetResult`, deploy, publish, activate.
- Verified with `sf agent preview` (live actions): routes to Car Rentals, invokes the action, honest reply to "Book the ...". Details in VERIFIED_FACTS.md.

**Your step now: record the plain-text BEFORE shot.**

1. Run `sf org open authoring-bundle --target-org HXL` (opens Agentforce Builder's authoring bundle list), or Setup > Agentforce Agents, and open **Roadster Rentals Assistant**.
2. In Builder's conversation preview, type `I want to book a car at Hyderabad Airport`. Expect a short text answer naming 4 cars at Hyderabad Airport, the Tesla Roadster at $1,999 per day, and the lowest price $55. If Builder asks for an action mode, choose live actions so the real data appears.
3. Then say **after**.

**When you say "after" (my steps):**

1. Change the output to `complex_data_type_name: "c__roadsterFleetResponse"` (keep `is_displayable: True`, `filter_from_agent: False`), compile, validate, deploy.
2. Retrieve the bundle and confirm the setting persisted; report the output Data Type.
3. Ask you to approve **publish and activate** (`sf agent publish authoring-bundle`, `sf agent activate`). Docs say the widget card does not render in Builder preview while the agent is Draft, so the AFTER shot needs this. I will also add `agentAccesses` for this agent to `Roadster_Rentals_Access` so it appears in the Agentforce panel.

Known CLI bug: `sf agent preview start` crashes on employee agents (`Cannot read properties of undefined (reading 'replace')`). Workaround documented in VERIFIED_FACTS.md; it touches the local file only.

### M3 and M4. Custom MCP server with the widget resource (done by metadata)

Created by deploy, not Setup. Docs: custom servers can "Be deployed via Metadata API between sandboxes and production" (https://developer.salesforce.com/docs/platform/hosted-mcp-servers/guide/custom-servers.html); deployable XML example in https://developer.salesforce.com/blogs/2026/05/expose-custom-apex-as-a-hosted-mcp-tool-for-agents.

- File: `force-app/main/default/mcpServerDefinitions/roadsterRentalsMcp.mcpServerDefinition-meta.xml`.
- Tool `getAvailableRentalCars` ("Get Available Rental Cars"), backed by the API Catalog entry auto-created from the global Apex class (`aa:apex-RoadsterRentalsGetAvailableCars`, `API_CATALOG`), not by the agent action. `<uiResource>roadsterFleetV3</uiResource>` (was `roadsterFleet` before the V3 resource change).
- Resource now `roadsterFleetV3`, `ui://widget/lightningType/c__roadsterFleetResultV3` (deploy [DEPLOY_ID]), title "Roadster Rentals Fleet". The hero renders through the `featuredCars` list (see VERIFIED_FACTS.md, T6).
- Dry run [DEPLOY_ID], deploy [DEPLOY_ID] (`created: true`). Retrieved back intact; the org added tool hints `destructive, idempotent, openWorld, readOnly, returnDirect` all `false`.
- Server URL (from the documented pattern for Production / Developer Edition; no org field exposes it): `https://api.salesforce.com/platform/mcp/v1/custom/roadsterRentalsMcp`. Confirm against Setup > MCP Servers when you activate.
- State: **not active** (no `McpServerAccess` record).

**Activation:** you toggle it in Setup (documented path, see below). The undocumented Tooling API `McpServerAccess` route will not be used.

- `readOnly` set to `true` on `getAvailableRentalCars`: deploy [DEPLOY_ID], confirmed by retrieve and by the `McpServerToolDefinition` record (`ReadOnly: true`).

### Activate the MCP server (you, documented path)

Setup > Quick Find "MCP Servers" (under API Catalog) > toggle **roadsterRentalsMcp** on. Up to 2 minutes to take effect. https://developer.salesforce.com/docs/platform/hosted-mcp-servers/guide/activate-mcp-servers.html. While there, confirm the server URL shown matches `https://api.salesforce.com/platform/mcp/v1/custom/roadsterRentalsMcp`.

### M5. External Client App (done by metadata)

`Roadster_Rentals_MCP`, four metadata files, deploy [DEPLOY_ID] (all `created: true`):

- `externalClientApps/Roadster_Rentals_MCP.eca-meta.xml`
- `extlClntAppOauthSettings/Roadster_Rentals_MCP.ecaOauth-meta.xml` (scopes `MCP, RefreshToken`)
- `extlClntAppGlobalOauthSets/Roadster_Rentals_MCP.ecaGlblOauth-meta.xml` (callback `https://claude.ai/api/mcp/auth_callback`, PKCE required, JWT-based tokens, secret optional). **Git-ignored**: a retrieve of this type writes the consumer key into it. Never retrieve it into the project.
- `extlClntAppOauthPolicies/Roadster_Rentals_MCP.ecaOauthPlcy-meta.xml` (all users self-authorized, refresh token valid until revoked)

The docs say a new External Client App can take up to 30 minutes to work.

**Consumer key (you):** Setup > Quick Find "external client" > **External Client App Manager** > **Roadster Rentals MCP** > **Settings** > under OAuth Settings click **Consumer Key and Secret** (Salesforce may ask you to verify your identity). Copy the key straight into Claude; do not paste it into any project file. Source: https://developer.salesforce.com/docs/platform/hosted-mcp-servers/guide/create-external-client-app.html

### M6. Connect Claude (you)

Docs: https://developer.salesforce.com/docs/platform/hosted-mcp-servers/guide/claude.html. Surfaces: "These setup steps apply to Claude.ai and the Claude Desktop app. Claude Code inherits the same connection."

1. Left sidebar > **Customize** > **Connectors** > **Add** > **Add custom connector**.
2. Name: any name. In use now: `roadsterRentalsConnector_V2` (re-registered after the resource URI change to V3).
3. Server URL: `https://api.salesforce.com/platform/mcp/v1/custom/roadsterRentalsMcp`.
4. **Continue**. Under OAuth client choose **Use your own OAuth client**.
5. OAuth Client ID: the consumer key. OAuth Client Secret: leave blank.
6. Click **Connect**, log in to org HXL as the user with `Roadster_Rentals_Access`.

## How to run the demo

Status: **T5 (Agentforce) and T6 (Claude) pass.** Final setup is listed in VERIFIED_FACTS.md ("Final working setup").

1. **Agentforce:** Lightning Experience > Agentforce panel > pick **Roadster Rentals Assistant**, or Builder Live Test on the active version. Start a fresh conversation and type `I want to book a car at Hyderabad Airport`.
2. **Expected:** a short text answer plus the widget. Header "Roadster Rentals" and "4 cars available at Hyderabad Airport". First, the **Tesla Roadster** featured card (large photo, Featured badge, tagline, $1,999 / day, Book). Then the list: Mahindra XUV700 ($55), Toyota RAV4 ($65), Tesla Model 3 ($89), each with photo, category, specs, rating, price, Book.
3. **Book:** click Book on a list card. It sends `Book the Toyota RAV4 at Hyderabad Airport`; the agent confirms the car, location and price, says nothing has been booked yet, and asks for a pickup date.
4. **Claude (claude.ai or Desktop):** connector **`roadsterRentalsConnector_V2`**, new chat, same prompt. Same widget, Roadster first.
5. **Variations:** `show me available cars in Hyderabad` (same 4), `cars at Bengaluru Airport` (2 cars, no featured card), `any SUVs under 60 a day?` (XUV700 only), `economy cars` (empty-state callout; the only Economy car, the Swift, is unavailable).
6. The model decides whether to show the card. If you get text only, clear the history (Agentforce) or start a new chat (Claude) and ask again.

## Shot list

1. **Before (optional, needs a temporary revert).** The live agent now renders the widget. To film the plain output again, I switch the output back to `@apexClassType/c__RoadsterRentalsGetAvailableCars$FleetResult`, then deploy, publish and activate (about a minute), and switch back after the shot. On screen: Builder Live Test with `I want to book a car at Hyderabad Airport`, showing the text answer plus the raw "Entry 1" field list. Skip this if you already recorded it.
2. **Agentforce widget.** Agentforce panel, fresh conversation, `I want to book a car at Hyderabad Airport`. Hold on the Tesla Roadster featured card at the top, then scroll the three list cards.
3. **Book in Agentforce.** Click Book on the Toyota RAV4. Show the sent message and the agent's honest "nothing booked yet, what pickup date?" reply.
4. **Same widget in Claude.** claude.ai or Desktop, connector `roadsterRentalsConnector_V2`, new chat, same prompt. Show the same layout: Roadster featured card first, three cars below with photos.
5. **Book in Claude.** Click Book on a card in Claude. **Rehearse this first: the Book click has not been tested in Claude yet.**
6. **Optional:** `cars at Bengaluru Airport` (list without a featured card) and `economy cars` (empty state, unavailable Swift filtered out).

## Open items

| Item | State |
|---|---|
| Org release | Winter '27 (API 68.0 max). Project deploys at 67.0. |
| T5 Agentforce | Pass. Visual check by you before the featuredCars change; after it, verified by CLI trace only (`featuredCars: ["Tesla Roadster"]`). Look once in the Agentforce panel before recording. |
| T6 Claude | **Pass** (you, 15:17 IST): Roadster featured card first, 3 list cars with images and details, via `roadsterRentalsConnector_V2`. |
| Book click in Claude | Not tested. Rehearse before shot 5. |
| Book click in Agentforce widget | Agent reply proven by CLI; the widget click itself was proven in the HXL Playground. Re-check on camera. |
| T7 GIF in `Image_URL__c` | Untested. |
| Old Claude connector `roadsterRentalsConnector` | Points at the same server; remove it so only `roadsterRentalsConnector_V2` is used. |
| Retired metadata | Done 2026-10-17: `roadsterFleetResult` (V1) deleted from the org (destructive deploy [DEPLOY_ID], check-only [DEPLOY_ID]) and locally; `roadsterFleetResultV2` deleted locally (never deployed). Agentforce preview and the MCP tool re-checked after. Remaining Lightning types: `roadsterFleetResponse`, `roadsterFleetOutputValues`, `roadsterFleetResultV3`. `FleetResult.featuredCar` kept but no longer used by the widget. |
| Future widget changes | Any widget change: redeploy, start a new chat. If Claude shows a stale widget, see Gotchas 25 in VERIFIED_FACTS.md (Update tools and a server toggle did not clear it; removing and re-adding the connector preceded the fix; a versioned resource URI is the documented fallback). |
