<?php

// --- Configuration ---
// !! IMPORTANT: In a real application, move these to a separate config file outside the web root !!
$dbHost = 'localhost';
$dbport = 3307; // Usually localhost for XAMPP
$dbName = 'weather_db';
$dbUser = 'root';      // Default XAMPP username
$dbPass = '';          // Default XAMPP password (often empty)

// --- Headers ---
header('Content-Type: application/json'); // Tell the browser we're sending JSON
header('Access-Control-Allow-Origin: *'); // Allow requests from any origin (for development). Restrict this in production.

// --- Database Connection ---
$dsn = "mysql:host=$dbHost;dbname=$dbName;port=$dbport;charset=utf8mb4";
$options = [
    PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION, // Throw exceptions on errors
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,       // Fetch associative arrays
    PDO::ATTR_EMULATE_PREPARES   => false,                  // Use native prepared statements
];

$pdo = null; // Initialize $pdo to null
try {
    $pdo = new PDO($dsn, $dbUser, $dbPass, $options);
} catch (PDOException $e) {
    // Database connection failed
    http_response_code(500); // Internal Server Error
    echo json_encode(['error' => 'Database connection failed. Please check server configuration.']);
    // In production, log the detailed error $e->getMessage() instead of showing it.
    error_log("Database Connection Error: " . $e->getMessage());
    exit; // Stop script execution
}

// --- Input Handling ---
$locationName = isset($_GET['location']) ? trim($_GET['location']) : '';

if (empty($locationName)) {
    http_response_code(400); // Bad Request
    echo json_encode(['error' => 'Location parameter is missing or empty.']);
    exit;
}

// --- Prepare Response Structure ---
$responseData = [
    'location' => null,
    'current'  => null,
    'hourly'   => [],
    'daily'    => [],
    'error'    => null // Add error key for consistency
];

// --- Main Logic ---
try {
    // 1. Find the Location ID and Details
    // Consider searching case-insensitively or adding country for uniqueness if needed
    $sqlLocation = "SELECT location_id, city_name, state_province, country_code, latitude, longitude, timezone
                    FROM locations
                    WHERE city_name = :locationName
                    LIMIT 1";

    $stmtLocation = $pdo->prepare($sqlLocation);
    $stmtLocation->execute([':locationName' => $locationName]);
    $locationData = $stmtLocation->fetch();

    if (!$locationData) {
        http_response_code(404); // Not Found
        $responseData['error'] = "Location '$locationName' not found in the database.";
        echo json_encode($responseData);
        exit;
    }

    $locationId = $locationData['location_id'];
    // Populate location details - Cast coordinates to float
    $responseData['location'] = [
        'id' => (int)$locationData['location_id'],
        'name' => $locationData['city_name'],
        'state' => $locationData['state_province'],
        'country' => $locationData['country_code'],
        'lat' => isset($locationData['latitude']) ? (float)$locationData['latitude'] : null,
        'lon' => isset($locationData['longitude']) ? (float)$locationData['longitude'] : null,
        'timezone' => $locationData['timezone']
    ];


    // 2. Fetch Current Weather (most recently retrieved 'current' type)
    // Select all relevant columns you might need
    $sqlCurrent = "SELECT *, forecast_datetime AS lastUpdated_utc
                   FROM forecasts
                   WHERE location_id = :locationId AND forecast_type = 'current'
                   ORDER BY data_retrieved_at DESC
                   LIMIT 1";
    $stmtCurrent = $pdo->prepare($sqlCurrent);
    $stmtCurrent->execute([':locationId' => $locationId]);
    $currentWeather = $stmtCurrent->fetch();

    if ($currentWeather) {
         // Map DB columns to the structure expected by JavaScript, casting numeric types
        $responseData['current'] = [
            'lastUpdated' => $currentWeather['data_retrieved_at'], // When we fetched it
            'forecastTimeUtc' => $currentWeather['lastUpdated_utc'], // When the forecast is valid for
            'temp' => isset($currentWeather['temperature']) ? (float)$currentWeather['temperature'] : null,
            'feelsLike' => isset($currentWeather['feels_like_temp']) ? (float)$currentWeather['feels_like_temp'] : null,
            'tempMin' => isset($currentWeather['temp_min']) ? (float)$currentWeather['temp_min'] : null, // Often null for current
            'tempMax' => isset($currentWeather['temp_max']) ? (float)$currentWeather['temp_max'] : null, // Often null for current
            'pressure' => isset($currentWeather['pressure_mb']) ? (int)$currentWeather['pressure_mb'] : null,
            'humidity' => isset($currentWeather['humidity_percent']) ? (int)$currentWeather['humidity_percent'] : null,
            'windSpeed' => isset($currentWeather['wind_speed']) ? (float)$currentWeather['wind_speed'] : null,
            'windDirection' => isset($currentWeather['wind_direction_deg']) ? (int)$currentWeather['wind_direction_deg'] : null,
            'windGust' => isset($currentWeather['wind_gust']) ? (float)$currentWeather['wind_gust'] : null,
            'cloudCover' => isset($currentWeather['cloud_cover_percent']) ? (int)$currentWeather['cloud_cover_percent'] : null,
            'precipitation' => isset($currentWeather['precipitation_mm']) ? (float)$currentWeather['precipitation_mm'] : null,
            'snow' => isset($currentWeather['snow_mm']) ? (float)$currentWeather['snow_mm'] : null,
            'uvIndex' => isset($currentWeather['uv_index']) ? (float)$currentWeather['uv_index'] : null,
            'visibility' => isset($currentWeather['visibility_meters']) ? (int)$currentWeather['visibility_meters'] : null,
            // String fields
            'description' => $currentWeather['weather_description'],
            'main' => $currentWeather['weather_main'],
            'icon' => $currentWeather['weather_icon_code'],
        ];
    }


    // 3. Fetch Hourly Forecast (e.g., next 24 hours from now)
    // Select all relevant columns you might need for hourly display
    $sqlHourly = "SELECT forecast_datetime AS time_utc, temperature, feels_like_temp, humidity_percent,
                         wind_speed, wind_gust, precipitation_probability, cloud_cover_percent,
                         weather_description, weather_icon_code
                  FROM forecasts
                  WHERE location_id = :locationId
                    AND forecast_type = 'hourly'
                    AND forecast_datetime >= UTC_TIMESTAMP() -- Use UTC_TIMESTAMP if forecast_datetime is UTC
                    AND forecast_datetime < DATE_ADD(UTC_TIMESTAMP(), INTERVAL 24 HOUR)
                  ORDER BY forecast_datetime ASC";
    $stmtHourly = $pdo->prepare($sqlHourly);
    $stmtHourly->execute([':locationId' => $locationId]);
    $hourlyForecasts = $stmtHourly->fetchAll();

    foreach ($hourlyForecasts as $hour) {
        $responseData['hourly'][] = [
             'time' => $hour['time_utc'], // JS expects 'time'
             // Cast numeric types
             'temp' => isset($hour['temperature']) ? (float)$hour['temperature'] : null,
             'feelsLike' => isset($hour['feels_like_temp']) ? (float)$hour['feels_like_temp'] : null,
             'humidity' => isset($hour['humidity_percent']) ? (int)$hour['humidity_percent'] : null,
             'windSpeed' => isset($hour['wind_speed']) ? (float)$hour['wind_speed'] : null,
             'windGust' => isset($hour['wind_gust']) ? (float)$hour['wind_gust'] : null,
             'precipProb' => isset($hour['precipitation_probability']) ? (float)$hour['precipitation_probability'] : null, // JS expects 'precipProb'
             'cloudCover' => isset($hour['cloud_cover_percent']) ? (int)$hour['cloud_cover_percent'] : null,
             // String types
             'description' => $hour['weather_description'],
             'icon' => $hour['weather_icon_code'],
        ];
    }

    // 4. Fetch Daily Forecast (e.g., next 7 days including today)
    // Select all relevant columns you might need for daily display
    // Using UTC_DATE() if forecast_datetime is stored as UTC midnight for the day
    $sqlDaily = "SELECT forecast_datetime AS date_utc, temp_min, temp_max, pressure_mb, humidity_percent,
                        wind_speed, precipitation_probability, uv_index,
                        weather_description, weather_icon_code
                 FROM forecasts
                 WHERE location_id = :locationId
                   AND forecast_type = 'daily'
                   AND forecast_datetime >= CURDATE() -- Assuming daily forecasts align with local date start
                   AND forecast_datetime < DATE_ADD(CURDATE(), INTERVAL 7 DAY)
                 ORDER BY forecast_datetime ASC";
    $stmtDaily = $pdo->prepare($sqlDaily);
    $stmtDaily->execute([':locationId' => $locationId]);
    $dailyForecasts = $stmtDaily->fetchAll();

     foreach ($dailyForecasts as $day) {
        $responseData['daily'][] = [
             'date' => $day['date_utc'], // JS expects 'date'
             // Cast numeric types
             'tempMax' => isset($day['temp_max']) ? (float)$day['temp_max'] : null, // JS expects 'tempMax'
             'tempMin' => isset($day['temp_min']) ? (float)$day['temp_min'] : null, // JS expects 'tempMin'
             'pressure' => isset($day['pressure_mb']) ? (int)$day['pressure_mb'] : null,
             'humidity' => isset($day['humidity_percent']) ? (int)$day['humidity_percent'] : null,
             'windSpeed' => isset($day['wind_speed']) ? (float)$day['wind_speed'] : null,
             'precipProb' => isset($day['precipitation_probability']) ? (float)$day['precipitation_probability'] : null,
             'uvIndex' => isset($day['uv_index']) ? (float)$day['uv_index'] : null,
             // String types
             'description' => $day['weather_description'],
             'icon' => $day['weather_icon_code'],
        ];
    }

    // If we reached here without errors, send 200 OK
    http_response_code(200);
    echo json_encode($responseData);


} catch (PDOException $e) {
    // Handle potential errors during query execution
    http_response_code(500); // Internal Server Error
    // Log the detailed error for debugging
    error_log("Database Query Error in weather.php: " . $e->getMessage());
    // Send a generic error to the client
    $responseData['error'] = 'An error occurred while fetching weather data from the database.';
    $responseData['location'] = null; // Ensure data fields are null on error
    $responseData['current'] = null;
    $responseData['hourly'] = [];
    $responseData['daily'] = [];
    echo json_encode($responseData);
    exit;
} catch (Exception $e) {
    // Catch any other unexpected errors
    http_response_code(500);
    error_log("General Error in weather.php: " . $e->getMessage());
    $responseData['error'] = 'An unexpected server error occurred.';
    $responseData['location'] = null;
    $responseData['current'] = null;
    $responseData['hourly'] = [];
    $responseData['daily'] = [];
    echo json_encode($responseData);
    exit;
}

?>