/**
 * @description Centralized factory for creating test data with sensible defaults.
 *              All methods accept a doInsert flag for flexibility.
 */
@isTest
public class TestDataFactory {

    private static final String TEST_IMAGE_BASE_URL = 'https://raw.githubusercontent.com/roadster-rentals/test/main/assets/cars/';

    // ─── Rental Vehicles ──────────────────────────────────────────────────

    /**
     * @description Builds the 8-car Roadster Rentals demo fleet (7 available, Swift unavailable,
     *              Tesla Roadster featured). Mirrors data/Rental_Vehicle__c.json.
     * @param doInsert When true, inserts the records in system mode (test setup only)
     * @return The vehicles
     */
    public static List<Rental_Vehicle__c> createRoadsterFleet(Boolean doInsert) {
        List<Rental_Vehicle__c> vehicles = new List<Rental_Vehicle__c>{
            vehicle('Tesla Roadster', 'Tesla', 'Roadster', 'Flagship', 1999, 4, 'Automatic', 'Electric', 1000, 'Hyderabad Airport', 5.0, true, true),
            vehicle('Tesla Model 3', 'Tesla', 'Model 3', 'Electric', 89, 5, 'Automatic', 'Electric', 510, 'Hyderabad Airport', 4.8, true, false),
            vehicle('Toyota RAV4', 'Toyota', 'RAV4', 'SUV', 65, 5, 'Automatic', 'Hybrid', 900, 'Hyderabad Airport', 4.6, true, false),
            vehicle('Mahindra XUV700', 'Mahindra', 'XUV700', 'SUV', 55, 7, 'Automatic', 'Diesel', 850, 'Hyderabad Airport', 4.5, true, false),
            vehicle('Honda City', 'Honda', 'City', 'Sedan', 35, 5, 'Manual', 'Petrol', 650, 'Bengaluru Airport', 4.4, true, false),
            vehicle('BMW 5 Series', 'BMW', '5 Series', 'Luxury', 149, 5, 'Automatic', 'Petrol', 700, 'Bengaluru Airport', 4.7, true, false),
            vehicle('Ford Mustang Convertible', 'Ford', 'Mustang Convertible', 'Sport', 129, 4, 'Automatic', 'Petrol', 550, 'San Francisco Airport', 4.7, true, false),
            vehicle('Maruti Suzuki Swift', 'Maruti Suzuki', 'Swift', 'Economy', 25, 5, 'Manual', 'Petrol', 600, 'Hyderabad Airport', 4.3, false, false)
        };
        if (doInsert) {
            insertSystemMode(vehicles);
        }
        return vehicles;
    }

    /**
     * @description Builds one available, non-featured vehicle with the given daily rate.
     */
    public static Rental_Vehicle__c createRentalVehicle(String name, Decimal dailyRate, Boolean doInsert) {
        Rental_Vehicle__c record = vehicle(name, 'Test', name, 'Economy', dailyRate, 5, 'Manual', 'Petrol', 500, 'San Francisco Airport', 4.0, true, false);
        if (doInsert) {
            insertSystemMode(new List<Rental_Vehicle__c>{ record });
        }
        return record;
    }

    // ─── Users ────────────────────────────────────────────────────────────

    /**
     * @description Creates a Standard User with the Roadster_Rentals_Access permission set,
     *              so tests exercise WITH USER_MODE the way a real agent user would.
     */
    public static User createFleetReader(Boolean doInsert) {
        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String unique = String.valueOf(Crypto.getRandomInteger()).replace('-', '');
        User reader = new User(
            Alias = 'rrread',
            Email = 'fleet.reader@roadster-rentals.test',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Fleet Reader',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = standardProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'fleet.reader.' + unique + '@roadster-rentals.test'
        );
        if (doInsert) {
            insert reader;
            PermissionSet access = [SELECT Id FROM PermissionSet WHERE Name = 'Roadster_Rentals_Access' LIMIT 1];
            insert new PermissionSetAssignment(AssigneeId = reader.Id, PermissionSetId = access.Id);
        }
        return reader;
    }

    // ─── Helpers ──────────────────────────────────────────────────────────

    private static Rental_Vehicle__c vehicle(
        String name, String make, String model, String category, Decimal dailyRate, Integer seats,
        String transmission, String fuelType, Integer rangeKm, String location, Decimal rating,
        Boolean isAvailable, Boolean isFeatured
    ) {
        return new Rental_Vehicle__c(
            Name = name,
            Make__c = make,
            Model__c = model,
            Category__c = category,
            Daily_Rate__c = dailyRate,
            Seats__c = seats,
            Transmission__c = transmission,
            Fuel_Type__c = fuelType,
            Range_Km__c = rangeKm,
            Location__c = location,
            Rating__c = rating,
            Image_URL__c = TEST_IMAGE_BASE_URL + name.toLowerCase().replace(' ', '-') + '.jpg',
            Tagline__c = 'Test tagline for ' + name,
            Is_Available__c = isAvailable,
            Is_Featured__c = isFeatured
        );
    }

    // Test setup data is inserted in system mode on purpose: the reader permission set is read-only.
    private static void insertSystemMode(List<Rental_Vehicle__c> records) {
        Database.insert(records, AccessLevel.SYSTEM_MODE);
    }
}
