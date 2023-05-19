// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT

//go:build !windows

package test_runner

import (
	"fmt"
	"log"
	"path/filepath"
	"time"

	"github.com/aws/amazon-cloudwatch-agent-test/internal/common"
	"github.com/aws/amazon-cloudwatch-agent-test/test/metric/dimension"
	"github.com/aws/amazon-cloudwatch-agent-test/test/status"
)

const (
	configOutputPath         = "/opt/aws/amazon-cloudwatch-agent/bin/config.json"
	agentConfigDirectory     = "agent_configs"
	extraConfigDirectory     = "extra_configs"
	MinimumAgentRuntime      = 1 * time.Minute
	HighResolutionStatPeriod = 30
)

type ITestRunner interface {
	Validate() status.TestGroupResult
	GetTestName() string
	GetAgentConfigFileName() string
	GetAgentRunDuration() time.Duration
	GetMeasuredMetrics() []string
	SetupBeforeAgentRun() error
	SetupAfterAgentRun() error
	runAgent() (status.TestGroupResult, error)
}

type TestRunner struct {
	TestRunner ITestRunner
}

type BaseTestRunner struct {
	DimensionFactory dimension.Factory
}

func (t *BaseTestRunner) GetTestName() string {
	return "BaseTestRunner"
}
func (t *BaseTestRunner) GetAgentConfigFileName() string {
	return "cpu_config.json"
}

func (t *BaseTestRunner) SetupBeforeAgentRun() error {
	return nil
}

func (t *BaseTestRunner) SetupAfterAgentRun() error {
	return nil
}

func (t *BaseTestRunner) GetAgentRunDuration() time.Duration {
	return MinimumAgentRuntime
}

func (t *BaseTestRunner) RunAgent() (status.TestGroupResult, error) {
	testGroupResult := status.TestGroupResult{
		Name: t.GetTestName(),
		TestResults: []status.TestResult{
			{
				Name:   "Starting Agent",
				Status: status.SUCCESSFUL,
			},
		},
	}

	err := t.SetupBeforeAgentRun()
	if err != nil {
		testGroupResult.TestResults[0].Status = status.FAILED
		return testGroupResult, fmt.Errorf("Failed to complete setup before agent run due to: %w", err)
	}

	agentConfigPath := filepath.Join(agentConfigDirectory, t.GetAgentConfigFileName())
	log.Printf("Starting agent using agent config file %s", agentConfigPath)
	common.CopyFile(agentConfigPath, configOutputPath)
	err = common.StartAgent(configOutputPath, false)

	if err != nil {
		testGroupResult.TestResults[0].Status = status.FAILED
		return testGroupResult, fmt.Errorf("Agent could not start due to: %w", err)
	}

	err = t.SetupAfterAgentRun()
	if err != nil {
		testGroupResult.TestResults[0].Status = status.FAILED
		return testGroupResult, fmt.Errorf("Failed to complete setup after agent run due to: %w", err)
	}

	runningDuration := t.GetAgentRunDuration()
	time.Sleep(runningDuration)
	log.Printf("Agent has been running for : %s", runningDuration.String())
	common.StopAgent()

	err = common.DeleteFile(configOutputPath)
	if err != nil {
		testGroupResult.TestResults[0].Status = status.FAILED
		return testGroupResult, fmt.Errorf("Failed to cleanup config file after agent run due to: %w", err)
	}

	return testGroupResult, nil
}

func (t *TestRunner) Run(s ITestSuite) {
	testName := t.TestRunner.GetTestName()
	log.Printf("Running %v", testName)
	testGroupResult, err := t.TestRunner.runAgent()
	if err == nil {
		testGroupResult = t.TestRunner.Validate()
	}

	s.AddToSuiteResult(testGroupResult)
	if testGroupResult.GetStatus() != status.SUCCESSFUL {
		log.Printf("%v test group failed due to %v", testName, err)
	}
}