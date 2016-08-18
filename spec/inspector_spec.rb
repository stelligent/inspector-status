AWS.stub!

require 'inspector'

RSpec.describe Inspector, '#create_template' do
  context 'When we get results' do
    it 'should contain real information' do
      inspector = Inspector.new
      expect(inspector.create_template).to eq 0
    end
  end
end
