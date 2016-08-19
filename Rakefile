task default: ['run']

task :run do
  ruby 'inspector.rb'
end

task :test do
  sh 'rubocop'
  sh 'rspec'
end
