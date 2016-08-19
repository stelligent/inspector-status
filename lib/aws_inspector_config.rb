# Module that configures and parses Inspectors arguments and config options
module InspectorConfig
  def self.parsed_options
    options = InspectorConfig.parse
    config_file = InspectorConfig.read_config(options['config_file'] || 'config.yml')
    merged_options = InspectorConfig.merged_options(config_file, options)
    InspectorConfig.check_for_required_options(merged_options)
    merged_options
  end

  def self.parse(options = {}) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    OptionParser.new do |opts|
      opts.banner = "Usage: #{$PROGRAM_NAME} [options]"

      opts.on('-c CFILE', '--config CFILE', 'Config file to get config options from, defaults to config.yml') do |c|
        options['config_file'] = c
      end

      opts.on('-n NAME', '--aws-name-prefix NAME', 'Name to prefix before any created AWS Resources') do |n|
        options['aws_name_prefix'] = n
      end

      opts.on('-f FAILURES', '--failure-metrics FAILURES', 'Comma separated key/value of failure metrics, e.g. numeric_severity:3,indicator_of_compromise:true') do |f|
        options['failure_metrics'] = f.split(',')
                                      .collect do |fm|
                                        keyname, keyvalue = fm.split(':')
                                        Hash[keyname, keyvalue]
                                      end
                                      .reduce({}, :merge)
      end

      opts.on('-r RULES', '--rules-to-run RULES', 'Comma separated list of rules to run, using the following abbreviations:
                                                   SEC = Security Best Practices
                                                   RUN = Runtime Behavior Analysis
                                                   COM = Common Vulnerabilities and Exposures
                                                   CIS = CIS Operating System Security Configuration Benchmarks
                                                   e.g. -r SEC,RUN') do |r|
        expanded_rules = {
          SEC: 'Security Best Practices',
          RUN: 'Runtime Behavior Analysis',
          COM: 'Common Vulnerabilities and Exposures',
          CIS: 'CIS Operating System Security Configuration Benchmarks'
        }
        options['rules_to_run'] = r.split(',').map { |rtr| expanded_rules[rtr.to_sym] }
      end

      opts.on('-t TAGS', '--target-tags TAGS', 'Comma separated list of AWS Resource tags to target for inspection, e.g. auditable:true,mybuild=333') do |t|
        options['target_tags'] = t.split(',')
                                  .collect do |tg|
                                    tagname, tagvalue = tg.split(':')
                                    Hash[tagname, tagvalue]
                                  end
                                  .reduce({}, :merge)
      end

      opts.on('-d DUR', '--asset-duration DUR', 'Duration in seconds to run the assessment for') do |d|
        options['asset_duration'] = d
      end

      opts.on('-x', '--[no-]cleanup-resources', TrueClass, 'Determines if resources created in AWS (Targets, templates & Runs) should be deleted after we are done') do |x|
        options['cleanup_resources'] = x
      end
    end.parse!
    options
  end

  def self.read_config(config_file)
    YAML.load_file(config_file)
  rescue
    $stderr.puts 'Warning: No config file provided, using CLI args only'
    false
  end

  def self.merged_options(yml_config, options)
    if yml_config
      yml_config.merge(options)
    else
      options
    end
  end

  def self.check_for_required_options(options)
    required_options = %w(aws_name_prefix rules_to_run target_tags asset_duration cleanup_resources)
    required_options.each do |ropt|
      raise "Missing config options: #{ropt}" unless options.key?(ropt)
    end
  end
end
