#!/usr/bin/env python3

"""
XcodeBuildMCP Integration for Rediscover Talk
Created by Claude on 2025-08-07
Automated testing framework using XcodeBuildMCP for comprehensive iOS testing
"""

import json
import os
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple

class XcodeBuildMCPIntegration:
    """XcodeBuildMCP integration for automated testing"""
    
    def __init__(self, project_path: str):
        self.project_path = Path(project_path)
        self.project_name = "RediscoverTalk"
        self.scheme_name = "RediscoverTalk"
        self.results_path = self.project_path / "TestResults"
        self.reports_path = self.project_path / "Reports"
        self.derived_data_path = self.project_path / "DerivedData"
        
        # Create necessary directories
        self._setup_directories()
        
    def _setup_directories(self):
        """Setup required directories for testing"""
        directories = [
            self.results_path,
            self.reports_path,
            self.derived_data_path,
            self.results_path / "UnitTests",
            self.results_path / "UITests", 
            self.results_path / "PerformanceTests",
            self.results_path / "Coverage",
            self.reports_path / "MCP"
        ]
        
        for directory in directories:
            directory.mkdir(parents=True, exist_ok=True)
            
    def log(self, message: str, level: str = "INFO"):
        """Log message with timestamp"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{timestamp}] [{level}] {message}")
        
    def run_command(self, command: List[str], capture_output: bool = True) -> Tuple[int, str, str]:
        """Run command and return exit code, stdout, stderr"""
        try:
            result = subprocess.run(
                command,
                capture_output=capture_output,
                text=True,
                cwd=self.project_path
            )
            return result.returncode, result.stdout, result.stderr
        except Exception as e:
            return 1, "", str(e)
            
    def clean_build(self) -> bool:
        """Clean build artifacts"""
        self.log("Cleaning build artifacts")
        
        if self.derived_data_path.exists():
            import shutil
            shutil.rmtree(self.derived_data_path)
            self.derived_data_path.mkdir(parents=True, exist_ok=True)
            
        return True
        
    def build_project(self) -> bool:
        """Build project using XcodeBuildMCP"""
        self.log("Building project for testing")
        
        command = [
            "xcodebuild",
            "-project", str(self.project_path / f"{self.project_name}.xcodeproj"),
            "-scheme", self.scheme_name,
            "-destination", "platform=iOS Simulator,name=iPhone 15 Pro,OS=17.0",
            "-derivedDataPath", str(self.derived_data_path),
            "build-for-testing"
        ]
        
        exit_code, stdout, stderr = self.run_command(command)
        
        # Save build log
        build_log_path = self.reports_path / "mcp_build.log"
        with open(build_log_path, 'w') as f:
            f.write(f"Command: {' '.join(command)}\n\n")
            f.write("STDOUT:\n")
            f.write(stdout)
            f.write("\nSTDERR:\n")
            f.write(stderr)
            
        if exit_code == 0:
            self.log("Build successful", "SUCCESS")
            return True
        else:
            self.log(f"Build failed with exit code {exit_code}", "ERROR")
            return False
            
    def run_unit_tests(self) -> Dict:
        """Run unit tests using XcodeBuildMCP"""
        self.log("Running unit tests")
        
        result_bundle = self.results_path / "UnitTests" / "UnitTests.xcresult"
        
        command = [
            "xcodebuild",
            "-project", str(self.project_path / f"{self.project_name}.xcodeproj"),
            "-scheme", self.scheme_name,
            "-destination", "platform=iOS Simulator,name=iPhone 15 Pro,OS=17.0",
            "-derivedDataPath", str(self.derived_data_path),
            "-resultBundlePath", str(result_bundle),
            "-enableCodeCoverage", "YES",
            "test-without-building",
            "-only-testing:RediscoverTalkUnitTests"
        ]
        
        exit_code, stdout, stderr = self.run_command(command)
        
        # Save test log
        test_log_path = self.reports_path / "mcp_unit_tests.log"
        with open(test_log_path, 'w') as f:
            f.write(f"Command: {' '.join(command)}\n\n")
            f.write("STDOUT:\n")
            f.write(stdout)
            f.write("\nSTDERR:\n")
            f.write(stderr)
            
        # Analyze results
        test_results = self._analyze_test_results(result_bundle, "unit")
        test_results["exit_code"] = exit_code
        
        if exit_code == 0:
            self.log("Unit tests passed", "SUCCESS")
        else:
            self.log(f"Unit tests failed with exit code {exit_code}", "ERROR")
            
        return test_results
        
    def run_ui_tests(self) -> Dict:
        """Run UI tests using XcodeBuildMCP"""
        self.log("Running UI tests")
        
        # Boot simulator
        self._boot_simulator()
        
        result_bundle = self.results_path / "UITests" / "UITests.xcresult"
        
        command = [
            "xcodebuild",
            "-project", str(self.project_path / f"{self.project_name}.xcodeproj"),
            "-scheme", self.scheme_name,
            "-destination", "platform=iOS Simulator,name=iPhone 15 Pro,OS=17.0",
            "-derivedDataPath", str(self.derived_data_path),
            "-resultBundlePath", str(result_bundle),
            "test-without-building",
            "-only-testing:RediscoverTalkUITests"
        ]
        
        exit_code, stdout, stderr = self.run_command(command)
        
        # Save test log
        test_log_path = self.reports_path / "mcp_ui_tests.log"
        with open(test_log_path, 'w') as f:
            f.write(f"Command: {' '.join(command)}\n\n")
            f.write("STDOUT:\n")
            f.write(stdout)
            f.write("\nSTDERR:\n")
            f.write(stderr)
            
        # Analyze results
        test_results = self._analyze_test_results(result_bundle, "ui")
        test_results["exit_code"] = exit_code
        
        if exit_code == 0:
            self.log("UI tests passed", "SUCCESS")
        else:
            self.log(f"UI tests failed with exit code {exit_code}", "ERROR")
            
        return test_results
        
    def run_performance_tests(self) -> Dict:
        """Run performance tests using XcodeBuildMCP"""
        self.log("Running performance tests")
        
        result_bundle = self.results_path / "PerformanceTests" / "PerformanceTests.xcresult"
        
        command = [
            "xcodebuild",
            "-project", str(self.project_path / f"{self.project_name}.xcodeproj"),
            "-scheme", self.scheme_name,
            "-destination", "platform=iOS Simulator,name=iPhone 15 Pro,OS=17.0",
            "-derivedDataPath", str(self.derived_data_path),
            "-resultBundlePath", str(result_bundle),
            "test-without-building",
            "-only-testing:RediscoverTalkUITests/PerformanceTests"
        ]
        
        exit_code, stdout, stderr = self.run_command(command)
        
        # Save test log
        test_log_path = self.reports_path / "mcp_performance_tests.log"
        with open(test_log_path, 'w') as f:
            f.write(f"Command: {' '.join(command)}\n\n")
            f.write("STDOUT:\n")
            f.write(stdout)
            f.write("\nSTDERR:\n")
            f.write(stderr)
            
        # Analyze results
        test_results = self._analyze_test_results(result_bundle, "performance")
        test_results["exit_code"] = exit_code
        
        if exit_code == 0:
            self.log("Performance tests passed", "SUCCESS")
        else:
            self.log("Performance tests completed with warnings", "WARNING")
            
        return test_results
        
    def generate_coverage_report(self) -> Dict:
        """Generate code coverage report"""
        self.log("Generating code coverage report")
        
        unit_test_results = self.results_path / "UnitTests" / "UnitTests.xcresult"
        
        if not unit_test_results.exists():
            self.log("No unit test results found for coverage", "WARNING")
            return {"coverage_percentage": 0, "error": "No test results"}
            
        # Generate JSON coverage report
        coverage_json_path = self.results_path / "Coverage" / "coverage.json"
        command = [
            "xcrun", "xccov", "view", "--report", "--json", str(unit_test_results)
        ]
        
        exit_code, stdout, stderr = self.run_command(command)
        
        if exit_code == 0:
            with open(coverage_json_path, 'w') as f:
                f.write(stdout)
                
            # Parse coverage percentage
            try:
                coverage_data = json.loads(stdout)
                coverage_percentage = coverage_data.get('lineCoverage', 0)
                coverage_percentage_float = float(coverage_percentage)
                
                self.log(f"Code coverage: {coverage_percentage_float:.1%}")
                
                # Generate human-readable report
                coverage_report_path = self.results_path / "Coverage" / "coverage_report.txt"
                command = [
                    "xcrun", "xccov", "view", "--report", str(unit_test_results)
                ]
                
                exit_code, stdout, stderr = self.run_command(command)
                if exit_code == 0:
                    with open(coverage_report_path, 'w') as f:
                        f.write(stdout)
                        
                return {
                    "coverage_percentage": coverage_percentage_float,
                    "meets_target": coverage_percentage_float >= 0.9,  # 90% target
                    "json_report": str(coverage_json_path),
                    "text_report": str(coverage_report_path)
                }
                
            except (json.JSONDecodeError, ValueError, KeyError) as e:
                self.log(f"Failed to parse coverage data: {e}", "ERROR")
                return {"coverage_percentage": 0, "error": str(e)}
        else:
            self.log(f"Failed to generate coverage report: {stderr}", "ERROR")
            return {"coverage_percentage": 0, "error": stderr}
            
    def _boot_simulator(self):
        """Boot iOS simulator"""
        self.log("Booting iOS Simulator")
        
        command = ["xcrun", "simctl", "boot", "iPhone 15 Pro"]
        self.run_command(command, capture_output=False)
        
        # Wait for simulator to boot
        time.sleep(5)
        
    def _analyze_test_results(self, result_bundle_path: Path, test_type: str) -> Dict:
        """Analyze test results from xcresult bundle"""
        if not result_bundle_path.exists():
            return {"error": "Result bundle not found", "test_count": 0}
            
        # Extract test summary using xcresulttool
        command = [
            "xcrun", "xcresulttool", "get",
            "--path", str(result_bundle_path),
            "--format", "json"
        ]
        
        exit_code, stdout, stderr = self.run_command(command)
        
        if exit_code != 0:
            return {"error": f"Failed to analyze results: {stderr}", "test_count": 0}
            
        # Save raw results
        results_json_path = self.reports_path / "MCP" / f"{test_type}_test_results.json"
        with open(results_json_path, 'w') as f:
            f.write(stdout)
            
        try:
            results_data = json.loads(stdout)
            
            # Extract test statistics
            test_summary = {
                "test_type": test_type,
                "result_bundle": str(result_bundle_path),
                "raw_results": str(results_json_path),
                "test_count": 0,
                "passed_count": 0,
                "failed_count": 0,
                "failures": []
            }
            
            # Parse test results (structure may vary)
            if "issues" in results_data:
                issues = results_data["issues"]
                if "testFailureSummaries" in issues:
                    failures = issues["testFailureSummaries"]
                    test_summary["failed_count"] = len(failures)
                    test_summary["failures"] = [failure.get("message", "Unknown failure") for failure in failures]
                    
            return test_summary
            
        except json.JSONDecodeError as e:
            return {"error": f"Failed to parse results JSON: {e}", "test_count": 0}
            
    def generate_comprehensive_report(self, test_results: Dict) -> str:
        """Generate comprehensive MCP test report"""
        self.log("Generating comprehensive MCP test report")
        
        report_path = self.reports_path / "mcp_comprehensive_report.json"
        
        report_data = {
            "generated_at": datetime.now().isoformat(),
            "project_name": self.project_name,
            "test_framework": "XcodeBuildMCP",
            "test_results": test_results,
            "summary": {
                "total_test_suites": len([k for k in test_results.keys() if k.endswith("_tests")]),
                "all_tests_passed": all(
                    result.get("exit_code", 1) == 0 
                    for key, result in test_results.items() 
                    if key.endswith("_tests")
                ),
                "coverage_target_met": test_results.get("coverage", {}).get("meets_target", False)
            }
        }
        
        with open(report_path, 'w') as f:
            json.dump(report_data, f, indent=2)
            
        # Also generate markdown report
        md_report_path = self.reports_path / "mcp_comprehensive_report.md"
        
        with open(md_report_path, 'w') as f:
            f.write("# Rediscover Talk - XcodeBuildMCP Test Report\n\n")
            f.write(f"**Generated:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"**Framework:** XcodeBuildMCP Integration\n\n")
            
            f.write("## Test Summary\n\n")
            
            # Build status
            if test_results.get("build_success", False):
                f.write("- ✅ Build: SUCCESS\n")
            else:
                f.write("- ❌ Build: FAILED\n")
                
            # Unit tests
            unit_tests = test_results.get("unit_tests", {})
            if unit_tests.get("exit_code", 1) == 0:
                f.write("- ✅ Unit Tests: PASSED\n")
            else:
                f.write("- ❌ Unit Tests: FAILED\n")
                
            # UI tests
            ui_tests = test_results.get("ui_tests", {})
            if ui_tests.get("exit_code", 1) == 0:
                f.write("- ✅ UI Tests: PASSED\n")
            else:
                f.write("- ❌ UI Tests: FAILED\n")
                
            # Performance tests
            perf_tests = test_results.get("performance_tests", {})
            if perf_tests.get("exit_code", 1) == 0:
                f.write("- ✅ Performance Tests: PASSED\n")
            else:
                f.write("- ⚠️ Performance Tests: COMPLETED WITH WARNINGS\n")
                
            # Coverage
            coverage = test_results.get("coverage", {})
            coverage_pct = coverage.get("coverage_percentage", 0)
            if coverage.get("meets_target", False):
                f.write(f"- ✅ Code Coverage: {coverage_pct:.1%} (Target: 90%)\n")
            else:
                f.write(f"- ⚠️ Code Coverage: {coverage_pct:.1%} (Below 90% target)\n")
                
            f.write("\n## Detailed Results\n\n")
            
            # Add detailed results for each test suite
            for test_type, results in test_results.items():
                if test_type.endswith("_tests"):
                    f.write(f"### {test_type.replace('_', ' ').title()}\n\n")
                    if results.get("failed_count", 0) > 0:
                        f.write("**Failures:**\n")
                        for failure in results.get("failures", []):
                            f.write(f"- {failure}\n")
                        f.write("\n")
                    else:
                        f.write("All tests passed ✅\n\n")
                        
        self.log(f"Comprehensive report generated: {md_report_path}")
        return str(md_report_path)
        
    def run_complete_test_suite(self) -> Dict:
        """Run complete test suite using XcodeBuildMCP"""
        self.log("Starting complete XcodeBuildMCP test suite")
        
        start_time = datetime.now()
        test_results = {}
        
        try:
            # Clean and build
            self.clean_build()
            build_success = self.build_project()
            test_results["build_success"] = build_success
            
            if not build_success:
                test_results["error"] = "Build failed - cannot proceed with tests"
                return test_results
                
            # Run all test suites
            test_results["unit_tests"] = self.run_unit_tests()
            test_results["ui_tests"] = self.run_ui_tests()
            test_results["performance_tests"] = self.run_performance_tests()
            
            # Generate coverage report
            test_results["coverage"] = self.generate_coverage_report()
            
            # Calculate overall success
            all_tests_passed = (
                test_results["unit_tests"].get("exit_code", 1) == 0 and
                test_results["ui_tests"].get("exit_code", 1) == 0 and
                test_results["performance_tests"].get("exit_code", 1) == 0
            )
            
            test_results["overall_success"] = all_tests_passed
            test_results["execution_time"] = (datetime.now() - start_time).total_seconds()
            
            # Generate comprehensive report
            report_path = self.generate_comprehensive_report(test_results)
            test_results["report_path"] = report_path
            
            if all_tests_passed:
                self.log("🎉 All tests passed! XcodeBuildMCP test suite completed successfully", "SUCCESS")
            else:
                self.log("⚠️ Some tests failed. Check the detailed report for more information", "WARNING")
                
        except Exception as e:
            self.log(f"Test suite execution failed: {e}", "ERROR")
            test_results["error"] = str(e)
            test_results["overall_success"] = False
            
        return test_results

def main():
    """Main execution function"""
    if len(sys.argv) != 2:
        print("Usage: python3 xcodebuild_mcp_integration.py <project_path>")
        sys.exit(1)
        
    project_path = sys.argv[1]
    
    if not os.path.exists(project_path):
        print(f"Error: Project path does not exist: {project_path}")
        sys.exit(1)
        
    # Create XcodeBuildMCP integration instance
    mcp_integration = XcodeBuildMCPIntegration(project_path)
    
    # Run complete test suite
    results = mcp_integration.run_complete_test_suite()
    
    # Exit with appropriate code
    if results.get("overall_success", False):
        sys.exit(0)
    else:
        sys.exit(1)

if __name__ == "__main__":
    main()