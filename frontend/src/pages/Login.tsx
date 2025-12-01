/**
 * Login page with email validation for PA Consulting employees
 * Validates @paconsulting.com domain
 */

import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import {
  Container,
  Box,
  Card,
  CardContent,
  Button,
  Typography,
  Alert,
} from '@mui/material';
import { Login as LoginIcon } from '@mui/icons-material';

export default function Login() {
  const navigate = useNavigate();
  const { login, isAuthenticated, user } = useAuth();
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  // Redirect if already authenticated - automatically based on security group membership
  useEffect(() => {
    if (isAuthenticated && user) {
      // Access is determined automatically by security group membership
      // Admin group members get admin dashboard, others get standard employee view
      if (user.isAdmin) {
        navigate('/admin/dashboard');
      } else {
        navigate('/proposals');
      }
    }
  }, [isAuthenticated, user, navigate]);

  // Email validation is handled by MSAL SSO - no manual validation needed
  // const validateEmail = (emailValue: string): boolean => {
  //   // Must end with @paconsulting.com
  //   const emailRegex = /^[^\s@]+@paconsulting\.com$/i;
  //   return emailRegex.test(emailValue);
  // };

  const handleSubmit = async (e?: React.FormEvent) => {
    if (e) {
      e.preventDefault();
    }
    setError('');
    setLoading(true);

    try {
      // Use MSAL SSO login
      // After login, AuthContext will check security group membership
      // and set user.isAdmin automatically
      await login();
      // Navigation will happen automatically via useEffect when user is authenticated
      // based on their security group membership (admin vs employee)
    } catch (err: any) {
      setError(err.message || 'Failed to sign in. Please try again.');
      setLoading(false);
    }
  };

  // Check if SSO is configured (has client ID) - check both runtime and build-time
  const runtimeConfig = (window as any).__ENV__;
  const clientId = runtimeConfig?.VITE_AZURE_AD_CLIENT_ID || import.meta.env.VITE_AZURE_AD_CLIENT_ID || '';
  const isSSOConfigured = clientId && clientId !== 'PLACEHOLDER_CLIENT_ID' && clientId.trim() !== '';

  return (
    <Container maxWidth="sm" sx={{ mt: 8 }}>
      <Card>
        <CardContent sx={{ p: 4 }}>
          <Box display="flex" flexDirection="column" alignItems="center" mb={3}>
            <LoginIcon sx={{ fontSize: 48, color: 'primary.main', mb: 2 }} />
            <Typography variant="h4" component="h1" gutterBottom>
              G-Cloud Proposal System
            </Typography>
          </Box>

          {isSSOConfigured ? (
            // SSO Login (Microsoft 365)
            // Access level (admin vs employee) is automatically determined by security group membership
            <Box>
              <Button
                fullWidth
                variant="contained"
                size="large"
                onClick={handleSubmit}
                disabled={loading}
                startIcon={<LoginIcon />}
                sx={{ mb: 2 }}
              >
                {loading ? 'Signing in...' : 'Sign in with Microsoft 365'}
              </Button>
              {error && (
                <Alert severity="error" sx={{ mb: 2 }}>
                  {error}
                </Alert>
              )}
            </Box>
          ) : (
            // SSO not configured - show error message
            <Alert severity="warning" sx={{ mb: 2 }}>
              SSO is not configured. Please run configure-auth.ps1 to enable Microsoft 365 SSO.
              <br />
              Access level (admin vs employee) is automatically determined by your security group membership.
            </Alert>
          )}

          <Box mt={3}>
            <Typography variant="caption" color="text.secondary" align="center" display="block">
              {isSSOConfigured ? (
                <>
                  Sign in with your Microsoft 365 account (PA Consulting).
                  <br />
                  Your access level (admin dashboard or standard employee view) is automatically determined by your security group membership.
                  <br />
                  Admin group members will see the admin dashboard; all other users will see the standard employee interface.
                </>
              ) : (
                <>
                  SSO is not configured. Please run configure-auth.ps1 to enable Microsoft 365 SSO.
                </>
              )}
            </Typography>
          </Box>
        </CardContent>
      </Card>
    </Container>
  );
}

