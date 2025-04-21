CREATE DATABASE weather_db;
CREATE TABLE locations (
    location_id INT AUTO_INCREMENT PRIMARY KEY,
    city_name VARCHAR(100) NOT NULL,
    state_province VARCHAR(100),          -- Optional, depends on country structure
    country_code CHAR(2) NOT NULL,        -- ISO 3166-1 alpha-2 (e.g., 'US', 'CA', 'GB')
    latitude DECIMAL(10, 8) NOT NULL,     -- Sufficient precision for most apps
    longitude DECIMAL(11, 8) NOT NULL,    -- Sufficient precision for most apps
    timezone VARCHAR(50) NOT NULL,        -- e.g., 'America/New_York', 'Europe/London', 'UTC'
    zip_postal_code VARCHAR(20),          -- Optional
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    -- Make sure a location (lat/lon) is unique, or perhaps city/state/country
    -- A UNIQUE constraint on lat/lon is often good enough practically
    UNIQUE KEY unique_lat_lon (latitude, longitude),
    -- Index for faster lookups by name
    INDEX idx_city_country (city_name, country_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE data_sources (
    source_id INT AUTO_INCREMENT PRIMARY KEY,
    source_name VARCHAR(100) NOT NULL UNIQUE, -- e.g., 'OpenWeatherMap API', 'Local Station Alpha'
    website_url VARCHAR(255),                 -- Optional URL for the source
    api_details TEXT                          -- Optional JSON or text field for notes, not API keys!
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE forecasts (
    forecast_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    location_id INT NOT NULL,
    source_id INT,                          -- Nullable if data_sources table is optional or source unknown

    forecast_datetime DATETIME NOT NULL,    -- The specific date & time this forecast applies TO (in UTC or the location's timezone - be consistent! UTC is recommended)
    data_retrieved_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- When this specific record was fetched/inserted

    forecast_type ENUM('current', 'hourly', 'daily') NOT NULL DEFAULT 'hourly', -- Type of forecast record

    temperature DECIMAL(5, 2),              -- e.g., in Celsius. Be consistent!
    feels_like_temp DECIMAL(5, 2),          -- Apparent temperature (Celsius)
    temp_min DECIMAL(5, 2),                 -- Min temp for the period (esp. for daily forecasts)
    temp_max DECIMAL(5, 2),                 -- Max temp for the period (esp. for daily forecasts)
    pressure_mb INT,                        -- Atmospheric pressure in millibars (hPa)
    humidity_percent TINYINT UNSIGNED,      -- Humidity percentage (0-100)
    wind_speed DECIMAL(5, 2),               -- e.g., in meters/sec or km/h. Be consistent!
    wind_direction_deg SMALLINT,            -- Wind direction in degrees (0-360)
    wind_gust DECIMAL(5, 2),                -- Optional: Wind gust speed
    cloud_cover_percent TINYINT UNSIGNED,   -- Cloud cover percentage (0-100)
    precipitation_mm DECIMAL(6, 2),         -- Precipitation volume (e.g., last hour or day)
    precipitation_probability DECIMAL(3, 2),-- Probability of precipitation (0.00 to 1.00)
    snow_mm DECIMAL(6, 2),                  -- Snow volume (if applicable)
    uv_index DECIMAL(4, 2),                 -- UV index
    visibility_meters INT,                  -- Visibility in meters
    weather_main VARCHAR(50),               -- Short description (e.g., 'Clouds', 'Rain', 'Clear')
    weather_description VARCHAR(150),       -- More detailed description (e.g., 'broken clouds', 'light rain')
    weather_icon_code VARCHAR(10),          -- Code for displaying weather icons (e.g., '01d', '10n')

    -- Foreign Key constraints
    FOREIGN KEY (location_id) REFERENCES locations(location_id) ON DELETE CASCADE ON UPDATE CASCADE,
    -- Make the FK to data_sources nullable if the table is optional or source might be unknown
    FOREIGN KEY (source_id) REFERENCES data_sources(source_id) ON DELETE SET NULL ON UPDATE CASCADE, -- Use SET NULL or RESTRICT depending on requirements

    -- Index for efficient querying by location and time
    INDEX idx_location_datetime (location_id, forecast_datetime),
    -- Index for efficient querying by type
    INDEX idx_forecast_type (forecast_type)

) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Select the database first (optional if already selected in phpMyAdmin)
USE weather_db;

-- ----------------------------
-- 1. Insert Location: London
-- ----------------------------
INSERT INTO locations (city_name, state_province, country_code, latitude, longitude, timezone, zip_postal_code)
VALUES ('London', 'England', 'GB', 51.507351, -0.127758, 'Europe/London', 'SW1A');

-- After running this, check the generated `location_id` for London. Let's assume it's 1 for the next steps.

-- ----------------------------
-- 2. Insert Data Source (Optional but recommended)
-- ----------------------------
INSERT INTO data_sources (source_name, website_url)
VALUES ('Test Data Provider', 'http://example.com/testdata');

-- After running this, check the generated `source_id`. Let's assume it's 1 for the next steps.


-- ----------------------------
-- 3. Insert Forecast Data for London (using assumed location_id=1, source_id=1)
--    !! ADJUST location_id and source_id if they are different in your DB !!
-- ----------------------------

-- CURRENT Forecast (One entry)
INSERT INTO forecasts (
    location_id, source_id, forecast_datetime, forecast_type,
    temperature, feels_like_temp, pressure_mb, humidity_percent, wind_speed,
    wind_direction_deg, cloud_cover_percent, visibility_meters, weather_main,
    weather_description, weather_icon_code
) VALUES (
    1, 1, UTC_TIMESTAMP(), 'current', -- Use current UTC time for forecast validity
    14.5, 13.8, 1012, 82, 5.1, 245, 90, 8000, 'Clouds',
    'Overcast clouds', '04d'
);


-- HOURLY Forecasts (Multiple entries for the next few hours)
INSERT INTO forecasts (
    location_id, source_id, forecast_datetime, forecast_type,
    temperature, feels_like_temp, humidity_percent, wind_speed, wind_gust,
    precipitation_probability, cloud_cover_percent, weather_main, weather_description, weather_icon_code
) VALUES
-- Hour +1 from now (UTC)
(1, 1, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 1 HOUR), 'hourly',
 14.8, 14.1, 80, 5.3, 8.0, 0.1, 85, 'Clouds', 'Broken clouds', '04d'),
-- Hour +2 from now (UTC)
(1, 1, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 2 HOUR), 'hourly',
 15.1, 14.5, 78, 5.5, 8.5, 0.15, 75, 'Clouds', 'Scattered clouds', '03d'),
-- Hour +3 from now (UTC)
(1, 1, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 3 HOUR), 'hourly',
 15.0, 14.4, 79, 5.4, 8.2, 0.25, 95, 'Rain', 'Light rain', '10d'),
 -- Hour +4 from now (UTC)
(1, 1, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 4 HOUR), 'hourly',
 14.7, 14.0, 81, 5.2, NULL, 0.2, 100, 'Rain', 'Light rain', '10d');


-- DAILY Forecasts (Multiple entries for the next few days)
-- Note: We set forecast_datetime to midnight UTC for the respective day.
INSERT INTO forecasts (
    location_id, source_id, forecast_datetime, forecast_type,
    temp_min, temp_max, pressure_mb, humidity_percent, wind_speed,
    precipitation_probability, uv_index, weather_main, weather_description, weather_icon_code
) VALUES
-- Today (Midnight UTC)
(1, 1, CONCAT(CURDATE(), ' 00:00:00'), 'daily',
 10.5, 16.2, 1013, 75, 6.0, 0.4, 4.5, 'Rain', 'Moderate rain showers', '09d'),
-- Tomorrow (Midnight UTC)
(1, 1, CONCAT(DATE_ADD(CURDATE(), INTERVAL 1 DAY), ' 00:00:00'), 'daily',
 9.8, 15.5, 1015, 72, 5.0, 0.2, 5.0, 'Clouds', 'Broken clouds', '04d'),
-- Day After Tomorrow (Midnight UTC)
(1, 1, CONCAT(DATE_ADD(CURDATE(), INTERVAL 2 DAY), ' 00:00:00'), 'daily',
 11.0, 17.0, 1016, 68, 4.5, 0.1, 6.0, 'Clear', 'Clear sky', '01d'),
-- Day After That (Midnight UTC)
 (1, 1, CONCAT(DATE_ADD(CURDATE(), INTERVAL 3 DAY), ' 00:00:00'), 'daily',
 11.5, 17.5, 1014, 70, 4.8, 0.15, 5.5, 'Clouds', 'Few clouds', '02d');

 -- Make sure you're using the correct database
USE weather_db;

-- ----------------------------
-- 1. Insert Location: New York
-- ----------------------------
INSERT INTO locations (city_name, state_province, country_code, latitude, longitude, timezone, zip_postal_code)
VALUES ('New York', 'NY', 'US', 40.7128, -74.0060, 'America/New_York', '10001');

-- =========================================================================
-- !! IMPORTANT !! Check the `locations` table now. Note the `location_id`
--                assigned to 'New York'. We assume it is 2 for the inserts
--                below. Change 'location_id = 2' if it's different!
--                We assume `source_id = 1` from the previous insert.
-- =========================================================================


-- -----------------------------------------------------
-- 2. Insert Forecast Data for New York (location_id=2)
-- -----------------------------------------------------

-- CURRENT Forecast (One entry for New York)
INSERT INTO forecasts (
    location_id, source_id, forecast_datetime, forecast_type,
    temperature, feels_like_temp, pressure_mb, humidity_percent, wind_speed,
    wind_direction_deg, cloud_cover_percent, visibility_meters, weather_main,
    weather_description, weather_icon_code
) VALUES (
    2, 1, UTC_TIMESTAMP(), 'current', -- Use current UTC time for forecast validity
    18.2, 17.9, 1015, 65, 3.5, 180, 40, 10000, 'Clouds',
    'Scattered clouds', '03d'
);


-- HOURLY Forecasts (Multiple entries for New York for the next few hours)
INSERT INTO forecasts (
    location_id, source_id, forecast_datetime, forecast_type,
    temperature, feels_like_temp, humidity_percent, wind_speed, wind_gust,
    precipitation_probability, cloud_cover_percent, weather_main, weather_description, weather_icon_code
) VALUES
-- Hour +1 from now (UTC)
(2, 1, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 1 HOUR), 'hourly',
 18.5, 18.2, 63, 3.8, 6.0, 0.05, 30, 'Clouds', 'Few clouds', '02d'),
-- Hour +2 from now (UTC)
(2, 1, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 2 HOUR), 'hourly',
 19.0, 18.8, 60, 4.0, 6.5, 0.0, 20, 'Clear', 'Clear sky', '01d'),
-- Hour +3 from now (UTC)
(2, 1, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 3 HOUR), 'hourly',
 18.8, 18.5, 62, 3.9, 6.2, 0.0, 25, 'Clear', 'Clear sky', '01d'),
 -- Hour +4 from now (UTC)
(2, 1, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 4 HOUR), 'hourly',
 18.4, 18.1, 64, 3.7, NULL, 0.1, 50, 'Clouds', 'Scattered clouds', '03d'),
 -- Hour +5 from now (UTC)
(2, 1, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 5 HOUR), 'hourly',
 18.0, 17.7, 66, 3.5, 5.5, 0.15, 60, 'Clouds', 'Broken clouds', '04d'),
 -- Hour +6 from now (UTC)
(2, 1, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 6 HOUR), 'hourly',
 17.5, 17.2, 68, 3.3, NULL, 0.2, 75, 'Rain', 'Light rain', '10d');


-- DAILY Forecasts (Multiple entries for New York for the next few days)
-- Note: We set forecast_datetime to midnight UTC for the respective day.
INSERT INTO forecasts (
    location_id, source_id, forecast_datetime, forecast_type,
    temp_min, temp_max, pressure_mb, humidity_percent, wind_speed,
    precipitation_probability, uv_index, weather_main, weather_description, weather_icon_code
) VALUES
-- Today (Midnight UTC)
(2, 1, CONCAT(CURDATE(), ' 00:00:00'), 'daily',
 14.5, 21.8, 1016, 68, 4.2, 0.1, 7.0, 'Clear', 'Sunny', '01d'),
-- Tomorrow (Midnight UTC)
(2, 1, CONCAT(DATE_ADD(CURDATE(), INTERVAL 1 DAY), ' 00:00:00'), 'daily',
 15.0, 22.5, 1014, 70, 5.1, 0.3, 6.5, 'Clouds', 'Partly cloudy', '02d'),
-- Day After Tomorrow (Midnight UTC)
(2, 1, CONCAT(DATE_ADD(CURDATE(), INTERVAL 2 DAY), ' 00:00:00'), 'daily',
 16.2, 20.5, 1012, 80, 6.5, 0.6, 4.0, 'Rain', 'Showers', '09d'),
-- Day After That (Midnight UTC)
 (2, 1, CONCAT(DATE_ADD(CURDATE(), INTERVAL 3 DAY), ' 00:00:00'), 'daily',
 13.8, 19.0, 1015, 75, 5.5, 0.2, 5.0, 'Clouds', 'Cloudy', '04d'),
 -- +4 Days (Midnight UTC)
 (2, 1, CONCAT(DATE_ADD(CURDATE(), INTERVAL 4 DAY), ' 00:00:00'), 'daily',
 14.2, 20.0, 1017, 72, 4.8, 0.1, 5.8, 'Clouds', 'Mostly cloudy', '04d');

 -- Make sure you're using the correct database
USE weather_db;

-- --------------------------------------------------------------------------
-- Step 1: Insert 10 New Locations
-- --------------------------------------------------------------------------
INSERT INTO locations (city_name, state_province, country_code, latitude, longitude, timezone, zip_postal_code)
VALUES
('Tokyo', NULL, 'JP', 35.6895, 139.6917, 'Asia/Tokyo', '100-0000'),          -- Expected ID: 3
('Paris', 'Île-de-France', 'FR', 48.8566, 2.3522, 'Europe/Paris', '75000'),      -- Expected ID: 4
('Sydney', 'New South Wales', 'AU', -33.8688, 151.2093, 'Australia/Sydney', '2000'),-- Expected ID: 5
('Cairo', NULL, 'EG', 30.0444, 31.2357, 'Africa/Cairo', '11511'),          -- Expected ID: 6
('Rio de Janeiro', 'RJ', 'BR', -22.9068, -43.1729, 'America/Sao_Paulo', '20000-000'),-- Expected ID: 7
('Moscow', NULL, 'RU', 55.7558, 37.6173, 'Europe/Moscow', '101000'),         -- Expected ID: 8
('Mexico City', 'CDMX', 'MX', 19.4326, -99.1332, 'America/Mexico_City', '06000'),-- Expected ID: 9
('Berlin', NULL, 'DE', 52.5200, 13.4050, 'Europe/Berlin', '10115'),         -- Expected ID: 10
('Mumbai', 'Maharashtra', 'IN', 19.0760, 72.8777, 'Asia/Kolkata', '400001'),    -- Expected ID: 11
('Toronto', 'ON', 'CA', 43.6532, -79.3832, 'America/Toronto', 'M5H');      -- Expected ID: 12

-- =========================================================================
-- !! STOP AND VERIFY !!
-- Check the `locations` table NOW. Confirm the actual `location_id` for
-- Tokyo, Paris, Sydney, Cairo, Rio, Moscow, Mexico City, Berlin, Mumbai, Toronto.
-- Adjust the `location_id` values (3 to 12) in ALL the `forecasts`
-- INSERT statements below if they differ from the expected IDs.
-- We continue assuming IDs 3 through 12 are correct.
-- =========================================================================


-- --------------------------------------------------------------------------
-- Step 2: Insert Forecast Data (Current, Hourly, Daily for each new location)
-- Using assumed source_id = 1 and location_ids 3-12
-- --------------------------------------------------------------------------

-- ======= Tokyo (ID: 3) =======
INSERT INTO forecasts (location_id, source_id, forecast_datetime, forecast_type, temperature, feels_like_temp, pressure_mb, humidity_percent, wind_speed, wind_direction_deg, cloud_cover_percent, visibility_meters, weather_main, weather_description, weather_icon_code, temp_min, temp_max, precipitation_probability, uv_index, wind_gust, snow_mm)
VALUES
-- Current
(3, 1, UTC_TIMESTAMP(), 'current', 25.5, 26.1, 1008, 75, 4.1, 160, 80, 9000, 'Rain', 'Light rain shower', '09d', NULL, NULL, NULL, NULL, 6.0, NULL),
-- Hourly +1hr
(3, 1, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 1 HOUR), 'hourly', 25.2, 25.9, 1008, 78, 4.0, 165, 90, NULL, 'Rain', 'Light rain', '10d', NULL, NULL, 0.6, NULL, 5.8, NULL),
-- Hourly +2hr
(3, 1, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 2 HOUR), 'hourly', 24.9, 25.5, 1009, 80, 3.9, 170, 85, NULL, 'Rain', 'Light rain', '10d', NULL, NULL, 0.5, NULL, NULL, NULL),
-- Hourly +3hr
(3, 1, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 3 HOUR), 'hourly', 24.6, 25.1, 1009, 82, 3.8, 170, 70, NULL, 'Clouds', 'Broken clouds', '04d', NULL, NULL, 0.3, NULL, 5.5, NULL),
-- Daily Today
(3, 1, CONCAT(CURDATE(), ' 00:00:00'), 'daily', 22.1, 28.4, 1009, 72, 4.5, NULL, NULL, NULL, 'Rain', 'Scattered showers', '09d', NULL, NULL, 0.7, 6.0, NULL, NULL),
-- Daily Tomorrow
(3, 1, CONCAT(DATE_ADD(CURDATE(), INTERVAL 1 DAY), ' 00:00:00'), 'daily', 23.0, 29.5, 1010, 68, 4.0, NULL, NULL, NULL, 'Clouds', 'Partly cloudy', '03d', NULL, NULL, 0.2, 7.0, NULL, NULL),
-- Daily +2 Days
(3, 1, CONCAT(DATE_ADD(CURDATE(), INTERVAL 2 DAY), ' 00:00:00'), 'daily', 23.5, 30.1, 1011, 65, 3.8, NULL, NULL, NULL, 'Clear', 'Sunny', '01d', NULL, NULL, 0.1, 8.0, NULL, NULL);

-- ======= Paris (ID: 4) =======
INSERT INTO forecasts (location_id, source_id, forecast_datetime, forecast_type, temperature, feels_like_temp, pressure_mb, humidity_percent, wind_speed, wind_direction_deg, cloud_cover_percent, visibility_meters, weather_main, weather_description, weather_icon_code, temp_min, temp_max, precipitation_probability, uv_index, wind_gust, snow_mm)
VALUES
-- Current
(4, 1, UTC_TIMESTAMP(), 'current', 19.8, 19.5, 1014, 60, 3.1, 270, 30, 10000, 'Clouds', 'Few clouds', '02d', NULL, NULL, NULL, NULL, NULL, NULL),
-- Hourly +1hr
(4, 1, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 1 HOUR), 'hourly', 20.2, 19.9, 1014, 58, 3.3, 275, 25, NULL, 'Clear', 'Clear sky', '01d', NULL, NULL, 0.0, NULL, 5.0, NULL),
-- Hourly +2hr
(4, 1, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 2 HOUR), 'hourly', 20.5, 20.2, 1014, 55, 3.5, 280, 20, NULL, 'Clear', 'Clear sky', '01d', NULL, NULL, 0.0, NULL, 5.5, NULL),
-- Hourly +3hr
(4, 1, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 3 HOUR), 'hourly', 20.1, 19.8, 1015, 57, 3.4, 280, 40, NULL, 'Clouds', 'Scattered clouds', '03d', NULL, NULL, 0.05, NULL, NULL, NULL),
-- Daily Today
(4, 1, CONCAT(CURDATE(), ' 00:00:00'), 'daily', 15.1, 23.5, 1015, 62, 3.8, NULL, NULL, NULL, 'Clouds', 'Partly sunny', '02d', NULL, NULL, 0.1, 5.0, NULL, NULL),
-- Daily Tomorrow
(4, 1, CONCAT(DATE_ADD(CURDATE(), INTERVAL 1 DAY), ' 00:00:00'), 'daily', 16.0, 24.8, 1016, 58, 4.0, NULL, NULL, NULL, 'Clear', 'Sunny', '01d', NULL, NULL, 0.0, 6.0, NULL, NULL),
-- Daily +2 Days
(4, 1, CONCAT(DATE_ADD(CURDATE(), INTERVAL 2 DAY), ' 00:00:00'), 'daily', 15.5, 22.9, 1014, 65, 4.2, NULL, NULL, NULL, 'Rain', 'Chance of showers', '09d', NULL, NULL, 0.4, 4.0, NULL, NULL);

-- ======= Sydney (ID: 5) =======
INSERT INTO forecasts (location_id, source_id, forecast_datetime, forecast_type, temperature, feels_like_temp, pressure_mb, humidity_percent, wind_speed, wind_direction_deg, cloud_cover_percent, visibility_meters, weather_main, weather_description, weather_icon_code, temp_min, temp_max, precipitation_probability, uv_index, wind_gust, snow_mm)
VALUES
-- Current (Southern Hemisphere Winter/Cool)
(5, 1, UTC_TIMESTAMP(), 'current', 15.3, 14.8, 1022, 68, 5.5, 210, 60, 10000, 'Clouds', 'Broken clouds', '04d', NULL, NULL, NULL, NULL, 8.0, NULL),
-- Hourly +1hr
(5, 1, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 1 HOUR), 'hourly', 15.0, 14.5, 1022, 70, 5.7, 215, 70, NULL, 'Clouds', 'Broken clouds', '04d', NULL, NULL, 0.1, NULL, 8.5, NULL),
-- Hourly +2hr
(5, 1, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 2 HOUR), 'hourly', 14.7, 14.1, 1023, 72, 5.9, 220, 80, NULL, 'Rain', 'Light rain shower', '09d', NULL, NULL, 0.4, NULL, NULL, NULL),
-- Hourly +3hr
(5, 1, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 3 HOUR), 'hourly', 14.5, 13.9, 1023, 74, 6.0, 220, 75, NULL, 'Rain', 'Light rain shower', '09d', NULL, NULL, 0.5, NULL, 9.0, NULL),
-- Daily Today
(5, 1, CONCAT(CURDATE(), ' 00:00:00'), 'daily', 11.2, 17.8, 1023, 70, 6.2, NULL, NULL, NULL, 'Rain', 'Showers possible', '09d', NULL, NULL, 0.6, 3.0, NULL, NULL),
-- Daily Tomorrow
(5, 1, CONCAT(DATE_ADD(CURDATE(), INTERVAL 1 DAY), ' 00:00:00'), 'daily', 10.8, 18.5, 1024, 65, 5.0, NULL, NULL, NULL, 'Clouds', 'Partly cloudy', '03d', NULL, NULL, 0.2, 4.0, NULL, NULL),
-- Daily +2 Days
(5, 1, CONCAT(DATE_ADD(CURDATE(), INTERVAL 2 DAY), ' 00:00:00'), 'daily', 12.0, 19.1, 1022, 63, 4.5, NULL, NULL, NULL, 'Clear', 'Mostly sunny', '02d', NULL, NULL, 0.1, 4.0, NULL, NULL);

-- ======= Cairo (ID: 6) =======
INSERT INTO forecasts (location_id, source_id, forecast_datetime, forecast_type, temperature, feels_like_temp, pressure_mb, humidity_percent, wind_speed, wind_direction_deg, cloud_cover_percent, visibility_meters, weather_main, weather_description, weather_icon_code, temp_min, temp_max, precipitation_probability, uv_index, wind_gust, snow_mm)
VALUES
-- Current (Hot/Dry)
(6, 1, UTC_TIMESTAMP(), 'current', 34.5, 33.8, 1005, 25, 6.1, 340, 5, 10000, 'Clear', 'Clear sky', '01d', NULL, NULL, NULL, NULL, 9.0, NULL),
-- Hourly +1hr
(6, 1, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 1 HOUR), 'hourly', 35.1, 34.2, 1005, 23, 6.3, 345, 0, NULL, 'Clear', 'Clear sky', '01d', NULL, NULL, 0.0, NULL, 9.5, NULL),
-- Hourly +2hr
(6, 1, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 2 HOUR), 'hourly', 35.6, 34.6, 1004, 22, 6.5, 350, 0, NULL, 'Clear', 'Clear sky', '01d', NULL, NULL, 0.0, NULL, NULL, NULL),
-- Hourly +3hr
(6, 1, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 3 HOUR), 'hourly', 35.2, 34.3, 1004, 24, 6.4, 350, 5, NULL, 'Clear', 'Clear sky', '01d', NULL, NULL, 0.0, NULL, 9.2, NULL),
-- Daily Today
(6, 1, CONCAT(CURDATE(), ' 00:00:00'), 'daily', 25.8, 37.9, 1006, 30, 6.0, NULL, NULL, NULL, 'Clear', 'Sunny and hot', '01d', NULL, NULL, 0.0, 11.0, NULL, NULL),
-- Daily Tomorrow
(6, 1, CONCAT(DATE_ADD(CURDATE(), INTERVAL 1 DAY), ' 00:00:00'), 'daily', 26.1, 38.5, 1007, 28, 5.8, NULL, NULL, NULL, 'Clear', 'Very hot', '01d', NULL, NULL, 0.0, 11.0, NULL, NULL),
-- Daily +2 Days
(6, 1, CONCAT(DATE_ADD(CURDATE(), INTERVAL 2 DAY), ' 00:00:00'), 'daily', 26.5, 38.2, 1008, 32, 5.5, NULL, NULL, NULL, 'Clear', 'Sunny', '01d', NULL, NULL, 0.0, 10.5, NULL, NULL);

-- ======= Rio de Janeiro (ID: 7) =======
INSERT INTO forecasts (location_id, source_id, forecast_datetime, forecast_type, temperature, feels_like_temp, pressure_mb, humidity_percent, wind_speed, wind_direction_deg, cloud_cover_percent, visibility_meters, weather_main, weather_description, weather_icon_code, temp_min, temp_max, precipitation_probability, uv_index, wind_gust, snow_mm)
VALUES
-- Current (Tropical)
(7, 1, UTC_TIMESTAMP(), 'current', 28.3, 30.5, 1012, 80, 2.5, 120, 70, 8000, 'Clouds', 'Broken clouds', '04d', NULL, NULL, NULL, NULL, 4.0, NULL),
-- Hourly +1hr
(7, 1, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 1 HOUR), 'hourly', 28.0, 30.1, 1012, 82, 2.8, 125, 85, NULL, 'Rain', 'Light rain shower', '09d', NULL, NULL, 0.5, NULL, 4.5, NULL),
-- Hourly +2hr
(7, 1, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 2 HOUR), 'hourly', 27.7, 29.8, 1013, 84, 2.6, 130, 90, NULL, 'Rain', 'Light rain', '10d', NULL, NULL, 0.6, NULL, NULL, NULL),
-- Hourly +3hr
(7, 1, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 3 HOUR), 'hourly', 27.5, 29.5, 1013, 85, 2.4, 130, 80, NULL, 'Rain', 'Light rain shower', '09d', NULL, NULL, 0.4, NULL, 4.2, NULL),
-- Daily Today
(7, 1, CONCAT(CURDATE(), ' 00:00:00'), 'daily', 23.1, 29.9, 1013, 78, 3.0, NULL, NULL, NULL, 'Rain', 'Scattered showers', '09d', NULL, NULL, 0.7, 8.0, NULL, NULL),
-- Daily Tomorrow
(7, 1, CONCAT(DATE_ADD(CURDATE(), INTERVAL 1 DAY), ' 00:00:00'), 'daily', 23.5, 30.5, 1014, 75, 3.2, NULL, NULL, NULL, 'Clouds', 'Partly cloudy', '03d', NULL, NULL, 0.3, 9.0, NULL, NULL),
-- Daily +2 Days
(7, 1, CONCAT(DATE_ADD(CURDATE(), INTERVAL 2 DAY), ' 00:00:00'), 'daily', 24.0, 31.0, 1015, 72, 3.5, NULL, NULL, NULL, 'Clear', 'Mostly sunny', '02d', NULL, NULL, 0.1, 9.5, NULL, NULL);

-- ======= Moscow (ID: 8) =======
INSERT INTO forecasts (location_id, source_id, forecast_datetime, forecast_type, temperature, feels_like_temp, pressure_mb, humidity_percent, wind_speed, wind_direction_deg, cloud_cover_percent, visibility_meters, weather_main, weather_description, weather_icon_code, temp_min, temp_max, precipitation_probability, uv_index, wind_gust, snow_mm)
VALUES
-- Current (Cool/Variable)
(8, 1, UTC_TIMESTAMP(), 'current', 16.2, 15.8, 1010, 70, 4.8, 310, 90, 7000, 'Clouds', 'Overcast clouds', '04d', NULL, NULL, NULL, NULL, 7.0, NULL),
-- Hourly +1hr
(8, 1, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 1 HOUR), 'hourly', 15.9, 15.5, 1010, 72, 5.0, 315, 95, NULL, 'Rain', 'Light drizzle', '09d', NULL, NULL, 0.3, NULL, 7.5, NULL),
-- Hourly +2hr
(8, 1, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 2 HOUR), 'hourly', 15.6, 15.1, 1011, 75, 5.2, 315, 100, NULL, 'Rain', 'Drizzle', '09d', NULL, NULL, 0.4, NULL, NULL, NULL),
-- Hourly +3hr
(8, 1, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 3 HOUR), 'hourly', 15.4, 14.9, 1011, 78, 5.1, 320, 100, NULL, 'Rain', 'Drizzle', '09d', NULL, NULL, 0.4, NULL, 7.8, NULL),
-- Daily Today
(8, 1, CONCAT(CURDATE(), ' 00:00:00'), 'daily', 12.5, 18.1, 1011, 73, 5.5, NULL, NULL, NULL, 'Rain', 'Cloudy with drizzle', '09d', NULL, NULL, 0.5, 3.0, NULL, NULL),
-- Daily Tomorrow
(8, 1, CONCAT(DATE_ADD(CURDATE(), INTERVAL 1 DAY), ' 00:00:00'), 'daily', 13.0, 19.5, 1012, 68, 4.8, NULL, NULL, NULL, 'Clouds', 'Mostly cloudy', '04d', NULL, NULL, 0.2, 4.0, NULL, NULL),
-- Daily +2 Days
(8, 1, CONCAT(DATE_ADD(CURDATE(), INTERVAL 2 DAY), ' 00:00:00'), 'daily', 14.1, 21.0, 1013, 65, 4.5, NULL, NULL, NULL, 'Clouds', 'Partly cloudy', '03d', NULL, NULL, 0.1, 4.0, NULL, NULL);

-- ======= Mexico City (ID: 9) =======
INSERT INTO forecasts (location_id, source_id, forecast_datetime, forecast_type, temperature, feels_like_temp, pressure_mb, humidity_percent, wind_speed, wind_direction_deg, cloud_cover_percent, visibility_meters, weather_main, weather_description, weather_icon_code, temp_min, temp_max, precipitation_probability, uv_index, wind_gust, snow_mm)
VALUES
-- Current (Temperate, chance of rain)
(9, 1, UTC_TIMESTAMP(), 'current', 21.0, 21.0, 1018, 55, 2.1, 90, 60, 9000, 'Clouds', 'Broken clouds', '04d', NULL, NULL, NULL, NULL, NULL, NULL),
-- Hourly +1hr
(9, 1, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 1 HOUR), 'hourly', 20.5, 20.5, 1018, 60, 2.5, 95, 75, NULL, 'Rain', 'Light rain shower', '09d', NULL, NULL, 0.4, NULL, 4.0, NULL),
-- Hourly +2hr
(9, 1, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 2 HOUR), 'hourly', 20.0, 20.0, 1019, 65, 2.8, 100, 85, NULL, 'Rain', 'Moderate rain shower', '09d', NULL, NULL, 0.6, NULL, 4.5, NULL),
-- Hourly +3hr
(9, 1, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 3 HOUR), 'hourly', 19.5, 19.5, 1019, 70, 2.6, 100, 90, NULL, 'Rain', 'Moderate rain', '10d', NULL, NULL, 0.7, NULL, NULL, NULL),
-- Daily Today
(9, 1, CONCAT(CURDATE(), ' 00:00:00'), 'daily', 14.8, 23.2, 1019, 62, 3.0, NULL, NULL, NULL, 'Rain', 'Afternoon showers', '09d', NULL, NULL, 0.8, 9.0, NULL, NULL),
-- Daily Tomorrow
(9, 1, CONCAT(DATE_ADD(CURDATE(), INTERVAL 1 DAY), ' 00:00:00'), 'daily', 15.1, 24.0, 1020, 58, 2.8, NULL, NULL, NULL, 'Rain', 'Scattered showers', '09d', NULL, NULL, 0.6, 10.0, NULL, NULL),
-- Daily +2 Days
(9, 1, CONCAT(DATE_ADD(CURDATE(), INTERVAL 2 DAY), ' 00:00:00'), 'daily', 15.5, 24.5, 1021, 55, 2.5, NULL, NULL, NULL, 'Clouds', 'Partly cloudy', '03d', NULL, NULL, 0.3, 10.0, NULL, NULL);

-- ======= Berlin (ID: 10) =======
INSERT INTO forecasts (location_id, source_id, forecast_datetime, forecast_type, temperature, feels_like_temp, pressure_mb, humidity_percent, wind_speed, wind_direction_deg, cloud_cover_percent, visibility_meters, weather_main, weather_description, weather_icon_code, temp_min, temp_max, precipitation_probability, uv_index, wind_gust, snow_mm)
VALUES
-- Current
(10, 1, UTC_TIMESTAMP(), 'current', 18.9, 18.6, 1012, 66, 4.2, 280, 75, 10000, 'Clouds', 'Broken clouds', '04d', NULL, NULL, NULL, NULL, 6.5, NULL),
-- Hourly +1hr
(10, 1, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 1 HOUR), 'hourly', 18.5, 18.2, 1012, 68, 4.4, 285, 85, NULL, 'Clouds', 'Overcast clouds', '04d', NULL, NULL, 0.1, NULL, 6.8, NULL),
-- Hourly +2hr
(10, 1, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 2 HOUR), 'hourly', 18.1, 17.7, 1013, 70, 4.6, 285, 90, NULL, 'Rain', 'Light drizzle', '09d', NULL, NULL, 0.3, NULL, NULL, NULL),
-- Hourly +3hr
(10, 1, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 3 HOUR), 'hourly', 17.8, 17.4, 1013, 72, 4.5, 290, 95, NULL, 'Rain', 'Light drizzle', '09d', NULL, NULL, 0.4, NULL, 7.0, NULL),
-- Daily Today
(10, 1, CONCAT(CURDATE(), ' 00:00:00'), 'daily', 14.3, 21.5, 1013, 69, 4.8, NULL, NULL, NULL, 'Rain', 'Cloudy with possible drizzle', '09d', NULL, NULL, 0.5, 4.0, NULL, NULL),
-- Daily Tomorrow
(10, 1, CONCAT(DATE_ADD(CURDATE(), INTERVAL 1 DAY), ' 00:00:00'), 'daily', 15.0, 22.8, 1014, 65, 4.2, NULL, NULL, NULL, 'Clouds', 'Mostly cloudy', '04d', NULL, NULL, 0.2, 5.0, NULL, NULL),
-- Daily +2 Days
(10, 1, CONCAT(DATE_ADD(CURDATE(), INTERVAL 2 DAY), ' 00:00:00'), 'daily', 15.6, 24.1, 1015, 62, 4.0, NULL, NULL, NULL, 'Clouds', 'Partly cloudy', '03d', NULL, NULL, 0.1, 5.0, NULL, NULL);

-- ======= Mumbai (ID: 11) =======
INSERT INTO forecasts (location_id, source_id, forecast_datetime, forecast_type, temperature, feels_like_temp, pressure_mb, humidity_percent, wind_speed, wind_direction_deg, cloud_cover_percent, visibility_meters, weather_main, weather_description, weather_icon_code, temp_min, temp_max, precipitation_probability, uv_index, wind_gust, snow_mm)
VALUES
-- Current (Hot/Humid, Monsoon season often)
(11, 1, UTC_TIMESTAMP(), 'current', 29.5, 34.0, 1005, 85, 5.2, 240, 90, 5000, 'Rain', 'Moderate rain', '10d', NULL, NULL, NULL, NULL, 8.0, NULL),
-- Hourly +1hr
(11, 1, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 1 HOUR), 'hourly', 29.2, 33.5, 1005, 87, 5.5, 245, 95, NULL, 'Rain', 'Heavy intensity rain', '10d', NULL, NULL, 0.8, NULL, 8.5, NULL),
-- Hourly +2hr
(11, 1, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 2 HOUR), 'hourly', 28.9, 33.0, 1006, 88, 5.8, 245, 100, NULL, 'Rain', 'Heavy intensity rain', '10d', NULL, NULL, 0.9, NULL, NULL, NULL),
-- Hourly +3hr
(11, 1, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 3 HOUR), 'hourly', 28.6, 32.5, 1006, 90, 5.6, 250, 100, NULL, 'Rain', 'Moderate rain', '10d', NULL, NULL, 0.7, NULL, 8.8, NULL),
-- Daily Today
(11, 1, CONCAT(CURDATE(), ' 00:00:00'), 'daily', 27.1, 31.5, 1006, 86, 6.0, NULL, NULL, NULL, 'Rain', 'Heavy rain likely', '10d', NULL, NULL, 0.9, 5.0, NULL, NULL),
-- Daily Tomorrow
(11, 1, CONCAT(DATE_ADD(CURDATE(), INTERVAL 1 DAY), ' 00:00:00'), 'daily', 27.5, 31.8, 1007, 84, 5.5, NULL, NULL, NULL, 'Rain', 'Scattered thunderstorms', '11d', NULL, NULL, 0.8, 6.0, NULL, NULL),
-- Daily +2 Days
(11, 1, CONCAT(DATE_ADD(CURDATE(), INTERVAL 2 DAY), ' 00:00:00'), 'daily', 27.8, 32.0, 1008, 82, 5.0, NULL, NULL, NULL, 'Rain', 'Showers likely', '09d', NULL, NULL, 0.6, 6.0, NULL, NULL);

-- ======= Toronto (ID: 12) =======
INSERT INTO forecasts (location_id, source_id, forecast_datetime, forecast_type, temperature, feels_like_temp, pressure_mb, humidity_percent, wind_speed, wind_direction_deg, cloud_cover_percent, visibility_meters, weather_main, weather_description, weather_icon_code, temp_min, temp_max, precipitation_probability, uv_index, wind_gust, snow_mm)
VALUES
-- Current
(12, 1, UTC_TIMESTAMP(), 'current', 22.1, 22.1, 1011, 60, 4.5, 290, 40, 10000, 'Clouds', 'Scattered clouds', '03d', NULL, NULL, NULL, NULL, 7.0, NULL),
-- Hourly +1hr
(12, 1, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 1 HOUR), 'hourly', 22.5, 22.5, 1011, 58, 4.7, 295, 30, NULL, 'Clouds', 'Few clouds', '02d', NULL, NULL, 0.05, NULL, 7.2, NULL),
-- Hourly +2hr
(12, 1, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 2 HOUR), 'hourly', 22.8, 22.8, 1011, 56, 4.9, 295, 25, NULL, 'Clear', 'Clear sky', '01d', NULL, NULL, 0.0, NULL, NULL, NULL),
-- Hourly +3hr
(12, 1, DATE_ADD(UTC_TIMESTAMP(), INTERVAL 3 HOUR), 'hourly', 22.6, 22.6, 1012, 57, 4.8, 300, 35, NULL, 'Clouds', 'Few clouds', '02d', NULL, NULL, 0.0, NULL, 7.5, NULL),
-- Daily Today
(12, 1, CONCAT(CURDATE(), ' 00:00:00'), 'daily', 17.5, 25.3, 1012, 62, 5.0, NULL, NULL, NULL, 'Clouds', 'Partly cloudy', '03d', NULL, NULL, 0.1, 7.0, NULL, NULL),
-- Daily Tomorrow
(12, 1, CONCAT(DATE_ADD(CURDATE(), INTERVAL 1 DAY), ' 00:00:00'), 'daily', 18.1, 26.8, 1013, 59, 4.5, NULL, NULL, NULL, 'Clear', 'Sunny', '01d', NULL, NULL, 0.0, 8.0, NULL, NULL),
-- Daily +2 Days
(12, 1, CONCAT(DATE_ADD(CURDATE(), INTERVAL 2 DAY), ' 00:00:00'), 'daily', 19.0, 27.5, 1011, 65, 5.2, NULL, NULL, NULL, 'Rain', 'Chance of late showers', '09d', NULL, NULL, 0.4, 7.0, NULL, NULL);

