# ADR 002: Navigation Architecture with React Navigation

**Status**: Accepted
**Date**: 2025-10-21
**Deciders**: Enterprise Architect, UI/UX Team
**Framework Compliance**: LitmonCloud MVVM-C Coordinator Pattern

---

## Context

Rediscover Talk requires sophisticated navigation across 8 feature modules with tab-based main navigation, hierarchical feature navigation, modal crisis access, and deep linking support. MVVM-C coordinator pattern mandates navigation logic separation from Views and ViewModels.

**Key Requirements**:
- Bottom tab navigation for 5 main sections (Home, Wellness, Journal, Tools, Profile)
- Stack navigation within each feature for detail screens
- Modal presentation for crisis plan (emergency access)
- Type-safe routing with TypeScript
- Deep linking support for conversation prompts, journal entries
- Coordinator pattern compliance (navigation separate from ViewModels)
- Accessibility-compliant navigation (screen reader support)

---

## Decision

**Chosen Solution**: React Navigation v6 with Native Stack Navigator and Bottom Tabs

**Architecture**:
- RootNavigator (Stack) → MainTabs (Bottom Tabs) → Feature Stacks
- Type-safe navigation with TypeScript route parameters
- Centralized NavigationService for coordinator pattern
- Modal overlays for crisis plan emergency access

---

## Alternatives Considered

### Option 1: React Native Navigation (Wix)
**Pros**:
- Native navigation performance
- Platform-specific animations

**Cons**:
- ❌ Complex native setup (iOS bridging, Android configuration)
- ❌ Breaking changes between versions
- ❌ Harder to customize styles
- ❌ Limited TypeScript support

**Verdict**: Setup complexity outweighs performance gains

### Option 2: React Router Native
**Pros**:
- Web-like routing familiar to web developers
- Shared patterns with web apps

**Cons**:
- ❌ Not designed for mobile navigation patterns
- ❌ Poor tab navigation support
- ❌ Lacks native gestures (swipe back)
- ❌ Smaller React Native community

**Verdict**: Poor fit for mobile-first navigation

### Option 3: React Navigation v6 (Selected)
**Pros**:
- ✅ Industry standard for React Native (used by Expo, Meta)
- ✅ Excellent TypeScript support with type inference
- ✅ Native gesture support (swipe back, tab switching)
- ✅ Extensive documentation and community
- ✅ Built-in accessibility features
- ✅ Flexible architecture (stack, tabs, drawer, modal)
- ✅ Deep linking support out-of-box

**Cons**:
- Slightly larger bundle than native solutions (~50KB)

**Verdict**: Best balance of features, DX, and community support

---

## Consequences

### Positive

1. **Type Safety**: Full TypeScript inference for route params prevents runtime errors
2. **Developer Experience**: Hot reload-friendly, extensive docs, large community
3. **Accessibility**: Built-in screen reader support, focus management
4. **Flexibility**: Easy to add new navigation patterns (drawer, modal)
5. **Coordinator Pattern**: NavigationService enables centralized routing logic
6. **Deep Linking**: Native support for app:// URLs and universal links

### Negative

1. **Bundle Size**: ~50KB addition (acceptable given feature set)
2. **Performance**: Slightly slower than native navigation (imperceptible to users)

### Neutral

1. **Learning Curve**: Team must learn React Navigation patterns (1-2 days)

---

## Implementation Example

```typescript
// src/components/navigation/types.ts
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { BottomTabNavigationProp } from '@react-navigation/bottom-tabs';
import { CompositeNavigationProp } from '@react-navigation/native';

// Root stack (top-level)
export type RootStackParamList = {
  MainTabs: undefined;
  CrisisModal: { source?: 'button' | 'deep_link' };
  Auth: undefined;
};

// Main tabs
export type MainTabsParamList = {
  Home: undefined;
  Wellness: undefined;
  Journal: undefined;
  Tools: undefined;
  Profile: undefined;
};

// Feature-specific stacks
export type WellnessStackParamList = {
  WellnessLog: undefined;
  MoodHistory: { timeRange?: 'week' | 'month' | 'year' };
  MoodDetail: { entryId: string };
};

export type JournalStackParamList = {
  JournalList: undefined;
  JournalEditor: { entryId?: string; mode: 'create' | 'edit' };
  JournalDetail: { entryId: string };
};

// Composite navigation prop (for screens needing tab + stack navigation)
export type WellnessScreenNavigationProp = CompositeNavigationProp<
  NativeStackNavigationProp<WellnessStackParamList, 'WellnessLog'>,
  BottomTabNavigationProp<MainTabsParamList>
>;

// src/components/navigation/RootNavigator.tsx
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { RootStackParamList } from './types';
import { MainTabsNavigator } from './MainTabsNavigator';
import { CrisisModalScreen } from '../../features/crisis/CrisisModalScreen';
import { navigationRef } from './NavigationService';

const Stack = createNativeStackNavigator<RootStackParamList>();

export const RootNavigator: React.FC = () => {
  return (
    <NavigationContainer ref={navigationRef}>
      <Stack.Navigator screenOptions={{ headerShown: false }}>
        <Stack.Screen name="MainTabs" component={MainTabsNavigator} />
        <Stack.Screen
          name="CrisisModal"
          component={CrisisModalScreen}
          options={{ presentation: 'modal' }}
        />
      </Stack.Navigator>
    </NavigationContainer>
  );
};

// src/components/navigation/NavigationService.ts (Coordinator Pattern)
import { createNavigationContainerRef } from '@react-navigation/native';
import { RootStackParamList } from './types';

export const navigationRef = createNavigationContainerRef<RootStackParamList>();

export const NavigationService = {
  navigate<T extends keyof RootStackParamList>(
    name: T,
    params?: RootStackParamList[T]
  ) {
    if (navigationRef.isReady()) {
      navigationRef.navigate(name, params as any);
    }
  },

  goBack() {
    if (navigationRef.isReady() && navigationRef.canGoBack()) {
      navigationRef.goBack();
    }
  },

  showCrisisModal(source: 'button' | 'deep_link' = 'button') {
    this.navigate('CrisisModal', { source });
  },

  navigateToMoodDetail(entryId: string) {
    // Type-safe navigation with params
    this.navigate('MainTabs', { screen: 'Wellness', params: { screen: 'MoodDetail', params: { entryId } } });
  },
};

// Usage in ViewModel (Coordinator Pattern)
export const useWellnessViewModel = () => {
  const handleMoodEntryPress = useCallback((entryId: string) => {
    NavigationService.navigateToMoodDetail(entryId);
  }, []);

  return { handleMoodEntryPress };
};

// Deep Linking Configuration
const linking = {
  prefixes: ['rediscovertalk://', 'https://rediscovertalk.com'],
  config: {
    screens: {
      MainTabs: {
        screens: {
          Wellness: {
            screens: {
              MoodDetail: 'mood/:entryId',
            },
          },
          Journal: {
            screens: {
              JournalDetail: 'journal/:entryId',
            },
          },
        },
      },
      CrisisModal: 'crisis',
    },
  },
};
// Usage: rediscovertalk://mood/abc-123 → MoodDetailScreen
```

---

## Navigation Structure

```
RootNavigator (Native Stack)
├── MainTabs (Bottom Tabs)
│   ├── HomeStack (Native Stack)
│   │   ├── DailyPromptScreen
│   │   ├── PromptDetailScreen
│   │   └── PromptHistoryScreen
│   ├── WellnessStack (Native Stack)
│   │   ├── WellnessLogScreen
│   │   ├── MoodHistoryScreen
│   │   └── MoodDetailScreen
│   ├── JournalStack (Native Stack)
│   │   ├── JournalListScreen
│   │   ├── JournalEditorScreen
│   │   └── JournalDetailScreen
│   ├── ToolsStack (Native Stack)
│   │   ├── ToolsHomeScreen
│   │   ├── BreathingExercisesScreen
│   │   └── GroundingToolsScreen
│   └── ProfileStack (Native Stack)
│       ├── ProfileScreen
│       ├── SettingsScreen
│       └── AboutScreen
├── CrisisModal (Modal Presentation)
│   ├── CrisisPlanScreen
│   └── EmergencyContactsScreen
└── AuthStack (Native Stack)
    ├── LoginScreen
    └── RegistrationScreen
```

---

## Compliance

**MVVM-C Coordinator Pattern**:
- ✅ Navigation logic in NavigationService (Coordinator layer)
- ✅ ViewModels use NavigationService, never direct navigation
- ✅ Views receive navigation callbacks via ViewModels
- ✅ Type-safe routing prevents runtime errors

**Accessibility**:
- ✅ Screen reader announcements for route changes
- ✅ Focus management on navigation transitions
- ✅ Accessible tab labels and icons

**Performance**:
- ✅ Lazy-loaded screens with React.lazy
- ✅ Native animations (60fps)
- ✅ Minimal re-renders on navigation

---

## References

- [React Navigation Documentation](https://reactnavigation.org/)
- [TypeScript Integration](https://reactnavigation.org/docs/typescript/)
- LitmonCloud MVVM-C Pattern Guide
- [Deep Linking Guide](https://reactnavigation.org/docs/deep-linking/)

---

## Review & Approval

**Approved By**: Enterprise Architect, UI/UX Lead
**Review Date**: 2025-10-21
**Next Review**: 2026-01-21 (Quarterly)
