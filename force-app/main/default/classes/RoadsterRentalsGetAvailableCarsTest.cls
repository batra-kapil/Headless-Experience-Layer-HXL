/**
 * @description Tests for RoadsterRentalsGetAvailableCars. Runs the action as a Standard User
 *              holding Roadster_Rentals_Access, so WITH USER_MODE is exercised for real.
 */
@isTest
private class RoadsterRentalsGetAvailableCarsTest {

    private static final Integer AVAILABLE_FLEET_SIZE = 7;
    private static final String FEATURED_CAR = 'Tesla Roadster';
    private static final String UNAVAILABLE_CAR = 'Maruti Suzuki Swift';

    @TestSetup
    static void setupTestData() {
        // Setup objects (User, PermissionSetAssignment) go in their own runAs block to avoid MIXED_DML_OPERATION.
        System.runAs(new User(Id = UserInfo.getUserId())) {
            TestDataFactory.createFleetReader(true);
        }
        TestDataFactory.createRoadsterFleet(true);
    }

    // ─── Helpers ──────────────────────────────────────────────────────────

    private static User reader() {
        return [SELECT Id FROM User WHERE LastName = 'Fleet Reader' AND Email = 'fleet.reader@roadster-rentals.test' LIMIT 1];
    }

    private static RoadsterRentalsGetAvailableCars.Request request(String location, String category, Decimal maxDailyRate) {
        RoadsterRentalsGetAvailableCars.Request req = new RoadsterRentalsGetAvailableCars.Request();
        req.location = location;
        req.category = category;
        req.maxDailyRate = maxDailyRate;
        return req;
    }

    private static RoadsterRentalsGetAvailableCars.FleetResult run(RoadsterRentalsGetAvailableCars.Request req) {
        List<RoadsterRentalsGetAvailableCars.Response> responses;
        System.runAs(reader()) {
            Test.startTest();
            responses = RoadsterRentalsGetAvailableCars.getAvailableCars(
                new List<RoadsterRentalsGetAvailableCars.Request>{ req }
            );
            Test.stopTest();
        }
        Assert.areEqual(1, responses.size(), 'One response per request');
        return responses[0].fleetResponse;
    }

    private static Set<String> names(List<RoadsterRentalsGetAvailableCars.Car> cars) {
        Set<String> result = new Set<String>();
        for (RoadsterRentalsGetAvailableCars.Car car : cars) {
            result.add(car.name);
        }
        return result;
    }

    // ─── Tests ────────────────────────────────────────────────────────────

    @isTest
    static void shouldReturnWholeAvailableFleet_WhenNoFilters() {
        RoadsterRentalsGetAvailableCars.FleetResult result = run(request(null, null, null));

        Assert.areEqual(AVAILABLE_FLEET_SIZE, result.totalCount, 'All available cars counted');
        Assert.areEqual(AVAILABLE_FLEET_SIZE - 1, result.cars.size(), 'Featured car is not in the list');
        Assert.isTrue(result.hasFeatured, 'Roadster is featured');
        Assert.areEqual(FEATURED_CAR, result.featuredCar.name, 'Roadster is the hero');
        Assert.isFalse(result.isEmpty, 'Results exist, so isEmpty is false');
        Assert.areEqual('Rated 5.0 / 5', result.featuredCar.ratingLabel, 'Featured rating label');
        Assert.areEqual('7 cars available at all Roadster Rentals locations', result.headline, 'Headline');
        Assert.areEqual('Honda City', result.cars[0].name, 'Cheapest non-featured car first');
    }

    private static void assertRoadsterIsOnlyHero(RoadsterRentalsGetAvailableCars.FleetResult result) {
        Assert.areEqual(1, result.featuredCars.size(), 'Exactly one hero car');
        Assert.areEqual(FEATURED_CAR, result.featuredCars[0].name, 'Tesla Roadster is the first and only hero');
        Assert.isFalse(names(result.cars).contains(FEATURED_CAR), 'Hero car never appears in cars');
        for (Integer i = 1; i < result.cars.size(); i++) {
            Assert.isTrue(result.cars[i - 1].dailyRate <= result.cars[i].dailyRate, 'cars sorted by daily rate ascending');
        }
    }

    @isTest
    static void shouldReturnRoadsterAsHero_WhenNoFilters() {
        assertRoadsterIsOnlyHero(run(request(null, null, null)));
    }

    @isTest
    static void shouldReturnRoadsterAsHero_WhenHyderabadAirport() {
        assertRoadsterIsOnlyHero(run(request('Hyderabad Airport', null, null)));
    }

    @isTest
    static void shouldFormatCarLabels_WhenCarReturned() {
        RoadsterRentalsGetAvailableCars.FleetResult result = run(request(null, 'Electric', null));

        RoadsterRentalsGetAvailableCars.Car car = result.cars[0];
        Assert.areEqual('Tesla Model 3', car.name, 'Model 3 returned');
        Assert.areEqual('$89 / day', car.dailyRateLabel, 'Rate label');
        Assert.areEqual(89, car.dailyRate, 'Raw rate');
        Assert.areEqual('5 seats', car.seatsLabel, 'Seats label');
        Assert.areEqual('510 km range', car.rangeLabel, 'Range label');
        Assert.areEqual('Automatic', car.transmission, 'Transmission');
        Assert.areEqual('Electric', car.fuelType, 'Fuel');
        Assert.areEqual(4.8, car.rating, 'Rating');
        Assert.areEqual('Rated 4.8 / 5', car.ratingLabel, 'Rating label');
        Assert.areEqual('Book the Tesla Model 3 at Hyderabad Airport', car.bookMessage, 'Book message');
        Assert.isTrue(car.imageUrl.endsWith('/tesla-model-3.jpg'), 'Image URL from record');
        Assert.isNotNull(car.vehicleId, 'Vehicle Id set');
    }

    @isTest
    static void shouldReturnBengaluruCarsWithoutFeatured_WhenLocationFilter() {
        RoadsterRentalsGetAvailableCars.FleetResult result = run(request('Bengaluru Airport', null, null));

        Assert.areEqual(2, result.totalCount, 'Two cars at Bengaluru');
        Assert.isFalse(result.hasFeatured, 'No featured car at Bengaluru');
        Assert.isNull(result.featuredCar, 'No hero car');
        Assert.areEqual(new Set<String>{ 'Honda City', 'BMW 5 Series' }, names(result.cars), 'Bengaluru fleet');
        Assert.areEqual('2 cars available at Bengaluru Airport', result.headline, 'Headline');
    }

    @isTest
    static void shouldMatchCityName_WhenPartialLocation() {
        RoadsterRentalsGetAvailableCars.FleetResult result = run(request('hyderabad', null, null));

        Assert.areEqual(4, result.totalCount, 'Four available cars at Hyderabad');
        Assert.areEqual(FEATURED_CAR, result.featuredCar.name, 'Roadster featured at Hyderabad');
        Assert.areEqual('Hyderabad Airport', result.locationLabel, 'Label uses picklist value');
        Assert.areEqual('4 cars available at Hyderabad Airport', result.headline, 'Headline');
    }

    @isTest
    static void shouldReturnOnlySuvs_WhenCategoryFilter() {
        RoadsterRentalsGetAvailableCars.FleetResult result = run(request(null, 'SUV', null));

        Assert.areEqual(2, result.totalCount, 'Two SUVs');
        Assert.isFalse(result.hasFeatured, 'No featured SUV');
        Assert.areEqual('Mahindra XUV700', result.cars[0].name, 'Cheaper SUV first');
        Assert.areEqual('Toyota RAV4', result.cars[1].name, 'Pricier SUV second');
    }

    @isTest
    static void shouldReturnCarsAtOrBelowRate_WhenMaxDailyRateFilter() {
        RoadsterRentalsGetAvailableCars.FleetResult result = run(request(null, null, 60));

        Assert.areEqual(2, result.totalCount, 'Two cars at or below 60 per day');
        Assert.areEqual(new Set<String>{ 'Honda City', 'Mahindra XUV700' }, names(result.cars), 'Cheap cars');
        Assert.isFalse(names(result.cars).contains(UNAVAILABLE_CAR), 'Unavailable Swift excluded even though it is cheapest');
    }

    @isTest
    static void shouldExcludeUnavailableCar_WhenOnlyMatchIsUnavailable() {
        RoadsterRentalsGetAvailableCars.FleetResult result = run(request(null, 'Economy', null));

        Assert.areEqual(0, result.totalCount, 'Swift is the only Economy car and is unavailable');
        Assert.isTrue(result.cars.isEmpty(), 'No cars listed');
    }

    @isTest
    static void shouldReturnEmptyResult_WhenNothingMatches() {
        RoadsterRentalsGetAvailableCars.FleetResult result = run(request('San Francisco Airport', null, 50));

        Assert.areEqual(0, result.totalCount, 'No cars match');
        Assert.isTrue(result.isEmpty, 'Empty search sets isEmpty');
        Assert.isTrue(result.featuredCars.isEmpty(), 'No hero list, empty not null');
        Assert.isFalse(result.hasFeatured, 'No featured car');
        Assert.isNull(result.featuredCar, 'No hero car');
        Assert.isTrue(result.cars.isEmpty(), 'Empty list, not null');
        Assert.areEqual('No cars available at San Francisco Airport for this search', result.headline, 'Empty headline');
    }

    @isTest
    static void shouldFormatFractionalRate_WhenRateHasCents() {
        TestDataFactory.createRentalVehicle('Test Cents Car', 49.5, true);

        RoadsterRentalsGetAvailableCars.FleetResult result = run(request(null, 'Economy', null));

        Assert.areEqual(1, result.totalCount, 'Only the new Economy car');
        Assert.areEqual('$49.50 / day', result.cars[0].dailyRateLabel, 'Two decimals when rate has cents');
        Assert.areEqual('1 car available at San Francisco Airport', result.headline, 'Singular headline');
    }

    @isTest
    static void shouldAnswerEachRequest_WhenBulkRequestsDiffer() {
        List<RoadsterRentalsGetAvailableCars.Request> requests = new List<RoadsterRentalsGetAvailableCars.Request>{
            request('Bengaluru Airport', null, null),
            request(null, 'SUV', null),
            request(null, null, null),
            null
        };
        List<RoadsterRentalsGetAvailableCars.Response> responses;

        System.runAs(reader()) {
            Test.startTest();
            responses = RoadsterRentalsGetAvailableCars.getAvailableCars(requests);
            Assert.areEqual(1, Limits.getQueries(), 'One SOQL query for the whole bulk call');
            Test.stopTest();
        }

        Assert.areEqual(4, responses.size(), 'One response per request');
        Assert.areEqual(2, responses[0].fleetResponse.totalCount, 'Bengaluru request');
        Assert.areEqual(2, responses[1].fleetResponse.totalCount, 'SUV request');
        Assert.areEqual(AVAILABLE_FLEET_SIZE, responses[2].fleetResponse.totalCount, 'Unfiltered request');
        Assert.areEqual(AVAILABLE_FLEET_SIZE, responses[3].fleetResponse.totalCount, 'Null request treated as no filters');
    }

    @isTest
    static void shouldReturnEmptyList_WhenNoRequests() {
        System.runAs(reader()) {
            Test.startTest();
            Assert.isTrue(RoadsterRentalsGetAvailableCars.getAvailableCars(null).isEmpty(), 'Null input');
            Assert.isTrue(
                RoadsterRentalsGetAvailableCars.getAvailableCars(new List<RoadsterRentalsGetAvailableCars.Request>()).isEmpty(),
                'Empty input'
            );
            Test.stopTest();
        }
    }
}
