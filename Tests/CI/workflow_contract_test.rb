require "minitest/autorun"
require "yaml"

class WorkflowContractTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  FAST_WORKFLOW = File.join(ROOT, ".github/workflows/ios.yml")
  EXHAUSTIVE_WORKFLOW = File.join(ROOT, ".github/workflows/ios-exhaustive.yml")
  PREPARE_IOS_ACTION = File.join(ROOT, ".github/actions/prepare-ios/action.yml")
  REPORT_DURATION_ACTION = File.join(ROOT, ".github/actions/report-ci-duration/action.yml")
  UI_TESTS = File.join(ROOT, "Tests/SoftballScoringUITests/ScrollReachabilityUITests.swift")
  RECOVERY_SMOKE = "SoftballScoringUITests/ScrollReachabilityUITests/testSliceSixRecoveryJourneySurvivesColdRelaunch"

  def test_pull_requests_run_the_stable_fast_verification_contract
    workflow = load_workflow(FAST_WORKFLOW)
    triggers = workflow_triggers(workflow)
    job = workflow.fetch("jobs").fetch("pr-fast-verification")
    commands = lane_commands(job)

    assert_equal "iOS PR Fast Verification", workflow.fetch("name")
    assert_equal ["pull_request"], triggers.keys.map(&:to_s).sort
    assert_equal "PR Fast Verification", job.fetch("name")
    assert_includes job.fetch("steps").map { |step| step["uses"] }.compact, "actions/checkout@v4"
    assert_includes commands, "ruby Tests/CI/workflow_contract_test.rb"
    assert_includes commands, "xcodegen generate"
    assert_includes commands, "xcodebuild build-for-testing"
    assert_includes commands, "-only-testing:DomainTests"
    assert_includes commands, "-only-testing:ScoringEngineTests"
    assert_includes commands, "-only-testing:#{RECOVERY_SMOKE}"
    assert_includes File.read(UI_TESTS), "func #{RECOVERY_SMOKE.split('/').last}()"
    assert_fresh_serial_simulator(job)
    assert_failures_surface(job)
    assert_duration_is_recorded(job)
  end

  def test_main_and_manual_runs_execute_every_ui_test_in_the_stable_exhaustive_contract
    workflow = load_workflow(EXHAUSTIVE_WORKFLOW)
    triggers = workflow_triggers(workflow)
    job = workflow.fetch("jobs").fetch("exhaustive-ui-evidence")
    commands = lane_commands(job)

    assert_equal "iOS Exhaustive UI Evidence", workflow.fetch("name")
    assert_equal ["push", "workflow_dispatch"], triggers.keys.map(&:to_s).sort
    assert_equal ["main"], triggers.fetch("push").fetch("branches")
    assert_equal "Exhaustive UI Evidence", job.fetch("name")
    assert_operator job.fetch("timeout-minutes"), :>=, 60
    assert_includes commands, "-only-testing:SoftballScoringUITests"
    refute_includes commands, "-skip-testing:"
    assert_fresh_serial_simulator(job)
    assert_failures_surface(job)
    assert_duration_is_recorded(job)
  end

  private

  def load_workflow(path)
    YAML.safe_load(File.read(path), aliases: true)
  end

  def workflow_triggers(workflow)
    workflow.fetch("on", workflow.fetch(true, nil))
  end

  def commands_for(job)
    job.fetch("steps").map { |step| step["run"] }.compact.join("\n")
  end

  def lane_commands(job)
    prepare_ios = load_workflow(PREPARE_IOS_ACTION).fetch("runs")
    report_duration = load_workflow(REPORT_DURATION_ACTION).fetch("runs")
    [commands_for(job), commands_for(prepare_ios), commands_for(report_duration)].join("\n")
  end

  def assert_fresh_serial_simulator(job)
    assert_includes job.fetch("steps").map { |step| step["uses"] }.compact,
                    "./.github/actions/prepare-ios"
    commands = lane_commands(job)

    assert_includes commands, "xcrun simctl create"
    assert_includes commands, "xcrun simctl bootstatus"
    assert_includes commands, "-parallel-testing-enabled NO"
  end

  def assert_failures_surface(job)
    prepare_steps = load_workflow(PREPARE_IOS_ACTION).fetch("runs").fetch("steps")
    report_steps = load_workflow(REPORT_DURATION_ACTION).fetch("runs").fetch("steps")

    (job.fetch("steps") + prepare_steps + report_steps).each do |step|
      refute step["continue-on-error"], "#{step.fetch("name", step["uses"])} must not tolerate failure"
      refute_match(/\|\|\s*true/, step.fetch("run", ""))
    end
  end

  def assert_duration_is_recorded(job)
    duration_step = job.fetch("steps").find do |step|
      step["uses"] == "./.github/actions/report-ci-duration"
    end

    refute_nil duration_step
    assert_equal "always()", duration_step.fetch("if")
    assert_equal job.fetch("name"), duration_step.fetch("with").fetch("lane-name")
    commands = lane_commands(job)

    assert_includes commands, "$GITHUB_STEP_SUMMARY"
    assert_includes commands, "Elapsed duration"
  end
end
