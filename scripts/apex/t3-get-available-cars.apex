// T3: call the invocable action with no filters, then with location Bengaluru Airport.
RoadsterRentalsGetAvailableCars.Request noFilters = new RoadsterRentalsGetAvailableCars.Request();
RoadsterRentalsGetAvailableCars.Request bengaluru = new RoadsterRentalsGetAvailableCars.Request();
bengaluru.location = 'Bengaluru Airport';
List<RoadsterRentalsGetAvailableCars.Response> responses = RoadsterRentalsGetAvailableCars.getAvailableCars(
    new List<RoadsterRentalsGetAvailableCars.Request>{ noFilters }
);
System.debug('T3_NO_FILTERS=' + JSON.serialize(responses[0]));
responses = RoadsterRentalsGetAvailableCars.getAvailableCars(
    new List<RoadsterRentalsGetAvailableCars.Request>{ bengaluru }
);
System.debug('T3_BENGALURU=' + JSON.serialize(responses[0]));
