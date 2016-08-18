# Set's up and runs AWS Inspector service against newly created CI components
class Inspector
  def initialize
    @name = "joshp-#{SecureRandom.hex(5)}"
    @assessment_duration = 60
    @rules_to_run = ['Security Best Practices',
                     'Runtime Behavior Analysis']
    @resource_target_tags = [{ key: 'auditable', value: 'true' }]
  end

  def aws
    @aws ||= Aws::Inspector::Client.new
  end

  def run
    retrieve_rule_arns # Region Specific rules
    create_resource_group
    create_target
    create_template
    start_assessment_run
    wait_for_assessment_run
    report_findings
  end

  def cleanup_resources
    puts 'Cleaning up resources before exiting'
    unless @assessment_run_arn.nil? && assessment_completed?
      #aws.stop_assessment_run(assessment_run_arn: @assessment_run_arn)
      #sleep [@assessment_duration, 60].min # Give us at most 60 seconds to shutdown the assessment run
    end
    
    #aws.delete_assessment_target(assessment_target_arn: @assessment_target_arn) unless @assessment_target_arn.nil?
    #aws.delete_assessment_template(assessment_template_arn: @assessment_template_arn) unless @assessment_template_arn.nil?
    #aws.delete_assessment_run(assessment_run_arn: @assessment_run_arn) unless @assessment_run_arn.nil?
  end

  private

  def retrieve_rule_arns
    region_rule_arns = aws.list_rules_packages.rules_package_arns
    rule_packages = aws.describe_rules_packages(rules_package_arns: region_rule_arns).rules_packages
    @rule_arns = rule_packages.map { |rule| rule.arn if @rules_to_run.include?(rule.name) }.compact
  end

  def wait_for_assessment_run
    puts 'Waiting for assessment to complete'
    Timeout::timeout(@assessment_duration + 180) do
      until assessment_completed?
        putc '.'
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
    aws.describe_findings(finding_arns: retrieve_finding_arns).findings
  end

  def report_findings
    describe_findings.each do |issue|
      begin
        asset_attr = issue.asset_attributes
        puts ''
         => #<struct Aws::Inspector::Types::AssetAttributes schema_version=1, agent_id="i-2a42ffac", auto_scaling_group=nil, ami_id=nil, hostname=nil, ipv4_addresses=[]>
        puts "ASG: #{asset_attr.auto_scaling_group}" unless asset_attr.auto_scaling_group.nil?
        puts "HOST: #{asset_attr.hostname}" unless asset_attr.hostname.nil?
        puts "type: #{issue.asset_type}"
        puts "id: #{issue.id}"
        puts "agent: #{asset_attr.agent_id}"
        puts "description: #{issue.description}"
        puts "severity: #{issue.severity} - #{issue.numeric_severity}"
        puts "confidence: #{issue.confidence}"
        puts "ami_id: #{asset_attr.ami_id}"
        puts "compromise: #{issue.indicator_of_compromise}"
        puts "title: #{issue.title}"
      end
    end
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
