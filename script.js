document.addEventListener('DOMContentLoaded', () => {
    // --- DOM Element References ---
    const locationInput = document.getElementById('locationInput');
    const getWeatherBtn = document.getElementById('getWeatherBtn');
    const weatherContainer = document.getElementById('weather-container');
    const loadingIndicator = document.getElementById('loading');
console.log('Loading Indicator Element on Load:', loadingIndicator); // <-- ADD THIS LINE
    const errorMessage = document.getElementById('error-message');

    // Current Weather UI Elements
    const currentLocationSpan = document.getElementById('current-location');
    const currentIcon = document.getElementById('current-icon');
    const currentTempSpan = document.getElementById('current-temp');
    const currentDescSpan = document.getElementById('current-desc');
    const currentFeelsLikeSpan = document.getElementById('current-feels-like');
    const currentHumiditySpan = document.getElementById('current-humidity');
    const currentWindSpan = document.getElementById('current-wind');
    const currentPressureSpan = document.getElementById('current-pressure');
    const lastUpdatedSpan = document.getElementById('last-updated-time');

    // Forecast List UI Elements
    const hourlyListDiv = document.getElementById('hourly-list');
    const dailyListDiv = document.getElementById('daily-list');

    // --- Event Listeners ---
    getWeatherBtn.addEventListener('click', handleGetWeather);
    locationInput.addEventListener('keypress', (event) => {
        if (event.key === 'Enter') {
            handleGetWeather();
        }
    });

    // --- Core Functions ---

    /**
     * Handles the button click or Enter key press to fetch weather.
     */
    function handleGetWeather() {
        const location = locationInput.value.trim();
        if (!location) {
            showError('Please enter a location.');
            return;
        }
        fetchWeatherData(location);
    }

    /**
     * Fetches weather data from the backend API.
     * @param {string} location - The city name entered by the user.
     */
    async function fetchWeatherData(location) {
        showLoading();
        // Construct the URL to your PHP backend script
        // Make sure '/weatherapp/' matches the folder structure in your htdocs
        const apiUrl = `/weatherapp/api/weather.php?location=${encodeURIComponent(location)}`;

        try {
            // Make the API request using fetch
            const response = await fetch(apiUrl);

            // Check for HTTP errors (e.g., 404 Not Found, 500 Internal Server Error)
            if (!response.ok) {
                let errorMsg = `Error: ${response.status} ${response.statusText}`;
                // Try to get a more specific error message from the backend JSON response
                try {
                    const errorData = await response.json();
                    if (errorData && errorData.error) {
                        errorMsg = errorData.error; // Use backend's specific error message
                    }
                } catch (e) {
                    // Ignore if the error response wasn't valid JSON
                    console.debug("Could not parse error response JSON:", e);
                }
                throw new Error(errorMsg); // Throw an error to be caught by the catch block
            }

            // Parse the successful JSON response
            const data = await response.json();

            // Check for application-level errors potentially returned in a 200 OK response
            if (data.error) {
                throw new Error(data.error);
            }

            // Optional: Check if essential data parts are missing
            if (!data.location || !data.current ) {
                 console.warn("Received data might be incomplete from backend:", data);
                 // Depending on requirements, you might want to throw an error here
                 // or just proceed cautiously.
            }

            updateUI(data); // Update the UI with the fetched data
            showWeatherData(); // Make the weather sections visible

        } catch (error) {
            // Catch any errors from fetch, HTTP status, JSON parsing, or application logic
            console.error("Error fetching or processing weather data:", error);
            // Display the specific error message caught
            showError(`Failed to retrieve weather: ${error.message}`);
        }
    }

    /**
     * Updates the HTML elements with the weather data received from the backend.
     * @param {object} data - The weather data object from the backend.
     */
    function updateUI(data) {
        // --- Update Current Weather ---
        currentLocationSpan.textContent = data.location?.name || 'N/A'; // Use optional chaining for safety
        currentIcon.src = getWeatherIconUrl(data.current?.icon);
        currentIcon.alt = data.current?.description || 'Weather icon';
        currentTempSpan.textContent = formatTemperature(data.current?.temp);
        currentDescSpan.textContent = data.current?.description || 'N/A';
        currentFeelsLikeSpan.textContent = formatTemperature(data.current?.feelsLike);
        currentHumiditySpan.textContent = formatPercentage(data.current?.humidity);
        currentWindSpan.textContent = formatWind(data.current?.windSpeed, data.current?.windDirection);
        currentPressureSpan.textContent = formatPressure(data.current?.pressure);
        lastUpdatedSpan.textContent = data.current?.lastUpdated ? new Date(data.current.lastUpdated).toLocaleString() : 'N/A';

        // --- Update Hourly Forecast ---
        hourlyListDiv.innerHTML = ''; // Clear previous items
        if (data.hourly && data.hourly.length > 0) {
            // Limit to a reasonable number, e.g., 24 hours
            data.hourly.slice(0, 24).forEach(hour => {
                const item = document.createElement('div');
                item.classList.add('hourly-item');
                item.innerHTML = `
                    <div>${formatTime(hour.time)}</div>
                    <img src="${getWeatherIconUrl(hour.icon)}" alt="${hour.description || ''}" width="30" height="30" title="${hour.description || ''}">
                    <div>${formatTemperature(hour.temp)}</div>
                    <div style="font-size: 0.8em; color: #007bff;">${formatPercentage(hour.precipProb * 100, 0)}</div> <!-- Show precip probability -->
                `;
                hourlyListDiv.appendChild(item);
            });
        } else {
            hourlyListDiv.innerHTML = '<div class="placeholder">Hourly data not available.</div>';
        }

        // --- Update Daily Forecast ---
        dailyListDiv.innerHTML = ''; // Clear previous items
        if (data.daily && data.daily.length > 0) {
             // Limit to a reasonable number, e.g., 7 days
            data.daily.slice(0, 7).forEach(day => {
                const item = document.createElement('div');
                item.classList.add('daily-item');
                item.innerHTML = `
                    <div>${formatDay(day.date)}</div>
                    <img src="${getWeatherIconUrl(day.icon)}" alt="${day.description || ''}" width="30" height="30" title="${day.description || ''}">
                    <div>H: ${formatTemperature(day.tempMax, 0)} L: ${formatTemperature(day.tempMin, 0)}</div>
                    <div style="font-size: 0.8em; color: #555;">${day.description || ''}</div>
                `;
                dailyListDiv.appendChild(item);
            });
        } else {
            dailyListDiv.innerHTML = '<div class="placeholder">Daily data not available.</div>';
        }
    }


    // --- UI State Functions ---

    /** Displays the loading indicator and hides data/errors. */
    function showLoading() {
        console.log('Inside showLoading, weatherContainer is:', weatherContainer);
        console.log('Inside showLoading, errorMessage is:', errorMessage);
        console.log('Inside showLoading, loadingIndicator is:', loadingIndicator);
        weatherContainer.classList.add('hidden');
        errorMessage.classList.add('hidden');
        loadingIndicator.classList.remove('hidden');
    }

    /** Hides the loading indicator. */
    function hideLoading() {
        loadingIndicator.classList.add('hidden');
    }

    /**
     * Displays an error message.
     * @param {string} message - The error message text.
     */
    function showError(message) {
        hideLoading();
        errorMessage.textContent = message;
        errorMessage.classList.remove('hidden');
        weatherContainer.classList.add('hidden'); // Keep weather sections hidden on error
    }

    /** Displays the weather data sections and hides errors/loading. */
    function showWeatherData() {
        hideLoading();
        errorMessage.classList.add('hidden');
        weatherContainer.classList.remove('hidden');
    }


    // --- Helper & Formatting Functions ---

    /**
     * Constructs the URL for a weather icon (adjust based on your icon source).
     * @param {string|null} iconCode - The icon code from the weather data (e.g., '01d').
     * @returns {string} - The full URL or path to the icon image.
     */
    function getWeatherIconUrl(iconCode) {
        if (iconCode) {
            // Example using OpenWeatherMap icon URLs
            return `https://openweathermap.org/img/wn/${iconCode}@2x.png`;
        }
        // Return a path to a local placeholder or default icon
        return 'placeholder.png';
    }

    /**
     * Formats a date string into a short time (e.g., "14:00").
     * Handles potential invalid date strings.
     * @param {string|null} dateString - ISO date string (UTC expected from backend).
     * @returns {string} - Formatted time or 'N/A'.
     */
    function formatTime(dateString) {
        if (!dateString) return '--:--';
        try {
            const date = new Date(dateString);
            // Check if the date is valid after parsing
            if (isNaN(date.getTime())) return '--:--';
            return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', hour12: false });
        } catch (e) {
            console.error("Error formatting time:", dateString, e);
            return '--:--';
        }
    }

    /**
     * Formats a date string into a short weekday (e.g., "Mon").
     * Handles potential invalid date strings.
     * @param {string|null} dateString - ISO date string.
     * @returns {string} - Formatted day or 'N/A'.
     */
    function formatDay(dateString) {
        if (!dateString) return '---';
         try {
            const date = new Date(dateString);
             if (isNaN(date.getTime())) return '---';
            return date.toLocaleDateString([], { weekday: 'short' });
        } catch (e) {
            console.error("Error formatting day:", dateString, e);
            return '---';
        }
    }

    /**
     * Formats a temperature value.
     * @param {number|null} temp - Temperature value.
     * @param {number} precision - Number of decimal places (default 0).
     * @returns {string} - Formatted temperature string (e.g., "15°C") or "--°C".
     */
    function formatTemperature(temp, precision = 0) {
         if (temp === null || temp === undefined || isNaN(temp)) return '--°C';
         return `${temp.toFixed(precision)}°C`;
    }

     /**
     * Formats a humidity or probability value as a percentage.
     * @param {number|null} value - The value (0-100 expected for humidity, 0-1 for probability if needs *100).
     * @param {number} precision - Number of decimal places (default 0).
     * @returns {string} - Formatted percentage string (e.g., "75%") or "--%".
     */
    function formatPercentage(value, precision = 0) {
        if (value === null || value === undefined || isNaN(value)) return '--%';
        // Assume value is already 0-100 if used for humidity, or needs scaling if from probability (0-1)
        // The updateUI function already handles scaling for precipProb
        return `${value.toFixed(precision)}%`;
    }

     /**
     * Formats wind speed and direction.
     * @param {number|null} speed - Wind speed (e.g., m/s).
     * @param {number|null} direction - Wind direction in degrees (0-360).
     * @returns {string} - Formatted wind string (e.g., "5.1 m/s W") or "N/A".
     */
    function formatWind(speed, direction) {
        if (speed === null || speed === undefined || isNaN(speed)) return 'N/A';
        let speedStr = `${speed.toFixed(1)} m/s`; // Adjust units/precision as needed
        // Add direction if available
        // You could implement a function degreesToCardinal(direction) here
        // if (direction !== null && direction !== undefined && !isNaN(direction)) {
        //    speedStr += ` ${degreesToCardinal(direction)}`;
        // }
        return speedStr;
    }

     /**
     * Formats atmospheric pressure.
     * @param {number|null} pressure - Pressure value (e.g., hPa/mb).
     * @returns {string} - Formatted pressure string (e.g., "1012 hPa") or "---- hPa".
     */
    function formatPressure(pressure) {
        if (pressure === null || pressure === undefined || isNaN(pressure)) return '---- hPa';
        return `${pressure} hPa`;
    }

    // --- DUMMY DATA FUNCTION REMOVED ---
    // The getDummyWeatherData function has been removed as we now fetch from the backend.

}); // End DOMContentLoaded