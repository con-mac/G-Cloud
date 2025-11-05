/**
 * G-Cloud Service Description Form - PA Consulting Style
 * 4 required sections with G-Cloud v15 validation
 */

import { useEffect, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Container, Box, Typography, TextField, Button, Card, CardContent,
  LinearProgress, Alert, IconButton, Chip, Dialog, DialogTitle,
  DialogContent, DialogActions, List, ListItem, ListItemText,
  CircularProgress, Tooltip,
} from '@mui/material';
import {
  ArrowBack, Add, Delete, CheckCircle, Error, Download, AttachFile,
} from '@mui/icons-material';
import apiService from '../services/api';
import ReactQuill from 'react-quill';
import 'react-quill/dist/quill.snow.css';

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
  // Service Definition subsections
  const generateId = () => `${Date.now()}_${Math.random().toString(36).slice(2,8)}`;
  const [serviceDefinition, setServiceDefinition] = useState<Array<{
    id: string;
    subtitle: string;
    content: string; // HTML from editor
  }>>(() => [{ id: `${Date.now()}_${Math.random().toString(36).slice(2,8)}`, subtitle: '', content: '' }]);
  
  // Validation state
  const [titleValid, setTitleValid] = useState<ValidationState>({ isValid: true, message: '' });
  const [descValid, setDescValid] = useState<ValidationState>({ isValid: true, message: '' });
  const [featuresValid, setFeaturesValid] = useState<ValidationState>({ isValid: true, message: '' });
  const [benefitsValid, setBenefitsValid] = useState<ValidationState>({ isValid: true, message: '' });
  
  // UI state
  const [submitting, setSubmitting] = useState(false);
  const [successDialog, setSuccessDialog] = useState(false);
  const [generatedFiles, setGeneratedFiles] = useState<any>(null);
  const quillRefs = useRef<Record<string, any>>({});
  const fileInputRef = useRef<HTMLInputElement | null>(null);
  const modulesByIdRef = useRef<Record<string, any>>({});
  const draftKey = 'service-description-draft-v1';

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

  // Service Definition handlers
  const addServiceDefBlock = () => {
    setServiceDefinition([...serviceDefinition, { id: generateId(), subtitle: '', content: '' }]);
  };

  const removeServiceDefBlock = (id: string) => {
    const next = serviceDefinition.filter((b) => b.id !== id);
    setServiceDefinition(next.length === 0 ? [{ id: generateId(), subtitle: '', content: '' }] : next);
  };

  const updateServiceDefBlock = (id: string, field: 'subtitle' | 'content', value: string) => {
    setServiceDefinition(prev => prev.map(b => b.id === id ? { ...b, [field]: value } : b));
  };

  // Stable toolbar modules per subsection (cached by id)
  const getModulesFor = (id: string) => {
    if (modulesByIdRef.current[id]) return modulesByIdRef.current[id];
    modulesByIdRef.current[id] = {
      toolbar: {
        container: [
          [{ 'font': [] }], // Font family
          [{ 'size': ['small', false, 'large', 'huge'] }], // Font size
          ['bold', 'italic', 'underline', 'strike'], // Text formatting
          [{ 'color': [] }, { 'background': [] }], // Text color, background color
          [{ 'list': 'ordered' }, { 'list': 'bullet' }, { 'indent': '-1' }, { 'indent': '+1' }], // Lists and indent
          [{ 'align': [] }], // Text alignment
          ['link', 'attach'], // Link and attach
          ['blockquote', 'code-block'], // Blockquote and code block
          ['clean'], // Remove formatting
        ],
        handlers: {
          attach: () => {
            (fileInputRef.current as any).dataset.id = String(id);
            fileInputRef.current?.click();
          },
        },
      },
    };
    return modulesByIdRef.current[id];
  };

  // Draft persistence: load on mount
  useEffect(() => {
    try {
      const raw = localStorage.getItem(draftKey);
      if (raw) {
        const data = JSON.parse(raw);
        if (typeof data.title === 'string') setTitle(data.title);
        if (typeof data.description === 'string') setDescription(data.description);
        if (Array.isArray(data.features)) setFeatures(data.features);
        if (Array.isArray(data.benefits)) setBenefits(data.benefits);
        if (Array.isArray(data.serviceDefinition)) {
          const restored = data.serviceDefinition.map((b: any) => ({
            id: typeof b.id === 'string' ? b.id : generateId(),
            subtitle: b.subtitle || '',
            content: b.content || '',
          }));
          setServiceDefinition(restored.length ? restored : [{ id: generateId(), subtitle: '', content: '' }]);
        }
      }
    } catch {}
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Draft persistence: save (debounced) on changes
  const saveTimeoutRef = useRef<number | null>(null);
  const scheduleSave = () => {
    if (saveTimeoutRef.current) window.clearTimeout(saveTimeoutRef.current);
    saveTimeoutRef.current = window.setTimeout(() => {
      try {
        const payload = {
          title,
          description,
          features,
          benefits,
          serviceDefinition,
        };
        localStorage.setItem(draftKey, JSON.stringify(payload));
      } catch {}
    }, 600);
  };
  useEffect(() => {
    scheduleSave();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [title, description, JSON.stringify(features), JSON.stringify(benefits), JSON.stringify(serviceDefinition)]);
  
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
        service_definition: serviceDefinition.map(b => ({
          subtitle: b.subtitle.trim(),
          content: b.content,
        })),
      });

      setGeneratedFiles(response);
      setSuccessDialog(true);
    } catch (error: any) {
      alert(`Error: ${error.response?.data?.detail || 'Failed to generate documents'}`);
    } finally {
      setSubmitting(false);
    }
  };

  const handleDownload = (url: string) => {
    // Use the presigned URL directly from the API response
    if (url && url.startsWith('http')) {
      window.open(url, '_blank');
    } else {
      // Fallback: construct download URL if we only have a filename
      const apiBaseUrl = import.meta.env.VITE_API_BASE_URL || import.meta.env.VITE_API_URL || 'https://jqms1xopz9.execute-api.eu-west-2.amazonaws.com';
      const downloadUrl = `${apiBaseUrl}/api/v1/templates/service-description/download/${url}`;
      window.open(downloadUrl, '_blank');
    }
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

      {/* Section 5: Service Definition (optional, unlimited subsections) */}
      <Card sx={{ mb: 3 }}>
        <CardContent>
          <Box display="flex" alignItems="center" justifyContent="space-between" mb={2}>
            <Typography variant="h6" sx={{ fontWeight: 600 }}>
              Service Definition
            </Typography>
            <Chip label={`${serviceDefinition.length} subsection(s)`} size="small" />
          </Box>

          <Typography variant="caption" color="text.secondary" display="block" sx={{ mb: 2 }}>
            Add as many subsections as needed. Subtitles will be styled as Heading 3 in the Word document.
          </Typography>

          {serviceDefinition.map((block, index) => {
            const modules = getModulesFor(block.id);
            return (
            <Box key={block.id} sx={{ border: '1px solid', borderColor: 'divider', borderRadius: 1, p: 2, mb: 2 }}>
              <Box display="flex" justifyContent="space-between" alignItems="center" mb={1}>
                <Typography variant="subtitle2">Subsection {index + 1}</Typography>
                {serviceDefinition.length > 1 && (
                  <IconButton size="small" color="error" onClick={() => removeServiceDefBlock(block.id)}>
                    <Delete />
                  </IconButton>
                )}
              </Box>

              <TextField
                fullWidth
                size="small"
                label="Subtitle (Heading 3)"
                placeholder="e.g., AI Security advisory"
                value={block.subtitle}
                onChange={(e) => updateServiceDefBlock(block.id, 'subtitle', e.target.value)}
                sx={{ mb: 2 }}
              />

              <Box sx={{ 
                mb: 2,
                position: 'relative',
                '& .ql-container': { 
                  minHeight: 260,
                  border: '1px solid #d0d0d0',
                  borderTop: 'none',
                  borderRadius: '0 0 4px 4px',
                },
                '& .ql-editor': { minHeight: 260 },
                // Hide the default Quill attach button (we're using custom one)
                '& .ql-toolbar .ql-attach': {
                  display: 'none',
                },
                // Style toolbar like Gmail compose
                '& .ql-toolbar': {
                  position: 'relative',
                  paddingRight: '40px', // Make room for custom attach button
                  border: '1px solid #d0d0d0',
                  borderBottom: 'none',
                  borderRadius: '4px 4px 0 0',
                  backgroundColor: '#fafafa',
                  padding: '8px',
                },
                // Style toolbar buttons
                '& .ql-toolbar .ql-formats': {
                  marginRight: '8px',
                },
                '& .ql-toolbar button': {
                  width: '28px',
                  height: '28px',
                  padding: '4px',
                  margin: '0 2px',
                  borderRadius: '2px',
                  '&:hover': {
                    backgroundColor: '#e8eaed',
                  },
                  '&.ql-active': {
                    backgroundColor: '#dadce0',
                  },
                },
                '& .ql-toolbar .ql-picker': {
                  height: '28px',
                  '&.ql-expanded': {
                    backgroundColor: '#e8eaed',
                  },
                },
                '& .ql-toolbar .ql-picker-label': {
                  padding: '4px 8px',
                  borderRadius: '2px',
                  '&:hover': {
                    backgroundColor: '#e8eaed',
                  },
                },
              }}>
                <Typography variant="caption" color="text.secondary" display="block" sx={{ mb: 1 }}>
                  Content (rich text editor with formatting options)
                </Typography>
                <Box sx={{ position: 'relative' }}>
                  <ReactQuill
                    theme="snow"
                    value={block.content}
                    onChange={(html: string) => updateServiceDefBlock(block.id, 'content', html)}
                    modules={modules}
                    ref={(el: any) => {
                      quillRefs.current[block.id] = el;
                      // Add tooltips to toolbar buttons and position attach button
                      if (el) {
                        setTimeout(() => {
                          const editor = el.getEditor?.();
                          if (editor) {
                            const toolbar = editor.container?.querySelector('.ql-toolbar');
                            if (toolbar) {
                              // Tooltip mappings for Quill buttons
                              const tooltips: Record<string, string> = {
                                'ql-font': 'Font family',
                                'ql-size': 'Font size',
                                'ql-bold': 'Bold',
                                'ql-italic': 'Italic',
                                'ql-underline': 'Underline',
                                'ql-strike': 'Strikethrough',
                                'ql-color': 'Text colour',
                                'ql-background': 'Background colour',
                                'ql-list': 'List',
                                'ql-indent': 'Indent',
                                'ql-align': 'Text alignment',
                                'ql-link': 'Insert link',
                                'ql-blockquote': 'Blockquote',
                                'ql-code-block': 'Code block',
                                'ql-clean': 'Clear formatting',
                              };
                              
                              // Add tooltips to all buttons
                              toolbar.querySelectorAll('button, .ql-picker-label').forEach((btn: Element) => {
                                const btnElement = btn as HTMLElement;
                                if (btnElement.classList.contains('ql-picker-label')) {
                                  const picker = btnElement.closest('.ql-picker');
                                  if (picker) {
                                    const pickerClass = Array.from(picker.classList).find(c => c.startsWith('ql-') && c !== 'ql-picker');
                                    if (pickerClass && tooltips[pickerClass]) {
                                      btnElement.setAttribute('title', tooltips[pickerClass]);
                                    }
                                  }
                                } else {
                                  // Regular button
                                  const btnClass = Array.from(btnElement.classList).find(c => c.startsWith('ql-') && c !== 'ql-toolbar-button');
                                  if (btnClass && tooltips[btnClass]) {
                                    btnElement.setAttribute('title', tooltips[btnClass]);
                                  }
                                }
                              });
                              
                              // Position attach button on toolbar
                              const attachBtn = toolbar.parentElement?.querySelector('.custom-attach-btn');
                              if (attachBtn) {
                                const toolbarRect = toolbar.getBoundingClientRect();
                                const toolbarParent = toolbar.parentElement;
                                if (toolbarParent) {
                                  (attachBtn as HTMLElement).style.position = 'absolute';
                                  (attachBtn as HTMLElement).style.top = `${toolbarRect.top - toolbarParent.getBoundingClientRect().top + 4}px`;
                                  (attachBtn as HTMLElement).style.right = '4px';
                                }
                              }
                            }
                          }
                        }, 100);
                      }
                    }}
                  />
                  {/* Custom attach button positioned on toolbar */}
                  <Tooltip title="Attach file or image" arrow>
                    <IconButton
                      className="custom-attach-btn"
                      size="small"
                      onClick={() => {
                        (fileInputRef.current as any).dataset.id = String(block.id);
                        fileInputRef.current?.click();
                      }}
                      sx={{
                        position: 'absolute',
                        top: 4,
                        right: 4,
                        zIndex: 10,
                        width: 28,
                        height: 28,
                        backgroundColor: 'transparent',
                        '&:hover': {
                          backgroundColor: '#e8eaed',
                        },
                        // Match Quill toolbar button styling
                        borderRadius: '2px',
                      }}
                    >
                      <AttachFile fontSize="small" sx={{ fontSize: '16px' }} />
                    </IconButton>
                  </Tooltip>
                </Box>
              </Box>
            </Box>
          );})}

          <Button startIcon={<Add />} variant="outlined" size="small" onClick={addServiceDefBlock}>
            Add Subsection
          </Button>
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
                onClick={() => handleDownload(generatedFiles?.word_path || generatedFiles?.word_filename)}
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
                onClick={() => handleDownload(generatedFiles?.pdf_path || generatedFiles?.pdf_filename)}
                disabled={!generatedFiles?.pdf_path || !generatedFiles?.pdf_path.startsWith('http')}
              >
                {generatedFiles?.pdf_path && generatedFiles?.pdf_path.startsWith('http') ? 'Download' : 'Coming Soon'}
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

      {/* Hidden file input for attachments */}
      <input
        type="file"
        ref={fileInputRef}
        style={{ display: 'none' }}
        onChange={async (e) => {
          const file = e.target.files?.[0];
          if (!file) return;
          try {
            const id = String((fileInputRef.current as any).dataset.id || '');
            const editor = quillRefs.current[id]?.getEditor?.();
            if (!editor) return;
            const range = editor.getSelection(true) || { index: editor.getLength(), length: 0 };
            if (file.type.startsWith('image/')) {
              const reader = new FileReader();
              reader.onload = () => {
                const dataUrl = reader.result as string;
                const html = `<img src="${dataUrl}" />`;
                editor.clipboard.dangerouslyPasteHTML(range.index, html);
                editor.setSelection(range.index + 1, 0);
              };
              reader.readAsDataURL(file);
            } else {
              const html = `<span>${file.name}</span>`;
              editor.clipboard.dangerouslyPasteHTML(range.index, html);
              editor.setSelection(range.index + 1, 0);
            }
          } finally {
            if (fileInputRef.current) fileInputRef.current.value = '';
          }
        }}
      />
    </Container>
  );
}

