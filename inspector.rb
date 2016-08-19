#!/usr/bin/env ruby

require 'aws-sdk'
require 'optparse'
require 'securerandom'
require 'timeout'
require 'yaml'

require_relative 'lib/aws_inspector_lib.rb'
require_relative 'lib/aws_inspector_config.rb'
require_relative 'lib/aws_inspector.rb'

options = InspectorConfig.parsed_options

begin
  inspection = Inspector.new(options)
  inspection.run
ensure
  inspection.cleanup_resources if options['cleanup_resources']
end
