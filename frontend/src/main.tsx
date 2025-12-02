import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MsalProvider } from '@azure/msal-react';
import { PublicClientApplication } from '@azure/msal-browser';
import { ToastContainer } from 'react-toastify';
import CssBaseline from '@mui/material/CssBaseline';
import { ThemeProvider } from '@mui/material/styles';

import App from './App';
import { AuthProvider } from './contexts/AuthContext';
import theme from './styles/theme';

import 'react-toastify/dist/ReactToastify.css';
import './styles/index.css';

// MSAL configuration - get from runtime window object or build-time env vars
// Wait for DOM to ensure window.__ENV__ is available
const getMsalConfig = () => {
  // Check for runtime config (injected by entrypoint script)
  const runtimeConfig = (window as any).__ENV__;
  const clientId = runtimeConfig?.VITE_AZURE_AD_CLIENT_ID || import.meta.env.VITE_AZURE_AD_CLIENT_ID || '';
  const tenantId = runtimeConfig?.VITE_AZURE_AD_TENANT_ID || import.meta.env.VITE_AZURE_AD_TENANT_ID || '';
  // Use redirect URI from config, or default to base URL (SPA doesn't need /auth/callback)
  const redirectUri = runtimeConfig?.VITE_AZURE_AD_REDIRECT_URI || import.meta.env.VITE_AZURE_AD_REDIRECT_URI || window.location.origin;
  
  console.log('MSAL Config:', { clientId: clientId ? `${clientId.substring(0, 8)}...` : 'empty', tenantId: tenantId ? `${tenantId.substring(0, 8)}...` : 'empty', redirectUri });
  console.log('Runtime config available:', !!runtimeConfig);
  
  if (!clientId || clientId === 'PLACEHOLDER_CLIENT_ID') {
    console.warn('MSAL Client ID not configured properly');
  }
  
  return {
    auth: {
      clientId: clientId,
      authority: `https://login.microsoftonline.com/${tenantId || 'common'}`,
      redirectUri: redirectUri,
      // Explicitly configure for redirect flow (not popup)
      navigateToLoginRequestUrl: true,
      // Ensure we're using redirect flow, not popup
      postLogoutRedirectUri: redirectUri,
    },
    cache: {
      cacheLocation: 'localStorage' as const,
      storeAuthStateInCookie: false,
    },
    system: {
      // Disable popup completely - force redirect flow only
      allowNativeBroker: false,
      // Increase timeouts for redirect flow
      windowHashTimeout: 60000,
      iframeHashTimeout: 6000,
      loadFrameTimeout: 0,
      // Prevent popup fallback
      asyncPopups: false,
    },
  };
};

const msalConfig = getMsalConfig();
const msalInstance = new PublicClientApplication(msalConfig);

// CRITICAL: Initialize MSAL and handle redirect BEFORE React Router processes the URL
// This ensures the hash fragment (#access_token=...) is preserved for MSAL to process
// We need to handle the redirect synchronously before React renders

// Check if we have a hash fragment that looks like an MSAL response
const hasMsalHash = window.location.hash && (
  window.location.hash.includes('access_token') ||
  window.location.hash.includes('id_token') ||
  window.location.hash.includes('error') ||
  window.location.hash.includes('code')
);

// Initialize MSAL and handle redirect immediately (synchronously)
msalInstance.initialize().then(() => {
  console.log('MSAL initialized successfully');
  
  // If we have an MSAL hash, process it IMMEDIATELY before anything else
  if (hasMsalHash) {
    console.log('Detected MSAL redirect response in hash, processing...');
  }
  
  // Handle redirect response IMMEDIATELY - before React Router processes the URL
  // This MUST be called synchronously on every page load to process redirect responses
  msalInstance.handleRedirectPromise()
    .then((response) => {
      if (response) {
        console.log('MSAL redirect response received:', response.account?.username);
        // Clear hash fragment after processing to prevent React Router from seeing it
        if (window.location.hash) {
          const hash = window.location.hash;
          // Only clear if it's an MSAL response (contains access_token or error)
          if (hash.includes('access_token') || hash.includes('error') || hash.includes('code') || hash.includes('id_token')) {
            // Replace hash with clean URL (preserve any non-MSAL hash)
            window.history.replaceState(null, '', window.location.pathname + window.location.search);
            console.log('Cleared MSAL hash fragment after processing');
          }
        }
      } else {
        console.log('No redirect response to process');
      }
    })
    .catch((error: any) => {
      // Only log if it's not a user cancellation
      // hash_empty_error might occur if hash was already processed or cleared
      if (error.errorCode !== 'user_cancelled') {
        if (error.errorCode === 'hash_empty_error') {
          console.warn('MSAL hash was empty - may have been processed already or cleared by browser');
        } else {
          console.error('MSAL redirect handling error:', error);
        }
      }
      // Don't throw - let the app continue
    });
}).catch((error) => {
  console.error('MSAL initialization error:', error);
});

// React Query client
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      refetchOnWindowFocus: false,
      retry: 1,
      staleTime: 5 * 60 * 1000, // 5 minutes
    },
  },
});

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <MsalProvider instance={msalInstance}>
      <AuthProvider>
        <QueryClientProvider client={queryClient}>
          <BrowserRouter>
            <ThemeProvider theme={theme}>
              <CssBaseline />
              <App />
              <ToastContainer
                position="top-right"
                autoClose={5000}
                hideProgressBar={false}
                newestOnTop
                closeOnClick
                rtl={false}
                pauseOnFocusLoss
                draggable
                pauseOnHover
                theme="light"
              />
            </ThemeProvider>
          </BrowserRouter>
        </QueryClientProvider>
      </AuthProvider>
    </MsalProvider>
  </React.StrictMode>
);

