# Contributing to Rediscover Talk

Thank you for your interest in contributing to Rediscover Talk! This document provides guidelines and information for contributors.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Environment](#development-environment)
- [Contributing Process](#contributing-process)
- [Code Standards](#code-standards)
- [Testing Guidelines](#testing-guidelines)
- [Pull Request Process](#pull-request-process)

## 🤝 Code of Conduct

We are committed to providing a welcoming and inclusive environment for all contributors. Please be respectful and constructive in all interactions.

### Our Standards

- **Be Respectful**: Treat everyone with respect and kindness
- **Be Inclusive**: Welcome newcomers and help them get started
- **Be Constructive**: Provide helpful feedback and suggestions
- **Be Professional**: Maintain a professional tone in all communications

## 🚀 Getting Started

### Prerequisites

Before contributing, ensure you have:

- **Xcode 26 Beta** or later (required for iOS 26+ features)
- **macOS 14.5+** for development
- **Git** for version control
- **Valid Apple Developer Account** for testing subscriptions
- **Python 3.11+** for automation scripts

### Development Setup

1. **Fork the Repository**
   ```bash
   # Fork on GitHub, then clone your fork
   git clone https://github.com/YOUR-USERNAME/rediscover-talk.git
   cd rediscover-talk
   ```

2. **Set Up Development Environment**
   ```bash
   # Open in Xcode
   open RediscoverTalk.xcodeproj
   
   # Install development dependencies
   pip3 install -r requirements.txt  # If available
   ```

3. **Configure Environment**
   - Add your OpenAI API key to test AI features
   - Configure Supabase credentials for backend testing
   - Set up StoreKit sandbox for subscription testing

## 🛠️ Development Environment

### Required Tools

- **Xcode 26 Beta**: Primary development environment
- **iOS 26 Simulator**: For testing modern iOS features  
- **Python 3.11+**: For automation scripts and MCP integration
- **Git**: Version control and collaboration

### Recommended Tools

- **SF Symbols 5**: For consistent iconography
- **Proxyman/Charles**: For network debugging
- **Simulator**: Multiple iOS versions for compatibility testing
- **TestFlight**: For beta testing and distribution

### Environment Variables

Create a `Config/Development.xcconfig` file with:
```
OPENAI_API_KEY = your_openai_key_here
SUPABASE_URL = your_supabase_url_here
SUPABASE_ANON_KEY = your_supabase_anon_key_here
```

## 🔄 Contributing Process

### 1. Choose an Issue

- Browse [open issues](https://github.com/litmonbobby/rediscover-talk/issues)
- Look for issues labeled `good first issue` for beginners
- Comment on the issue to indicate you're working on it
- Wait for maintainer acknowledgment before starting work

### 2. Create a Branch

```bash
# Create feature branch from main
git checkout main
git pull origin main
git checkout -b feature/your-feature-name

# For bug fixes
git checkout -b fix/bug-description

# For documentation
git checkout -b docs/documentation-update
```

### 3. Make Changes

- Keep commits atomic and well-described
- Follow the established code patterns and architecture
- Add tests for new functionality
- Update documentation as needed

### 4. Test Your Changes

```bash
# Run full test suite
./Scripts/ci_testing_pipeline.sh

# Run specific test categories
xcodebuild test -project RediscoverTalk.xcodeproj -scheme RediscoverTalk -only-testing:RediscoverTalkUnitTests

# Validate framework compliance
python3 Scripts/validate_testing_framework.py "$(pwd)"
```

## 📝 Code Standards

### Swift Style Guidelines

#### Modern iOS 26+ Patterns
```swift
// ✅ Use @Observable for state management
@Observable
class BreathingViewModel {
    var isActive: Bool = false
    var breathingPattern: BreathingPattern = .calm
}

// ✅ Use structured concurrency
func loadBreathingExercises() async throws -> [BreathingExercise] {
    try await exerciseService.fetchExercises()
}

// ✅ Use @MainActor for UI updates
@MainActor
class UIViewModel: ObservableObject {
    @Published var isLoading = false
}
```

#### SwiftUI Best Practices
```swift
// ✅ Prefer explicit state management
struct ContentView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @State private var showingModal = false
    
    var body: some View {
        NavigationStack(path: .constant(coordinator.navigationPath)) {
            // View content
        }
    }
}

// ✅ Use computed properties for view logic
var isReadyForBreathing: Bool {
    hasActiveSubscription && !isCurrentlyInSession
}
```

### Naming Conventions

- **Classes**: PascalCase (`BreathingViewModel`)
- **Functions**: camelCase (`startBreathingSession()`)
- **Variables**: camelCase (`breathingPattern`)
- **Constants**: camelCase (`maxSessionDuration`)
- **Enums**: PascalCase with lowercase cases (`BreathingPattern.calm`)

### Documentation Standards

```swift
/// Manages breathing exercise sessions with SharePlay integration
/// 
/// This class coordinates breathing exercises across multiple devices using
/// SharePlay GroupActivities, ensuring synchronized timing and state.
///
/// - Important: Requires iOS 26+ for SharePlay functionality
/// - Note: Subscribe to `breathingStateUpdates` for real-time coordination
class FamilyBreathingManager: ObservableObject {
    
    /// Starts a new family breathing session
    /// - Parameters:
    ///   - pattern: The breathing pattern to use
    ///   - duration: Session duration in seconds
    /// - Returns: Session identifier for coordination
    /// - Throws: `BreathingError` if session cannot be started
    func startFamilySession(
        pattern: BreathingPattern,
        duration: TimeInterval
    ) async throws -> SessionIdentifier {
        // Implementation
    }
}
```

## 🧪 Testing Guidelines

### Testing Requirements

All contributions must include appropriate tests:

- **Unit Tests**: 90%+ code coverage for new functionality
- **Integration Tests**: For API integrations and cross-component interaction
- **UI Tests**: For critical user journeys and accessibility
- **Performance Tests**: For animation-heavy or resource-intensive features

### Test Categories

#### Unit Tests (`RediscoverTalkUnitTests/`)
```swift
class BreathingViewModelTests: XCTestCase {
    var viewModel: BreathingViewModel!
    
    override func setUp() async throws {
        viewModel = BreathingViewModel()
    }
    
    func testStartingBreathingSession() async throws {
        // Given
        XCTAssertFalse(viewModel.isActive)
        
        // When
        await viewModel.startSession(pattern: .calm)
        
        // Then
        XCTAssertTrue(viewModel.isActive)
    }
}
```

#### UI Tests (`RediscoverTalkUITests/`)
```swift
func testBreathingSessionFlow() throws {
    let app = XCUIApplication()
    app.launch()
    
    // Navigate to breathing view
    app.tabBars.buttons["Breathe"].tap()
    
    // Start session
    app.buttons["Start Session"].tap()
    
    // Verify session started
    XCTAssertTrue(app.staticTexts["Breathe In"].waitForExistence(timeout: 3))
}
```

#### Performance Tests
```swift
func testBreathingAnimationPerformance() {
    measure(metrics: [XCTCPUMetric(), XCTMemoryMetric()]) {
        // Performance-critical code
        viewModel.animateBreathingCycle()
    }
}
```

### Testing MCP Integration

When testing MCP-enhanced features:

```swift
func testMCPIntegration() async throws {
    // Use XcodeBuildMCP for build testing
    let buildResult = try await MCPTestHelper.buildProject()
    XCTAssertTrue(buildResult.success)
    
    // Test Sequential MCP for complex workflows
    let analysisResult = try await MCPTestHelper.analyzeComplexWorkflow()
    XCTAssertGreaterThan(analysisResult.confidence, 0.8)
}
```

## 🔀 Pull Request Process

### Before Submitting

- [ ] All tests pass locally (`./Scripts/ci_testing_pipeline.sh`)
- [ ] Code follows style guidelines
- [ ] Documentation updated for new features
- [ ] CHANGELOG.md updated with changes
- [ ] No merge conflicts with main branch

### Pull Request Template

When creating a PR, include:

```markdown
## Description
Brief description of changes and motivation.

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## Testing
- [ ] Unit tests added/updated
- [ ] UI tests added/updated  
- [ ] Manual testing completed
- [ ] Performance impact assessed

## Screenshots
Include screenshots for UI changes.

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] Tests added and passing
```

### Review Process

1. **Automated Checks**: CI/CD pipeline runs automatically
2. **Code Review**: Maintainers review code quality and architecture
3. **Testing**: Reviewers test functionality manually if needed
4. **Approval**: At least one maintainer approval required
5. **Merge**: Squash and merge preferred for clean history

## 🏷️ Issue Labels

Understanding our label system:

- `bug`: Something isn't working correctly
- `enhancement`: New feature or improvement  
- `good first issue`: Perfect for newcomers
- `help wanted`: Extra attention needed
- `documentation`: Documentation improvements
- `testing`: Testing-related improvements
- `performance`: Performance optimization
- `accessibility`: Accessibility improvements
- `ios26`: Specific to iOS 26+ features
- `shareplay`: SharePlay functionality
- `subscriptions`: StoreKit/subscription features
- `ai-integration`: OpenAI/AI-related features

## 📚 Resources

### Documentation
- [Apple iOS Development](https://developer.apple.com/ios/)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [SharePlay Documentation](https://developer.apple.com/documentation/groupactivities)
- [StoreKit 2 Documentation](https://developer.apple.com/documentation/storekit)

### Internal Resources
- `Documentation/`: Project-specific documentation
- `Scripts/`: Automation and testing scripts
- `TESTING_FRAMEWORK_SUMMARY.md`: Comprehensive testing guide
- `FamilyWellnessSharePlay.md`: SharePlay implementation details

### MCP Resources
- [Model Context Protocol](https://modelcontextprotocol.io/)
- MCP Server Integration guides in project documentation

## 🆘 Getting Help

- **GitHub Issues**: For bug reports and feature requests
- **GitHub Discussions**: For questions and community support
- **Documentation**: Check existing docs first
- **Code Comments**: Comprehensive inline documentation available

## 🙏 Recognition

Contributors will be:

- Listed in project contributors
- Acknowledged in release notes for significant contributions
- Invited to beta testing programs
- Considered for maintainer roles based on consistent quality contributions

---

Thank you for contributing to Rediscover Talk! Your efforts help create better mental wellness tools for families worldwide. 🌟