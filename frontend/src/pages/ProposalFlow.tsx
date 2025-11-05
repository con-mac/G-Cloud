/**
 * Proposal Flow Questionnaire
 * Handles Update vs Create workflow with SharePoint integration
 */

import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Container,
  Box,
  Card,
  CardContent,
  Typography,
  Button,
  Radio,
  RadioGroup,
  FormControlLabel,
  FormControl,
  FormLabel,
  TextField,
  Alert,
  Stepper,
  Step,
  StepLabel,
  CircularProgress,
} from '@mui/material';
import {
  ArrowBack,
  ArrowForward,
  Update,
  Add,
  Description,
  AttachMoney,
} from '@mui/icons-material';
import SharePointSearch from '../components/SharePointSearch';
import sharepointApi, { SearchResult } from '../services/sharepointApi';

type FlowType = 'update' | 'create' | null;
type DocType = 'SERVICE DESC' | 'Pricing Doc' | null;
type LotType = '2' | '3' | null;

export default function ProposalFlow() {
  const navigate = useNavigate();
  const [activeStep, setActiveStep] = useState(0);
  const [flowType, setFlowType] = useState<FlowType>(null);
  const [docType, setDocType] = useState<DocType>(null);
  const [selectedResult, setSelectedResult] = useState<SearchResult | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [createData, setCreateData] = useState({
    service: '',
    owner: '',
    sponsor: '',
    lot: null as LotType,
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const steps = [
    'Select Flow Type',
    flowType === 'update' ? 'Search & Select Document' : 'Enter Proposal Details',
    'Confirm & Proceed',
  ];

  const handleNext = () => {
    setError('');
    if (activeStep === 0) {
      if (!flowType) {
        setError('Please select a flow type');
        return;
      }
    } else if (activeStep === 1) {
      if (flowType === 'update') {
        if (!selectedResult) {
          setError('Please select a document');
          return;
        }
      } else {
        if (!createData.service || !createData.owner || !createData.sponsor || !createData.lot) {
          setError('Please fill in all fields');
          return;
        }
      }
    } else if (activeStep === 2) {
      handleProceed();
      return;
    }
    setActiveStep((prev) => prev + 1);
  };

  const handleBack = () => {
    setActiveStep((prev) => prev - 1);
    setError('');
  };

  const handleSelectResult = (result: SearchResult) => {
    setSelectedResult(result);
    setSearchQuery(result.service_name);
    setError('');
  };

  const handleProceed = async () => {
    setLoading(true);
    setError('');

    try {
      if (flowType === 'update' && selectedResult) {
        // Load document content and redirect to editor with pre-populated data
        try {
          const documentContent = await sharepointApi.getDocumentContent(
            selectedResult.service_name,
            selectedResult.doc_type as 'SERVICE DESC' | 'Pricing Doc',
            selectedResult.lot as '2' | '3',
            selectedResult.gcloud_version as '14' | '15'
          );
          
          // Store document content and metadata for the form
          sessionStorage.setItem('updateDocument', JSON.stringify({
            ...selectedResult,
            content: documentContent,
          }));
          
          navigate(`/proposals/create/service-description`);
        } catch (err: any) {
          setError(`Failed to load document: ${err.response?.data?.detail || err.message}`);
          setLoading(false);
          return;
        }
      } else if (flowType === 'create') {
        // Create folder and metadata
        await sharepointApi.createFolder({
          service_name: createData.service,
          lot: createData.lot!,
          gcloud_version: '15',
        });

        await sharepointApi.createMetadata({
          service_name: createData.service,
          owner: createData.owner,
          sponsor: createData.sponsor,
          lot: createData.lot!,
          gcloud_version: '15',
        });

        // Store creation data for document generation
        sessionStorage.setItem('newProposal', JSON.stringify(createData));

        // Redirect to service description form
        navigate(`/proposals/create/service-description`);
      }
    } catch (err: any) {
      setError(err.response?.data?.detail || 'An error occurred. Please try again.');
      setLoading(false);
    }
  };

  const renderStepContent = () => {
    switch (activeStep) {
      case 0:
        return (
          <Box>
            <FormControl component="fieldset" fullWidth>
              <FormLabel component="legend" sx={{ mb: 2, fontWeight: 600 }}>
                Are you updating or creating new?
              </FormLabel>
              <RadioGroup
                value={flowType || ''}
                onChange={(e) => {
                  setFlowType(e.target.value as FlowType);
                  setError('');
                }}
              >
                <FormControlLabel
                  value="update"
                  control={<Radio />}
                  label={
                    <Box display="flex" alignItems="center" gap={1}>
                      <Update />
                      <Typography>Updating existing proposal</Typography>
                    </Box>
                  }
                />
                <FormControlLabel
                  value="create"
                  control={<Radio />}
                  label={
                    <Box display="flex" alignItems="center" gap={1}>
                      <Add />
                      <Typography>Creating new proposal</Typography>
                    </Box>
                  }
                />
              </RadioGroup>
            </FormControl>
          </Box>
        );

      case 1:
        if (flowType === 'update') {
          return (
            <Box>
              <FormControl fullWidth sx={{ mb: 2 }}>
                <FormLabel component="legend" sx={{ mb: 2, fontWeight: 600 }}>
                  Are you updating a Service Description or Pricing Document?
                </FormLabel>
                <RadioGroup
                  value={docType || ''}
                  onChange={(e) => {
                    setDocType(e.target.value as DocType);
                    setError('');
                  }}
                >
                  <FormControlLabel
                    value="SERVICE DESC"
                    control={<Radio />}
                    label={
                      <Box display="flex" alignItems="center" gap={1}>
                        <Description />
                        <Typography>Service Description</Typography>
                      </Box>
                    }
                  />
                  <FormControlLabel
                    value="Pricing Doc"
                    control={<Radio />}
                    label={
                      <Box display="flex" alignItems="center" gap={1}>
                        <AttachMoney />
                        <Typography>Pricing Document</Typography>
                      </Box>
                    }
                  />
                </RadioGroup>
              </FormControl>

              {docType && (
                <Box>
                  <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                    Enter the name of the service you are updating:
                  </Typography>
                  <SharePointSearch
                    query={searchQuery}
                    onChange={setSearchQuery}
                    onSelect={handleSelectResult}
                    docType={docType}
                    gcloudVersion="14"
                    placeholder="Type service name (e.g., Test Title, Agile Test Title)"
                    label="Search Service"
                  />
                  {selectedResult && (
                    <Alert severity="success" sx={{ mt: 2 }}>
                      Selected: {selectedResult.service_name} | OWNER: {selectedResult.owner}
                    </Alert>
                  )}
                </Box>
              )}
            </Box>
          );
        } else {
          return (
            <Box>
              <Typography variant="body2" color="text.secondary" sx={{ mb: 3 }}>
                Enter the proposal details:
              </Typography>
              <TextField
                fullWidth
                label="SERVICE"
                value={createData.service}
                onChange={(e) => setCreateData({ ...createData, service: e.target.value })}
                placeholder="e.g., Test Title"
                sx={{ mb: 2 }}
                required
                helperText="Service name (will be used for folder name)"
              />
              <TextField
                fullWidth
                label="OWNER"
                value={createData.owner}
                onChange={(e) => setCreateData({ ...createData, owner: e.target.value })}
                placeholder="First name Last name"
                sx={{ mb: 2 }}
                required
                helperText="Owner name (First name Last name)"
              />
              <TextField
                fullWidth
                label="SPONSOR"
                value={createData.sponsor}
                onChange={(e) => setCreateData({ ...createData, sponsor: e.target.value })}
                placeholder="First name Last name"
                sx={{ mb: 2 }}
                required
                helperText="Sponsor name (First name Last name)"
              />
              <FormControl fullWidth>
                <FormLabel component="legend" sx={{ mb: 1, fontWeight: 600 }}>
                  Is this a LOT 2 or LOT 3 proposal?
                </FormLabel>
                <RadioGroup
                  value={createData.lot || ''}
                  onChange={(e) => setCreateData({ ...createData, lot: e.target.value as LotType })}
                >
                  <FormControlLabel value="2" control={<Radio />} label="Cloud Support Services LOT 2" />
                  <FormControlLabel value="3" control={<Radio />} label="Cloud Support Services LOT 3" />
                </RadioGroup>
              </FormControl>
            </Box>
          );
        }

      case 2:
        return (
          <Box>
            <Typography variant="h6" gutterBottom>
              Confirm Details
            </Typography>
            {flowType === 'update' && selectedResult ? (
              <Box>
                <Typography variant="body1" paragraph>
                  <strong>Flow Type:</strong> Update Existing
                </Typography>
                <Typography variant="body1" paragraph>
                  <strong>Document Type:</strong> {selectedResult.doc_type}
                </Typography>
                <Typography variant="body1" paragraph>
                  <strong>Service Name:</strong> {selectedResult.service_name}
                </Typography>
                <Typography variant="body1" paragraph>
                  <strong>Owner:</strong> {selectedResult.owner}
                </Typography>
                <Typography variant="body1" paragraph>
                  <strong>LOT:</strong> {selectedResult.lot}
                </Typography>
              </Box>
            ) : (
              <Box>
                <Typography variant="body1" paragraph>
                  <strong>Flow Type:</strong> Create New
                </Typography>
                <Typography variant="body1" paragraph>
                  <strong>Service:</strong> {createData.service}
                </Typography>
                <Typography variant="body1" paragraph>
                  <strong>Owner:</strong> {createData.owner}
                </Typography>
                <Typography variant="body1" paragraph>
                  <strong>Sponsor:</strong> {createData.sponsor}
                </Typography>
                <Typography variant="body1" paragraph>
                  <strong>LOT:</strong> {createData.lot}
                </Typography>
                <Typography variant="body1" paragraph>
                  <strong>GCloud Version:</strong> 15 (New Proposal)
                </Typography>
              </Box>
            )}
          </Box>
        );

      default:
        return null;
    }
  };

  return (
    <Container maxWidth="md" sx={{ mt: 4, mb: 4 }}>
      <Card>
        <CardContent sx={{ p: 4 }}>
          <Box display="flex" alignItems="center" gap={2} mb={4}>
            <Button startIcon={<ArrowBack />} onClick={() => navigate('/proposals')}>
              Back
            </Button>
            <Typography variant="h5" component="h1" sx={{ flex: 1 }}>
              Proposal Workflow
            </Typography>
          </Box>

          <Stepper activeStep={activeStep} sx={{ mb: 4 }}>
            {steps.map((label) => (
              <Step key={label}>
                <StepLabel>{label}</StepLabel>
              </Step>
            ))}
          </Stepper>

          {error && (
            <Alert severity="error" sx={{ mb: 3 }}>
              {error}
            </Alert>
          )}

          <Box sx={{ mb: 4, minHeight: 300 }}>{renderStepContent()}</Box>

          <Box display="flex" justifyContent="space-between">
            <Button
              disabled={activeStep === 0 || loading}
              onClick={handleBack}
              startIcon={<ArrowBack />}
            >
              Back
            </Button>
            <Button
              variant="contained"
              onClick={handleNext}
              disabled={loading}
              endIcon={loading ? <CircularProgress size={20} /> : <ArrowForward />}
            >
              {activeStep === steps.length - 1 ? 'Proceed' : 'Next'}
            </Button>
          </Box>
        </CardContent>
      </Card>
    </Container>
  );
}

