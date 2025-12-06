# Vercel Web Analytics Setup

This document describes the Vercel Web Analytics integration in the Substitute web application.

## Overview

Vercel Web Analytics is configured to track user interactions and performance metrics for the Substitute web app. The integration uses a **CDN-based approach** optimized for plain HTML sites.

## Implementation Details

### Current Setup

The Substitute web app uses Vercel Analytics via CDN script tags in `index.html`:

```html
<!-- Vercel Web Analytics - CDN-based integration for plain HTML sites -->
<script defer src="https://cdn.vercel-analytics.com/v1/web"></script>
<!-- Vercel Speed Insights for performance monitoring -->
<script defer src="https://cdn.vercel-analytics.com/v1/speed-insights"></script>
```

### Features

1. **Web Analytics**: Automatically tracks page views, user interactions, and navigation events
2. **Speed Insights**: Monitors Core Web Vitals and performance metrics
3. **Zero Configuration**: The scripts automatically initialize on page load
4. **Client-Side Only**: No server-side setup required for plain HTML sites

## Files

- **index.html** - Main HTML file with Vercel Analytics scripts integrated
- **analytics.js** - Analytics module with helper functions for custom event tracking
- **package.json** - Package configuration including @vercel/analytics dependency

## Usage

### Automatic Tracking

The analytics scripts automatically track:
- Page views
- User interactions
- Navigation events
- Core Web Vitals

No additional setup is required for automatic tracking.

### Custom Event Tracking

To track custom events, use the `trackEvent()` function in `analytics.js`:

```javascript
trackEvent('button_click', {
    element: 'button',
    text: 'Load Classes'
});
```

To use this with HTML elements, add the `data-track` attribute:

```html
<button data-track="load_classes">Load Classes</button>
```

## Package-Based Integration (Optional)

For applications using a build system or framework, you can use the package-based approach:

### Installation

```bash
npm install @vercel/analytics
```

### Usage

In your application entry point (e.g., `script.js`):

```javascript
import { inject } from '@vercel/analytics';
inject();
```

**Note**: The `inject()` function must run on the client side and does not include route support for plain HTML sites.

## Framework-Specific Integration

For different frameworks, refer to Vercel's documentation:

- **Next.js**: Built-in support, install and import in app layout
- **React**: Install package and use in app root component
- **Vue**: Import and call `inject()` in app setup
- **Svelte**: Import and call `inject()` in main.js
- **Astro**: Use integration package for seamless setup

See [Vercel Analytics Documentation](https://vercel.com/docs/analytics) for framework-specific patterns.

## Configuration

No additional configuration is required for the CDN-based setup. The analytics automatically send data to Vercel.

If you need to configure analytics settings, see the [Vercel Analytics Documentation](https://vercel.com/docs/analytics/quickstart).

## Data Privacy

Vercel Web Analytics follows privacy-first principles:
- No personal data is collected by default
- Core Web Vitals are tracked anonymously
- User interactions are tracked without storing personal information

For more information on privacy, see [Vercel's Privacy Policy](https://vercel.com/legal/privacy-policy).

## Monitoring

View your analytics data in the Vercel Dashboard:
1. Go to https://vercel.com/dashboard
2. Select your project
3. Navigate to Analytics tab

You'll see:
- Real-time page views
- User interactions
- Performance metrics (Core Web Vitals)
- Traffic sources

## Troubleshooting

### Analytics Not Appearing

1. Check that you're accessing the site over HTTPS (required for analytics)
2. Verify the scripts are loaded in the browser DevTools Network tab
3. Check for JavaScript errors in the browser console
4. Allow a few minutes for data to appear in the Vercel Dashboard

### Slow Page Load

If the analytics scripts are causing performance issues:
1. The `defer` attribute ensures scripts load asynchronously
2. Speed Insights measures actual performance impact
3. Consider using a Content Delivery Network (CDN) for faster script delivery

## References

- [Vercel Web Analytics Documentation](https://vercel.com/docs/analytics)
- [Vercel Speed Insights](https://vercel.com/docs/speed-insights)
- [@vercel/analytics npm Package](https://www.npmjs.com/package/@vercel/analytics)
