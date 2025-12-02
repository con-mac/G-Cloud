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

  // Debug: Log MSAL instance config
  useEffect(() => {
    // MSAL config is stored in instance.configuration, not instance.config
    const config = (instance as any).configuration || (instance as any).config;
    if (config) {
      console.log('MSAL Instance Config:', {
        clientId: config?.auth?.clientId ? `${config.auth.clientId.substring(0, 8)}...` : 'missing',
        authority: config?.auth?.authority,
        redirectUri: config?.auth?.redirectUri,
      });
    } else {
      console.log('MSAL Instance Config: Not accessible (this is normal)');
    }
  }, [instance]);

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
      if (inProgress === InteractionStatus.None) {
        if (account) {
          try {
            // Get access token silently (will use cached token if available)
            let tokenResponse;
            try {
              tokenResponse = await instance.acquireTokenSilent({
                scopes: ['User.Read'],
                account: account,
              });
            } catch (silentError) {
              // If silent acquisition fails, try interactive redirect
              // But only if we're not already in a redirect flow
              if (inProgress === InteractionStatus.None) {
                console.log('Silent token acquisition failed, user may need to re-authenticate');
                setUser(null);
                setIsLoading(false);
                return;
              }
              throw silentError;
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
      // Use redirect flow instead of popup to avoid COOP policy issues
      await instance.loginRedirect({
        scopes: ['User.Read'],
      });
      // Note: After redirect, the page will reload and MSAL will handle the response
      // The useEffect in this component will detect the authenticated account
    } catch (error) {
      console.error('Login error:', error);
      throw error;
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

