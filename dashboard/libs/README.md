# External Libraries

This directory contains external JavaScript libraries that are self-hosted to improve performance and reduce external dependencies.

## ApexCharts

ApexCharts is used for rendering charts and data visualizations in the dashboard.

### Current Setup

- **Loader**: `apexcharts/loader.js`
- **Strategy**: CDN fallback (tries local first, falls back to CDN)
- **Status**: ✅ Configured with automatic fallback

### Installation (Optional - for full self-hosting)

To fully self-host ApexCharts without CDN fallback:

1. Download ApexCharts distribution:
```bash
npm install apexcharts
cp node_modules/apexcharts/dist/apexcharts.min.js libs/apexcharts/
cp node_modules/apexcharts/dist/apexcharts.min.js.map libs/apexcharts/
```

2. The loader will automatically use the local version if available.

## html2canvas

html2canvas is used for exporting dashboard views as PNG images.

### Current Setup

- **Loader**: `html2canvas/loader.js`
- **Strategy**: Lazy loading (loads only on export action)
- **Status**: ✅ Configured for on-demand loading
- **Benefit**: Reduces initial page load time (~200KB savings)

### How It Works

1. html2canvas is NOT loaded on page load
2. When user clicks "Export" button, the loader fetches from CDN
3. Export completes, file is downloaded
4. Library remains in memory for subsequent exports (no re-download)

## Performance Benefits

1. **Initial Load**: Removed 400KB+ of external dependencies from page load
2. **Lazy Loading**: html2canvas only loads when needed (saves ~200KB for users who don't export)
3. **Local Fallback**: ApexCharts can be served locally to avoid CDN latency

## Monitoring

Check browser console for loader messages:
- ✅ `ApexCharts loaded from local` - Local version is being used
- ✅ `ApexCharts loaded from CDN` - CDN version is being used
- ✅ `html2canvas loaded for export` - Export library loaded successfully

## Troubleshooting

If charts aren't rendering:
1. Check browser console for errors
2. Verify CDN is accessible: `https://cdn.jsdelivr.net/npm/apexcharts@latest`
3. Check Network tab for failed requests

If export fails:
1. Check console for html2canvas loading errors
2. Verify browser has sufficient memory
3. Try exporting a smaller view
