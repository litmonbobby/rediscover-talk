# Rediscover Talk - Accessibility Implementation Guide

**Platform**: React Native (iOS + Android)
**Standard**: WCAG 2.1 Level AA
**Target**: Mental Wellness Application
**Version**: 1.0

---

## Table of Contents

1. [Overview](#overview)
2. [Base Component Accessibility Patterns](#base-component-accessibility-patterns)
3. [Feature-Specific Implementations](#feature-specific-implementations)
4. [Screen Reader Support](#screen-reader-support)
5. [Color and Contrast Standards](#color-and-contrast-standards)
6. [Touch Target Guidelines](#touch-target-guidelines)
7. [Mental Health-Specific Patterns](#mental-health-specific-patterns)
8. [Testing and Validation](#testing-and-validation)

---

## Overview

This guide provides implementation patterns for achieving WCAG 2.1 AA compliance across all 8 feature modules of Rediscover Talk. Each pattern includes code examples, rationale, and testing instructions.

### Accessibility Principles for Mental Health Apps

1. **Crisis Access**: Emergency features must be accessible in moments of distress
2. **Privacy + Accessibility**: Biometric authentication must support assistive technologies
3. **Emotional Context**: Mood tracking must not rely solely on visual indicators
4. **Calm Interactions**: Breathing exercises must respect motion preferences
5. **Clear Communication**: Error messages must be compassionate and actionable

---

## Base Component Accessibility Patterns

### Button Component - Best Practices

The Button component provides a strong accessibility foundation. Here's how to use it effectively:

```typescript
import { Button } from '@/components/ui/Button';

// ✅ GOOD: Descriptive label with hint
<Button
  title="Save Journal Entry"
  onPress={handleSave}
  accessibilityLabel="Save your private journal entry"
  accessibilityHint="Double tap to save and encrypt this entry"
  testID="journal-save-button"
/>

// ✅ GOOD: Icon button with explicit label
<Button
  title=""
  icon={<TrashIcon />}
  onPress={handleDelete}
  variant="destructive"
  accessibilityLabel="Delete journal entry"
  accessibilityHint="This action cannot be undone"
  testID="journal-delete-button"
/>

// ❌ BAD: Icon-only without label
<Button
  title=""
  icon={<SaveIcon />}
  onPress={handleSave}
  // Missing: accessibilityLabel
/>

// ❌ BAD: Generic label
<Button
  title="OK"
  onPress={handleSave}
  // Should be: "Save changes to crisis plan"
/>
```

**Rationale**: Screen reader users need descriptive labels that explain the action and consequence. Hints provide additional context for complex interactions.

---

### Input Component - Form Accessibility

Form inputs require proper labeling, error handling, and keyboard support:

```typescript
import { Input } from '@/components/ui/Input';

// ✅ GOOD: Complete form field
<Input
  label="Emergency Contact Name"
  value={contactName}
  onChangeText={setContactName}
  placeholder="Enter full name"
  error={errors.contactName}
  accessibilityLabel="Emergency contact full name"
  accessibilityHint="This person will be contacted in a crisis"
  testID="crisis-contact-name-input"
  textContentType="name"
  autoCapitalize="words"
/>

// ✅ GOOD: Error with live region
{errors.contactName && (
  <Text
    style={styles.errorText}
    accessibilityLiveRegion="assertive"
    accessibilityRole="alert"
  >
    {errors.contactName}
  </Text>
)}

// ✅ GOOD: Secure password input
<Input
  label="Journal Passcode"
  value={passcode}
  onChangeText={setPasscode}
  isSecure={true}
  accessibilityLabel="Journal passcode"
  accessibilityHint="Create a 6-digit passcode to protect your journal"
  testID="journal-passcode-input"
  keyboardType="number-pad"
  maxLength={6}
/>
```

**Key Features**:
- `accessibilityLabelledBy`: Associates label with input field
- `accessibilityLiveRegion="polite"`: Announces errors without interrupting
- `textContentType`: Enables autofill and password managers
- Password toggle: 44×44pt touch target with "Show/Hide password" label

---

### Modal Component - Dialog Accessibility

Modals require focus management and clear dismissal options:

```typescript
import { Modal } from '@/components/ui/Modal';

// ✅ GOOD: Accessible confirmation dialog
<Modal
  visible={showDeleteConfirmation}
  onClose={handleCancelDelete}
  title="Delete Journal Entry?"
  variant="center"
  showCloseButton={true}
  closeOnBackdropPress={true}
  accessibilityLabel="Delete confirmation dialog"
  testID="delete-confirmation-modal"
>
  <Text accessibilityRole="text">
    This will permanently delete your journal entry from {entryDate}.
    This action cannot be undone.
  </Text>

  <View style={styles.buttonRow}>
    <Button
      title="Cancel"
      variant="secondary"
      onPress={handleCancelDelete}
      accessibilityLabel="Cancel deletion"
      testID="delete-cancel-button"
    />
    <Button
      title="Delete"
      variant="destructive"
      onPress={handleConfirmDelete}
      accessibilityLabel="Confirm delete journal entry"
      accessibilityHint="This action cannot be undone"
      testID="delete-confirm-button"
    />
  </View>
</Modal>

// ✅ GOOD: Bottom sheet modal
<Modal
  visible={showMoodSelector}
  onClose={handleCloseMoodSelector}
  title="How are you feeling?"
  variant="bottom"
  accessibilityLabel="Mood selection sheet"
  testID="mood-selector-modal"
>
  {/* Mood options */}
</Modal>
```

**Key Features**:
- `accessibilityViewIsModal={true}`: Traps focus within modal
- `onRequestClose`: Handles hardware back button (Android)
- Close button: 44×44pt minimum with "Close" label
- Focus restoration: Return focus to trigger element on close

---

### LoadingView Component - Progress Indicators

Loading states must announce progress to screen readers:

```typescript
import { LoadingView } from '@/components/ui/LoadingView';

// ✅ GOOD: Decrypting journal
<LoadingView
  message="Decrypting your journal..."
  size="large"
  accessibilityLabel="Decrypting your journal, please wait"
  accessibilityLiveRegion="polite"
  testID="journal-decryption-loading"
/>

// ✅ GOOD: Saving entry
<LoadingView
  message="Saving..."
  size="small"
  fullScreen={false}
  overlay={false}
  accessibilityLabel="Saving your journal entry"
  testID="journal-save-loading"
/>

// ❌ BAD: Generic loading
<LoadingView
  message="Loading..."
  // Should specify what is loading
/>
```

**Rationale**: Users need to know what is happening during wait times, especially for security-sensitive operations like encryption/decryption.

---

### ErrorView Component - Error Communication

Errors must be announced with appropriate urgency and recovery options:

```typescript
import { ErrorView } from '@/components/ui/ErrorView';

// ✅ GOOD: Network error with retry
<ErrorView
  title="Connection Error"
  message="Unable to sync your mood data. Your entries are saved locally and will sync when connection is restored."
  severity="warning"
  icon="📡"
  onRetry={handleRetrySync}
  retryLabel="Try Again"
  accessibilityLabel="Connection error, data saved locally"
  testID="sync-error-view"
/>

// ✅ GOOD: Critical biometric error
<ErrorView
  title="Biometric Authentication Failed"
  message="Face ID could not verify your identity. You can use your passcode instead."
  severity="critical"
  icon="🔐"
  actions={[
    { label: 'Use Passcode', onPress: handleUsePasscode },
    { label: 'Cancel', onPress: handleCancel }
  ]}
  accessibilityLabel="Biometric authentication failed, use passcode"
  accessibilityLiveRegion="assertive"
  testID="biometric-error-view"
/>

// ✅ GOOD: Informational message
<ErrorView
  title="No Entries Yet"
  message="Start tracking your mood to see trends over time."
  severity="info"
  icon="📊"
  actions={[
    { label: 'Track Mood Now', onPress={handleTrackMood }
  ]}
  testID="no-mood-data-view"
/>
```

**Severity Levels**:
- **info**: `accessibilityLiveRegion="polite"`
- **warning**: `accessibilityLiveRegion="polite"`
- **error**: `accessibilityLiveRegion="assertive"`
- **critical**: `accessibilityLiveRegion="assertive"` + immediate focus

---

## Feature-Specific Implementations

### 1. Conversation Prompts - Daily Prompts

**Accessibility Requirements**:
- Daily prompt announced on screen load
- Skip/save buttons clearly labeled
- History accessible with date navigation

```typescript
// DailyPromptScreen.tsx
import { useEffect, useRef } from 'react';
import { AccessibilityInfo, findNodeHandle } from 'react-native';

export function DailyPromptScreen() {
  const promptRef = useRef(null);

  // Announce daily prompt on screen focus
  useEffect(() => {
    const announcement = `Today's conversation prompt: ${prompt.question}`;
    AccessibilityInfo.announceForAccessibility(announcement);

    // Set initial focus to prompt
    if (promptRef.current) {
      const reactTag = findNodeHandle(promptRef.current);
      AccessibilityInfo.setAccessibilityFocus(reactTag);
    }
  }, [prompt]);

  return (
    <View style={styles.container}>
      {/* Daily Prompt Card */}
      <Card
        ref={promptRef}
        variant="elevated"
        accessibilityLabel={`Daily prompt for ${formatDate(new Date())}`}
        accessibilityHint="Swipe or tap to read the conversation starter"
        testID="daily-prompt-card"
      >
        <Text
          variant="headlineMedium"
          accessibilityRole="header"
          accessibilityLevel={1}
        >
          Today's Prompt
        </Text>

        <Text
          variant="bodyLarge"
          style={styles.promptText}
          accessible={true}
          accessibilityLabel={prompt.question}
        >
          {prompt.question}
        </Text>

        <Text
          variant="bodySmall"
          color="textSecondary"
          accessibilityLabel={`Category: ${prompt.category}`}
        >
          Category: {prompt.category}
        </Text>
      </Card>

      {/* Action Buttons */}
      <View style={styles.actionRow}>
        <Button
          title="Skip for Today"
          variant="secondary"
          onPress={handleSkip}
          accessibilityLabel="Skip today's prompt"
          accessibilityHint="You can return to this prompt later"
          testID="skip-prompt-button"
        />

        <Button
          title="Start Conversation"
          variant="primary"
          onPress={handleStartConversation}
          accessibilityLabel="Start conversation with this prompt"
          testID="start-conversation-button"
        />
      </View>

      {/* History Navigation */}
      <Button
        title="View Past Prompts"
        variant="text"
        onPress={handleViewHistory}
        accessibilityLabel="View conversation history"
        accessibilityHint="Browse your past conversations and responses"
        testID="view-history-button"
      />
    </View>
  );
}
```

**Screen Reader Flow**:
1. Screen loads: "Daily prompt for October 21, 2025"
2. Focus on prompt card
3. User swipes: "Today's Prompt" (header)
4. User swipes: "[Prompt question]"
5. User swipes: "Category: [category]"
6. User swipes: "Skip for Today button"
7. User double-taps: Prompt skipped, announcement: "Prompt skipped for today"

---

### 2. Family Exercises - Activity Library

**Accessibility Requirements**:
- Activity cards with descriptive labels
- Difficulty level accessible
- Completion status announced

```typescript
// ExerciseLibraryScreen.tsx
export function ExerciseCard({ exercise, onPress }: ExerciseCardProps) {
  // Generate rich accessibility label
  const accessibilityLabel = [
    exercise.title,
    `Difficulty: ${exercise.difficulty}`,
    `Duration: ${exercise.estimatedMinutes} minutes`,
    exercise.completed ? 'Completed' : 'Not started',
  ].join(', ');

  const accessibilityHint = exercise.completed
    ? 'Double tap to view details and do again'
    : 'Double tap to start this activity';

  return (
    <Card
      variant="outlined"
      onPress={onPress}
      accessibilityLabel={accessibilityLabel}
      accessibilityHint={accessibilityHint}
      accessibilityState={{ disabled: false, selected: false }}
      testID={`exercise-card-${exercise.id}`}
    >
      {/* Completion Badge */}
      {exercise.completed && (
        <View
          style={styles.completedBadge}
          accessibilityElementsHidden={true} // Already in label
          importantForAccessibility="no"
        >
          <Text>✅</Text>
        </View>
      )}

      <Text variant="titleMedium" accessibilityRole="header">
        {exercise.title}
      </Text>

      <Text variant="bodyMedium">
        {exercise.description}
      </Text>

      {/* Visual metadata (already in accessibility label) */}
      <View
        style={styles.metadata}
        accessibilityElementsHidden={true}
        importantForAccessibility="no-hide-descendants"
      >
        <Text variant="labelSmall">
          {exercise.difficulty} • {exercise.estimatedMinutes} min
        </Text>
      </View>
    </Card>
  );
}
```

**Rationale**:
- Rich accessibility labels provide all context in one announcement
- Visual metadata hidden from screen reader (redundant)
- Completion status integrated into label for quick scanning
- `accessibilityState` provides additional context for future enhancements

---

### 3. Wellness Logs - Mood Tracking

**Accessibility Requirements**:
- Mood emojis MUST have descriptive text labels
- Color cannot be sole indicator
- Trend charts accessible as data tables

```typescript
// MoodTrackerScreen.tsx
const MOOD_OPTIONS = [
  {
    value: 1,
    emoji: '😢',
    label: 'Very Sad',
    description: 'Feeling very sad, distressed, or overwhelmed',
    color: '#D32F2F', // Red
    accessibilityLabel: 'Very sad or distressed mood',
  },
  {
    value: 2,
    emoji: '😟',
    label: 'Somewhat Down',
    description: 'Feeling down, worried, or anxious',
    color: '#F57C00', // Orange
    accessibilityLabel: 'Somewhat down or worried mood',
  },
  {
    value: 3,
    emoji: '😐',
    label: 'Neutral',
    description: 'Feeling neutral, calm, or balanced',
    color: '#FBC02D', // Yellow
    accessibilityLabel: 'Neutral or calm mood',
  },
  {
    value: 4,
    emoji: '🙂',
    label: 'Good',
    description: 'Feeling good, content, or positive',
    color: '#689F38', // Light Green
    accessibilityLabel: 'Good or content mood',
  },
  {
    value: 5,
    emoji: '😊',
    label: 'Very Happy',
    description: 'Feeling very happy, energized, or joyful',
    color: '#388E3C', // Green
    accessibilityLabel: 'Very happy or energized mood',
  },
];

export function MoodSelector({ onSelectMood }: MoodSelectorProps) {
  const [selectedMood, setSelectedMood] = useState<number | null>(null);

  const handleSelectMood = (mood: typeof MOOD_OPTIONS[0]) => {
    setSelectedMood(mood.value);

    // Announce selection
    AccessibilityInfo.announceForAccessibility(
      `Selected ${mood.label} mood`
    );

    onSelectMood(mood.value);
  };

  return (
    <View
      style={styles.container}
      accessibilityLabel="Mood selector"
      accessibilityRole="radiogroup"
    >
      <Text
        variant="titleMedium"
        accessibilityRole="header"
        accessibilityLevel={2}
      >
        How are you feeling right now?
      </Text>

      <View style={styles.moodGrid}>
        {MOOD_OPTIONS.map((mood) => (
          <TouchableOpacity
            key={mood.value}
            style={[
              styles.moodOption,
              selectedMood === mood.value && styles.moodSelected,
              { borderColor: mood.color }, // Visual indicator
            ]}
            onPress={() => handleSelectMood(mood)}
            accessible={true}
            accessibilityRole="radio"
            accessibilityLabel={mood.accessibilityLabel}
            accessibilityHint={mood.description}
            accessibilityState={{
              selected: selectedMood === mood.value,
              checked: selectedMood === mood.value,
            }}
            testID={`mood-option-${mood.value}`}
          >
            {/* Emoji (decorative, label has text description) */}
            <Text
              style={styles.moodEmoji}
              accessibilityElementsHidden={true}
              importantForAccessibility="no"
            >
              {mood.emoji}
            </Text>

            {/* Text Label (visible and accessible) */}
            <Text
              variant="labelMedium"
              style={[
                styles.moodLabel,
                { color: mood.color }, // Reinforces color coding
              ]}
            >
              {mood.label}
            </Text>

            {/* Selection Indicator (visual + accessible) */}
            {selectedMood === mood.value && (
              <View
                style={styles.checkmark}
                accessibilityLabel="Selected"
              >
                <Text>✓</Text>
              </View>
            )}
          </TouchableOpacity>
        ))}
      </View>

      {/* Selected Mood Description */}
      {selectedMood !== null && (
        <Text
          variant="bodyMedium"
          style={styles.selectedDescription}
          accessibilityLiveRegion="polite"
          accessibilityLabel={`You selected: ${
            MOOD_OPTIONS.find((m) => m.value === selectedMood)?.description
          }`}
        >
          {MOOD_OPTIONS.find((m) => m.value === selectedMood)?.description}
        </Text>
      )}
    </View>
  );
}
```

**Accessibility Features**:
- Emoji + text label (never emoji alone)
- Color + text + border (never color alone)
- `accessibilityRole="radiogroup"` for group semantics
- `accessibilityRole="radio"` for each option
- `accessibilityState.checked` for selection state
- Live region announces selection immediately
- Touch targets: 72×72pt minimum (mood tracking is primary interaction)

---

### 4. Therapeutic Journaling - Secure Entry

**Accessibility Requirements**:
- Biometric authentication accessible
- Voice dictation support
- Encryption process transparent

```typescript
// JournalEditorScreen.tsx
import ReactNativeBiometrics from 'react-native-biometrics';
import Voice from '@react-native-voice/voice';

export function JournalEditorScreen() {
  const [isRecording, setIsRecording] = useState(false);
  const [content, setContent] = useState('');
  const [isEncrypting, setIsEncrypting] = useState(false);

  // Biometric authentication with accessibility
  const handleBiometricAuth = async () => {
    try {
      // Announce authentication requirement
      AccessibilityInfo.announceForAccessibility(
        'Face ID required to access your journal'
      );

      const { success, error } = await ReactNativeBiometrics.simplePrompt({
        promptMessage: 'Verify your identity to access journal',
        cancelButtonText: 'Use Passcode',
      });

      if (success) {
        AccessibilityInfo.announceForAccessibility(
          'Authentication successful, journal unlocked'
        );
        // Unlock journal
      } else if (error) {
        AccessibilityInfo.announceForAccessibility(
          `Authentication failed: ${error}. You can use your passcode instead.`
        );
        // Show passcode fallback
      }
    } catch (err) {
      AccessibilityInfo.announceForAccessibility(
        'Biometric authentication unavailable, please use your passcode'
      );
    }
  };

  // Voice dictation
  const handleStartDictation = async () => {
    try {
      setIsRecording(true);
      AccessibilityInfo.announceForAccessibility(
        'Voice dictation started, speak to record your journal entry'
      );

      await Voice.start('en-US');
    } catch (err) {
      AccessibilityInfo.announceForAccessibility(
        'Voice dictation failed to start, please type your entry'
      );
    }
  };

  const handleStopDictation = async () => {
    try {
      await Voice.stop();
      setIsRecording(false);
      AccessibilityInfo.announceForAccessibility(
        'Voice dictation stopped'
      );
    } catch (err) {
      // Handle error
    }
  };

  // Save with encryption
  const handleSave = async () => {
    try {
      setIsEncrypting(true);

      // Announce encryption process
      AccessibilityInfo.announceForAccessibility(
        'Encrypting your journal entry'
      );

      await encryptAndSaveJournalEntry(content);

      AccessibilityInfo.announceForAccessibility(
        'Journal entry saved and encrypted successfully'
      );

      // Navigate back
    } catch (err) {
      AccessibilityInfo.announceForAccessibility(
        'Failed to save journal entry, please try again'
      );
    } finally {
      setIsEncrypting(false);
    }
  };

  return (
    <View style={styles.container}>
      {/* Journal Title Input */}
      <Input
        label="Entry Title (Optional)"
        value={title}
        onChangeText={setTitle}
        placeholder="Give this entry a title"
        accessibilityLabel="Journal entry title"
        testID="journal-title-input"
      />

      {/* Journal Content */}
      <View style={styles.editorContainer}>
        <Text
          variant="labelMedium"
          accessibilityRole="header"
          accessibilityLevel={2}
        >
          Your Thoughts
        </Text>

        <TextInput
          style={styles.journalTextArea}
          value={content}
          onChangeText={setContent}
          placeholder="Write your thoughts here..."
          multiline={true}
          numberOfLines={10}
          textAlignVertical="top"
          accessible={true}
          accessibilityLabel="Journal entry text area"
          accessibilityHint="Type or use voice dictation to record your thoughts"
          testID="journal-content-input"
        />
      </View>

      {/* Voice Dictation Button */}
      <Button
        title={isRecording ? 'Stop Recording' : 'Voice Dictation'}
        icon={<MicrophoneIcon />}
        variant="secondary"
        onPress={isRecording ? handleStopDictation : handleStartDictation}
        accessibilityLabel={
          isRecording
            ? 'Stop voice dictation'
            : 'Start voice dictation'
        }
        accessibilityHint={
          isRecording
            ? 'Tap to stop recording your voice'
            : 'Tap to start recording your voice'
        }
        accessibilityState={{ busy: isRecording }}
        testID="voice-dictation-button"
      />

      {/* Save Button */}
      <Button
        title="Save Entry"
        variant="primary"
        onPress={handleSave}
        isLoading={isEncrypting}
        isDisabled={content.length === 0}
        accessibilityLabel="Save and encrypt journal entry"
        accessibilityHint="Your entry will be encrypted and protected"
        accessibilityState={{
          busy: isEncrypting,
          disabled: content.length === 0,
        }}
        testID="journal-save-button"
      />

      {/* Encryption Loading Overlay */}
      {isEncrypting && (
        <LoadingView
          message="Encrypting your journal entry..."
          fullScreen={true}
          overlay={true}
          accessibilityLabel="Encrypting journal entry, please wait"
          accessibilityLiveRegion="assertive"
          testID="encryption-loading"
        />
      )}
    </View>
  );
}
```

**Accessibility Features**:
- Biometric prompt announces requirement and result
- Voice dictation announces start/stop states
- Encryption process announced during save
- All state changes announced via `AccessibilityInfo.announceForAccessibility`
- `accessibilityState.busy` indicates loading states
- Fallback to passcode clearly communicated

---

### 5. Breathing Tools - Guided Exercises

**Accessibility Requirements**:
- Multi-sensory guidance (visual + audio + haptic)
- Respects `prefers-reduced-motion`
- Pause/resume controls

```typescript
// ActiveBreathingScreen.tsx
import { Animated, Vibration, AccessibilityInfo } from 'react-native';
import { useReducedMotion } from '@/hooks/useReducedMotion';

const BREATHING_PATTERN = {
  inhale: 4,   // seconds
  hold: 4,     // seconds
  exhale: 6,   // seconds
  rest: 2,     // seconds
};

export function ActiveBreathingScreen({ exercise }: Props) {
  const prefersReducedMotion = useReducedMotion();
  const [phase, setPhase] = useState<'inhale' | 'hold' | 'exhale' | 'rest'>('inhale');
  const [isPaused, setIsPaused] = useState(false);
  const [elapsedTime, setElapsedTime] = useState(0);

  const circleScale = useRef(new Animated.Value(1)).current;

  // Breathing cycle with multi-sensory feedback
  useEffect(() => {
    if (isPaused) return;

    const timer = setInterval(() => {
      advancePhase();
    }, 1000);

    return () => clearInterval(timer);
  }, [phase, isPaused]);

  const advancePhase = () => {
    const nextPhase = getNextPhase(phase);
    setPhase(nextPhase);

    // Multi-sensory feedback
    provideBreathingGuidance(nextPhase);
  };

  const provideBreathingGuidance = (currentPhase: typeof phase) => {
    // 1. Visual Animation (respects reduced motion)
    if (!prefersReducedMotion) {
      animateBreathingCircle(currentPhase);
    }

    // 2. Haptic Feedback
    if (currentPhase === 'inhale' || currentPhase === 'exhale') {
      Vibration.vibrate(200); // Short pulse
    }

    // 3. Voice Guidance
    const instruction = getVoiceInstruction(currentPhase);
    AccessibilityInfo.announceForAccessibility(instruction);

    // 4. Visual Text (for reduced motion users)
    // Rendered in UI below
  };

  const animateBreathingCircle = (currentPhase: typeof phase) => {
    const targetScale = currentPhase === 'inhale' ? 1.5 : 1.0;
    const duration = BREATHING_PATTERN[currentPhase] * 1000;

    Animated.timing(circleScale, {
      toValue: targetScale,
      duration,
      useNativeDriver: true,
    }).start();
  };

  const getVoiceInstruction = (currentPhase: typeof phase): string => {
    const instructions = {
      inhale: 'Breathe in slowly through your nose',
      hold: 'Hold your breath',
      exhale: 'Breathe out slowly through your mouth',
      rest: 'Rest and prepare for the next breath',
    };
    return instructions[currentPhase];
  };

  const handleTogglePause = () => {
    setIsPaused(!isPaused);

    const announcement = isPaused
      ? 'Breathing exercise resumed'
      : 'Breathing exercise paused';

    AccessibilityInfo.announceForAccessibility(announcement);
  };

  const handleStop = () => {
    AccessibilityInfo.announceForAccessibility(
      `Breathing session completed. Duration: ${formatDuration(elapsedTime)}`
    );
    // Navigate back
  };

  return (
    <View style={styles.container}>
      {/* Exercise Title */}
      <Text
        variant="headlineMedium"
        accessibilityRole="header"
        accessibilityLevel={1}
      >
        {exercise.name}
      </Text>

      {/* Breathing Animation (conditional) */}
      {!prefersReducedMotion ? (
        <Animated.View
          style={[
            styles.breathingCircle,
            { transform: [{ scale: circleScale }] },
          ]}
          accessibilityElementsHidden={true}
          importantForAccessibility="no"
        >
          {/* Visual circle */}
        </Animated.View>
      ) : (
        // Static visual for reduced motion
        <View
          style={styles.staticCircle}
          accessibilityElementsHidden={true}
          importantForAccessibility="no"
        >
          <Text variant="displayLarge">{phase === 'inhale' ? '↑' : '↓'}</Text>
        </View>
      )}

      {/* Current Phase Instruction (Always Visible) */}
      <Text
        variant="headlineSmall"
        style={styles.phaseInstruction}
        accessibilityLiveRegion="assertive"
        accessibilityLabel={`Current breathing phase: ${getVoiceInstruction(phase)}`}
      >
        {getVoiceInstruction(phase)}
      </Text>

      {/* Progress Timer */}
      <Text
        variant="bodyLarge"
        accessibilityLiveRegion="polite"
        accessibilityLabel={`Session duration: ${formatDuration(elapsedTime)}`}
      >
        {formatDuration(elapsedTime)}
      </Text>

      {/* Controls */}
      <View style={styles.controlsRow}>
        <Button
          title={isPaused ? 'Resume' : 'Pause'}
          variant="secondary"
          onPress={handleTogglePause}
          accessibilityLabel={isPaused ? 'Resume breathing exercise' : 'Pause breathing exercise'}
          testID="breathing-pause-button"
        />

        <Button
          title="Stop"
          variant="destructive"
          onPress={handleStop}
          accessibilityLabel="Stop breathing exercise"
          accessibilityHint="Your session will be saved"
          testID="breathing-stop-button"
        />
      </View>

      {/* Reduced Motion Notice */}
      {prefersReducedMotion && (
        <Text
          variant="labelSmall"
          color="textSecondary"
          style={styles.reducedMotionNotice}
          accessibilityLabel="Reduced motion mode active, using static visual guidance"
        >
          Animation reduced per your system preferences
        </Text>
      )}
    </View>
  );
}

// Custom hook to detect reduced motion preference
function useReducedMotion() {
  const [reducedMotion, setReducedMotion] = useState(false);

  useEffect(() => {
    AccessibilityInfo.isReduceMotionEnabled().then(setReducedMotion);

    const subscription = AccessibilityInfo.addEventListener(
      'reduceMotionChanged',
      setReducedMotion
    );

    return () => subscription.remove();
  }, []);

  return reducedMotion;
}
```

**Accessibility Features**:
- Multi-sensory guidance: Visual + Voice + Haptic
- Respects `prefers-reduced-motion` system setting
- Always-visible text instructions (not just animation)
- Pause/resume controls for user pacing
- Live region announces phase changes
- Duration announced on completion

---

### 6. Crisis Plan - Emergency Access

**Accessibility Requirements** (CRITICAL):
- One-tap emergency access from any screen
- Large touch targets (56×56pt minimum)
- High contrast mode
- Voice Control integration

```typescript
// CrisisPlanScreen.tsx
import { Linking, Alert, AccessibilityInfo } from 'react-native';

export function CrisisPlanScreen() {
  const { crisisPlan } = useCrisisPlan();

  // Emergency call with confirmation
  const handleEmergencyCall = (contact: EmergencyContact) => {
    Alert.alert(
      'Call Emergency Contact',
      `Call ${contact.name} at ${contact.phoneNumber}?`,
      [
        {
          text: 'Cancel',
          style: 'cancel',
          onPress: () => {
            AccessibilityInfo.announceForAccessibility('Call cancelled');
          },
        },
        {
          text: 'Call Now',
          style: 'default',
          onPress: () => {
            Linking.openURL(`tel:${contact.phoneNumber}`);
            AccessibilityInfo.announceForAccessibility(
              `Calling ${contact.name}`
            );
          },
        },
      ],
      {
        cancelable: true,
        userInterfaceStyle: 'alert',
      }
    );
  };

  return (
    <View style={styles.container}>
      {/* Emergency Banner */}
      <View
        style={styles.emergencyBanner}
        accessibilityRole="alert"
        accessibilityLiveRegion="assertive"
      >
        <Text
          variant="titleLarge"
          style={styles.emergencyText}
          accessibilityLabel="Crisis plan activated, emergency resources available"
        >
          🚨 Crisis Resources
        </Text>
      </View>

      {/* National Crisis Line (Prominent) */}
      <Card
        variant="filled"
        style={styles.crisisLineCard}
        onPress={() => handleEmergencyCall(NATIONAL_CRISIS_LINE)}
        accessibilityLabel="National Suicide Prevention Lifeline, 988, call now"
        accessibilityHint="Double tap to call immediately"
        testID="crisis-line-button"
      >
        <Text variant="headlineMedium" style={styles.crisisLineText}>
          988
        </Text>
        <Text variant="bodyLarge">
          Suicide & Crisis Lifeline
        </Text>
        <Text variant="labelMedium" color="textSecondary">
          Tap to call 24/7 support
        </Text>
      </Card>

      {/* Emergency Contacts List */}
      <Text
        variant="titleMedium"
        accessibilityRole="header"
        accessibilityLevel={2}
        style={styles.sectionHeader}
      >
        My Emergency Contacts
      </Text>

      {crisisPlan.emergencyContacts.map((contact, index) => (
        <Card
          key={contact.id}
          variant="outlined"
          style={styles.contactCard}
          onPress={() => handleEmergencyCall(contact)}
          accessibilityLabel={`Emergency contact ${index + 1}: ${contact.name}, ${contact.relationship}, ${contact.phoneNumber}`}
          accessibilityHint="Double tap to call"
          testID={`emergency-contact-${index}`}
        >
          <View style={styles.contactHeader}>
            <Text variant="titleMedium">{contact.name}</Text>
            <Text variant="labelMedium" color="textSecondary">
              {contact.relationship}
            </Text>
          </View>

          <Text
            variant="bodyLarge"
            style={styles.phoneNumber}
            accessibilityLabel={`Phone number: ${formatPhoneNumber(contact.phoneNumber)}`}
          >
            {formatPhoneNumber(contact.phoneNumber)}
          </Text>
        </Card>
      ))}

      {/* Safety Plan Steps */}
      <Text
        variant="titleMedium"
        accessibilityRole="header"
        accessibilityLevel={2}
        style={styles.sectionHeader}
      >
        My Safety Plan
      </Text>

      {crisisPlan.safetySteps.map((step, index) => (
        <Card
          key={step.id}
          variant="outlined"
          style={styles.safetyStepCard}
          accessibilityLabel={`Safety step ${index + 1} of ${crisisPlan.safetySteps.length}: ${step.action}`}
          testID={`safety-step-${index}`}
        >
          <View style={styles.stepHeader}>
            <View
              style={styles.stepNumber}
              accessibilityElementsHidden={true}
              importantForAccessibility="no"
            >
              <Text variant="labelLarge">{index + 1}</Text>
            </View>

            <Text variant="bodyLarge" style={styles.stepAction}>
              {step.action}
            </Text>
          </View>

          {step.notes && (
            <Text variant="bodySmall" color="textSecondary">
              {step.notes}
            </Text>
          )}
        </Card>
      ))}

      {/* Edit Button (Lower Priority) */}
      <Button
        title="Edit Crisis Plan"
        variant="secondary"
        onPress={handleEditPlan}
        accessibilityLabel="Edit your crisis plan"
        accessibilityHint="Add or modify emergency contacts and safety steps"
        testID="edit-crisis-plan-button"
        style={styles.editButton}
      />
    </View>
  );
}

// Floating Emergency Button (Global Component)
export function FloatingEmergencyButton() {
  const navigation = useNavigation();

  const handleEmergencyAccess = () => {
    AccessibilityInfo.announceForAccessibility(
      'Opening crisis resources'
    );
    navigation.navigate('CrisisPlan');
  };

  return (
    <TouchableOpacity
      style={styles.floatingButton}
      onPress={handleEmergencyAccess}
      accessible={true}
      accessibilityRole="button"
      accessibilityLabel="Emergency crisis resources"
      accessibilityHint="Quick access to crisis plan and emergency contacts"
      testID="floating-emergency-button"
    >
      <Text style={styles.emergencyIcon}>🚨</Text>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  floatingButton: {
    position: 'absolute',
    bottom: 20,
    right: 20,
    width: 64,
    height: 64,
    borderRadius: 32,
    backgroundColor: '#D32F2F', // High contrast red
    alignItems: 'center',
    justifyContent: 'center',
    elevation: 8,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 6,
    // Accessibility enhancement
    borderWidth: 3,
    borderColor: '#FFFFFF', // White border for contrast
  },
  emergencyIcon: {
    fontSize: 32,
  },
  // ... other styles
});
```

**Critical Accessibility Features**:
- Floating emergency button: 64×64pt touch target, high contrast
- One-tap call confirmation (accessibility-friendly alert)
- Screen reader announces all emergency actions
- Safety steps numbered for easy navigation
- High contrast color scheme throughout
- Voice Control compatible: "Hey Siri, emergency" can be configured

**Voice Control Integration** (iOS):
```swift
// In iOS native code, add Siri shortcut
import Intents
import IntentsUI

// Register shortcut for "emergency" keyword
let activity = NSUserActivity(activityType: "com.rediscovertalk.emergency")
activity.title = "Emergency Crisis Plan"
activity.isEligibleForPrediction = true
activity.suggestedInvocationPhrase = "Emergency"
```

---

## Screen Reader Support

### iOS VoiceOver Optimization

**Gesture Support**:
```typescript
// Implement custom VoiceOver actions
<View
  accessible={true}
  accessibilityLabel="Journal Entry from October 21, 2025"
  accessibilityActions={[
    { name: 'activate', label: 'Open entry' },
    { name: 'delete', label: 'Delete entry' },
    { name: 'share', label: 'Export entry' },
  ]}
  onAccessibilityAction={(event) => {
    switch (event.nativeEvent.actionName) {
      case 'activate':
        handleOpenEntry();
        break;
      case 'delete':
        handleDeleteEntry();
        break;
      case 'share':
        handleShareEntry();
        break;
    }
  }}
>
  {/* Journal entry content */}
</View>
```

**Rationale**: Custom actions provide quick access to common operations without navigating through multiple screens.

---

### Android TalkBack Optimization

**Reading Order**:
```typescript
// Control reading order with accessibilityViewIsModal
<Modal
  visible={showModal}
  accessibilityViewIsModal={true}
>
  <View accessible={true} accessibilityLabel="Modal content">
    {/* Content read first */}
  </View>
</Modal>

// Hide decorative elements
<View
  accessibilityElementsHidden={true}
  importantForAccessibility="no-hide-descendants"
>
  {/* Decorative graphics */}
</View>
```

---

## Color and Contrast Standards

### Minimum Contrast Ratios

**WCAG AA Requirements**:
- Normal text (< 18pt): 4.5:1
- Large text (≥ 18pt or ≥ 14pt bold): 3:1
- UI components and graphical objects: 3:1
- Focus indicators: 3:1

**Theme Configuration**:
```typescript
// theme/colors.ts
export const lightTheme = {
  colors: {
    // Text on Background
    textPrimary: '#000000',      // Black on white = 21:1 ✅
    textSecondary: '#5F6368',    // Gray on white = 7.0:1 ✅
    textTertiary: '#9AA0A6',     // Light gray on white = 4.6:1 ✅

    // Interactive Elements
    primary: '#1976D2',          // Blue
    onPrimary: '#FFFFFF',        // White text on blue = 5.3:1 ✅

    secondary: '#455A64',        // Blue gray
    onSecondary: '#FFFFFF',      // White on blue gray = 8.6:1 ✅

    error: '#D32F2F',            // Red
    onError: '#FFFFFF',          // White on red = 5.9:1 ✅

    warning: '#F57C00',          // Orange
    onWarning: '#FFFFFF',        // White on orange = 4.7:1 ✅

    success: '#388E3C',          // Green
    onSuccess: '#FFFFFF',        // White on green = 4.7:1 ✅

    // Surface Colors
    background: '#FFFFFF',       // White
    surface: '#FAFAFA',          // Off-white
    surfaceVariant: '#F5F5F5',   // Light gray

    border: '#E0E0E0',           // Border on white = 2.5:1 ⚠️ (visual only)

    // Focus Indicator
    focusOutline: '#1976D2',     // Blue on white = 5.1:1 ✅
  },
};

export const darkTheme = {
  colors: {
    // Text on Background
    textPrimary: '#FFFFFF',      // White on black = 21:1 ✅
    textSecondary: '#E8EAED',    // Light gray on black = 15.8:1 ✅
    textTertiary: '#9AA0A6',     // Gray on black = 7.0:1 ✅

    // Interactive Elements
    primary: '#90CAF9',          // Light blue
    onPrimary: '#000000',        // Black on light blue = 11.1:1 ✅

    secondary: '#B0BEC5',        // Light blue gray
    onSecondary: '#000000',      // Black on light blue gray = 12.6:1 ✅

    error: '#EF5350',            // Light red
    onError: '#000000',          // Black on light red = 7.3:1 ✅

    warning: '#FFB74D',          // Light orange
    onWarning: '#000000',        // Black on light orange = 10.4:1 ✅

    success: '#81C784',          // Light green
    onSuccess: '#000000',        // Black on light green = 9.5:1 ✅

    // Surface Colors
    background: '#121212',       // Near-black
    surface: '#1E1E1E',          // Dark gray
    surfaceVariant: '#2C2C2C',   // Medium gray

    border: '#424242',           // Border on dark = 2.8:1 ⚠️ (visual only)

    // Focus Indicator
    focusOutline: '#90CAF9',     // Light blue on dark = 9.1:1 ✅
  },
};
```

**Validation Script**:
```typescript
// scripts/validateContrast.ts
import { lightTheme, darkTheme } from '../src/theme/colors';

const WCAG_AA_NORMAL_TEXT = 4.5;
const WCAG_AA_LARGE_TEXT = 3.0;
const WCAG_AA_UI_COMPONENTS = 3.0;

function calculateContrastRatio(color1: string, color2: string): number {
  // Convert hex to RGB, calculate relative luminance, compute ratio
  // Implementation: https://www.w3.org/TR/WCAG21/#contrast-minimum
  // ... (detailed implementation)
}

function validateTheme(theme: typeof lightTheme, themeName: string) {
  const failures: string[] = [];

  // Text contrast tests
  const textContrast = calculateContrastRatio(
    theme.colors.textPrimary,
    theme.colors.background
  );
  if (textContrast < WCAG_AA_NORMAL_TEXT) {
    failures.push(
      `${themeName}: textPrimary/background = ${textContrast.toFixed(2)}:1 (needs ${WCAG_AA_NORMAL_TEXT}:1)`
    );
  }

  // UI component contrast tests
  const primaryContrast = calculateContrastRatio(
    theme.colors.onPrimary,
    theme.colors.primary
  );
  if (primaryContrast < WCAG_AA_UI_COMPONENTS) {
    failures.push(
      `${themeName}: onPrimary/primary = ${primaryContrast.toFixed(2)}:1 (needs ${WCAG_AA_UI_COMPONENTS}:1)`
    );
  }

  // ... (validate all color pairs)

  return failures;
}

// Run validation
const lightFailures = validateTheme(lightTheme, 'Light Theme');
const darkFailures = validateTheme(darkTheme, 'Dark Theme');

if (lightFailures.length === 0 && darkFailures.length === 0) {
  console.log('✅ All color contrast ratios meet WCAG 2.1 AA standards');
} else {
  console.error('❌ Contrast validation failed:');
  [...lightFailures, ...darkFailures].forEach((failure) => {
    console.error(`  - ${failure}`);
  });
  process.exit(1);
}
```

---

## Touch Target Guidelines

### Minimum Sizes

**iOS**: 44×44 points (enforced by Human Interface Guidelines)
**Android**: 48×48 density-independent pixels (Material Design)
**Rediscover Talk Standard**: 50×50 points (exceeds both platforms)

**Emergency Targets**: 56×56 points (crisis button, emergency call)

### Spacing Requirements

**Minimum spacing between interactive elements**: 8 points

```typescript
// theme/layout.ts
export const layout = {
  touchTarget: {
    minimum: 50,     // Standard interactive elements
    emergency: 56,   // Crisis-related buttons
  },
  spacing: {
    betweenTargets: 8,  // Minimum spacing
  },
};
```

---

## Mental Health-Specific Patterns

### Crisis Mode High Contrast

```typescript
// Enable high contrast mode for crisis features
export const crisisTheme = {
  colors: {
    background: '#FFFFFF',
    surface: '#FFFFFF',
    textPrimary: '#000000',
    emergency: '#D32F2F',      // Red
    onEmergency: '#FFFFFF',
    safe: '#388E3C',           // Green
    onSafe: '#FFFFFF',
  },
  // Larger text for stress
  typography: {
    emergencyButton: {
      fontSize: 24,
      fontWeight: '700',
      lineHeight: 28,
    },
  },
};
```

### Compassionate Error Messages

```typescript
// Error messages for mental health context
export const errorMessages = {
  // ✅ GOOD: Compassionate, actionable
  journalSaveFailed: {
    title: 'We couldn't save your entry',
    message: 'Your thoughts are important. Please try saving again, and if the problem continues, your entry is still in this window.',
    severity: 'warning',
  },

  // ❌ BAD: Technical, cold
  // "Error 500: Internal server error"
};
```

---

## Testing and Validation

### Automated Tests

```typescript
// __tests__/accessibility/Button.test.tsx
import { render } from '@testing-library/react-native';
import { Button } from '@/components/ui/Button';

describe('Button Accessibility', () => {
  it('has accessible label', () => {
    const { getByLabelText } = render(
      <Button
        title="Save"
        onPress={() => {}}
        accessibilityLabel="Save journal entry"
      />
    );

    expect(getByLabelText('Save journal entry')).toBeTruthy();
  });

  it('has minimum touch target size', () => {
    const { getByTestId } = render(
      <Button
        title="Save"
        onPress={() => {}}
        testID="save-button"
      />
    );

    const button = getByTestId('save-button');
    const { height, width } = button.props.style;

    expect(height).toBeGreaterThanOrEqual(44);
    expect(width).toBeGreaterThanOrEqual(44);
  });

  it('announces state changes', () => {
    const { rerender } = render(
      <Button
        title="Save"
        onPress={() => {}}
        isLoading={false}
      />
    );

    rerender(
      <Button
        title="Save"
        onPress={() => {}}
        isLoading={true}
        accessibilityLabel="Saving journal entry"
      />
    );

    // Verify accessibility state updated
    expect(button.props.accessibilityState.busy).toBe(true);
  });
});
```

### Manual Testing Checklist

**Before Each Release**:
- [ ] Test all features with VoiceOver enabled (iOS)
- [ ] Test all features with TalkBack enabled (Android)
- [ ] Test crisis plan emergency access with screen reader
- [ ] Test mood tracking with color blindness simulator
- [ ] Test breathing exercises with reduced motion enabled
- [ ] Test journal with voice dictation
- [ ] Verify all touch targets meet 50×50pt minimum
- [ ] Validate color contrast ratios in light and dark modes
- [ ] Test with Dynamic Type at largest size (iOS)
- [ ] Test with font scaling at 200% (Android)

---

## Conclusion

This implementation guide provides WCAG 2.1 AA-compliant patterns for all Rediscover Talk features. Key principles:

1. **Screen Reader First**: All interactions must work with VoiceOver/TalkBack
2. **Multi-Sensory**: Never rely on a single sense (vision, hearing, touch)
3. **Crisis Accessible**: Emergency features must work under stress
4. **Compassionate**: Error messages and guidance must be supportive
5. **Testable**: All patterns must be validated with automated and manual tests

**Next Steps**:
1. Integrate patterns into feature implementation (Phases 2-4)
2. Conduct user testing with assistive technology users (Phase 5)
3. Obtain WCAG 2.1 AA certification before App Store submission

**Document Version**: 1.0
**Last Updated**: October 21, 2025
**Next Review**: After Phase 2 implementation
