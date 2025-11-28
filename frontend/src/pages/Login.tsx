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
  TextField,
  Button,
  Typography,
  Alert,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
} from '@mui/material';
import { Login as LoginIcon } from '@mui/icons-material';

type LoginType = 'employee' | 'admin';

export default function Login() {
  const navigate = useNavigate();
  const { login, isAuthenticated, user } = useAuth();
  const [email, setEmail] = useState('');
  const [loginType, setLoginType] = useState<LoginType>('employee');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  // Redirect if already authenticated
  useEffect(() => {
    if (isAuthenticated && user) {
      if (user.isAdmin || loginType === 'admin') {
        navigate('/admin/dashboard');
      } else {
        navigate('/proposals');
      }
    }
  }, [isAuthenticated, user, navigate, loginType]);

  const validateEmail = (emailValue: string): boolean => {
    // Must end with @paconsulting.com
    const emailRegex = /^[^\s@]+@paconsulting\.com$/i;
    return emailRegex.test(emailValue);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      // Use MSAL SSO login
      await login();
      // Navigation will happen automatically via useEffect when user is authenticated
    } catch (err: any) {
      setError(err.message || 'Failed to sign in. Please try again.');
      setLoading(false);
    }
  };

  // Check if SSO is configured (has client ID)
  const clientId = import.meta.env.VITE_AZURE_AD_CLIENT_ID || '';
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
            // Manual Login (fallback)
            <form onSubmit={handleSubmit}>
              <FormControl fullWidth sx={{ mb: 3 }}>
                <InputLabel id="login-type-label">Login Type</InputLabel>
                <Select
                  labelId="login-type-label"
                  id="login-type"
                  value={loginType}
                  label="Login Type"
                  onChange={(e) => setLoginType(e.target.value as LoginType)}
                  disabled={loading}
                >
                  <MenuItem value="employee">PA Consulting Employee Login</MenuItem>
                  <MenuItem value="admin">PA Consulting Admin Login</MenuItem>
                </Select>
              </FormControl>
              <TextField
                fullWidth
                label="Email Address"
                type="email"
                value={email}
                onChange={(e) => {
                  setEmail(e.target.value);
                  setError('');
                }}
                placeholder="your.name@paconsulting.com"
                error={!!error}
                helperText={error || 'Enter your PA Consulting email address'}
                disabled={loading}
                sx={{ mb: 3 }}
                autoFocus
              />

              {error && (
                <Alert severity="error" sx={{ mb: 2 }}>
                  {error}
                </Alert>
              )}

              <Button
                type="submit"
                fullWidth
                variant="contained"
                size="large"
                disabled={loading || !email.trim()}
                startIcon={<LoginIcon />}
              >
                {loading ? 'Signing in...' : 'Sign In'}
              </Button>
            </form>
          )}

          <Box mt={3}>
            <Typography variant="caption" color="text.secondary" align="center" display="block">
              {isSSOConfigured ? (
                <>
                  Sign in with your Microsoft 365 account (PA Consulting).
                  <br />
                  Admin access requires membership in the admin security group.
                </>
              ) : (
                <>
                  SSO is not configured. Using manual login.
                  <br />
                  Please run configure-auth.ps1 to enable Microsoft 365 SSO.
                </>
              )}
            </Typography>
          </Box>
        </CardContent>
      </Card>
    </Container>
  );
}

