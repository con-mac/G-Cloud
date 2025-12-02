/**
 * Authentication Context using MSAL
 * Handles SSO authentication and user information
 */

import React, { createContext, useContext, useEffect, useState, ReactNode } from 'react';
import { useMsal, useAccount } from '@azure/msal-react';
import { InteractionStatus } from '@azure/msal-browser';

interface User {
  email: string;
  formattedEmail: string; // firstName.LastName@paconsulting.com format
  name: string;
  isAdmin: boolean;
}

interface AuthContextType {
  user: User | null;
  isLoading: boolean;
  isAuthenticated: boolean;
  login: () => Promise<void>;
  logout: () => Promise<void>;
  getAccessToken: () => Promise<string | null>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return context;
};

interface AuthProviderProps {
  children: ReactNode;
}

export const AuthProvider: React.FC<AuthProviderProps> = ({ children }) => {
  const { instance, accounts, inProgress } = useMsal();
  const account = useAccount(accounts[0] || {});
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  // Debug: Verify MSAL is configured (check via getConfiguration method if available)
  useEffect(() => {
    // MSAL stores config internally - we can't always access it directly
    // But we can verify it's working by checking if accounts are being managed
    // The config was already validated in main.tsx, so we trust it here
    if (accounts.length > 0) {
      console.log('MSAL is working - accounts found:', accounts.length);
    }
  }, [accounts, instance]);

  // Format email as firstName.LastName@paconsulting.com
  const formatEmail = (email: string): string => {
    if (!email) return email;
    
    // Extract name from email (e.g., "conor.macklin@paconsulting.com" -> "conor.macklin")
    const localPart = email.split('@')[0];
    const domain = email.split('@')[1];
    
    // If already in firstName.LastName format, return as-is
    if (domain === 'paconsulting.com' || domain === 'conmacdev.onmicrosoft.com') {
      return `${localPart}@paconsulting.com`;
    }
    
    // Try to extract from name if available
    if (account?.name) {
      const nameParts = account.name.toLowerCase().split(' ');
      if (nameParts.length >= 2) {
        const firstName = nameParts[0];
        const lastName = nameParts[nameParts.length - 1];
        return `${firstName}.${lastName}@paconsulting.com`;
      }
    }
    
    // Fallback: use email as-is
    return email;
  };

  // Check if user is in admin group
  const checkAdminStatus = async (accessToken: string): Promise<boolean> => {
    try {
      // Get admin group ID from runtime config or build-time env
      const runtimeConfig = (window as any).__ENV__;
      const adminGroupId = runtimeConfig?.VITE_AZURE_AD_ADMIN_GROUP_ID || import.meta.env.VITE_AZURE_AD_ADMIN_GROUP_ID || '';
      
      if (!adminGroupId) {
        // If no admin group configured, check for common admin patterns
        const email = account?.username || '';
        // Check if email contains admin indicators (can be customized)
        return email.includes('admin') || email.includes('administrator');
      }

      // Call Graph API to check group membership
      const response = await fetch(`https://graph.microsoft.com/v1.0/me/memberOf`, {
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
      });

      if (response.ok) {
        const groups = await response.json();
        // Check if user is a member of the admin security group
        // Only exact group ID match is used for security
        return groups.value?.some((group: any) => 
          group.id === adminGroupId
        ) || false;
      }
    } catch (error) {
      console.error('Error checking admin status:', error);
    }
    return false;
  };

  useEffect(() => {
    const initializeAuth = async () => {
      // Wait for MSAL to finish processing redirect
      // IMPORTANT: Don't proceed if MSAL is still processing a redirect
      if (inProgress !== InteractionStatus.None) {
        // Still processing - wait
        return;
      }
      
      if (account) {
        try {
          // Get access token silently (will use cached token if available)
          let tokenResponse;
          try {
            tokenResponse = await instance.acquireTokenSilent({
              scopes: ['User.Read'],
              account: account,
            });
          } catch (silentError: any) {
            // If silent acquisition fails, check the error type
            // NEVER fall back to popup - always use redirect
            if (silentError.errorCode === 'interaction_required' || 
                silentError.errorCode === 'consent_required' ||
                silentError.errorCode === 'login_required') {
              // User needs to authenticate - but don't do it here
              // Let them click the login button which uses loginRedirect
              console.log('Silent token acquisition failed - user needs to authenticate');
              setUser(null);
              setIsLoading(false);
              return;
            }
            // For other errors, log and clear state
            console.log('Silent token acquisition error:', silentError.errorCode);
            localStorage.removeItem('access_token');
            setUser(null);
            setIsLoading(false);
            return;
          }

            const accessToken = tokenResponse.accessToken;
            
            // Check admin status
            const isAdmin = await checkAdminStatus(accessToken);

            // Format email
            const email = account.username || account.name || '';
            const formattedEmail = formatEmail(email);

            setUser({
              email: email,
              formattedEmail: formattedEmail,
              name: account.name || email,
              isAdmin: isAdmin,
            });

            // Store token and user info for API calls
            localStorage.setItem('access_token', accessToken);
            sessionStorage.setItem('isAuthenticated', 'true');
            sessionStorage.setItem('user_email', email);
            sessionStorage.setItem('userEmail', formattedEmail); // Also store as userEmail for compatibility
            sessionStorage.setItem('user_formatted_email', formattedEmail);
            sessionStorage.setItem('user_is_admin', isAdmin.toString());
          } catch (error) {
            console.error('Error initializing auth:', error);
            setUser(null);
          }
        } else {
          setUser(null);
        }
        setIsLoading(false);
      }
    };

    initializeAuth();
  }, [account, inProgress, instance]);

  const login = async () => {
    try {
      // CRITICAL: Use redirect flow ONLY - never popup
      // Ensure we're not already in a redirect flow
      if (inProgress !== InteractionStatus.None) {
        console.log('MSAL interaction already in progress, waiting...');
        return;
      }
      
      // Clear any existing hash that might interfere
      if (window.location.hash) {
        window.history.replaceState(null, '', window.location.pathname + window.location.search);
      }
      
      // Explicitly use loginRedirect - this will navigate away
      // After redirect, the page will reload and handleRedirectPromise() will process the response
      console.log('Initiating MSAL redirect login...');
      await instance.loginRedirect({
        scopes: ['User.Read'],
        prompt: 'select_account',
      });
      // Note: This will navigate away, so code after this won't execute
      // The redirect response will be handled by handleRedirectPromise() in main.tsx
    } catch (error: any) {
      // Check if this is a redirect navigation (expected)
      if (error.name === 'BrowserConfigurationAuthError' || 
          error.message?.includes('redirect') ||
          error.errorCode === 'user_cancelled') {
        // These are expected - redirect is happening
        console.log('Redirect initiated (this is expected)');
      } else {
        console.error('Login error:', error);
        // Don't throw - let user try again
      }
    }
  };

  const logout = async () => {
    try {
      // Use redirect flow for logout as well
      await instance.logoutRedirect({
        account: account,
      });
      // Clear local state before redirect
      setUser(null);
      localStorage.removeItem('access_token');
      sessionStorage.removeItem('isAuthenticated');
      sessionStorage.removeItem('user_email');
      sessionStorage.removeItem('userEmail');
      sessionStorage.removeItem('user_formatted_email');
      sessionStorage.removeItem('user_is_admin');
    } catch (error) {
      console.error('Logout error:', error);
    }
  };

  const getAccessToken = async (): Promise<string | null> => {
    if (!account) return null;
    
    try {
      const tokenResponse = await instance.acquireTokenSilent({
        scopes: ['User.Read'],
        account: account,
      });
      return tokenResponse.accessToken;
    } catch (error) {
      console.error('Error getting access token:', error);
      return null;
    }
  };

  const value: AuthContextType = {
    user,
    isLoading: isLoading || inProgress !== InteractionStatus.None,
    isAuthenticated: !!user,
    login,
    logout,
    getAccessToken,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};

