# Set's up and runs AWS Inspector service against newly created CI components
class Inspector
  include InspectorLib

  def initialize(options)
    @name = "#{options['aws_name_prefix']}-#{SecureRandom.hex(5)}"
    @assessment_duration = options['asset_duration']
    @rules_to_run = options['rules_to_run']
    @resource_target_tags = options['target_tags'].collect { |k, v| { key: k, value: v.to_s } }
  end

  def run
    retrieve_rule_arns # Region Specific rules
    create_resource_group
    create_target
    create_template
    start_assessment_run
    wait_for_assessment_run
    report_findings
    evaluate_for_failure
  end

  def cleanup_resources
    stop_resources unless @assessment_run_arn.nil? || assessment_completed?
    delete_resources
  end

  private

  def delete_resources
    allow_fail { aws.delete_assessment_target(assessment_target_arn: @assessment_target_arn) unless @assessment_target_arn.nil? }
    allow_fail { aws.delete_assessment_template(assessment_template_arn: @assessment_template_arn) unless @assessment_template_arn.nil? }
    allow_fail { aws.delete_assessment_run(assessment_run_arn: @assessment_run_arn) unless @assessment_run_arn.nil? }
  end

  def stop_resources
    allow_fail { aws.stop_assessment_run(assessment_run_arn: @assessment_run_arn) }
    sleep [@assessment_duration, 60].min # Give us at most 60 seconds to shutdown the assessment run
  end

  def retrieve_rule_arns
    region_rule_arns = aws.list_rules_packages.rules_package_arns
    rule_packages = aws.describe_rules_packages(rules_package_arns: region_rule_arns).rules_packages
    @rule_arns = rule_packages.map { |rule| rule.arn if @rules_to_run.include?(rule.name) }.compact
  end

  def wait_for_assessment_run
    Timeout.timeout(@assessment_duration + 180) do
      until assessment_completed? # rubocop:disable Style/WhileUntilModifier
        sleep 5
      end
    end
  rescue Timeout::Error
    puts 'We could not get results from the assessment run in time'
  end

  def create_template
    @assessment_template_arn = aws.create_assessment_template(assessment_target_arn: @assessment_target_arn,
                                                              assessment_template_name: "#{@name}-assessment-template",
                                                              duration_in_seconds: @assessment_duration,
                                                              rules_package_arns: @rule_arns).assessment_template_arn
  end

  def retrieve_finding_arns
    aws.list_findings(assessment_run_arns: [@assessment_run_arn]).finding_arns
  end

  def describe_findings
    @assessment_findings = aws.describe_findings(finding_arns: retrieve_finding_arns).findings
  end

  def evaluate_for_failure
  end

  def report_findings
    converted_findings = describe_findings.map(&:to_hash)
    report = { InspectorOutput: converted_findings }.to_json
    $stdout.puts JSON.pretty_generate(JSON.parse(report))
  end

  def assessment_completed?
    assessment_state == 'COMPLETED'
  end

  def assessment_state
    # TODO: Fix state where the ARN is running and cant be cleaned up and need to be stopped first
    aws.describe_assessment_runs(assessment_run_arns: [@assessment_run_arn]).assessment_runs.first.state
  end

  def start_assessment_run
    @assessment_run_arn = aws.start_assessment_run(assessment_template_arn: @assessment_template_arn).assessment_run_arn
  rescue Aws::Inspector::Errors::NoSuchEntityException
    puts "Failed to find any resources matching the given tag key/values: #{@resource_target_tags}"
    raise
  end

  def create_resource_group
    @resource_group_arn = aws.create_resource_group(resource_group_tags: @resource_target_tags).resource_group_arn
  end

  def create_target
    @assessment_target_arn = aws.create_assessment_target(assessment_target_name: "#{@name}-assessment-target", resource_group_arn: @resource_group_arn).assessment_target_arn
  end
end
