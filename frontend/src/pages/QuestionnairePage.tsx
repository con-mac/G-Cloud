/**
 * G-Cloud Capabilities Questionnaire Page
 * Displays questionnaire with pagination by section
 */

import { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import {
  Container,
  Box,
  Typography,
  Button,
  Paper,
  FormControl,
  FormLabel,
  RadioGroup,
  FormControlLabel,
  Radio,
  Checkbox,
  TextField,
  FormGroup,
  CircularProgress,
  Stepper,
  Step,
  StepLabel,
  Alert,
  Chip,
} from '@mui/material';
import {
  ArrowBack as ArrowBackIcon,
  ArrowForward as ArrowForwardIcon,
  Save as SaveIcon,
  Lock as LockIcon,
} from '@mui/icons-material';
import questionnaireApi, { Question, QuestionnaireData, QuestionAnswer } from '../services/questionnaireApi';

export default function QuestionnairePage() {
  const { serviceName, lot } = useParams<{ serviceName: string; lot: string }>();
  const navigate = useNavigate();
  
  const [loading, setLoading] = useState(true);
  const [questionnaireData, setQuestionnaireData] = useState<QuestionnaireData | null>(null);
  const [currentSectionIndex, setCurrentSectionIndex] = useState(0);
  const [answers, setAnswers] = useState<Record<string, any>>({});
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);

  useEffect(() => {
    if (lot && serviceName) {
      loadQuestionnaire();
    }
  }, [lot, serviceName]);

  const loadQuestionnaire = async () => {
    try {
      setLoading(true);
      setError(null);
      
      const data = await questionnaireApi.getQuestions(lot!, serviceName, '15');
      setQuestionnaireData(data);
      
      // Load saved answers if available
      if (data.saved_answers) {
        setAnswers(data.saved_answers);
      }
      
      // Pre-fill service name if available
      if (serviceName) {
        for (const sectionName of data.section_order) {
          const questions = data.sections[sectionName] || [];
          for (const question of questions) {
            if (question.prefilled_answer) {
              setAnswers(prev => ({
                ...prev,
                [question.question_text]: question.prefilled_answer,
              }));
            }
          }
        }
      }
    } catch (err: any) {
      setError(err.response?.data?.detail || 'Failed to load questionnaire');
    } finally {
      setLoading(false);
    }
  };

  const handleAnswerChange = (questionText: string, answer: any) => {
    setAnswers(prev => ({
      ...prev,
      [questionText]: answer,
    }));
  };

  const handleSaveDraft = async () => {
    if (!questionnaireData) return;
    
    try {
      setSaving(true);
      setError(null);
      setSuccessMessage(null);
      
      // Convert answers to QuestionAnswer format
      const questionAnswers: QuestionAnswer[] = [];
      for (const sectionName of questionnaireData.section_order) {
        const questions = questionnaireData.sections[sectionName] || [];
        for (const question of questions) {
          if (answers[question.question_text] !== undefined) {
            questionAnswers.push({
              question_text: question.question_text,
              question_type: question.question_type,
              answer: answers[question.question_text],
              section_name: sectionName,
            });
          }
        }
      }
      
      await questionnaireApi.saveResponses({
        service_name: questionnaireData.service_name,
        lot: questionnaireData.lot,
        gcloud_version: questionnaireData.gcloud_version,
        answers: questionAnswers,
        is_draft: true,
        is_locked: false,
      });
      
      setSuccessMessage('Draft saved successfully!');
      setTimeout(() => setSuccessMessage(null), 3000);
    } catch (err: any) {
      setError(err.response?.data?.detail || 'Failed to save draft');
    } finally {
      setSaving(false);
    }
  };

  const handleLock = async () => {
    if (!questionnaireData) return;
    
    if (!confirm('Are you sure you want to lock this questionnaire? Once locked, you cannot edit it.')) {
      return;
    }
    
    try {
      setSaving(true);
      setError(null);
      setSuccessMessage(null);
      
      // Convert answers to QuestionAnswer format
      const questionAnswers: QuestionAnswer[] = [];
      for (const sectionName of questionnaireData.section_order) {
        const questions = questionnaireData.sections[sectionName] || [];
        for (const question of questions) {
          if (answers[question.question_text] !== undefined) {
            questionAnswers.push({
              question_text: question.question_text,
              question_type: question.question_type,
              answer: answers[question.question_text],
              section_name: sectionName,
            });
          }
        }
      }
      
      await questionnaireApi.saveResponses({
        service_name: questionnaireData.service_name,
        lot: questionnaireData.lot,
        gcloud_version: questionnaireData.gcloud_version,
        answers: questionAnswers,
        is_draft: false,
        is_locked: true,
      });
      
      setSuccessMessage('Questionnaire locked successfully!');
      // Reload to get updated locked status
      await loadQuestionnaire();
    } catch (err: any) {
      setError(err.response?.data?.detail || 'Failed to lock questionnaire');
    } finally {
      setSaving(false);
    }
  };

  const handleNext = () => {
    if (questionnaireData && currentSectionIndex < questionnaireData.section_order.length - 1) {
      setCurrentSectionIndex(prev => prev + 1);
    }
  };

  const handlePrevious = () => {
    if (currentSectionIndex > 0) {
      setCurrentSectionIndex(prev => prev - 1);
    }
  };

  const handleSectionClick = (index: number) => {
    setCurrentSectionIndex(index);
  };

  const renderQuestion = (question: Question, sectionName: string) => {
    const currentAnswer = answers[question.question_text];
    
    switch (question.question_type) {
      case 'radio':
        return (
          <FormControl key={question.question_text} fullWidth sx={{ mb: 3 }}>
            <FormLabel component="legend" sx={{ mb: 1, fontWeight: 600 }}>
              {question.question_text}
            </FormLabel>
            {question.question_hint && (
              <Typography variant="caption" color="text.secondary" sx={{ mb: 1, display: 'block' }}>
                {question.question_hint}
              </Typography>
            )}
            {question.question_advice && (
              <Typography variant="body2" color="text.secondary" sx={{ mb: 1, fontStyle: 'italic' }}>
                {question.question_advice}
              </Typography>
            )}
            <RadioGroup
              value={currentAnswer || ''}
              onChange={(e) => handleAnswerChange(question.question_text, e.target.value)}
            >
              {question.answer_options?.map((option, idx) => (
                <FormControlLabel
                  key={idx}
                  value={option}
                  control={<Radio />}
                  label={option}
                />
              ))}
            </RadioGroup>
          </FormControl>
        );
      
      case 'checkbox':
        return (
          <FormControl key={question.question_text} fullWidth component="fieldset" sx={{ mb: 3 }}>
            <FormLabel component="legend" sx={{ mb: 1, fontWeight: 600 }}>
              {question.question_text}
            </FormLabel>
            {question.question_hint && (
              <Typography variant="caption" color="text.secondary" sx={{ mb: 1, display: 'block' }}>
                {question.question_hint}
              </Typography>
            )}
            {question.question_advice && (
              <Typography variant="body2" color="text.secondary" sx={{ mb: 1, fontStyle: 'italic' }}>
                {question.question_advice}
              </Typography>
            )}
            <FormGroup>
              {question.answer_options?.map((option, idx) => (
                <FormControlLabel
                  key={idx}
                  control={
                    <Checkbox
                      checked={(currentAnswer || []).includes(option)}
                      onChange={(e) => {
                        const current = (currentAnswer || []) as string[];
                        if (e.target.checked) {
                          handleAnswerChange(question.question_text, [...current, option]);
                        } else {
                          handleAnswerChange(question.question_text, current.filter(v => v !== option));
                        }
                      }}
                    />
                  }
                  label={option}
                />
              ))}
            </FormGroup>
          </FormControl>
        );
      
      case 'textarea':
        return (
          <TextField
            key={question.question_text}
            fullWidth
            multiline
            rows={4}
            label={question.question_text}
            value={currentAnswer || ''}
            onChange={(e) => handleAnswerChange(question.question_text, e.target.value)}
            helperText={question.question_hint || question.question_advice}
            sx={{ mb: 3 }}
          />
        );
      
      case 'list':
        // List of text fields (like features/benefits)
        const listItems = currentAnswer || [''];
        return (
          <Box key={question.question_text} sx={{ mb: 3 }}>
            <FormLabel component="legend" sx={{ mb: 1, fontWeight: 600, display: 'block' }}>
              {question.question_text}
            </FormLabel>
            {question.question_hint && (
              <Typography variant="caption" color="text.secondary" sx={{ mb: 1, display: 'block' }}>
                {question.question_hint}
              </Typography>
            )}
            {question.question_advice && (
              <Typography variant="body2" color="text.secondary" sx={{ mb: 1, fontStyle: 'italic' }}>
                {question.question_advice}
              </Typography>
            )}
            {listItems.map((item: string, idx: number) => (
              <TextField
                key={idx}
                fullWidth
                value={item}
                onChange={(e) => {
                  const newList = [...listItems];
                  newList[idx] = e.target.value;
                  handleAnswerChange(question.question_text, newList);
                }}
                sx={{ mb: 1 }}
                placeholder={`Item ${idx + 1}`}
              />
            ))}
            <Button
              size="small"
              onClick={() => {
                handleAnswerChange(question.question_text, [...listItems, '']);
              }}
              sx={{ mt: 1 }}
            >
              Add Item
            </Button>
          </Box>
        );
      
      case 'text':
      default:
        return (
          <TextField
            key={question.question_text}
            fullWidth
            label={question.question_text}
            value={currentAnswer || ''}
            onChange={(e) => handleAnswerChange(question.question_text, e.target.value)}
            helperText={question.question_hint || question.question_advice}
            sx={{ mb: 3 }}
          />
        );
    }
  };

  if (loading) {
    return (
      <Container maxWidth="lg" sx={{ py: 4 }}>
        <Box display="flex" justifyContent="center" alignItems="center" minHeight="400px">
          <CircularProgress />
        </Box>
      </Container>
    );
  }

  if (!questionnaireData) {
    return (
      <Container maxWidth="lg" sx={{ py: 4 }}>
        <Alert severity="error">Failed to load questionnaire</Alert>
      </Container>
    );
  }

  const currentSectionName = questionnaireData.section_order[currentSectionIndex];
  const currentQuestions = questionnaireData.sections[currentSectionName] || [];
  const totalSections = questionnaireData.section_order.length;

  return (
    <Container maxWidth="lg" sx={{ py: 4 }}>
      <Box sx={{ mb: 4 }}>
        <Typography variant="h4" gutterBottom>
          G-Cloud Capabilities Questionnaire
        </Typography>
        <Typography variant="body1" color="text.secondary" gutterBottom>
          Service: {questionnaireData.service_name} | LOT: {questionnaireData.lot} | G-Cloud {questionnaireData.gcloud_version}
        </Typography>
        {questionnaireData.is_locked && (
          <Chip
            icon={<LockIcon />}
            label="Locked"
            color="warning"
            sx={{ mt: 1 }}
          />
        )}
      </Box>

      {error && (
        <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>
          {error}
        </Alert>
      )}

      {successMessage && (
        <Alert severity="success" sx={{ mb: 2 }} onClose={() => setSuccessMessage(null)}>
          {successMessage}
        </Alert>
      )}

      {/* Section Stepper */}
      <Paper sx={{ p: 2, mb: 3 }}>
        <Stepper activeStep={currentSectionIndex} alternativeLabel>
          {questionnaireData.section_order.map((sectionName, index) => (
            <Step key={sectionName}>
              <StepLabel
                onClick={() => handleSectionClick(index)}
                sx={{ cursor: 'pointer' }}
              >
                {sectionName}
              </StepLabel>
            </Step>
          ))}
        </Stepper>
      </Paper>

      {/* Current Section */}
      <Paper sx={{ p: 4, mb: 3 }}>
        <Typography variant="h5" gutterBottom>
          {currentSectionName}
        </Typography>
        <Typography variant="body2" color="text.secondary" sx={{ mb: 3 }}>
          Section {currentSectionIndex + 1} of {totalSections}
        </Typography>

        {currentQuestions.map((question) => renderQuestion(question, currentSectionName))}
      </Paper>

      {/* Navigation */}
      <Box display="flex" justifyContent="space-between" alignItems="center">
        <Button
          startIcon={<ArrowBackIcon />}
          onClick={handlePrevious}
          disabled={currentSectionIndex === 0 || questionnaireData.is_locked}
        >
          Previous
        </Button>

        <Box>
          <Button
            startIcon={<SaveIcon />}
            onClick={handleSaveDraft}
            disabled={saving || questionnaireData.is_locked}
            sx={{ mr: 2 }}
          >
            {saving ? <CircularProgress size={24} /> : 'Save Draft'}
          </Button>
          <Button
            startIcon={<LockIcon />}
            onClick={handleLock}
            disabled={saving || questionnaireData.is_locked}
            variant="contained"
            color="warning"
          >
            Lock Questionnaire
          </Button>
        </Box>

        <Button
          endIcon={<ArrowForwardIcon />}
          onClick={handleNext}
          disabled={currentSectionIndex === totalSections - 1 || questionnaireData.is_locked}
          variant="contained"
        >
          Next
        </Button>
      </Box>
    </Container>
  );
}

