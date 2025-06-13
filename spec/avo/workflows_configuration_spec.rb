# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Avo::Workflows do
  describe '.configuration' do
    it 'returns a Configuration instance' do
      expect(described_class.configuration).to be_a(Avo::Workflows::Configuration)
    end

    it 'returns the same instance on multiple calls' do
      config1 = described_class.configuration
      config2 = described_class.configuration
      expect(config1).to be(config2)
    end
  end

  describe '.configure' do
    before { described_class.reset_configuration! }

    it 'yields the configuration object' do
      expect { |b| described_class.configure(&b) }.to yield_with_args(
        described_class.configuration
      )
    end

    it 'allows setting configuration values' do
      described_class.configure do |config|
        config.user_class = 'CustomUser'
        config.enabled = false
      end

      expect(described_class.configuration.user_class).to eq('CustomUser')
      expect(described_class.configuration.enabled).to be false
    end
  end

  describe '.reset_configuration!' do
    it 'creates a new configuration instance' do
      old_config = described_class.configuration
      described_class.reset_configuration!
      new_config = described_class.configuration

      expect(new_config).not_to be(old_config)
      expect(new_config).to be_a(Avo::Workflows::Configuration)
    end

    it 'resets to default values' do
      described_class.configure do |config|
        config.user_class = 'CustomUser'
        config.enabled = false
      end

      described_class.reset_configuration!

      expect(described_class.configuration.user_class).to eq('User')
      expect(described_class.configuration.enabled).to be true
    end
  end
end