# Inspector library for common functions
module InspectorLib
  def aws
    @aws ||= Aws::Inspector::Client.new
  end

  def allow_fail
    yield
  rescue => e
    $stderr.puts "Could not shutdown resource: #{e.inspect}"
  end
end
