#!/usr/bin/env ruby

require 'aws-sdk'
require 'securerandom'
require 'timeout'
require_relative 'lib/aws_inspector.rb'

begin
  inspection = Inspector.new
  inspection.run
ensure
  inspection.cleanup_resources
end
