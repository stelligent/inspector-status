# AWS Inspector Status

This is a tool to execute AWS inspector templates against targets and report the findings from the runs via JSON. Specifically this is made to be integrated into a CI/CD Pipeline.

## What it does
  * Creates an AWS Inspector target
  * Creates an AWS Inspector template
  * Runs an AWS Inspector asessment run
  * Reports the findings of that assessment to stdout

## How it does it

This tool uses the aws-sdk to programmatically interact with the AWS Inspector API to create, modify, run and delete resources. 

At the moment of this writing Cloudformation does not support Inspector. This tool uses a config file and/or CLI arguments to build the attributes needed to create these resources.

The results are then printed to stdout for consumption by reporting/pipeline functions. Inspector runs assessments against resource targets, these are tagged AWS Resources (instances, services, etc). 

Note: Your resources should already be tagged with whatever you will have set in your target_tags in the config file.

## Requirements / Setup

* A modern Ruby of the 2.x variety
* AWS IAM role with proper permissions to AWS Inspector OR one of the following configuration methods for [aws-sdk](https://github.com/aws/aws-sdk-ruby#configuration). Also ensure you configure against the proper region.
* Tagged AWS resources in the region you plan to inspect against
* Git to clone out the repo

## Installation

This method assumes you want to use whatever settings are setup in the config.yml provided in the top level directory of this repo. See below for CLI args.

```
git clone git@github.com:stelligent/inspector-status.git
cd inspector-status
bundle install
rake run
```

## Tests

`rake test`

## AWS Resources

Resources are created in AWS with whatever name prefix you choose in the config file OR the command line, This creates resources with the prefix-name, a random string, and then the type concatenated. By default resources will be cleaned up after. The run/findings will be left in your AWS account for posterity.

## Options
Note: The provided config file has all of these options. If an option is provided below then the config file's option will be overridden by the CLI argument.

```
Usage: ./inspector.rb [options]
  -c, --config CFILE               Config file to get config options from, defaults to config.yml
  -n, --aws-name-prefix NAME       Name to prefix before any created AWS Resources
  -f, --failure-metrics FAILURES   Comma separated key/value of failure metrics, e.g. numeric_severity:3,indicator_of_compromise:true
  -r, --rules-to-run RULES         Comma separated list of rules to run, using the following abbreviations:
                                       SEC = Security Best Practices
                                       RUN = Runtime Behavior Analysis
                                       COM = Common Vulnerabilities and Exposures
                                       CIS = CIS Operating System Security Configuration Benchmarks
                                   e.g. -r SEC,RUN
  -t, --target-tags TAGS           Comma separated list of AWS Resource tags to target for inspection, e.g. auditable:true,mybuild=333
  -d, --asset-duration DUR         Duration in seconds to run the assessment for
  -x, --[no-]cleanup-resources     Determines if resources created in AWS (Targets, templates & Runs) should be deleted after we are done
```

## Evaluate for failure
The evaluate for failure configuration is a method of failing your CI pipeline/toolchain when a severity, or compromise greater than what you have set has occurred. 

This works on numeric and/or true/false values within the output of the report. The config file has a few examples of how to use this but the most common are setting the numeric_severity and indicator_of_compromise. 

This way on critical or compromising issues you can fail your toolchain.
