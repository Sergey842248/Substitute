/**
 * Vercel Web Analytics Integration
 * 
 * This module initializes Vercel Web Analytics for the Substitute web app.
 * 
 * Note: For plain HTML sites, the analytics scripts are loaded via CDN in the HTML head.
 * For applications using a build system or framework, the @vercel/analytics package
 * can be used with the inject() function instead.
 * 
 * CDN Script Tags (in index.html):
 * - https://cdn.vercel-analytics.com/v1/web
 * - https://cdn.vercel-analytics.com/v1/speed-insights
 */

/**
 * Initialize Vercel Analytics
 * This function can be used if switching to a package-based approach with bundlers
 */
async function initializeAnalytics() {
    try {
        // For package-based integration:
        // import { inject } from '@vercel/analytics';
        // inject();
        
        // For CDN-based integration (current approach):
        // The scripts are loaded via defer in the HTML <head>
        // They automatically initialize when the page loads
        
        console.log('Analytics initialized');
    } catch (error) {
        console.error('Failed to initialize analytics:', error);
    }
}

/**
 * Log custom events to Vercel Analytics
 * @param {string} name - Event name
 * @param {object} data - Event data
 */
function trackEvent(name, data = {}) {
    try {
        if (window.va) {
            // Track event using Vercel Analytics
            window.va.track(name, data);
        } else {
            console.warn('Vercel Analytics not yet initialized');
        }
    } catch (error) {
        console.error('Failed to track event:', error);
    }
}

// Initialize analytics when the page loads
document.addEventListener('DOMContentLoaded', initializeAnalytics);

// Track navigation events
document.addEventListener('click', function(event) {
    const target = event.target.closest('[data-track]');
    if (target) {
        trackEvent(target.dataset.track, {
            element: target.tagName,
            text: target.textContent
        });
    }
});
