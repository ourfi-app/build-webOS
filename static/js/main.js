// webOS Build Dashboard - Main JavaScript

console.log('webOS Build Dashboard loaded');

// Utility function for API calls
async function apiCall(endpoint) {
    try {
        const response = await fetch(endpoint);
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        return await response.json();
    } catch (error) {
        console.error(`Error calling ${endpoint}:`, error);
        throw error;
    }
}

// Format bytes to human-readable size
function formatBytes(bytes, decimals = 2) {
    if (bytes === 0) return '0 Bytes';

    const k = 1024;
    const dm = decimals < 0 ? 0 : decimals;
    const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];

    const i = Math.floor(Math.log(bytes) / Math.log(k));

    return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
}

// Format date to locale string
function formatDate(dateString) {
    const date = new Date(dateString);
    return date.toLocaleString();
}

// Show loading state
function showLoading(elementId, message = 'Loading...') {
    const element = document.getElementById(elementId);
    if (element) {
        element.innerHTML = `<p class="loading">${message}</p>`;
    }
}

// Show error state
function showError(elementId, message) {
    const element = document.getElementById(elementId);
    if (element) {
        element.innerHTML = `<div class="error"><p>${message}</p></div>`;
    }
}

// Health check
async function checkHealth() {
    try {
        const data = await apiCall('/health');
        console.log('Health check:', data);
    } catch (error) {
        console.error('Health check failed:', error);
    }
}

// Run health check on page load
document.addEventListener('DOMContentLoaded', () => {
    checkHealth();
});

// Auto-refresh functionality
class AutoRefresh {
    constructor(callback, interval = 10000) {
        this.callback = callback;
        this.interval = interval;
        this.timerId = null;
    }

    start() {
        this.stop();
        this.callback();
        this.timerId = setInterval(this.callback, this.interval);
    }

    stop() {
        if (this.timerId) {
            clearInterval(this.timerId);
            this.timerId = null;
        }
    }
}

// Export utilities for use in other scripts
window.dashboardUtils = {
    apiCall,
    formatBytes,
    formatDate,
    showLoading,
    showError,
    AutoRefresh
};
