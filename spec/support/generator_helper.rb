# frozen_string_literal: true

require 'rails/generators/test_case'
require 'fileutils'

module GeneratorHelper
  def setup_generator_test
    @destination_root = File.expand_path("../../tmp/generator_test", __dir__)
    FileUtils.rm_rf(@destination_root)
    FileUtils.mkdir_p(@destination_root)
    
    # Set up a minimal Rails app structure
    FileUtils.mkdir_p(File.join(@destination_root, 'app', 'models'))
    FileUtils.mkdir_p(File.join(@destination_root, 'app', 'avo', 'workflows'))
    FileUtils.mkdir_p(File.join(@destination_root, 'config', 'initializers'))
    FileUtils.mkdir_p(File.join(@destination_root, 'db', 'migrate'))
    FileUtils.mkdir_p(File.join(@destination_root, 'spec', 'avo', 'workflows'))
  end

  def destination_root
    @destination_root
  end

  def file_exists?(path)
    File.exist?(File.join(destination_root, path))
  end

  def read_file(path)
    File.read(File.join(destination_root, path))
  end

  def migration_file_exists?(name)
    Dir.glob(File.join(destination_root, 'db', 'migrate', "*_#{name}.rb")).any?
  end

  def find_migration_file(name)
    Dir.glob(File.join(destination_root, 'db', 'migrate', "*_#{name}.rb")).first
  end
end

RSpec.configure do |config|
  config.include GeneratorHelper, type: :generator
end