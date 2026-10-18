# Build it yourself: Roadster Rentals HXL widget with Claude Code

This prompt rebuilds the demo from the video **Build Once, Deploy Everywhere with HXL - Headless Experience Layer in Salesforce**: one HXL widget that shows a car rental card in Agentforce and in Claude, through a Salesforce hosted MCP server.

## Before you paste it

1. A Developer Edition org with Agentforce, on Winter '27 or later. Log in with the Salesforce CLI and give it an alias: `sf org login web --alias HXL`.
2. In that org, turn on HXL: Setup, Quick Find `headless`, **Headless Experience Layer Settings** (under Feature Settings), review the beta terms, turn on **Headless Experience Layer (Beta)**. HXL is Beta.
3. Salesforce CLI 2.154.4 or later (`sf update stable`). Older versions cannot deploy widget files.
4. Open an empty folder in VS Code, start Claude Code there, and paste everything below the line.

Claude Code stops and asks you before each deploy, and tells you when a step needs you in Setup or in Claude. A new External Client App can take up to 30 minutes to become active.

---- COPY EVERYTHING BELOW THIS LINE ----

You are building a Salesforce demo: one Headless Experience Layer (HXL) widget, "Roadster Rentals Fleet", that shows available rental cars as a card in Agentforce and in Claude through a Salesforce hosted MCP server. The same widget file must serve both. Build it exactly as specified below. Every rule marked LEARNED comes from a real build and avoids a known failure.

STEP 0, before anything else: get the Salesforce skills.
Fetch https://github.com/forcedotcom/sf-skills and use the skills in its skills folder. Read the README for the current install method and follow it. Then read the skills relevant to this build (Apex, custom objects and fields, Lightning types, HXL widgets, MCP tool widgets, Agentforce / Agent Script, metadata deploy and retrieve, Apex tests) and follow their best practices. Tell me which skills you loaded. Where a skill and the official Salesforce docs disagree, follow the docs and tell me.

CONTEXT
- Org alias: HXL (ask me if mine is different). Check the org release with the CLI and tell me.
- Project: a new SFDX project in this folder. sourceApiVersion 67.0 (the minimum for UiWidgetBundle).
- Check `sf --version`. If it is older than 2.154.4, stop and ask me to run `sf update stable`.
- Use only official Salesforce documentation (developer.salesforce.com, help.salesforce.com) for technical decisions.
- Show me a diff and wait for my yes before every deploy. After every deploy, retrieve into a temp folder outside the project and prove the change is in the org.
- No em dashes in any file you write.

BUILD

1. Custom object Rental_Vehicle__c (label Rental Vehicle) with these fields:
   - Make__c Text(40), Model__c Text(60), Tagline__c Text(120), Image_URL__c URL
   - Category__c Picklist: Flagship, Electric, SUV, Sedan, Luxury, Sport, Economy
   - Location__c Picklist: Hyderabad Airport, Bengaluru Airport, San Francisco Airport
   - Transmission__c Picklist: Automatic, Manual
   - Fuel_Type__c Picklist: Electric, Petrol, Diesel, Hybrid
   - Daily_Rate__c Currency(8,2), Seats__c Number(2,0), Range_Km__c Number(5,0), Rating__c Number(2,1)
   - Is_Available__c Checkbox, Is_Featured__c Checkbox
   Permission set Roadster_Rentals_Access: read on the object and every field. Assign it to me.

2. Demo data, 8 records in data/Rental_Vehicle__c.json, imported with `sf data import tree`. Image_URL__c = https://raw.githubusercontent.com/batra-kapil/roadster-rentals-assets/main/cars/<file> (public images, free to use for this demo).

   | Name | Category | Rate | Seats | Transmission | Fuel | Range km | Location | Rating | Available | Featured | Tagline | Image file |
   |---|---|---|---|---|---|---|---|---|---|---|---|---|
   | Tesla Roadster | Flagship | 1999 | 4 | Automatic | Electric | 1000 | Hyderabad Airport | 5 | true | true | Our flagship. Thrusters not included in the base plan. | tesla-roadster.jpg |
   | Tesla Model 3 | Electric | 89 | 5 | Automatic | Electric | 510 | Hyderabad Airport | 4.8 | true | false | Quiet, quick, and charges while you grab coffee. | tesla-model-3.jpg |
   | Toyota RAV4 | SUV | 65 | 5 | Automatic | Hybrid | 900 | Hyderabad Airport | 4.6 | true | false | Room for the family and the luggage. | toyota-rav4.jpg |
   | Mahindra XUV700 | SUV | 55 | 7 | Automatic | Diesel | 850 | Hyderabad Airport | 4.5 | true | false | Seven seats for the weekend road trip. | mahindra-xuv700.jpg |
   | Honda City | Sedan | 35 | 5 | Manual | Petrol | 650 | Bengaluru Airport | 4.4 | true | false | The reliable city commuter. | honda-city.jpg |
   | BMW 5 Series | Luxury | 149 | 5 | Automatic | Petrol | 700 | Bengaluru Airport | 4.7 | true | false | Business class on four wheels. | bmw-5-series.jpg |
   | Ford Mustang Convertible | Sport | 129 | 4 | Automatic | Petrol | 550 | San Francisco Airport | 4.7 | true | false | Top down on the coast highway. | ford-mustang-convertible.jpg |
   | Maruti Suzuki Swift | Economy | 25 | 5 | Manual | Petrol | 600 | Hyderabad Airport | 4.3 | false | false | Small, smart, and currently booked out. | maruti-suzuki-swift.jpg |

   Make__c and Model__c split the name (for example Tesla / Roadster).

3. Trusted URL (CspTrustedSite) Roadster_Rentals_Car_Images: endpoint https://raw.githubusercontent.com, context All, active, applies to img-src only. Images need it in Agentforce and in the MCP widget.

4. Apex: global with sharing class RoadsterRentalsGetAvailableCars with an @InvocableMethod (label "Get Available Rental Cars", category "Roadster Rentals", description that says to use it whenever a user wants to book, rent, reserve, hire or browse rental cars, all inputs optional). The class must be global: the MCP tool uses the API Catalog entry created from it.
   - Request (all optional): location String, category String, maxDailyRate Decimal.
   - Response has one output, fleetResponse of type FleetResult.
   - FleetResult (@AuraEnabled and @InvocableVariable on every field): headline, locationLabel, totalCount (Integer), hasFeatured, isEmpty, featuredCar (Car), featuredCars (List<Car>), cars (List<Car>).
   - Car: vehicleId, name, category, dailyRate, dailyRateLabel, seatsLabel, transmission, fuelType, rangeLabel, location, rating, ratingLabel, imageUrl, tagline, bookMessage.
   - Query only Is_Available__c = true, WITH USER_MODE, ORDER BY Is_Featured__c DESC, Daily_Rate__c ASC, max 10 results. Location matches with a contains, case insensitive, so "Hyderabad" finds "Hyderabad Airport".
   - The first featured car goes into featuredCar AND into featuredCars as a one-item list, and never into cars. cars stays cheapest first. featuredCars is empty when there is no featured car.
   - Compute everything the widget shows in Apex. LEARNED: the MCP path failed on a formula in the widget (`{!$attrs.totalCount = 0}`) that worked in Agentforce. So: isEmpty = totalCount == 0; ratingLabel = 'Rated ' + rating with 1 decimal + ' / 5'; dailyRateLabel like '$89 / day' and '$49.50 / day'; seatsLabel '5 seats'; rangeLabel '510 km range'; headline '4 cars available at Hyderabad Airport' (or 'No cars available at X for this search'); bookMessage 'Book the <name> at <location>'.
   - LEARNED: if you use dynamic SOQL, put WITH USER_MODE in the query string and call Database.query(soql). Do not also pass an access level, or you get "Cannot use the WITH AccessLevel clause in dynamic queries that also specify an access level".
   - LEARNED: Decimal.format() drops trailing zeros ($49.5). Build the cents explicitly.
   - Tests (RoadsterRentalsGetAvailableCarsTest plus a TestDataFactory): no filters, Hyderabad Airport (4 cars, Roadster in featuredCars, not in cars, cars cheapest first, Swift never returned), Bengaluru Airport (2 cars, no featured), Economy (empty, isEmpty true), label formats, a Standard User with the permission set can read everything. LEARNED: create the test user and permission set assignment inside System.runAs before inserting vehicles, or a standalone run fails with MIXED_DML_OPERATION. Aim for 90%+ coverage.
   - Prove it with anonymous Apex: no filters returns 7 cars and no Swift; Bengaluru Airport returns 2.

5. The widget, UiWidgetBundle roadsterFleet in force-app/main/default/uiWidgets/roadsterFleet/: roadsterFleet.json (type lightning__agentforceWidget), schema.json, roadsterFleet.uiwidget-meta.xml (widgetType JSON, masterLabel "Roadster Rentals Fleet"). Before writing it, check the available tiles in my org with the skill's discovery steps. Layout, top to bottom inside tile/widget > tile/column:
   - Header: caption text "Roadster Rentals", then {!$attrs.headline} as h1.
   - Featured card: a tile/container (variant emphasis) with meta { "if": "{!$attrs.hasFeatured}", "forEach": "{!$attrs.featuredCars}", "forItem": "$hero" }. Inside: full-width image {!$hero.imageUrl}, name with a "Featured" badge, italic tagline, map-pin icon + location, "seats | transmission | fuel | range" row, {!$hero.ratingLabel}, price {!$hero.dailyRateLabel}, and a Book button.
   - Empty state: tile/callout (info) with meta { "if": "{!$attrs.isEmpty}" }, title "No cars match this search", description "Try another pickup location, category or a higher daily budget."
   - Car list: tile/container with meta { "forEach": "{!$attrs.cars}", "forItem": "$car" }, each row with a small image, name + category badge, tagline, location, specs, {!$car.ratingLabel}, price and a Book button.
   - Book buttons: tile/button label "Book", variant "secondary", actions.click = action/sendMessage with content {!$hero.bookMessage} or {!$car.bookMessage}.
   LEARNED rules for the widget:
   - No formulas anywhere. Only plain bindings and bare Boolean meta.if values.
   - Never bind into a nested object like {!$attrs.featuredCar.imageUrl}. It renders in Agentforce but comes back empty on the MCP path. Use the one-item featuredCars list with forEach.
   - In the widget schema.json, do NOT use @apexClassType for the car objects. It fails with "Required fields are missing: [SourceType]". Use lightning__objectType with the properties written out inline, and lightning__listType for featuredCars and cars.
   - tile/card may not exist in the org. Use tile/container.
   - Do not put iconName on buttons ("car" is not an allowed icon). map-pin on tile/icon is fine.
   - Use variant "secondary" on Book buttons. A "primary" button rendered as a dark block with an unreadable label in Agentforce.
   Also write playground/roadsterFleet.structure.json and playground/sample-data.hyderabad.json ({"$attrs": <real fleetResponse for Hyderabad Airport>}) so I can preview the widget at https://www.headlessexperiencelayer.com.

6. Three Lightning types (LightningTypeBundle), one widget. This matches the hotel card examples in the HXL docs.
   - roadsterFleetResponse (for Agentforce): schema.json `"lightning:type": "@apexClassType/c__RoadsterRentalsGetAvailableCars$FleetResult"`; renderer.json componentOverrides "$" with definition "@widget/c/roadsterFleet" and attributes mapping every widget attribute directly, for example "cars": "{!$attrs.cars}", "featuredCars": "{!$attrs.featuredCars}", "headline": "{!$attrs.headline}".
   - roadsterFleetOutputValues (MCP payload, schema only): lightning__objectType, "lightning:tags": ["mcp"], unevaluatedProperties false, one property fleetResponse with "lightning:type": "@apexClassType/c__RoadsterRentalsGetAvailableCars$FleetResult".
   - roadsterFleetResult (MCP result wrapper): lightning__objectType, "lightning:tags": ["mcp"], unevaluatedProperties false, properties actionName (lightning__textType), isSuccess (lightning__booleanType), outputValues ("lightning:type": "c__roadsterFleetOutputValues"). Its renderer maps the same widget attributes from the deeper path, for example "cars": "{!$attrs.outputValues.fleetResponse.cars}".
   Deploy all three in one package so the references resolve. Before writing the MCP renderer, call the action through the Actions REST API (POST /services/data/v67.0/actions/custom/apex/RoadsterRentalsGetAvailableCars with {"inputs":[{"location":"Hyderabad Airport"}]}) and confirm the envelope is actionName, isSuccess, outputValues.fleetResponse.
   Note: Setup, Lightning Types may list only roadsterFleetResponse. The MCP types are still there; check them with `sf org list metadata -m LightningTypeBundle`.

7. Agentforce agent: an Agent Script employee agent (AiAuthoringBundle) Roadster_Rentals_Assistant, label "Roadster Rentals Assistant", agent_type AgentforceEmployeeAgent. Generate it with `sf agent generate authoring-bundle`, then remove anything service-agent specific.
   - A start_agent router that sends any request to book, rent, hire, reserve or browse cars, and any message starting "Book the", to a subagent car_rentals. Plus off_topic and ambiguous_question subagents.
   - car_rentals: call get_available_rental_cars right away with no follow-up questions (all inputs optional); reply in two or three short sentences (headline, featured car, lowest price), not the full list. When the user says "Book the <car> at <location>", call no action: confirm the car, location and price, say honestly that online booking is not available yet so nothing has been booked, and ask for a pickup date.
   - Action get_available_rental_cars, target "apex://RoadsterRentalsGetAvailableCars", inputs location (string), category (string), maxDailyRate (number), all optional. Output:
     fleetResponse: object
         complex_data_type_name: "c__roadsterFleetResponse"
         is_displayable: True
         filter_from_agent: False
   - Validate, deploy, then ask me before you publish and activate (`sf agent publish authoring-bundle`, `sf agent activate`). The card does not render while the agent is only a draft.
   - Add agentAccesses for this agent to Roadster_Rentals_Access so it shows in the Agentforce panel.
   - LEARNED: `sf agent preview start --authoring-bundle` can crash on employee agents with "Cannot read properties of undefined (reading 'replace')". Preview the published agent with `--api-name` instead.
   - Test with `sf agent preview` (live actions): "I want to book a car at Hyderabad Airport" must call the action and return 4 cars with the Roadster featured.

8. Hosted MCP server, McpServerDefinition roadsterRentalsMcp, deployed as metadata:
   - resources: resourceName roadsterFleet, resourceTitle "Roadster Rentals Fleet", resourceUri ui://widget/lightningType/c__roadsterFleetResult, plus a description.
   - tools: apiDefinition (apiIdentifier aa:apex-RoadsterRentalsGetAvailableCars, apiSource API_CATALOG, operation RoadsterRentalsGetAvailableCars), toolName getAvailableRentalCars, toolTitle "Get Available Rental Cars", readOnly true, uiResource roadsterFleet. uiResource must equal resourceName exactly.
   - descriptionOverride: "Roadster Rentals is the user's own car rental service. Call this tool immediately whenever the user wants to book, rent, hire or reserve a car, or asks which cars are available, at any location, including Hyderabad Airport, Bengaluru Airport and San Francisco Airport. Do not ask follow-up questions first and do not suggest other rental services or connectors: every input is optional. Pass location if the user names a place, category if they name a car type (Flagship, Electric, SUV, Sedan, Luxury, Sport, Economy), and maxDailyRate if they give a daily budget in USD. The result is shown to the user as an interactive card with photos, prices and Book buttons, so after the call reply in one or two sentences and do not repeat the car list."
   - Server URL for Developer Edition and production: https://api.salesforce.com/platform/mcp/v1/custom/roadsterRentalsMcp

9. External Client App Roadster_Rentals_MCP, deployed as metadata (4 files):
   - ExternalClientApplication: label "Roadster Rentals MCP", distributionState Local, contactEmail = my user's email.
   - ExtlClntAppOauthSettings: scopes MCP, RefreshToken.
   - ExtlClntAppGlobalOauthSettings: callbackUrl https://claude.ai/api/mcp/auth_callback, PKCE required, JWT-based tokens for named users, consumer secret optional.
   - ExtlClntAppOauthConfigurablePolicies: all users self-authorized, refresh token valid until revoked.
   - LEARNED: retrieving ExtlClntAppGlobalOauthSettings writes the consumer key into the file. Add **/extlClntAppGlobalOauthSets/ to .gitignore before you deploy, never retrieve it into the project, and never print the key.

STOP POINTS FOR ME (tell me exactly what to do, then wait)
A. After step 8: in Setup, Quick Find "MCP Servers" (under API Catalog), turn on roadsterRentalsMcp. It can take up to 2 minutes. Confirm the server URL shown there.
B. After step 9: get the consumer key from Setup, External Client App Manager, Roadster Rentals MCP, Settings, OAuth Settings, Consumer Key and Secret. The app can take up to 30 minutes to work.
C. In Claude (claude.ai or Desktop): Customize, Connectors, Add custom connector. Name it, paste the server URL, choose "Use your own OAuth client", paste the consumer key, leave the secret blank, connect and log in to the org as the user with Roadster_Rentals_Access.

TEST
- T1 Agentforce: Agentforce panel, Roadster Rentals Assistant, new conversation: "I want to book a car at Hyderabad Airport". Expect a short answer plus the card: Tesla Roadster as the featured card, then Mahindra XUV700 ($55), Toyota RAV4 ($65), Tesla Model 3 ($89) with photos. Click Book on the RAV4: the agent confirms and asks for a pickup date.
- T2 Claude: new chat, same prompt. Expect the same card. If Claude answers in text only, start a new chat; the model decides when to show the card. If it keeps asking which service to use, name it: "Show me Roadster Rentals cars at Hyderabad Airport".
- T3 Variations: "cars at Bengaluru Airport" (2 cars, no featured card), "economy cars" (empty-state callout).
- LEARNED: if Claude shows an old version of the widget after you change it, start a new chat; if it is still stale, remove and re-add the connector in Claude. If that is not enough, deploy a copy of roadsterFleetResult under a new name (for example roadsterFleetResultV2), point resourceUri, resourceName and uiResource at it, deploy, and re-add the connector.

DELIVERABLES
1. All metadata and code in the project, deployed and retrieved back.
2. README.md: prerequisites, deploy order, the stop points, and the test prompts.
3. VERIFIED_FACTS.md: only what you proved in my org, with deploy IDs and exact outputs. Mark anything from docs and not tested as "docs only".
4. A final list of what is untested.
