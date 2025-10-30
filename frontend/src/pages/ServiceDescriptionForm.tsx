/**
 * G-Cloud Service Description Form - PA Consulting Style
 * 4 required sections with G-Cloud v15 validation
 */

import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Container, Box, Typography, TextField, Button, Card, CardContent,
  LinearProgress, Alert, IconButton, Chip, Dialog, DialogTitle,
  DialogContent, DialogActions, List, ListItem, ListItemText,
  CircularProgress,
} from '@mui/material';
import {
  ArrowBack, Add, Delete, CheckCircle, Error, Download,
} from '@mui/icons-material';
import apiService from '../services/api';

interface ValidationState {
  isValid: boolean;
  message: string;
}

export default function ServiceDescriptionForm() {
  const navigate = useNavigate();
  
  // Form state
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [features, setFeatures] = useState<string[]>(['']);
  const [benefits, setBenefits] = useState<string[]>(['']);
  
  // Validation state
  const [titleValid, setTitleValid] = useState<ValidationState>({ isValid: true, message: '' });
  const [descValid, setDescValid] = useState<ValidationState>({ isValid: true, message: '' });
  const [featuresValid, setFeaturesValid] = useState<ValidationState>({ isValid: true, message: '' });
  const [benefitsValid, setBenefitsValid] = useState<ValidationState>({ isValid: true, message: '' });
  
  // UI state
  const [submitting, setSubmitting] = useState(false);
  const [successDialog, setSuccessDialog] = useState(false);
  const [generatedFiles, setGeneratedFiles] = useState<any>(null);

  // Word counting helper
  const countWords = (text: string): number => {
    return text.trim().split(/\s+/).filter(Boolean).length;
  };

  // Validation functions
  const validateTitle = (value: string) => {
    if (!value.trim()) {
      setTitleValid({ isValid: false, message: 'Title is required' });
      return false;
    }
    if (value.trim().split(/\s+/).length > 10) {
      setTitleValid({ isValid: false, message: 'Title should be concise - just the service name (max 10 words)' });
      return false;
    }
    setTitleValid({ isValid: true, message: 'Valid service name' });
    return true;
  };

  const validateDescription = (value: string) => {
    const words = countWords(value);
    if (words > 50) {
      setDescValid({ isValid: false, message: `Description must not exceed 50 words (currently ${words})` });
      return false;
    }
    setDescValid({ isValid: true, message: `Valid (${words}/50 words)` });
    return true;
  };

  const validateListItems = (items: string[], type: 'features' | 'benefits') => {
    const validItems = items.filter(item => item.trim().length > 0);
    
    if (validItems.length === 0) {
      const setState = type === 'features' ? setFeaturesValid : setBenefitsValid;
      setState({ isValid: false, message: `At least one ${type.slice(0, -1)} is required` });
      return false;
    }
    
    if (validItems.length > 10) {
      const setState = type === 'features' ? setFeaturesValid : setBenefitsValid;
      setState({ isValid: false, message: `Maximum 10 ${type} allowed (currently ${validItems.length})` });
      return false;
    }
    
    // Check each item is max 10 words
    for (const item of validItems) {
      const words = countWords(item);
      if (words > 10) {
        const setState = type === 'features' ? setFeaturesValid : setBenefitsValid;
        setState({ isValid: false, message: `Each ${type.slice(0, -1)} must be max 10 words (found ${words} words in one item)` });
        return false;
      }
    }
    
    const setState = type === 'features' ? setFeaturesValid : setBenefitsValid;
    setState({ isValid: true, message: `Valid (${validItems.length}/10 ${type})` });
    return true;
  };

  // Handlers
  const handleTitleChange = (value: string) => {
    setTitle(value);
    validateTitle(value);
  };

  const handleDescriptionChange = (value: string) => {
    setDescription(value);
    validateDescription(value);
  };

  const handleFeatureChange = (index: number, value: string) => {
    const newFeatures = [...features];
    newFeatures[index] = value;
    setFeatures(newFeatures);
    validateListItems(newFeatures, 'features');
  };

  const handleBenefitChange = (index: number, value: string) => {
    const newBenefits = [...benefits];
    newBenefits[index] = value;
    setBenefits(newBenefits);
    validateListItems(newBenefits, 'benefits');
  };

  const addFeature = () => {
    if (features.length < 10) {
      setFeatures([...features, '']);
    }
  };

  const addBenefit = () => {
    if (benefits.length < 10) {
      setBenefits([...benefits, '']);
    }
  };

  const removeFeature = (index: number) => {
    const newFeatures = features.filter((_, i) => i !== index);
    setFeatures(newFeatures.length === 0 ? [''] : newFeatures);
    validateListItems(newFeatures, 'features');
  };

  const removeBenefit = (index: number) => {
    const newBenefits = benefits.filter((_, i) => i !== index);
    setBenefits(newBenefits.length === 0 ? [''] : newBenefits);
    validateListItems(newBenefits, 'benefits');
  };

  const handleSubmit = async () => {
    // Validate all fields
    const titleOk = validateTitle(title);
    const descOk = validateDescription(description);
    const featuresOk = validateListItems(features, 'features');
    const benefitsOk = validateListItems(benefits, 'benefits');

    if (!titleOk || !descOk || !featuresOk || !benefitsOk) {
      return;
    }

    setSubmitting(true);

    try {
      const response = await apiService.post('/templates/service-description/generate', {
        title: title.trim(),
        description: description.trim(),
        features: features.filter(f => f.trim().length > 0),
        benefits: benefits.filter(b => b.trim().length > 0),
      });

      setGeneratedFiles(response);
      setSuccessDialog(true);
    } catch (error: any) {
      alert(`Error: ${error.response?.data?.detail || 'Failed to generate documents'}`);
    } finally {
      setSubmitting(false);
    }
  };

  const handleDownload = async (filename: string) => {
    window.open(`http://localhost:8000/api/v1/templates/service-description/download/${filename}`, '_blank');
  };

  const descWords = countWords(description);
  const descProgress = Math.min((descWords / 50) * 100, 100);

  return (
    <Container maxWidth="md" sx={{ py: 4 }}>
      <Box mb={4}>
        <Button
          startIcon={<ArrowBack />}
          onClick={() => navigate('/proposals/create')}
          sx={{ mb: 2 }}
        >
          Back to Templates
        </Button>

        <Typography variant="h3" gutterBottom sx={{ fontWeight: 700 }}>
          G-Cloud Service Description
        </Typography>
        <Typography variant="body1" color="text.secondary">
          Complete all 4 required sections following G-Cloud v15 guidelines
        </Typography>
      </Box>

      {/* Section 1: Title */}
      <Card sx={{ mb: 3 }}>
        <CardContent>
          <Box display="flex" alignItems="center" justifyContent="space-between" mb={2}>
            <Typography variant="h6" sx={{ fontWeight: 600 }}>
              Service Name
            </Typography>
            {titleValid.isValid ? (
              <Chip icon={<CheckCircle />} label="Valid" color="success" size="small" />
            ) : (
              <Chip icon={<Error />} label="Invalid" color="error" size="small" />
            )}
          </Box>

          <TextField
            fullWidth
            placeholder="ENTER TITLE HERE"
            value={title}
            onChange={(e) => handleTitleChange(e.target.value)}
            error={!titleValid.isValid && title.length > 0}
            helperText={titleValid.message || 'Just your service name - no extra keywords'}
            sx={{ mb: 1 }}
          />
        </CardContent>
      </Card>

      {/* Section 2: Short Service Description */}
      <Card sx={{ mb: 3 }}>
        <CardContent>
          <Box display="flex" alignItems="center" justifyContent="space-between" mb={2}>
            <Typography variant="h6" sx={{ fontWeight: 600 }}>
              Short Service Description
            </Typography>
            {descValid.isValid ? (
              <Chip icon={<CheckCircle />} label={descValid.message} color="success" size="small" />
            ) : (
              <Chip icon={<Error />} label="Invalid" color="error" size="small" />
            )}
          </Box>

          <TextField
            fullWidth
            multiline
            rows={6}
            placeholder="Provide a summary describing what your service is for..."
            value={description}
            onChange={(e) => handleDescriptionChange(e.target.value)}
            error={!descValid.isValid && description.length > 0}
            helperText={`${descWords}/50 words • ${descValid.message}`}
            sx={{ mb: 1 }}
          />

          <LinearProgress
            variant="determinate"
            value={descProgress}
            color={descValid.isValid ? 'success' : 'error'}
            sx={{ height: 8, borderRadius: 4 }}
          />
        </CardContent>
      </Card>

      {/* Section 3: Key Service Features */}
      <Card sx={{ mb: 3 }}>
        <CardContent>
          <Box display="flex" alignItems="center" justifyContent="space-between" mb={2}>
            <Typography variant="h6" sx={{ fontWeight: 600 }}>
              Key Service Features
            </Typography>
            {featuresValid.isValid ? (
              <Chip icon={<CheckCircle />} label={featuresValid.message} color="success" size="small" />
            ) : (
              <Chip icon={<Error />} label="Invalid" color="error" size="small" />
            )}
          </Box>

          <Typography variant="caption" color="text.secondary" display="block" sx={{ mb: 2 }}>
            10 words maximum for each feature, up to 10 features
          </Typography>

          {features.map((feature, index) => (
            <Box key={index} display="flex" alignItems="start" gap={1} mb={2}>
              <TextField
                fullWidth
                size="small"
                placeholder={`Feature ${index + 1}`}
                value={feature}
                onChange={(e) => handleFeatureChange(index, e.target.value)}
                helperText={`${countWords(feature)}/10 words`}
              />
              {features.length > 1 && (
                <IconButton onClick={() => removeFeature(index)} color="error" size="small">
                  <Delete />
                </IconButton>
              )}
            </Box>
          ))}

          {features.length < 10 && (
            <Button
              startIcon={<Add />}
              onClick={addFeature}
              variant="outlined"
              size="small"
            >
              Add Feature
            </Button>
          )}

          {!featuresValid.isValid && (
            <Alert severity="error" sx={{ mt: 2 }}>
              {featuresValid.message}
            </Alert>
          )}
        </CardContent>
      </Card>

      {/* Section 4: Key Service Benefits */}
      <Card sx={{ mb: 3 }}>
        <CardContent>
          <Box display="flex" alignItems="center" justifyContent="space-between" mb={2}>
            <Typography variant="h6" sx={{ fontWeight: 600 }}>
              Key Service Benefits
            </Typography>
            {benefitsValid.isValid ? (
              <Chip icon={<CheckCircle />} label={benefitsValid.message} color="success" size="small" />
            ) : (
              <Chip icon={<Error />} label="Invalid" color="error" size="small" />
            )}
          </Box>

          <Typography variant="caption" color="text.secondary" display="block" sx={{ mb: 2 }}>
            10 words maximum for each benefit, up to 10 benefits
          </Typography>

          {benefits.map((benefit, index) => (
            <Box key={index} display="flex" alignItems="start" gap={1} mb={2}>
              <TextField
                fullWidth
                size="small"
                placeholder={`Benefit ${index + 1}`}
                value={benefit}
                onChange={(e) => handleBenefitChange(index, e.target.value)}
                helperText={`${countWords(benefit)}/10 words`}
              />
              {benefits.length > 1 && (
                <IconButton onClick={() => removeBenefit(index)} color="error" size="small">
                  <Delete />
                </IconButton>
              )}
            </Box>
          ))}

          {benefits.length < 10 && (
            <Button
              startIcon={<Add />}
              onClick={addBenefit}
              variant="outlined"
              size="small"
            >
              Add Benefit
            </Button>
          )}

          {!benefitsValid.isValid && (
            <Alert severity="error" sx={{ mt: 2 }}>
              {benefitsValid.message}
            </Alert>
          )}
        </CardContent>
      </Card>

      {/* Submit Button */}
      <Box display="flex" justifyContent="flex-end" gap={2}>
        <Button
          variant="outlined"
          onClick={() => navigate('/proposals/create')}
        >
          Cancel
        </Button>
        <Button
          variant="contained"
          size="large"
          onClick={handleSubmit}
          disabled={submitting || !titleValid.isValid || !descValid.isValid || !featuresValid.isValid || !benefitsValid.isValid}
        >
          {submitting ? <CircularProgress size={24} /> : 'Generate Documents'}
        </Button>
      </Box>

      {/* Success Dialog */}
      <Dialog open={successDialog} onClose={() => setSuccessDialog(false)} maxWidth="sm" fullWidth>
        <DialogTitle>
          <Box display="flex" alignItems="center" gap={1}>
            <CheckCircle color="success" />
            <Typography variant="h6">Documents Generated Successfully!</Typography>
          </Box>
        </DialogTitle>
        <DialogContent>
          <Typography variant="body2" color="text.secondary" paragraph>
            Your G-Cloud Service Description documents have been generated with PA Consulting branding.
          </Typography>

          <List>
            <ListItem>
              <ListItemText
                primary="Word Document (.docx)"
                secondary={generatedFiles?.word_filename}
              />
              <Button
                startIcon={<Download />}
                variant="outlined"
                size="small"
                onClick={() => handleDownload(generatedFiles?.word_filename)}
              >
                Download
              </Button>
            </ListItem>
            <ListItem>
              <ListItemText
                primary="PDF Document"
                secondary={generatedFiles?.pdf_filename}
              />
              <Button
                startIcon={<Download />}
                variant="outlined"
                size="small"
                onClick={() => handleDownload(generatedFiles?.pdf_filename)}
                disabled
              >
                Coming Soon
              </Button>
            </ListItem>
          </List>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => {
            setSuccessDialog(false);
            navigate('/proposals');
          }}>
            Done
          </Button>
          <Button variant="contained" onClick={() => {
            setSuccessDialog(false);
            // Reset form
            setTitle('');
            setDescription('');
            setFeatures(['']);
            setBenefits(['']);
          }}>
            Create Another
          </Button>
        </DialogActions>
      </Dialog>
    </Container>
  );
}

