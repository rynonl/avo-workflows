# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Avo::Workflows do
  describe 'version' do
    it 'has a version number' do
      expect(Avo::Workflows::VERSION).not_to be_nil
      expect(Avo::Workflows::VERSION).to match(/\A\d+\.\d+\.\d+.*\z/)
    end
  end

  describe 'module loading' do
    it 'loads core modules correctly' do
      expect(Avo::Workflows::Base).to be_a(Class)
      expect(Avo::Workflows::Configuration).to be_a(Class)
      expect(Avo::Workflows::Registry).to be_a(Class)
      expect(Avo::Workflows::WorkflowExecution).to be_a(Class)
      expect(Avo::Workflows::Validators).to be_a(Module)
    end

    it 'defines the Error class' do
      expect(Avo::Workflows::Error).to be < StandardError
    end
  end

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
    it 'yields the configuration object' do
      expect { |b| described_class.configure(&b) }.to yield_with_args(described_class.configuration)
    end

    it 'allows setting configuration values' do
      described_class.configure do |config|
        config.enabled = false
        config.user_class = 'CustomUser'
      end

      expect(described_class.configuration.enabled).to be false
      expect(described_class.configuration.user_class).to eq('CustomUser')
    end
  end

  describe '.reset_configuration!' do
    it 'creates a new configuration instance' do
      old_config = described_class.configuration
      old_config.enabled = false

      new_config = described_class.reset_configuration!

      expect(new_config).not_to be(old_config)
      expect(new_config.enabled).to be true # default value
    end

    it 'resets to default values' do
      described_class.configure { |config| config.enabled = false }
      
      described_class.reset_configuration!
      
      expect(described_class.configuration.enabled).to be true
    end
  end

  describe '.avo_available?' do
    context 'when Avo constants are not defined' do
      before do
        allow(described_class).to receive(:avo_defined?).and_return(false)
        allow(described_class).to receive(:base_resource_defined?).and_return(false)
      end

      it 'returns false' do
        expect(described_class.avo_available?).to be false
      end
    end

    context 'when only Avo is defined but not BaseResource' do
      before do
        allow(described_class).to receive(:avo_defined?).and_return(true)
        allow(described_class).to receive(:base_resource_defined?).and_return(false)
      end

      it 'returns false' do
        expect(described_class.avo_available?).to be false
      end
    end

    context 'when Avo is available (mocked)' do
      it 'returns true when both constants are defined' do
        # Our mocks are loaded, so this should be true
        expect(described_class.avo_available?).to be true
      end
    end
  end

  describe '.load_avo_integration!' do
    context 'when Avo is not available' do
      before do
        allow(described_class).to receive(:avo_available?).and_return(false)
      end

      it 'returns false' do
        expect(described_class.load_avo_integration!).to be false
      end
    end

    context 'when Avo is available but files fail to load' do
      before do
        allow(described_class).to receive(:avo_available?).and_return(true)
        allow(described_class).to receive(:require_avo_components).and_raise(LoadError)
      end

      it 'returns false and handles errors gracefully' do
        expect(described_class.load_avo_integration!).to be false
      end
    end
  end
end
