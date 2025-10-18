#!/usr/bin/env python3
"""
Comprehensive Test Orchestration System for Podinfo Application
This script orchestrates comprehensive testing across Go, Java, and Python
"""

import subprocess
import sys
import os
import time
import json
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
import argparse

class TestOrchestrator:
    def __init__(self):
        self.start_time = time.time()
        self.results = {
            'go_tests': {},
            'java_tests': {},
            'python_tests': {},
            'coverage': {},
            'performance': {},
            'integration': {},
            'security': {},
            'summary': {}
        }
        self.project_root = Path.cwd()
        
    def log(self, message, level="INFO"):
        timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{timestamp}] [{level}] {message}")
        
    def run_command(self, command, cwd=None, timeout=300):
        """Run a command and return the result"""
        try:
            self.log(f"Running: {command}")
            result = subprocess.run(
                command,
                shell=True,
                cwd=cwd or self.project_root,
                capture_output=True,
                text=True,
                timeout=timeout
            )
            return {
                'success': result.returncode == 0,
                'returncode': result.returncode,
                'stdout': result.stdout,
                'stderr': result.stderr,
                'command': command
            }
        except subprocess.TimeoutExpired:
            return {
                'success': False,
                'returncode': -1,
                'stdout': '',
                'stderr': f'Command timed out after {timeout} seconds',
                'command': command
            }
        except Exception as e:
            return {
                'success': False,
                'returncode': -1,
                'stdout': '',
                'stderr': str(e),
                'command': command
            }
    
    def run_go_tests(self):
        """Run comprehensive Go tests"""
        self.log("Starting Go test execution...")
        
        # Set up Go environment
        go_path = self.project_root / "go" / "bin"
        go_root = self.project_root / "go"
        
        env = os.environ.copy()
        env['PATH'] = f"{go_path}:{env.get('PATH', '')}"
        env['GOROOT'] = str(go_root)
        
        # Run different types of Go tests
        test_commands = [
            {
                'name': 'unit_tests',
                'command': f'export PATH={go_path}:$PATH && export GOROOT={go_root} && ./go/bin/go test -v -coverprofile=coverage.out ./pkg/... ./cmd/...',
                'description': 'Unit tests with coverage'
            },
            {
                'name': 'integration_tests',
                'command': f'export PATH={go_path}:$PATH && export GOROOT={go_root} && ./go/bin/go test -v -tags=integration ./pkg/... ./cmd/...',
                'description': 'Integration tests'
            },
            {
                'name': 'comprehensive_tests',
                'command': f'export PATH={go_path}:$PATH && export GOROOT={go_root} && ./go/bin/go test -v -tags=comprehensive ./pkg/... ./cmd/...',
                'description': 'Comprehensive tests'
            },
            {
                'name': 'performance_tests',
                'command': f'export PATH={go_path}:$PATH && export GOROOT={go_root} && ./go/bin/go test -v -tags=performance -bench=. ./pkg/... ./cmd/...',
                'description': 'Performance tests'
            }
        ]
        
        for test_cmd in test_commands:
            self.log(f"Running {test_cmd['description']}...")
            result = self.run_command(test_cmd['command'], timeout=600)
            self.results['go_tests'][test_cmd['name']] = result
            
            if result['success']:
                self.log(f"✅ {test_cmd['description']} passed")
            else:
                self.log(f"❌ {test_cmd['description']} failed: {result['stderr']}", "ERROR")
        
        # Generate coverage report
        self.log("Generating Go coverage report...")
        coverage_result = self.run_command(f'export PATH={go_path}:$PATH && export GOROOT={go_root} && ./go/bin/go tool cover -func=coverage.out')
        if coverage_result['success']:
            self.results['coverage']['go'] = coverage_result['stdout']
            self.log("✅ Go coverage report generated")
        else:
            self.log("❌ Failed to generate Go coverage report", "ERROR")
    
    def run_java_tests(self):
        """Run comprehensive Java tests"""
        self.log("Starting Java test execution...")
        
        # Check if Maven is available
        maven_check = self.run_command("mvn --version")
        if not maven_check['success']:
            self.log("Maven not found, skipping Java tests", "WARNING")
            return
        
        # Run Maven tests with JaCoCo
        java_commands = [
            {
                'name': 'unit_tests',
                'command': 'mvn clean test',
                'description': 'Java unit tests'
            },
            {
                'name': 'integration_tests',
                'command': 'mvn clean test -Dtest=*IntegrationTest',
                'description': 'Java integration tests'
            },
            {
                'name': 'coverage_report',
                'command': 'mvn clean test jacoco:report',
                'description': 'Java coverage report with JaCoCo'
            }
        ]
        
        for test_cmd in java_commands:
            self.log(f"Running {test_cmd['description']}...")
            result = self.run_command(test_cmd['command'], timeout=600)
            self.results['java_tests'][test_cmd['name']] = result
            
            if result['success']:
                self.log(f"✅ {test_cmd['description']} passed")
            else:
                self.log(f"❌ {test_cmd['description']} failed: {result['stderr']}", "ERROR")
        
        # Check if coverage report was generated
        coverage_file = self.project_root / "target" / "site" / "jacoco" / "index.html"
        if coverage_file.exists():
            self.log("✅ Java coverage report generated at target/site/jacoco/index.html")
            self.results['coverage']['java'] = str(coverage_file)
        else:
            self.log("❌ Java coverage report not found", "WARNING")
    
    def run_python_tests(self):
        """Run comprehensive Python tests"""
        self.log("Starting Python test execution...")
        
        # Check if pytest is available
        pytest_check = self.run_command("python3 -m pytest --version")
        if not pytest_check['success']:
            self.log("pytest not found, installing requirements...")
            install_result = self.run_command("pip3 install -r requirements-test.txt")
            if not install_result['success']:
                self.log("Failed to install Python test requirements", "ERROR")
                return
        
        # Run Python tests
        python_commands = [
            {
                'name': 'unit_tests',
                'command': 'python3 -m pytest test/ -v --cov=. --cov-report=html --cov-report=term',
                'description': 'Python unit tests with coverage'
            },
            {
                'name': 'integration_tests',
                'command': 'python3 -m pytest test/ -v -m integration',
                'description': 'Python integration tests'
            },
            {
                'name': 'performance_tests',
                'command': 'python3 -m pytest test/ -v -m performance --benchmark-only',
                'description': 'Python performance tests'
            }
        ]
        
        for test_cmd in python_commands:
            self.log(f"Running {test_cmd['description']}...")
            result = self.run_command(test_cmd['command'], timeout=600)
            self.results['python_tests'][test_cmd['name']] = result
            
            if result['success']:
                self.log(f"✅ {test_cmd['description']} passed")
            else:
                self.log(f"❌ {test_cmd['description']} failed: {result['stderr']}", "ERROR")
    
    def run_performance_benchmarks(self):
        """Run performance benchmarks across all languages"""
        self.log("Starting performance benchmarks...")
        
        # Go performance benchmarks
        go_path = self.project_root / "go" / "bin"
        go_root = self.project_root / "go"
        
        benchmark_commands = [
            {
                'name': 'go_benchmarks',
                'command': f'export PATH={go_path}:$PATH && export GOROOT={go_root} && ./go/bin/go test -bench=. -benchmem ./pkg/... ./cmd/...',
                'description': 'Go performance benchmarks'
            },
            {
                'name': 'java_benchmarks',
                'command': 'mvn test -Dtest=*BenchmarkTest',
                'description': 'Java performance benchmarks'
            },
            {
                'name': 'python_benchmarks',
                'command': 'python3 -m pytest test/ -v --benchmark-only --benchmark-sort=mean',
                'description': 'Python performance benchmarks'
            }
        ]
        
        for benchmark_cmd in benchmark_commands:
            self.log(f"Running {benchmark_cmd['description']}...")
            result = self.run_command(benchmark_cmd['command'], timeout=300)
            self.results['performance'][benchmark_cmd['name']] = result
            
            if result['success']:
                self.log(f"✅ {benchmark_cmd['description']} completed")
            else:
                self.log(f"❌ {benchmark_cmd['description']} failed: {result['stderr']}", "ERROR")
    
    def run_integration_tests(self):
        """Run cross-language integration tests"""
        self.log("Starting integration tests...")
        
        integration_commands = [
            {
                'name': 'end_to_end',
                'command': 'python3 -m pytest test/integration/ -v',
                'description': 'End-to-end integration tests'
            },
            {
                'name': 'system_interaction',
                'command': 'python3 -m pytest test/integration/system_interaction/ -v',
                'description': 'System interaction tests'
            },
            {
                'name': 'cross_language',
                'command': 'python3 -m pytest test/integration/cross_language/ -v',
                'description': 'Cross-language integration tests'
            }
        ]
        
        for integration_cmd in integration_commands:
            self.log(f"Running {integration_cmd['description']}...")
            result = self.run_command(integration_cmd['command'], timeout=300)
            self.results['integration'][integration_cmd['name']] = result
            
            if result['success']:
                self.log(f"✅ {integration_cmd['description']} passed")
            else:
                self.log(f"❌ {integration_cmd['description']} failed: {result['stderr']}", "ERROR")
    
    def run_security_tests(self):
        """Run security tests and vulnerability scans"""
        self.log("Starting security tests...")
        
        security_commands = [
            {
                'name': 'vulnerability_scan',
                'command': 'trivy fs .',
                'description': 'Vulnerability scan with Trivy'
            },
            {
                'name': 'dependency_check',
                'command': 'mvn org.owasp:dependency-check-maven:check',
                'description': 'Dependency vulnerability check'
            },
            {
                'name': 'code_analysis',
                'command': 'gosec ./...',
                'description': 'Go security analysis'
            }
        ]
        
        for security_cmd in security_commands:
            self.log(f"Running {security_cmd['description']}...")
            result = self.run_command(security_cmd['command'], timeout=300)
            self.results['security'][security_cmd['name']] = result
            
            if result['success']:
                self.log(f"✅ {security_cmd['description']} completed")
            else:
                self.log(f"❌ {security_cmd['description']} failed: {result['stderr']}", "ERROR")
    
    def generate_report(self):
        """Generate comprehensive test report"""
        self.log("Generating comprehensive test report...")
        
        end_time = time.time()
        total_duration = end_time - self.start_time
        
        # Calculate summary statistics
        total_tests = 0
        passed_tests = 0
        failed_tests = 0
        
        for category in ['go_tests', 'java_tests', 'python_tests']:
            for test_name, result in self.results[category].items():
                total_tests += 1
                if result['success']:
                    passed_tests += 1
                else:
                    failed_tests += 1
        
        self.results['summary'] = {
            'total_duration': total_duration,
            'total_tests': total_tests,
            'passed_tests': passed_tests,
            'failed_tests': failed_tests,
            'success_rate': (passed_tests / total_tests * 100) if total_tests > 0 else 0,
            'timestamp': time.strftime("%Y-%m-%d %H:%M:%S")
        }
        
        # Save detailed report
        report_file = self.project_root / "test_report.json"
        with open(report_file, 'w') as f:
            json.dump(self.results, f, indent=2)
        
        # Print summary
        self.log("=" * 60)
        self.log("COMPREHENSIVE TEST EXECUTION SUMMARY")
        self.log("=" * 60)
        self.log(f"Total Duration: {total_duration:.2f} seconds")
        self.log(f"Total Tests: {total_tests}")
        self.log(f"Passed Tests: {passed_tests}")
        self.log(f"Failed Tests: {failed_tests}")
        self.log(f"Success Rate: {self.results['summary']['success_rate']:.2f}%")
        self.log(f"Detailed Report: {report_file}")
        self.log("=" * 60)
        
        return self.results['summary']['success_rate']
    
    def run_all_tests(self):
        """Run all comprehensive tests"""
        self.log("Starting comprehensive test orchestration...")
        
        # Run tests in parallel where possible
        with ThreadPoolExecutor(max_workers=4) as executor:
            # Submit test categories
            futures = {
                executor.submit(self.run_go_tests): 'go_tests',
                executor.submit(self.run_java_tests): 'java_tests',
                executor.submit(self.run_python_tests): 'python_tests',
                executor.submit(self.run_performance_benchmarks): 'performance',
                executor.submit(self.run_integration_tests): 'integration',
                executor.submit(self.run_security_tests): 'security'
            }
            
            # Wait for completion
            for future in as_completed(futures):
                category = futures[future]
                try:
                    future.result()
                    self.log(f"✅ {category} completed")
                except Exception as e:
                    self.log(f"❌ {category} failed: {str(e)}", "ERROR")
        
        # Generate final report
        success_rate = self.generate_report()
        
        if success_rate >= 90:
            self.log("🎉 Excellent! Test success rate is 90% or higher!")
        elif success_rate >= 80:
            self.log("✅ Good! Test success rate is 80% or higher!")
        elif success_rate >= 70:
            self.log("⚠️  Warning! Test success rate is below 80%")
        else:
            self.log("❌ Critical! Test success rate is below 70%", "ERROR")
        
        return success_rate

def main():
    parser = argparse.ArgumentParser(description='Comprehensive Test Orchestration System')
    parser.add_argument('--go-only', action='store_true', help='Run only Go tests')
    parser.add_argument('--java-only', action='store_true', help='Run only Java tests')
    parser.add_argument('--python-only', action='store_true', help='Run only Python tests')
    parser.add_argument('--performance-only', action='store_true', help='Run only performance tests')
    parser.add_argument('--integration-only', action='store_true', help='Run only integration tests')
    parser.add_argument('--security-only', action='store_true', help='Run only security tests')
    
    args = parser.parse_args()
    
    orchestrator = TestOrchestrator()
    
    if args.go_only:
        orchestrator.run_go_tests()
    elif args.java_only:
        orchestrator.run_java_tests()
    elif args.python_only:
        orchestrator.run_python_tests()
    elif args.performance_only:
        orchestrator.run_performance_benchmarks()
    elif args.integration_only:
        orchestrator.run_integration_tests()
    elif args.security_only:
        orchestrator.run_security_tests()
    else:
        # Run all tests
        success_rate = orchestrator.run_all_tests()
        sys.exit(0 if success_rate >= 80 else 1)

if __name__ == "__main__":
    main()