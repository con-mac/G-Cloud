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
const getMsalConfig = () => {
  // Check for runtime config (injected by nginx startup script)
  const runtimeConfig = (window as any).__ENV__;
  const clientId = runtimeConfig?.VITE_AZURE_AD_CLIENT_ID || import.meta.env.VITE_AZURE_AD_CLIENT_ID || '';
  const tenantId = runtimeConfig?.VITE_AZURE_AD_TENANT_ID || import.meta.env.VITE_AZURE_AD_TENANT_ID || '';
  const redirectUri = runtimeConfig?.VITE_AZURE_AD_REDIRECT_URI || import.meta.env.VITE_AZURE_AD_REDIRECT_URI || window.location.origin;
  
  return {
    auth: {
      clientId: clientId,
      authority: `https://login.microsoftonline.com/${tenantId || 'common'}`,
      redirectUri: redirectUri,
    },
    cache: {
      cacheLocation: 'localStorage' as const,
      storeAuthStateInCookie: false,
    },
  };
};

const msalConfig = getMsalConfig();
const msalInstance = new PublicClientApplication(msalConfig);

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

