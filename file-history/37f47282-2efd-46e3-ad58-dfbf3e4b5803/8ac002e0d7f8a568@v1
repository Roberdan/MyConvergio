import type { NextConfig } from "next";
import packageJson from './package.json';

const nextConfig: NextConfig = {
  env: {
    APP_VERSION: packageJson.version,
  },
  // C-18 FIX: External packages that should not be bundled by Next.js
  // pdf-parse uses pdfjs-dist which has native dependencies
  serverExternalPackages: ['pdf-parse'],
  // Add security headers for proper permissions handling
  async headers() {
    const allowedOrigin = process.env.ALLOWED_ORIGIN || 'http://localhost:3000';

    return [
      {
        // Global security headers for all routes
        source: '/:path*',
        headers: [
          {
            // Allow microphone and camera for voice sessions
            key: 'Permissions-Policy',
            value: 'microphone=(self), camera=(self), display-capture=(self)',
          },
          {
            // Prevent clickjacking
            key: 'X-Frame-Options',
            value: 'DENY',
          },
          {
            // Prevent MIME type sniffing
            key: 'X-Content-Type-Options',
            value: 'nosniff',
          },
          {
            // XSS protection
            key: 'X-XSS-Protection',
            value: '1; mode=block',
          },
        ],
      },
      {
        // CORS headers for API routes only
        source: '/api/:path*',
        headers: [
          {
            key: 'Access-Control-Allow-Origin',
            value: allowedOrigin,
          },
          {
            key: 'Access-Control-Allow-Methods',
            value: 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
          },
          {
            key: 'Access-Control-Allow-Headers',
            value: 'Content-Type, Authorization, X-Requested-With',
          },
          {
            key: 'Access-Control-Max-Age',
            value: '86400', // 24 hours preflight cache
          },
        ],
      },
    ];
  },
};

export default nextConfig;
