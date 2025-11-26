/**
 * Login page with email validation for PA Consulting employees
 * Validates @paconsulting.com domain
 */

import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
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
  const [email, setEmail] = useState('');
  const [loginType, setLoginType] = useState<LoginType>('employee');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const validateEmail = (emailValue: string): boolean => {
    // Must end with @paconsulting.com
    const emailRegex = /^[^\s@]+@paconsulting\.com$/i;
    return emailRegex.test(emailValue);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    // Validate email
    if (!email.trim()) {
      setError('Email is required');
      setLoading(false);
      return;
    }

    if (!validateEmail(email)) {
      setError('Email must end with @paconsulting.com');
      setLoading(false);
      return;
    }

    try {
      // Store email in sessionStorage for authenticated session
      sessionStorage.setItem('userEmail', email);
      sessionStorage.setItem('isAuthenticated', 'true');
      sessionStorage.setItem('loginType', loginType);

      // Navigate based on login type
      if (loginType === 'admin') {
        navigate('/admin/dashboard');
      } else {
        navigate('/proposals/flow');
      }
    } catch (err) {
      setError('An error occurred. Please try again.');
      setLoading(false);
    }
  };

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

          <Box mt={3}>
            <Typography variant="caption" color="text.secondary" align="center" display="block">
              Access is restricted to PA Consulting employees only.
              <br />
              Future versions will support Microsoft 365 SSO.
            </Typography>
          </Box>
        </CardContent>
      </Card>
    </Container>
  );
}

