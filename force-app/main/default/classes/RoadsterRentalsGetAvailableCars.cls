/**
 * @description Invocable action that returns the available Roadster Rentals fleet for an
 *              Agentforce agent or a hosted MCP server tool. The output is shaped for the
 *              roadsterFleet HXL widget: one featured hero car plus a list of other cars.
 *              Accepts a bulk List<Request> and runs a single SOQL query for all requests.
 */
global with sharing class RoadsterRentalsGetAvailableCars {

    private static final Integer MAX_RESULTS = 10;
    private static final Integer BULK_ROW_CAP = 2000;
    private static final String CURRENCY_SYMBOL = '$';
    private static final String ALL_LOCATIONS_LABEL = 'all Roadster Rentals locations';

    /**
     * @description Returns available rental cars, optionally filtered by location, category
     *              and maximum daily rate. Featured cars sort first, then cheapest first.
     * @param requests Bulk list of search requests (all inputs optional)
     * @return One Response per Request, in the same order
     * @throws FleetQueryException when the fleet query fails
     */
    @InvocableMethod(
        label='Get Available Rental Cars'
        description='Use this action whenever a user wants to book, rent, reserve, hire or browse rental cars, or asks which cars are available. Returns the available Roadster Rentals fleet as a featured flagship car plus a list of other cars, with price per day, seats, transmission, fuel, range and rating. All inputs are optional: pickup location, car category and maximum daily rate.'
        category='Roadster Rentals'
    )
    global static List<Response> getAvailableCars(List<Request> requests) {
        List<Response> responses = new List<Response>();
        if (requests == null || requests.isEmpty()) {
            return responses;
        }

        List<Rental_Vehicle__c> candidates = queryCandidates(requests);

        for (Request req : requests) {
            Response res = new Response();
            res.fleetResponse = buildFleetResult(req ?? new Request(), candidates);
            responses.add(res);
        }
        return responses;
    }

    // ─── Query ───────────────────────────────────────────────────────────

    /**
     * @description Runs one query that covers the union of every request's filters.
     *              For a single request the filters are exact and LIMIT 10 is applied in SOQL.
     *              For several requests the query is widened and each request is sliced in memory.
     */
    private static List<Rental_Vehicle__c> queryCandidates(List<Request> requests) {
        Boolean anyWithoutLocation = false;
        Boolean anyWithoutCategory = false;
        Boolean anyWithoutMaxRate = false;
        List<String> locationPatterns = new List<String>();
        List<String> categories = new List<String>();
        Decimal widestMaxRate = null;

        for (Request req : requests) {
            String location = req?.location?.trim();
            String category = req?.category?.trim();
            Decimal maxRate = req?.maxDailyRate;

            if (String.isBlank(location)) {
                anyWithoutLocation = true;
            } else {
                locationPatterns.add('%' + escapeLike(location) + '%');
            }
            if (String.isBlank(category)) {
                anyWithoutCategory = true;
            } else {
                categories.add(category);
            }
            if (maxRate == null) {
                anyWithoutMaxRate = true;
            } else if (widestMaxRate == null || maxRate > widestMaxRate) {
                widestMaxRate = maxRate;
            }
        }

        // Bind variables below are referenced by name from the dynamic SOQL string.
        Integer rowLimit = requests.size() == 1 ? MAX_RESULTS : BULK_ROW_CAP;
        String soql =
            'SELECT Id, Name, Category__c, Daily_Rate__c, Seats__c, Transmission__c, Fuel_Type__c, ' +
            'Range_Km__c, Location__c, Rating__c, Image_URL__c, Tagline__c, Is_Featured__c ' +
            'FROM Rental_Vehicle__c WHERE Is_Available__c = true';
        if (!anyWithoutLocation) {
            soql += ' AND Location__c LIKE :locationPatterns';
        }
        if (!anyWithoutCategory) {
            soql += ' AND Category__c IN :categories';
        }
        if (!anyWithoutMaxRate) {
            soql += ' AND Daily_Rate__c <= :widestMaxRate';
        }
        soql += ' WITH USER_MODE ORDER BY Is_Featured__c DESC, Daily_Rate__c ASC LIMIT :rowLimit';

        try {
            return Database.query(soql);
        } catch (QueryException e) {
            throw new FleetQueryException('Unable to load the Roadster Rentals fleet: ' + e.getMessage(), e);
        }
    }

    // ─── Mapping ─────────────────────────────────────────────────────────

    private static FleetResult buildFleetResult(Request req, List<Rental_Vehicle__c> candidates) {
        List<Rental_Vehicle__c> matches = new List<Rental_Vehicle__c>();
        for (Rental_Vehicle__c vehicle : candidates) {
            if (matches.size() == MAX_RESULTS) {
                break;
            }
            if (matchesRequest(vehicle, req)) {
                matches.add(vehicle);
            }
        }

        FleetResult result = new FleetResult();
        result.cars = new List<Car>();
        result.featuredCars = new List<Car>();
        result.hasFeatured = false;
        result.totalCount = matches.size();
        result.locationLabel = resolveLocationLabel(req, matches);

        for (Rental_Vehicle__c vehicle : matches) {
            Car car = toCar(vehicle);
            // Only the first featured car becomes the hero; any others stay in the list.
            if (vehicle.Is_Featured__c && !result.hasFeatured) {
                result.featuredCar = car;
                // One-item list so the widget renders the hero through forEach (object binding is empty on MCP, see T6).
                result.featuredCars.add(car);
                result.hasFeatured = true;
            } else {
                result.cars.add(car);
            }
        }

        // Booleans and labels are computed here so the widget needs no formulas (see T6 in VERIFIED_FACTS.md).
        result.isEmpty = result.totalCount == 0;
        result.headline = buildHeadline(result.totalCount, result.locationLabel);
        return result;
    }

    private static Boolean matchesRequest(Rental_Vehicle__c vehicle, Request req) {
        String location = req.location?.trim();
        String category = req.category?.trim();
        if (String.isNotBlank(location) && !(vehicle.Location__c ?? '').containsIgnoreCase(location)) {
            return false;
        }
        if (String.isNotBlank(category) && !category.equalsIgnoreCase(vehicle.Category__c)) {
            return false;
        }
        if (req.maxDailyRate != null && (vehicle.Daily_Rate__c == null || vehicle.Daily_Rate__c > req.maxDailyRate)) {
            return false;
        }
        return true;
    }

    private static String resolveLocationLabel(Request req, List<Rental_Vehicle__c> matches) {
        Set<String> locations = new Set<String>();
        for (Rental_Vehicle__c vehicle : matches) {
            locations.add(vehicle.Location__c);
        }
        if (locations.size() == 1) {
            return new List<String>(locations)[0];
        }
        String requested = req.location?.trim();
        return String.isNotBlank(requested) ? requested : ALL_LOCATIONS_LABEL;
    }

    private static String buildHeadline(Integer total, String locationLabel) {
        if (total == 0) {
            return 'No cars available at ' + locationLabel + ' for this search';
        }
        return total + (total == 1 ? ' car' : ' cars') + ' available at ' + locationLabel;
    }

    private static Car toCar(Rental_Vehicle__c vehicle) {
        Car car = new Car();
        car.vehicleId = vehicle.Id;
        car.name = vehicle.Name;
        car.category = vehicle.Category__c;
        car.dailyRate = vehicle.Daily_Rate__c;
        car.dailyRateLabel = formatDailyRate(vehicle.Daily_Rate__c);
        car.seatsLabel = vehicle.Seats__c == null ? '' : vehicle.Seats__c.intValue() + ' seats';
        car.transmission = vehicle.Transmission__c;
        car.fuelType = vehicle.Fuel_Type__c;
        car.rangeLabel = vehicle.Range_Km__c == null ? '' : vehicle.Range_Km__c.intValue() + ' km range';
        car.location = vehicle.Location__c;
        car.rating = vehicle.Rating__c;
        car.ratingLabel = vehicle.Rating__c == null ? '' : 'Rated ' + vehicle.Rating__c.setScale(1) + ' / 5';
        car.imageUrl = vehicle.Image_URL__c;
        car.tagline = vehicle.Tagline__c;
        car.bookMessage = 'Book the ' + vehicle.Name +
            (String.isBlank(vehicle.Location__c) ? '' : ' at ' + vehicle.Location__c);
        return car;
    }

    private static String formatDailyRate(Decimal rate) {
        if (rate == null) {
            return '';
        }
        Decimal rounded = rate.setScale(2, System.RoundingMode.HALF_UP);
        Decimal whole = rounded.setScale(0, System.RoundingMode.DOWN);
        Integer cents = ((rounded - whole) * 100).intValue();
        // Decimal.format() drops trailing zeros, so cents are appended explicitly.
        String amount = whole.format() + (cents == 0 ? '' : '.' + String.valueOf(cents).leftPad(2, '0'));
        return CURRENCY_SYMBOL + amount + ' / day';
    }

    private static String escapeLike(String value) {
        return value.replace('\\', '\\\\').replace('%', '\\%').replace('_', '\\_');
    }

    // ─── DTOs ────────────────────────────────────────────────────────────

    /**
     * @description Optional search filters supplied by the agent or MCP client.
     */
    global class Request {
        @InvocableVariable(
            label='Location'
            description='Optional pickup location. Valid values: Hyderabad Airport, Bengaluru Airport, San Francisco Airport. A city name such as Hyderabad also matches. Leave empty to search every location.'
            required=false
        )
        global String location;

        @InvocableVariable(
            label='Category'
            description='Optional car category. Valid values: Flagship, Electric, SUV, Sedan, Luxury, Sport, Economy. Leave empty for all categories.'
            required=false
        )
        global String category;

        @InvocableVariable(
            label='Max Daily Rate'
            description='Optional maximum price per day in USD. Only cars at or below this daily rate are returned.'
            required=false
        )
        global Decimal maxDailyRate;
    }

    /**
     * @description Action output. fleetResponse is rendered by the roadsterFleet HXL widget.
     */
    global class Response {
        @InvocableVariable(
            label='Fleet Response'
            description='Available Roadster Rentals cars: a headline, an optional featured hero car and the list of other cars.'
        )
        global FleetResult fleetResponse;
    }

    /**
     * @description Widget payload: headline, featured hero car and the remaining cars.
     */
    global class FleetResult {
        @AuraEnabled
        @InvocableVariable(label='Headline' description='Summary line, for example 6 cars available at Hyderabad Airport.')
        global String headline;

        @AuraEnabled
        @InvocableVariable(label='Location Label' description='Location the results refer to.')
        global String locationLabel;

        @AuraEnabled
        @InvocableVariable(label='Total Count' description='Number of available cars returned, including the featured car.')
        global Integer totalCount;

        @AuraEnabled
        @InvocableVariable(label='Has Featured' description='True when a featured flagship car is included.')
        global Boolean hasFeatured;

        @AuraEnabled
        @InvocableVariable(label='Is Empty' description='True when no cars match the search.')
        global Boolean isEmpty;

        @AuraEnabled
        @InvocableVariable(label='Featured Car' description='The featured flagship car shown as the hero card.')
        global Car featuredCar;

        @AuraEnabled
        @InvocableVariable(label='Featured Cars' description='The featured flagship car as a one-item list (empty when none). Rendered as the hero card.')
        global List<Car> featuredCars;

        @AuraEnabled
        @InvocableVariable(label='Cars' description='Available cars other than the featured car.')
        global List<Car> cars;
    }

    /**
     * @description One rental car, with display-ready labels.
     */
    global class Car {
        @AuraEnabled
        @InvocableVariable(label='Vehicle Id' description='Salesforce record Id of the vehicle.')
        global String vehicleId;

        @AuraEnabled
        @InvocableVariable(label='Name' description='Vehicle display name.')
        global String name;

        @AuraEnabled
        @InvocableVariable(label='Category' description='Fleet category.')
        global String category;

        @AuraEnabled
        @InvocableVariable(label='Daily Rate Label' description='Formatted price, for example $89 / day.')
        global String dailyRateLabel;

        @AuraEnabled
        @InvocableVariable(label='Daily Rate' description='Price per day in USD.')
        global Decimal dailyRate;

        @AuraEnabled
        @InvocableVariable(label='Seats Label' description='Seat count, for example 5 seats.')
        global String seatsLabel;

        @AuraEnabled
        @InvocableVariable(label='Transmission' description='Automatic or Manual.')
        global String transmission;

        @AuraEnabled
        @InvocableVariable(label='Fuel Type' description='Electric, Petrol, Diesel or Hybrid.')
        global String fuelType;

        @AuraEnabled
        @InvocableVariable(label='Range Label' description='Range per charge or tank, for example 510 km range.')
        global String rangeLabel;

        @AuraEnabled
        @InvocableVariable(label='Location' description='Pickup location.')
        global String location;

        @AuraEnabled
        @InvocableVariable(label='Rating' description='Customer rating out of 5.')
        global Decimal rating;

        @AuraEnabled
        @InvocableVariable(label='Rating Label' description='Formatted rating, for example Rated 4.8 / 5.')
        global String ratingLabel;

        @AuraEnabled
        @InvocableVariable(label='Image URL' description='Public image URL of the car.')
        global String imageUrl;

        @AuraEnabled
        @InvocableVariable(label='Tagline' description='Short marketing line.')
        global String tagline;

        @AuraEnabled
        @InvocableVariable(label='Book Message' description='Follow-up message sent to the agent when the user clicks Book.')
        global String bookMessage;
    }

    /**
     * @description Raised when the fleet query fails, for example missing access.
     */
    global class FleetQueryException extends Exception {}
}