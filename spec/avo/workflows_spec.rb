# frozen_string_literal: true

RSpec.describe Avo::Workflows do
  it "has a version number" do
    expect(Avo::Workflows::VERSION).not_to be nil
  end

  it "has modules loaded correctly" do
    expect(Avo::Workflows::Base).to be_a(Class)
    expect(Avo::Workflows::Configuration).to be_a(Class)
    expect(Avo::Workflows::Registry).to be_a(Class)
  end
end
