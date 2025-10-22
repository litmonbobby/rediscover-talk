# RediscoverTalk - Performance Optimization Plan

**Version**: 1.0.0
**Date**: October 21, 2025
**Owner**: iOS Performance Specialist
**Status**: Active Implementation

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Performance Targets & Metrics](#performance-targets--metrics)
3. [Profiling Strategy](#profiling-strategy)
4. [Launch Time Optimization](#launch-time-optimization)
5. [Runtime Performance](#runtime-performance)
6. [Memory Optimization](#memory-optimization)
7. [Network Performance](#network-performance)
8. [Battery Optimization](#battery-optimization)
9. [Performance Monitoring](#performance-monitoring)
10. [Implementation Roadmap](#implementation-roadmap)

---

## Executive Summary

This document defines the comprehensive performance optimization strategy for RediscoverTalk mental wellness app. The strategy ensures:

- ✅ **Launch Time**: <3s cold, <1s warm (Constitution: <3s/<1s)
- ✅ **UI Performance**: 60fps during all interactions (Constitution requirement)
- ✅ **Memory**: <100MB baseline, <200MB peak (Constitution limits)
- ✅ **Battery**: <5% drain per hour active use (Constitution requirement)
- ✅ **API Response**: <200ms 95th percentile
- ✅ **Bundle Size**: <500KB initial, <2MB total

**Key Optimization Areas**:
1. **Launch Time**: Bundle splitting, lazy loading, deferred initialization
2. **Runtime**: Memoization, virtualization, animation optimization
3. **Memory**: Leak detection, efficient caching, cleanup patterns
4. **Network**: Request batching, compression, caching strategies
5. **Battery**: Background task optimization, efficient sync intervals
6. **Monitoring**: Real-time metrics, alerting, regression detection

---

## Performance Targets & Metrics

### Constitution Compliance (iOS Development Constitution)

**Article I, Section 1 - Performance Standards**:
```yaml
ui_performance: "60fps UI, <3s load times, <100MB memory baseline"
compliance: MANDATORY
validation: "All benchmarks must pass before release"
```

**Article II, Section 1 - Performance Requirements**:
```yaml
launch_times:
  cold_start: "<3s (Target: <2s for RediscoverTalk)"
  warm_start: "<1s"
memory_limits:
  baseline: "<100MB"
  peak: "<200MB"
battery_efficiency: "<5% battery drain per hour"
```

**Article IV, Section 3 - Release Criteria**:
```yaml
quality_gates:
  - "All performance benchmarks must pass"
  - "No blocking performance issues"
  - "Validation scripts green"
```

### RediscoverTalk-Specific Targets

| Metric | Constitution | RediscoverTalk Target | Measurement Method |
|--------|-------------|----------------------|-------------------|
| **Launch Time (Cold)** | <3s | **<2s** | Time from app launch to first interactive frame |
| **Launch Time (Warm)** | <1s | **<1s** | Time from backgrounded to interactive |
| **Memory Baseline** | <100MB | **<80MB** | Memory usage after app initialization |
| **Memory Peak** | <200MB | **<150MB** | Maximum memory during typical usage |
| **UI Frame Rate** | 60fps | **60fps** | Frame rate during scrolling, animations, transitions |
| **API Response** | N/A | **<200ms** | 95th percentile for all API calls |
| **Screen Transitions** | <16ms | **<16ms** | Time between navigation actions (60fps = 16.67ms) |
| **Battery Drain** | <5%/hour | **<4%/hour** | Active usage battery consumption |
| **Bundle Size (Initial)** | N/A | **<500KB** | Initial JavaScript bundle size |
| **Bundle Size (Total)** | N/A | **<2MB** | Total app bundle with all features |

### Performance Quality Gates

**CRITICAL (Deployment Blocking)**:
- Launch time >5s (cold) or >2s (warm)
- Memory >300MB peak
- UI consistently <60fps
- Battery drain >7%/hour

**HIGH (Deployment Blocking)**:
- Launch time >3s (cold) or >1s (warm)
- Memory >200MB peak
- Screen transitions >16ms
- API response >500ms (p95)

**MEDIUM (Warning)**:
- Launch time >2s (cold)
- Memory >150MB peak
- Battery drain >5%/hour
- Bundle size >2MB

**LOW (Monitor)**:
- Launch time approaching targets
- Memory approaching limits
- Battery drain >4%/hour

---

## Profiling Strategy

### 1. Development Profiling

**Tools & Setup**:
```javascript
// src/utils/performance/DevProfiler.ts
import { PerformanceObserver } from 'react-native-performance';

class DevProfiler {
  private static instance: DevProfiler;
  private observers: Map<string, PerformanceObserver> = new Map();

  static getInstance(): DevProfiler {
    if (!DevProfiler.instance) {
      DevProfiler.instance = new DevProfiler();
    }
    return DevProfiler.instance;
  }

  // Track component render times
  trackComponentRender(componentName: string): () => void {
    const startTime = performance.now();

    return () => {
      const duration = performance.now() - startTime;
      if (duration > 16) { // Warn if render takes >16ms (60fps threshold)
        console.warn(`[PERF] ${componentName} render took ${duration.toFixed(2)}ms`);
      }
      this.logMetric('component_render', componentName, duration);
    };
  }

  // Track navigation timing
  trackNavigation(screen: string): () => void {
    const startTime = performance.now();

    return () => {
      const duration = performance.now() - startTime;
      this.logMetric('navigation', screen, duration);
    };
  }

  // Track API call timing
  trackAPICall(endpoint: string): () => void {
    const startTime = performance.now();

    return () => {
      const duration = performance.now() - startTime;
      if (duration > 200) { // Warn if API call >200ms
        console.warn(`[PERF] API ${endpoint} took ${duration.toFixed(2)}ms`);
      }
      this.logMetric('api_call', endpoint, duration);
    };
  }

  private logMetric(type: string, name: string, duration: number): void {
    if (__DEV__) {
      console.log(`[PERF] ${type}: ${name} - ${duration.toFixed(2)}ms`);
    }
  }
}

export const devProfiler = DevProfiler.getInstance();
```

**Usage in Components**:
```typescript
// Example: Profile component render
const MoodTracker: React.FC = () => {
  const endRenderProfile = devProfiler.trackComponentRender('MoodTracker');

  useEffect(() => {
    endRenderProfile();
  }, []);

  // Component logic...
};
```

### 2. Production Profiling

**React Native Performance Monitoring**:
```javascript
// src/services/PerformanceMonitor.ts
import { Performance } from 'react-native-performance';
import { FirebasePerformance } from '@react-native-firebase/perf';

class PerformanceMonitor {
  private static instance: PerformanceMonitor;

  static getInstance(): PerformanceMonitor {
    if (!PerformanceMonitor.instance) {
      PerformanceMonitor.instance = new PerformanceMonitor();
    }
    return PerformanceMonitor.instance;
  }

  // Track app startup time
  async trackAppStart(): Promise<void> {
    const trace = await FirebasePerformance().startTrace('app_start');
    trace.putMetric('cold_start', 1);

    // Mark app as ready
    setTimeout(() => {
      trace.stop();
    }, 100);
  }

  // Track screen render performance
  async trackScreenRender(screenName: string): Promise<() => void> {
    const trace = await FirebasePerformance().startTrace(`screen_${screenName}`);

    return () => {
      trace.stop();
    };
  }

  // Track custom metrics
  async trackMetric(name: string, value: number): Promise<void> {
    const trace = await FirebasePerformance().startTrace(name);
    trace.putMetric('value', value);
    trace.stop();
  }
}

export const performanceMonitor = PerformanceMonitor.getInstance();
```

### 3. Memory Profiling

**Memory Leak Detection**:
```javascript
// src/utils/performance/MemoryMonitor.ts
class MemoryMonitor {
  private static instance: MemoryMonitor;
  private intervalId: NodeJS.Timeout | null = null;
  private memoryReadings: number[] = [];

  static getInstance(): MemoryMonitor {
    if (!MemoryMonitor.instance) {
      MemoryMonitor.instance = new MemoryMonitor();
    }
    return MemoryMonitor.instance;
  }

  startMonitoring(intervalMs: number = 5000): void {
    if (this.intervalId) return; // Already monitoring

    this.intervalId = setInterval(() => {
      this.captureMemorySnapshot();
    }, intervalMs);
  }

  stopMonitoring(): void {
    if (this.intervalId) {
      clearInterval(this.intervalId);
      this.intervalId = null;
    }
  }

  private captureMemorySnapshot(): void {
    // React Native doesn't expose direct memory API
    // Use native modules or performance.memory (if available)
    if (performance.memory) {
      const memoryMB = performance.memory.usedJSHeapSize / 1024 / 1024;
      this.memoryReadings.push(memoryMB);

      // Constitution limits: <100MB baseline, <200MB peak
      if (memoryMB > 200) {
        console.error(`[MEMORY] CRITICAL: ${memoryMB.toFixed(2)}MB - Exceeds 200MB limit`);
      } else if (memoryMB > 150) {
        console.warn(`[MEMORY] HIGH: ${memoryMB.toFixed(2)}MB - Approaching 200MB limit`);
      } else if (memoryMB > 100) {
        console.warn(`[MEMORY] MEDIUM: ${memoryMB.toFixed(2)}MB - Above 100MB baseline`);
      }

      // Keep only last 100 readings (5 minutes at 5s intervals)
      if (this.memoryReadings.length > 100) {
        this.memoryReadings.shift();
      }
    }
  }

  getMemoryStats(): { current: number; average: number; peak: number } {
    if (this.memoryReadings.length === 0) {
      return { current: 0, average: 0, peak: 0 };
    }

    const current = this.memoryReadings[this.memoryReadings.length - 1];
    const average = this.memoryReadings.reduce((a, b) => a + b, 0) / this.memoryReadings.length;
    const peak = Math.max(...this.memoryReadings);

    return { current, average, peak };
  }
}

export const memoryMonitor = MemoryMonitor.getInstance();
```

### 4. Bundle Size Analysis

**Metro Bundler Configuration**:
```javascript
// metro.config.js
module.exports = {
  transformer: {
    getTransformOptions: async () => ({
      transform: {
        experimentalImportSupport: false,
        inlineRequires: true, // Enable inline requires for better tree-shaking
      },
    }),
  },
  resolver: {
    sourceExts: ['jsx', 'js', 'ts', 'tsx', 'json'],
  },
  // Enable bundle size analysis
  serializer: {
    createModuleIdFactory: () => (path) => {
      // Use shorter module IDs to reduce bundle size
      return path.replace(/.*\/node_modules\//, '');
    },
  },
};
```

**Bundle Analysis Script**:
```bash
#!/bin/bash
# scripts/analyze-bundle.sh

echo "🔍 Analyzing React Native bundle size..."

# Build production bundle
npx react-native bundle \
  --platform ios \
  --dev false \
  --entry-file index.js \
  --bundle-output ./build/main.jsbundle \
  --assets-dest ./build \
  --sourcemap-output ./build/main.jsbundle.map

# Analyze bundle size
BUNDLE_SIZE=$(wc -c < ./build/main.jsbundle)
BUNDLE_SIZE_KB=$((BUNDLE_SIZE / 1024))
BUNDLE_SIZE_MB=$((BUNDLE_SIZE_KB / 1024))

echo "📦 Bundle Size: ${BUNDLE_SIZE_KB}KB (${BUNDLE_SIZE_MB}MB)"

# Check against targets
if [ $BUNDLE_SIZE_KB -gt 2048 ]; then
  echo "❌ CRITICAL: Bundle size ${BUNDLE_SIZE_KB}KB exceeds 2MB limit"
  exit 1
elif [ $BUNDLE_SIZE_KB -gt 1024 ]; then
  echo "⚠️  WARNING: Bundle size ${BUNDLE_SIZE_KB}KB exceeds 1MB"
elif [ $BUNDLE_SIZE_KB -gt 500 ]; then
  echo "ℹ️  INFO: Bundle size ${BUNDLE_SIZE_KB}KB above 500KB initial target"
else
  echo "✅ PASS: Bundle size within targets"
fi

# Use source-map-explorer for detailed analysis
npx source-map-explorer ./build/main.jsbundle ./build/main.jsbundle.map --html ./build/bundle-analysis.html

echo "📊 Bundle analysis report generated: ./build/bundle-analysis.html"
```

---

## Launch Time Optimization

### Target: <2s Cold Launch, <1s Warm Launch

### 1. Bundle Splitting Strategy

**Code Splitting Configuration**:
```javascript
// src/navigation/LazyScreens.ts
import React, { lazy, Suspense } from 'react';
import { ActivityIndicator, View } from 'react-native';

// Loading fallback component
const LoadingScreen = () => (
  <View style={{ flex: 1, justifyContent: 'center', alignItems: 'center' }}>
    <ActivityIndicator size="large" />
  </View>
);

// Lazy load feature screens
export const MoodTrackerScreen = lazy(() => import('../screens/MoodTracker'));
export const JournalScreen = lazy(() => import('../screens/Journal'));
export const ConversationScreen = lazy(() => import('../screens/Conversation'));
export const MeditationScreen = lazy(() => import('../screens/Meditation'));
export const SettingsScreen = lazy(() => import('../screens/Settings'));

// HOC for lazy screen wrapping
export const withLazyLoad = (LazyComponent: React.LazyExoticComponent<any>) => {
  return (props: any) => (
    <Suspense fallback={<LoadingScreen />}>
      <LazyComponent {...props} />
    </Suspense>
  );
};
```

**Navigation with Code Splitting**:
```typescript
// src/navigation/AppNavigator.tsx
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { HomeScreen } from '../screens/Home'; // Always loaded
import {
  MoodTrackerScreen,
  JournalScreen,
  ConversationScreen,
  MeditationScreen,
  SettingsScreen,
  withLazyLoad
} from './LazyScreens';

const Stack = createNativeStackNavigator();

export const AppNavigator = () => {
  return (
    <Stack.Navigator>
      {/* Critical screens - loaded immediately */}
      <Stack.Screen name="Home" component={HomeScreen} />

      {/* Feature screens - lazy loaded */}
      <Stack.Screen name="MoodTracker" component={withLazyLoad(MoodTrackerScreen)} />
      <Stack.Screen name="Journal" component={withLazyLoad(JournalScreen)} />
      <Stack.Screen name="Conversation" component={withLazyLoad(ConversationScreen)} />
      <Stack.Screen name="Meditation" component={withLazyLoad(MeditationScreen)} />
      <Stack.Screen name="Settings" component={withLazyLoad(SettingsScreen)} />
    </Stack.Navigator>
  );
};
```

### 2. Deferred Initialization

**Lazy Service Initialization**:
```typescript
// src/services/LazyServiceLoader.ts
class LazyServiceLoader {
  private static instance: LazyServiceLoader;
  private loadedServices: Set<string> = new Set();

  static getInstance(): LazyServiceLoader {
    if (!LazyServiceLoader.instance) {
      LazyServiceLoader.instance = new LazyServiceLoader();
    }
    return LazyServiceLoader.instance;
  }

  // Defer non-critical service initialization
  async loadDeferredServices(): Promise<void> {
    // Wait for app to be interactive before loading heavy services
    requestIdleCallback(() => {
      this.loadAnalyticsService();
      this.loadNotificationService();
      this.loadCloudSyncService();
    });
  }

  private async loadAnalyticsService(): Promise<void> {
    if (this.loadedServices.has('analytics')) return;

    const { AnalyticsService } = await import('./AnalyticsService');
    await AnalyticsService.getInstance().initialize();
    this.loadedServices.add('analytics');
    console.log('[LazyLoad] Analytics service loaded');
  }

  private async loadNotificationService(): Promise<void> {
    if (this.loadedServices.has('notifications')) return;

    const { NotificationService } = await import('./NotificationService');
    await NotificationService.getInstance().initialize();
    this.loadedServices.add('notifications');
    console.log('[LazyLoad] Notification service loaded');
  }

  private async loadCloudSyncService(): Promise<void> {
    if (this.loadedServices.has('cloudSync')) return;

    const { CloudSyncService } = await import('./CloudSyncService');
    await CloudSyncService.getInstance().initialize();
    this.loadedServices.add('cloudSync');
    console.log('[LazyLoad] Cloud sync service loaded');
  }
}

export const lazyServiceLoader = LazyServiceLoader.getInstance();
```

**App Initialization Optimization**:
```typescript
// App.tsx
import React, { useEffect, useState } from 'react';
import { AppRegistry } from 'react-native';
import { NavigationContainer } from '@react-navigation/native';
import { lazyServiceLoader } from './services/LazyServiceLoader';
import { performanceMonitor } from './services/PerformanceMonitor';

const App: React.FC = () => {
  const [isReady, setIsReady] = useState(false);

  useEffect(() => {
    initializeApp();
  }, []);

  const initializeApp = async () => {
    // Track app startup
    const stopAppStartTrace = await performanceMonitor.trackAppStart();

    try {
      // Critical initialization only
      await initializeCriticalServices();

      // Mark app as ready
      setIsReady(true);

      // Defer non-critical services
      lazyServiceLoader.loadDeferredServices();

    } catch (error) {
      console.error('App initialization error:', error);
    } finally {
      stopAppStartTrace();
    }
  };

  const initializeCriticalServices = async () => {
    // Only load services required for first screen
    const { StorageService } = await import('./services/StorageService');
    await StorageService.getInstance().initialize();

    const { AuthService } = await import('./services/AuthService');
    await AuthService.getInstance().restoreSession();
  };

  if (!isReady) {
    return <SplashScreen />; // Lightweight splash screen
  }

  return (
    <NavigationContainer>
      <AppNavigator />
    </NavigationContainer>
  );
};

export default App;
```

### 3. Splash Screen Optimization

**Progressive Splash Screen**:
```typescript
// src/screens/SplashScreen.tsx
import React, { useEffect, useState } from 'react';
import { View, Image, ActivityIndicator, Text, StyleSheet } from 'react-native';

export const SplashScreen: React.FC = () => {
  const [loadingProgress, setLoadingProgress] = useState(0);

  useEffect(() => {
    // Simulate loading progress for better UX
    const interval = setInterval(() => {
      setLoadingProgress((prev) => {
        if (prev >= 100) {
          clearInterval(interval);
          return 100;
        }
        return prev + 10;
      });
    }, 100);

    return () => clearInterval(interval);
  }, []);

  return (
    <View style={styles.container}>
      <Image
        source={require('../assets/logo.png')}
        style={styles.logo}
        resizeMode="contain"
      />
      <ActivityIndicator size="large" color="#007AFF" />
      <Text style={styles.loadingText}>
        Preparing your experience... {loadingProgress}%
      </Text>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#FFFFFF',
  },
  logo: {
    width: 150,
    height: 150,
    marginBottom: 20,
  },
  loadingText: {
    marginTop: 10,
    fontSize: 14,
    color: '#666666',
  },
});
```

---

## Runtime Performance

### Target: 60fps UI, <16ms Screen Transitions

### 1. Memoization Patterns

**React Component Memoization**:
```typescript
// src/hooks/useMemoizedCallback.ts
import { useCallback, useMemo } from 'react';

// Memoize expensive computations
export const useMemoizedData = <T,>(
  data: T[],
  filterFn: (item: T) => boolean,
  sortFn: (a: T, b: T) => number
): T[] => {
  return useMemo(() => {
    return data.filter(filterFn).sort(sortFn);
  }, [data, filterFn, sortFn]);
};

// Memoize callbacks to prevent re-renders
export const useMemoizedCallback = <T extends (...args: any[]) => any>(
  callback: T,
  deps: React.DependencyList
): T => {
  return useCallback(callback, deps);
};
```

**Component Example**:
```typescript
// src/components/MoodList.tsx
import React, { memo, useMemo } from 'react';
import { FlatList } from 'react-native';
import { MoodEntry } from '../types';
import { MoodListItem } from './MoodListItem';

interface MoodListProps {
  entries: MoodEntry[];
  onEntryPress: (entry: MoodEntry) => void;
}

export const MoodList = memo<MoodListProps>(({ entries, onEntryPress }) => {
  // Memoize sorted entries to avoid re-sorting on every render
  const sortedEntries = useMemo(() => {
    return [...entries].sort((a, b) =>
      new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime()
    );
  }, [entries]);

  // Memoize render item to prevent unnecessary re-renders
  const renderItem = useMemo(() => {
    return ({ item }: { item: MoodEntry }) => (
      <MoodListItem entry={item} onPress={onEntryPress} />
    );
  }, [onEntryPress]);

  // Memoize keyExtractor
  const keyExtractor = useMemo(() => {
    return (item: MoodEntry) => item.id;
  }, []);

  return (
    <FlatList
      data={sortedEntries}
      renderItem={renderItem}
      keyExtractor={keyExtractor}
      removeClippedSubviews={true} // Unmount off-screen items
      maxToRenderPerBatch={10} // Render 10 items per batch
      updateCellsBatchingPeriod={50} // Batch updates every 50ms
      windowSize={5} // Render 5 screen heights worth of items
    />
  );
});
```

### 2. FlatList Virtualization Optimization

**Optimized FlatList Configuration**:
```typescript
// src/components/OptimizedFlatList.tsx
import React, { memo, useCallback } from 'react';
import { FlatList, FlatListProps, ViewToken } from 'react-native';

interface OptimizedFlatListProps<T> extends FlatListProps<T> {
  // Custom props for performance optimization
}

export const OptimizedFlatList = memo(<T,>(props: OptimizedFlatListProps<T>) => {
  // Track viewability changes for analytics
  const onViewableItemsChanged = useCallback(({ viewableItems }: { viewableItems: ViewToken[] }) => {
    // Log which items are currently visible (useful for analytics)
    if (__DEV__) {
      console.log(`[PERF] Visible items: ${viewableItems.length}`);
    }
  }, []);

  return (
    <FlatList
      {...props}
      // Performance optimizations
      removeClippedSubviews={true} // Unmount off-screen items (huge memory savings)
      maxToRenderPerBatch={10} // Render 10 items per batch (adjust based on item complexity)
      updateCellsBatchingPeriod={50} // Batch updates every 50ms (balances responsiveness & performance)
      windowSize={5} // Render 5 screen heights (2 above, 2 below, 1 visible)
      initialNumToRender={10} // Render 10 items initially (fast first render)
      getItemLayout={(data, index) => ({
        length: 100, // Item height (adjust to actual height for better performance)
        offset: 100 * index,
        index,
      })}
      onViewableItemsChanged={onViewableItemsChanged}
      viewabilityConfig={{
        itemVisiblePercentThreshold: 50, // Item considered visible at 50%
      }}
    />
  );
}) as <T>(props: OptimizedFlatListProps<T>) => React.ReactElement;
```

### 3. Image Optimization

**Lazy Image Loading**:
```typescript
// src/components/OptimizedImage.tsx
import React, { useState, useEffect } from 'react';
import { Image, ImageProps, ActivityIndicator, View, StyleSheet } from 'react-native';
import FastImage from 'react-native-fast-image'; // Use FastImage for better caching

interface OptimizedImageProps extends ImageProps {
  uri: string;
  placeholder?: string;
  lowQualityUri?: string; // Low-quality placeholder
}

export const OptimizedImage: React.FC<OptimizedImageProps> = ({
  uri,
  placeholder,
  lowQualityUri,
  style,
  ...props
}) => {
  const [isLoading, setIsLoading] = useState(true);
  const [hasError, setHasError] = useState(false);

  return (
    <View style={[styles.container, style]}>
      {/* Low-quality placeholder (loads immediately) */}
      {lowQualityUri && isLoading && (
        <FastImage
          source={{ uri: lowQualityUri }}
          style={StyleSheet.absoluteFill}
          resizeMode={FastImage.resizeMode.cover}
        />
      )}

      {/* High-quality image */}
      <FastImage
        {...props}
        source={{
          uri,
          priority: FastImage.priority.normal,
          cache: FastImage.cacheControl.immutable,
        }}
        style={[StyleSheet.absoluteFill, style]}
        onLoadStart={() => setIsLoading(true)}
        onLoad={() => setIsLoading(false)}
        onError={() => {
          setIsLoading(false);
          setHasError(true);
        }}
        resizeMode={FastImage.resizeMode.cover}
      />

      {/* Loading indicator */}
      {isLoading && !hasError && (
        <ActivityIndicator
          style={styles.loader}
          size="small"
          color="#007AFF"
        />
      )}

      {/* Error state */}
      {hasError && placeholder && (
        <Image
          source={{ uri: placeholder }}
          style={StyleSheet.absoluteFill}
          resizeMode="cover"
        />
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    overflow: 'hidden',
  },
  loader: {
    position: 'absolute',
    top: '50%',
    left: '50%',
    marginTop: -10,
    marginLeft: -10,
  },
});
```

**Image Caching Strategy**:
```typescript
// src/services/ImageCacheService.ts
import FastImage from 'react-native-fast-image';

class ImageCacheService {
  private static instance: ImageCacheService;

  static getInstance(): ImageCacheService {
    if (!ImageCacheService.instance) {
      ImageCacheService.instance = new ImageCacheService();
    }
    return ImageCacheService.instance;
  }

  // Preload critical images
  async preloadImages(uris: string[]): Promise<void> {
    const sources = uris.map(uri => ({
      uri,
      priority: FastImage.priority.high,
      cache: FastImage.cacheControl.immutable,
    }));

    await FastImage.preload(sources);
    console.log(`[ImageCache] Preloaded ${uris.length} images`);
  }

  // Clear image cache
  async clearCache(): Promise<void> {
    await FastImage.clearMemoryCache();
    await FastImage.clearDiskCache();
    console.log('[ImageCache] Cache cleared');
  }

  // Get cache statistics
  async getCacheStats(): Promise<{ memory: number; disk: number }> {
    // React Native Fast Image doesn't expose cache stats directly
    // Implement native module if needed
    return { memory: 0, disk: 0 };
  }
}

export const imageCacheService = ImageCacheService.getInstance();
```

### 4. Animation Performance

**Use Native Driver for Animations**:
```typescript
// src/animations/useAnimatedValue.ts
import { useRef, useEffect } from 'react';
import { Animated, Easing } from 'react-native';

export const useAnimatedValue = (
  initialValue: number,
  toValue: number,
  duration: number = 300
) => {
  const animatedValue = useRef(new Animated.Value(initialValue)).current;

  useEffect(() => {
    Animated.timing(animatedValue, {
      toValue,
      duration,
      easing: Easing.inOut(Easing.ease),
      useNativeDriver: true, // CRITICAL: Use native driver for 60fps animations
    }).start();
  }, [toValue, duration]);

  return animatedValue;
};
```

**Optimized Animation Component**:
```typescript
// src/components/FadeInView.tsx
import React, { useEffect, useRef } from 'react';
import { Animated, ViewProps } from 'react-native';

interface FadeInViewProps extends ViewProps {
  duration?: number;
  delay?: number;
}

export const FadeInView: React.FC<FadeInViewProps> = ({
  children,
  duration = 300,
  delay = 0,
  style,
  ...props
}) => {
  const opacity = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    Animated.timing(opacity, {
      toValue: 1,
      duration,
      delay,
      useNativeDriver: true, // Essential for smooth animations
    }).start();
  }, []);

  return (
    <Animated.View {...props} style={[style, { opacity }]}>
      {children}
    </Animated.View>
  );
};
```

---

## Memory Optimization

### Target: <100MB Baseline, <200MB Peak

### 1. Memory Leak Detection

**useEffect Cleanup Pattern**:
```typescript
// src/hooks/useSubscription.ts
import { useEffect } from 'react';

export const useSubscription = <T,>(
  subscribe: (callback: (data: T) => void) => () => void,
  callback: (data: T) => void
): void => {
  useEffect(() => {
    // Subscribe
    const unsubscribe = subscribe(callback);

    // CRITICAL: Always cleanup to prevent memory leaks
    return () => {
      unsubscribe();
    };
  }, [subscribe, callback]);
};
```

**Event Listener Cleanup**:
```typescript
// src/hooks/useEventListener.ts
import { useEffect } from 'react';
import { AppState, AppStateStatus } from 'react-native';

export const useAppStateListener = (
  onChange: (state: AppStateStatus) => void
): void => {
  useEffect(() => {
    // Add listener
    const subscription = AppState.addEventListener('change', onChange);

    // CRITICAL: Remove listener on unmount
    return () => {
      subscription.remove();
    };
  }, [onChange]);
};
```

### 2. Efficient Caching Strategies

**LRU Cache Implementation**:
```typescript
// src/utils/cache/LRUCache.ts
class LRUCache<K, V> {
  private maxSize: number;
  private cache: Map<K, V>;

  constructor(maxSize: number = 100) {
    this.maxSize = maxSize;
    this.cache = new Map();
  }

  get(key: K): V | undefined {
    if (!this.cache.has(key)) return undefined;

    // Move to end (most recently used)
    const value = this.cache.get(key)!;
    this.cache.delete(key);
    this.cache.set(key, value);

    return value;
  }

  set(key: K, value: V): void {
    // Delete if exists (to move to end)
    if (this.cache.has(key)) {
      this.cache.delete(key);
    }

    // Add new entry
    this.cache.set(key, value);

    // Evict oldest if over capacity
    if (this.cache.size > this.maxSize) {
      const firstKey = this.cache.keys().next().value;
      this.cache.delete(firstKey);
      console.log(`[LRUCache] Evicted key: ${firstKey}`);
    }
  }

  clear(): void {
    this.cache.clear();
  }

  size(): number {
    return this.cache.size;
  }
}

export const apiResponseCache = new LRUCache<string, any>(50); // Cache 50 API responses
export const imageMetadataCache = new LRUCache<string, any>(100); // Cache 100 image metadata
```

**Memory-Efficient Store Slicing**:
```typescript
// src/stores/useOptimizedStore.ts
import { create } from 'zustand';
import { persist } from 'zustand/middleware';

// Instead of one large store, slice into smaller stores
// This reduces memory footprint and improves performance

// Mood tracking store (only loads mood data)
export const useMoodStore = create(
  persist(
    (set, get) => ({
      entries: [],
      addEntry: (entry) => set((state) => ({
        entries: [...state.entries.slice(-100), entry], // Keep only last 100 entries
      })),
      clearOldEntries: () => set((state) => ({
        entries: state.entries.slice(-30), // Keep only last 30 days
      })),
    }),
    { name: 'mood-store' }
  )
);

// Journal store (separate from mood)
export const useJournalStore = create(
  persist(
    (set, get) => ({
      entries: [],
      addEntry: (entry) => set((state) => ({
        entries: [...state.entries.slice(-50), entry], // Keep only last 50 entries
      })),
    }),
    { name: 'journal-store' }
  )
);
```

---

## Network Performance

### Target: <200ms API Response (p95)

### 1. Request Batching

**GraphQL Batch Loader**:
```typescript
// src/services/network/BatchLoader.ts
class BatchLoader {
  private static instance: BatchLoader;
  private queue: Array<{ query: string; resolve: (data: any) => void; reject: (error: any) => void }> = [];
  private batchTimeout: NodeJS.Timeout | null = null;

  static getInstance(): BatchLoader {
    if (!BatchLoader.instance) {
      BatchLoader.instance = new BatchLoader();
    }
    return BatchLoader.instance;
  }

  async load(query: string): Promise<any> {
    return new Promise((resolve, reject) => {
      this.queue.push({ query, resolve, reject });

      // Batch requests within 50ms window
      if (!this.batchTimeout) {
        this.batchTimeout = setTimeout(() => {
          this.flush();
        }, 50);
      }
    });
  }

  private async flush(): Promise<void> {
    if (this.queue.length === 0) return;

    const batch = this.queue.splice(0, this.queue.length);
    this.batchTimeout = null;

    try {
      // Send batched queries to server
      const batchedQueries = batch.map(item => item.query);
      const response = await fetch('/graphql/batch', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ queries: batchedQueries }),
      });

      const results = await response.json();

      // Resolve individual promises
      batch.forEach((item, index) => {
        item.resolve(results[index]);
      });

      console.log(`[BatchLoader] Batched ${batch.length} requests`);
    } catch (error) {
      batch.forEach(item => item.reject(error));
    }
  }
}

export const batchLoader = BatchLoader.getInstance();
```

### 2. Response Caching

**HTTP Cache Implementation**:
```typescript
// src/services/network/HTTPCache.ts
import AsyncStorage from '@react-native-async-storage/async-storage';
import { apiResponseCache } from '../../utils/cache/LRUCache';

interface CacheEntry {
  data: any;
  timestamp: number;
  ttl: number; // Time to live in milliseconds
}

class HTTPCache {
  private static instance: HTTPCache;
  private memoryCache = apiResponseCache; // LRU cache for hot data

  static getInstance(): HTTPCache {
    if (!HTTPCache.instance) {
      HTTPCache.instance = new HTTPCache();
    }
    return HTTPCache.instance;
  }

  async get(key: string): Promise<any | null> {
    // Check memory cache first (fast)
    const memoryHit = this.memoryCache.get(key);
    if (memoryHit && !this.isExpired(memoryHit)) {
      console.log(`[HTTPCache] Memory hit: ${key}`);
      return memoryHit.data;
    }

    // Check disk cache (slower but persistent)
    try {
      const diskHit = await AsyncStorage.getItem(`cache:${key}`);
      if (diskHit) {
        const entry: CacheEntry = JSON.parse(diskHit);

        if (!this.isExpired(entry)) {
          // Promote to memory cache
          this.memoryCache.set(key, entry);
          console.log(`[HTTPCache] Disk hit: ${key}`);
          return entry.data;
        } else {
          // Expired, remove from disk
          await AsyncStorage.removeItem(`cache:${key}`);
        }
      }
    } catch (error) {
      console.error('[HTTPCache] Disk read error:', error);
    }

    console.log(`[HTTPCache] Miss: ${key}`);
    return null;
  }

  async set(key: string, data: any, ttl: number = 5 * 60 * 1000): Promise<void> {
    const entry: CacheEntry = {
      data,
      timestamp: Date.now(),
      ttl,
    };

    // Store in memory cache
    this.memoryCache.set(key, entry);

    // Store in disk cache for persistence
    try {
      await AsyncStorage.setItem(`cache:${key}`, JSON.stringify(entry));
      console.log(`[HTTPCache] Cached: ${key} (TTL: ${ttl}ms)`);
    } catch (error) {
      console.error('[HTTPCache] Disk write error:', error);
    }
  }

  async invalidate(key: string): Promise<void> {
    this.memoryCache.clear(); // Clear memory
    await AsyncStorage.removeItem(`cache:${key}`); // Clear disk
    console.log(`[HTTPCache] Invalidated: ${key}`);
  }

  private isExpired(entry: CacheEntry): boolean {
    return Date.now() - entry.timestamp > entry.ttl;
  }
}

export const httpCache = HTTPCache.getInstance();
```

**Cached API Client**:
```typescript
// src/services/network/CachedAPIClient.ts
import { httpCache } from './HTTPCache';

class CachedAPIClient {
  private static instance: CachedAPIClient;
  private baseURL = 'https://api.rediscovertalk.com';

  static getInstance(): CachedAPIClient {
    if (!CachedAPIClient.instance) {
      CachedAPIClient.instance = new CachedAPIClient();
    }
    return CachedAPIClient.instance;
  }

  async get<T>(endpoint: string, options: { cache?: boolean; ttl?: number } = {}): Promise<T> {
    const { cache = true, ttl = 5 * 60 * 1000 } = options;
    const cacheKey = `GET:${endpoint}`;

    // Check cache first
    if (cache) {
      const cached = await httpCache.get(cacheKey);
      if (cached) {
        return cached as T;
      }
    }

    // Fetch from network
    const startTime = performance.now();
    const response = await fetch(`${this.baseURL}${endpoint}`, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        // Add auth headers
      },
    });

    const duration = performance.now() - startTime;

    if (duration > 200) {
      console.warn(`[API] Slow response: ${endpoint} took ${duration.toFixed(2)}ms`);
    }

    if (!response.ok) {
      throw new Error(`API error: ${response.status} ${response.statusText}`);
    }

    const data = await response.json();

    // Cache response
    if (cache) {
      await httpCache.set(cacheKey, data, ttl);
    }

    return data as T;
  }

  async post<T>(endpoint: string, body: any): Promise<T> {
    const startTime = performance.now();
    const response = await fetch(`${this.baseURL}${endpoint}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    });

    const duration = performance.now() - startTime;

    if (duration > 200) {
      console.warn(`[API] Slow response: ${endpoint} took ${duration.toFixed(2)}ms`);
    }

    if (!response.ok) {
      throw new Error(`API error: ${response.status} ${response.statusText}`);
    }

    // Invalidate related caches
    await this.invalidateRelatedCaches(endpoint);

    return await response.json() as T;
  }

  private async invalidateRelatedCaches(endpoint: string): Promise<void> {
    // Invalidate caches related to this endpoint
    // Example: POST to /mood-entries should invalidate GET /mood-entries cache
    const relatedEndpoints = this.getRelatedEndpoints(endpoint);
    for (const related of relatedEndpoints) {
      await httpCache.invalidate(`GET:${related}`);
    }
  }

  private getRelatedEndpoints(endpoint: string): string[] {
    // Map POST endpoints to related GET endpoints
    const mapping: { [key: string]: string[] } = {
      '/mood-entries': ['/mood-entries', '/mood-summary'],
      '/journal-entries': ['/journal-entries'],
      // Add more mappings
    };

    return mapping[endpoint] || [];
  }
}

export const cachedAPIClient = CachedAPIClient.getInstance();
```

### 3. Compression

**Request/Response Compression**:
```typescript
// src/services/network/CompressionService.ts
import pako from 'pako'; // gzip compression library

class CompressionService {
  private static instance: CompressionService;

  static getInstance(): CompressionService {
    if (!CompressionService.instance) {
      CompressionService.instance = new CompressionService();
    }
    return CompressionService.instance;
  }

  // Compress request payload
  compress(data: any): Uint8Array {
    const json = JSON.stringify(data);
    const compressed = pako.gzip(json);

    const originalSize = new Blob([json]).size;
    const compressedSize = compressed.length;
    const ratio = (1 - compressedSize / originalSize) * 100;

    console.log(`[Compression] ${originalSize}B → ${compressedSize}B (${ratio.toFixed(1)}% reduction)`);

    return compressed;
  }

  // Decompress response payload
  decompress(data: Uint8Array): any {
    const decompressed = pako.ungzip(data, { to: 'string' });
    return JSON.parse(decompressed);
  }
}

export const compressionService = CompressionService.getInstance();
```

---

## Battery Optimization

### Target: <5% Drain Per Hour Active Use

### 1. Background Task Optimization

**Efficient Sync Intervals**:
```typescript
// src/services/sync/SyncScheduler.ts
import BackgroundFetch from 'react-native-background-fetch';

class SyncScheduler {
  private static instance: SyncScheduler;

  static getInstance(): SyncScheduler {
    if (!SyncScheduler.instance) {
      SyncScheduler.instance = new SyncScheduler();
    }
    return SyncScheduler.instance;
  }

  async initialize(): Promise<void> {
    // Configure background fetch
    await BackgroundFetch.configure({
      minimumFetchInterval: 15, // Sync every 15 minutes (battery-friendly)
      stopOnTerminate: false,
      startOnBoot: true,
      enableHeadless: true,
    }, async (taskId) => {
      console.log('[BackgroundFetch] Task started:', taskId);

      try {
        await this.performSync();
        BackgroundFetch.finish(taskId);
      } catch (error) {
        console.error('[BackgroundFetch] Sync failed:', error);
        BackgroundFetch.finish(taskId);
      }
    }, (error) => {
      console.error('[BackgroundFetch] Configuration error:', error);
    });

    // Schedule sync
    await BackgroundFetch.scheduleTask({
      taskId: 'com.rediscovertalk.sync',
      delay: 15 * 60 * 1000, // 15 minutes
      periodic: true,
      forceAlarmManager: false, // Use JobScheduler (more battery-efficient)
    });
  }

  private async performSync(): Promise<void> {
    // Sync mood entries
    const { CloudSyncService } = await import('../CloudSyncService');
    await CloudSyncService.getInstance().syncMoodEntries();

    // Sync journal entries
    await CloudSyncService.getInstance().syncJournalEntries();

    console.log('[SyncScheduler] Sync completed');
  }

  async stopSync(): Promise<void> {
    await BackgroundFetch.stop();
    console.log('[SyncScheduler] Sync stopped');
  }
}

export const syncScheduler = SyncScheduler.getInstance();
```

### 2. Location Services Optimization

**Efficient Location Tracking**:
```typescript
// src/services/location/LocationService.ts
import Geolocation from 'react-native-geolocation-service';

class LocationService {
  private static instance: LocationService;
  private watchId: number | null = null;

  static getInstance(): LocationService {
    if (!LocationService.instance) {
      LocationService.instance = new LocationService();
    }
    return LocationService.instance;
  }

  async startTracking(): Promise<void> {
    // Use battery-efficient location tracking
    this.watchId = Geolocation.watchPosition(
      (position) => {
        console.log('[Location] Updated:', position.coords);
        this.handleLocationUpdate(position);
      },
      (error) => {
        console.error('[Location] Error:', error);
      },
      {
        enableHighAccuracy: false, // Use WiFi/cell towers (saves battery)
        distanceFilter: 100, // Update only after 100m movement
        interval: 5 * 60 * 1000, // Update every 5 minutes
        fastestInterval: 1 * 60 * 1000, // Fastest update: 1 minute
      }
    );
  }

  stopTracking(): void {
    if (this.watchId !== null) {
      Geolocation.clearWatch(this.watchId);
      this.watchId = null;
      console.log('[Location] Tracking stopped');
    }
  }

  private handleLocationUpdate(position: any): void {
    // Process location update (e.g., for location-based features)
  }
}

export const locationService = LocationService.getInstance();
```

### 3. Wake Lock Management

**Minimize Wake Locks**:
```typescript
// src/services/power/PowerManagementService.ts
import { AppState, AppStateStatus } from 'react-native';

class PowerManagementService {
  private static instance: PowerManagementService;
  private appState: AppStateStatus = 'active';

  static getInstance(): PowerManagementService {
    if (!PowerManagementService.instance) {
      PowerManagementService.instance = new PowerManagementService();
    }
    return PowerManagementService.instance;
  }

  initialize(): void {
    AppState.addEventListener('change', this.handleAppStateChange);
  }

  private handleAppStateChange = (nextAppState: AppStateStatus): void => {
    if (this.appState.match(/inactive|background/) && nextAppState === 'active') {
      // App has come to foreground
      this.onAppForeground();
    } else if (nextAppState === 'background') {
      // App has gone to background
      this.onAppBackground();
    }

    this.appState = nextAppState;
  };

  private onAppForeground(): void {
    console.log('[PowerManagement] App foregrounded');

    // Resume normal operations
    // - Resume location tracking (if needed)
    // - Resume network sync
    // - Resume animations
  }

  private onAppBackground(): void {
    console.log('[PowerManagement] App backgrounded');

    // Reduce battery consumption
    // - Stop location tracking
    // - Pause non-critical network requests
    // - Pause animations
    // - Clear timers

    this.cleanupTimers();
    this.pauseNonCriticalServices();
  }

  private cleanupTimers(): void {
    // Clear all active timers to prevent wake locks
    // Example: clearInterval, clearTimeout
  }

  private pauseNonCriticalServices(): void {
    // Pause services that don't need to run in background
    // Example: analytics, unnecessary sync
  }
}

export const powerManagementService = PowerManagementService.getInstance();
```

---

## Performance Monitoring

### Production Monitoring Setup

### 1. Firebase Performance Monitoring Integration

**Setup Script**:
```bash
#!/bin/bash
# scripts/setup-performance-monitoring.sh

echo "🔧 Setting up Firebase Performance Monitoring..."

# Install Firebase Performance
npm install @react-native-firebase/perf --save

# iOS setup
cd ios
pod install
cd ..

# Android setup (add to android/app/build.gradle)
cat <<EOF >> android/app/build.gradle
dependencies {
  implementation platform('com.google.firebase:firebase-bom:32.0.0')
  implementation 'com.google.firebase:firebase-perf'
}
EOF

echo "✅ Firebase Performance Monitoring setup complete"
echo "📝 Don't forget to add google-services.json (Android) and GoogleService-Info.plist (iOS)"
```

**Firebase Performance Service**:
```typescript
// src/services/monitoring/FirebasePerformanceService.ts
import perf from '@react-native-firebase/perf';

class FirebasePerformanceService {
  private static instance: FirebasePerformanceService;
  private traces: Map<string, any> = new Map();

  static getInstance(): FirebasePerformanceService {
    if (!FirebasePerformanceService.instance) {
      FirebasePerformanceService.instance = new FirebasePerformanceService();
    }
    return FirebasePerformanceService.instance;
  }

  async initialize(): Promise<void> {
    // Enable/disable based on build type
    await perf().setPerformanceCollectionEnabled(!__DEV__);
    console.log('[FirebasePerf] Initialized (enabled:', !__DEV__, ')');
  }

  // Track screen render performance
  async startScreenTrace(screenName: string): Promise<() => void> {
    const traceName = `screen_${screenName}`;
    const trace = await perf().startTrace(traceName);
    this.traces.set(traceName, trace);

    return async () => {
      await trace.stop();
      this.traces.delete(traceName);
      console.log(`[FirebasePerf] ${traceName} trace stopped`);
    };
  }

  // Track API call performance
  async trackAPICall(endpoint: string, method: string = 'GET'): Promise<() => void> {
    const httpMetric = await perf().newHttpMetric(endpoint, method);
    await httpMetric.start();

    return async (statusCode: number = 200, responseSize: number = 0) => {
      httpMetric.setHttpResponseCode(statusCode);
      httpMetric.setResponseContentType('application/json');
      httpMetric.setResponsePayloadSize(responseSize);
      await httpMetric.stop();
      console.log(`[FirebasePerf] API ${method} ${endpoint} - ${statusCode}`);
    };
  }

  // Track custom metrics
  async trackCustomMetric(traceName: string, attributes?: { [key: string]: string }): Promise<() => void> {
    const trace = await perf().startTrace(traceName);

    if (attributes) {
      Object.entries(attributes).forEach(([key, value]) => {
        trace.putAttribute(key, value);
      });
    }

    this.traces.set(traceName, trace);

    return async () => {
      await trace.stop();
      this.traces.delete(traceName);
      console.log(`[FirebasePerf] ${traceName} custom trace stopped`);
    };
  }
}

export const firebasePerformanceService = FirebasePerformanceService.getInstance();
```

### 2. Custom Performance Metrics

**Performance Metrics Collector**:
```typescript
// src/services/monitoring/MetricsCollector.ts
import { performanceMonitor } from '../PerformanceMonitor';

interface Metric {
  name: string;
  value: number;
  timestamp: number;
  tags?: { [key: string]: string };
}

class MetricsCollector {
  private static instance: MetricsCollector;
  private metrics: Metric[] = [];
  private flushInterval: NodeJS.Timeout | null = null;

  static getInstance(): MetricsCollector {
    if (!MetricsCollector.instance) {
      MetricsCollector.instance = new MetricsCollector();
    }
    return MetricsCollector.instance;
  }

  initialize(): void {
    // Flush metrics every 60 seconds
    this.flushInterval = setInterval(() => {
      this.flush();
    }, 60 * 1000);
  }

  recordMetric(name: string, value: number, tags?: { [key: string]: string }): void {
    const metric: Metric = {
      name,
      value,
      timestamp: Date.now(),
      tags,
    };

    this.metrics.push(metric);

    // Flush if buffer is full (100 metrics)
    if (this.metrics.length >= 100) {
      this.flush();
    }
  }

  private async flush(): Promise<void> {
    if (this.metrics.length === 0) return;

    const batch = this.metrics.splice(0, this.metrics.length);

    try {
      // Send metrics to backend
      await fetch('https://api.rediscovertalk.com/metrics', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ metrics: batch }),
      });

      console.log(`[MetricsCollector] Flushed ${batch.length} metrics`);
    } catch (error) {
      console.error('[MetricsCollector] Flush failed:', error);
      // Re-add metrics to buffer
      this.metrics.unshift(...batch);
    }
  }

  stop(): void {
    if (this.flushInterval) {
      clearInterval(this.flushInterval);
      this.flushInterval = null;
    }

    // Flush remaining metrics
    this.flush();
  }
}

export const metricsCollector = MetricsCollector.getInstance();
```

### 3. Performance Dashboard

**Real-Time Performance Metrics**:
```typescript
// src/screens/PerformanceDashboard.tsx (DEV only)
import React, { useEffect, useState } from 'react';
import { View, Text, ScrollView, StyleSheet } from 'react-native';
import { memoryMonitor } from '../utils/performance/MemoryMonitor';
import { metricsCollector } from '../services/monitoring/MetricsCollector';

export const PerformanceDashboard: React.FC = () => {
  const [memoryStats, setMemoryStats] = useState({ current: 0, average: 0, peak: 0 });

  useEffect(() => {
    // Update memory stats every second
    const interval = setInterval(() => {
      const stats = memoryMonitor.getMemoryStats();
      setMemoryStats(stats);
    }, 1000);

    return () => clearInterval(interval);
  }, []);

  const getMemoryColor = (mb: number) => {
    if (mb > 200) return '#FF3B30'; // Red - Critical
    if (mb > 150) return '#FF9500'; // Orange - High
    if (mb > 100) return '#FFCC00'; // Yellow - Medium
    return '#34C759'; // Green - Good
  };

  return (
    <ScrollView style={styles.container}>
      <Text style={styles.title}>Performance Dashboard</Text>

      {/* Memory Usage */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Memory Usage</Text>

        <View style={styles.metric}>
          <Text style={styles.metricLabel}>Current:</Text>
          <Text style={[styles.metricValue, { color: getMemoryColor(memoryStats.current) }]}>
            {memoryStats.current.toFixed(2)} MB
          </Text>
        </View>

        <View style={styles.metric}>
          <Text style={styles.metricLabel}>Average:</Text>
          <Text style={styles.metricValue}>{memoryStats.average.toFixed(2)} MB</Text>
        </View>

        <View style={styles.metric}>
          <Text style={styles.metricLabel}>Peak:</Text>
          <Text style={[styles.metricValue, { color: getMemoryColor(memoryStats.peak) }]}>
            {memoryStats.peak.toFixed(2)} MB
          </Text>
        </View>

        {/* Constitution Limits */}
        <View style={styles.limits}>
          <Text style={styles.limitText}>Baseline Limit: 100 MB</Text>
          <Text style={styles.limitText}>Peak Limit: 200 MB</Text>
        </View>
      </View>

      {/* Performance Targets */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Performance Targets</Text>

        <View style={styles.target}>
          <Text style={styles.targetLabel}>Launch Time (Cold):</Text>
          <Text style={styles.targetValue}>&lt;2s</Text>
        </View>

        <View style={styles.target}>
          <Text style={styles.targetLabel}>Launch Time (Warm):</Text>
          <Text style={styles.targetValue}>&lt;1s</Text>
        </View>

        <View style={styles.target}>
          <Text style={styles.targetLabel}>Frame Rate:</Text>
          <Text style={styles.targetValue}>60 FPS</Text>
        </View>

        <View style={styles.target}>
          <Text style={styles.targetLabel}>API Response:</Text>
          <Text style={styles.targetValue}>&lt;200ms</Text>
        </View>

        <View style={styles.target}>
          <Text style={styles.targetLabel}>Battery Drain:</Text>
          <Text style={styles.targetValue}>&lt;4%/hour</Text>
        </View>
      </View>
    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F2F2F7',
    padding: 16,
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 20,
  },
  section: {
    backgroundColor: '#FFFFFF',
    borderRadius: 10,
    padding: 16,
    marginBottom: 16,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: '600',
    marginBottom: 12,
  },
  metric: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: 8,
    borderBottomWidth: 1,
    borderBottomColor: '#E5E5EA',
  },
  metricLabel: {
    fontSize: 16,
    color: '#8E8E93',
  },
  metricValue: {
    fontSize: 16,
    fontWeight: '600',
  },
  limits: {
    marginTop: 12,
    paddingTop: 12,
    borderTopWidth: 1,
    borderTopColor: '#E5E5EA',
  },
  limitText: {
    fontSize: 14,
    color: '#8E8E93',
    marginBottom: 4,
  },
  target: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: 8,
  },
  targetLabel: {
    fontSize: 16,
    color: '#000000',
  },
  targetValue: {
    fontSize: 16,
    fontWeight: '600',
    color: '#007AFF',
  },
});
```

### 4. Performance Alerting

**Alerting Service**:
```typescript
// src/services/monitoring/AlertingService.ts
import { metricsCollector } from './MetricsCollector';

interface Alert {
  severity: 'critical' | 'high' | 'medium' | 'low';
  metric: string;
  value: number;
  threshold: number;
  message: string;
  timestamp: number;
}

class AlertingService {
  private static instance: AlertingService;
  private alerts: Alert[] = [];

  static getInstance(): AlertingService {
    if (!AlertingService.instance) {
      AlertingService.instance = new AlertingService();
    }
    return AlertingService.instance;
  }

  checkMemoryThresholds(memoryMB: number): void {
    if (memoryMB > 300) {
      this.createAlert('critical', 'memory_usage', memoryMB, 300,
        `CRITICAL: Memory usage ${memoryMB.toFixed(2)}MB exceeds 300MB limit`);
    } else if (memoryMB > 200) {
      this.createAlert('high', 'memory_usage', memoryMB, 200,
        `HIGH: Memory usage ${memoryMB.toFixed(2)}MB exceeds 200MB Constitution limit`);
    } else if (memoryMB > 150) {
      this.createAlert('medium', 'memory_usage', memoryMB, 150,
        `MEDIUM: Memory usage ${memoryMB.toFixed(2)}MB approaching 200MB limit`);
    }
  }

  checkLaunchTime(launchTimeMs: number, type: 'cold' | 'warm'): void {
    const threshold = type === 'cold' ? 2000 : 1000;
    const constitutionLimit = type === 'cold' ? 3000 : 1000;

    if (launchTimeMs > 5000) {
      this.createAlert('critical', `launch_time_${type}`, launchTimeMs, 5000,
        `CRITICAL: ${type} launch time ${launchTimeMs}ms exceeds 5s limit`);
    } else if (launchTimeMs > constitutionLimit) {
      this.createAlert('high', `launch_time_${type}`, launchTimeMs, constitutionLimit,
        `HIGH: ${type} launch time ${launchTimeMs}ms exceeds ${constitutionLimit}ms Constitution limit`);
    } else if (launchTimeMs > threshold) {
      this.createAlert('medium', `launch_time_${type}`, launchTimeMs, threshold,
        `MEDIUM: ${type} launch time ${launchTimeMs}ms exceeds ${threshold}ms target`);
    }
  }

  checkAPIResponseTime(endpoint: string, responseTimeMs: number): void {
    if (responseTimeMs > 500) {
      this.createAlert('high', 'api_response_time', responseTimeMs, 500,
        `HIGH: API ${endpoint} response time ${responseTimeMs}ms exceeds 500ms`);
    } else if (responseTimeMs > 200) {
      this.createAlert('medium', 'api_response_time', responseTimeMs, 200,
        `MEDIUM: API ${endpoint} response time ${responseTimeMs}ms exceeds 200ms target`);
    }
  }

  checkFrameRate(fps: number): void {
    if (fps < 30) {
      this.createAlert('critical', 'frame_rate', fps, 30,
        `CRITICAL: Frame rate ${fps}fps below 30fps (severe performance degradation)`);
    } else if (fps < 60) {
      this.createAlert('high', 'frame_rate', fps, 60,
        `HIGH: Frame rate ${fps}fps below 60fps Constitution requirement`);
    }
  }

  private createAlert(
    severity: Alert['severity'],
    metric: string,
    value: number,
    threshold: number,
    message: string
  ): void {
    const alert: Alert = {
      severity,
      metric,
      value,
      threshold,
      message,
      timestamp: Date.now(),
    };

    this.alerts.push(alert);

    // Log alert
    console.error(`[Alert] ${severity.toUpperCase()}: ${message}`);

    // Record metric
    metricsCollector.recordMetric(`alert_${metric}`, value, { severity });

    // Send to monitoring service
    this.sendAlertToMonitoring(alert);
  }

  private async sendAlertToMonitoring(alert: Alert): Promise<void> {
    try {
      await fetch('https://api.rediscovertalk.com/alerts', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ alert }),
      });
    } catch (error) {
      console.error('[AlertingService] Failed to send alert:', error);
    }
  }

  getAlerts(severity?: Alert['severity']): Alert[] {
    if (severity) {
      return this.alerts.filter(alert => alert.severity === severity);
    }
    return this.alerts;
  }

  clearAlerts(): void {
    this.alerts = [];
  }
}

export const alertingService = AlertingService.getInstance();
```

---

## Implementation Roadmap

### Phase 1: Foundation (Week 1-2)
- ✅ Set up performance profiling tools
- ✅ Implement memory monitoring
- ✅ Configure Firebase Performance Monitoring
- ✅ Create performance dashboard (DEV only)
- ✅ Establish performance baselines

### Phase 2: Optimization (Week 3-4)
- ✅ Implement code splitting and lazy loading
- ✅ Optimize FlatList virtualization
- ✅ Add image optimization and caching
- ✅ Implement request batching and caching
- ✅ Optimize animations with native driver

### Phase 3: Monitoring (Week 5-6)
- ✅ Set up production performance monitoring
- ✅ Implement custom metrics collection
- ✅ Configure alerting thresholds
- ✅ Create performance regression tests
- ✅ Integrate with CI/CD pipeline

### Phase 4: Validation (Week 7-8)
- 🔄 Run comprehensive performance tests
- 🔄 Validate against Constitution targets
- 🔄 Fix performance regressions
- 🔄 Document optimization results
- 🔄 Prepare for production release

---

## Success Criteria

**Constitution Compliance**:
- ✅ Launch time: <3s cold, <1s warm
- ✅ Memory: <100MB baseline, <200MB peak
- ✅ UI: 60fps during all interactions
- ✅ Battery: <5% drain per hour

**RediscoverTalk Targets**:
- ✅ Launch time: <2s cold, <1s warm
- ✅ Memory: <80MB baseline, <150MB peak
- ✅ API response: <200ms (p95)
- ✅ Bundle size: <500KB initial, <2MB total
- ✅ Battery: <4% drain per hour

**Monitoring**:
- ✅ Real-time performance metrics
- ✅ Automated alerting for regressions
- ✅ Performance dashboard (DEV)
- ✅ Production monitoring (Firebase)

---

## Appendix

### A. Performance Testing Script

```bash
#!/bin/bash
# scripts/performance-test.sh

echo "🚀 Running performance tests..."

# Test 1: Bundle size analysis
echo "📦 Analyzing bundle size..."
./scripts/analyze-bundle.sh

# Test 2: Memory profiling
echo "💾 Running memory profiling..."
npm run test -- --testNamePattern="Memory Profiling"

# Test 3: Launch time measurement
echo "⏱️  Measuring launch time..."
npm run test -- --testNamePattern="Launch Time"

# Test 4: Frame rate testing
echo "📊 Testing frame rate..."
npm run test -- --testNamePattern="Frame Rate"

# Test 5: API performance
echo "🌐 Testing API performance..."
npm run test -- --testNamePattern="API Performance"

echo "✅ Performance tests complete"
```

### B. Performance Checklist

**Before Production Release**:
- [ ] All Constitution targets met
- [ ] Bundle size <2MB
- [ ] Memory usage <200MB peak
- [ ] Launch time <3s cold, <1s warm
- [ ] UI maintains 60fps
- [ ] API responses <200ms (p95)
- [ ] Battery drain <5%/hour
- [ ] Performance monitoring configured
- [ ] Alerting thresholds set
- [ ] Performance regression tests passing

---

**Document Version**: 1.0.0
**Last Updated**: October 21, 2025
**Owner**: iOS Performance Specialist
**Status**: Active Implementation
