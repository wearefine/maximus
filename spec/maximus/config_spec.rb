require 'spec_helper'
require 'support/config_helper'

describe Maximus::Config do

  include ConfigHelper

  let(:config_body) { '' }
  subject(:config) do
    create_config(config_body)
  end

  after(:each) { destroy_config }

  describe 'options in general', :isolated_environment do
    context 'options are passed directly' do
      it 'should read the options as is' do
        conf = described_class.new({port: 1000})

        expect(conf.settings[:port]).to eq 1000
      end
    end

    context 'options are passed through a file' do
      let(:config_body) { 'port: 1000' }
      it 'should parse the file accurately' do
        expect(config.settings[:port]).to eq 1000
      end
    end

    context 'options are passed through a file and directly' do
      let(:config_body) { 'port: 1000' }
      it 'should prefer the direct options' do
        conf = described_class.new({port: 1001, config_file: '.maximus.yml'})
        expect(conf.settings[:port]).to eq 1001
      end
    end

  end

  describe 'config file loading (load_confg_file)', :isolated_environment do

    context 'only maximus.yml is available' do
      it 'should take the settings in maximus.yml' do
        create_config('port: 1001', 'maximus.yml')
        conf = described_class.new

        expect(conf.settings[:port]).to eq 1001
        destroy_config('maximus.yml')
      end
    end

    context '.maximus.yml and maximus.yml are available' do
      it 'should prefer .maximus.yml' do
        create_config('port: 1000', '.maximus.yml')
        create_config('port: 1001', 'maximus.yml')
        conf = described_class.new

        expect(conf.settings[:port]).to eq 1000
        destroy_config('maximus.yml')
      end
    end

  end

  describe '.working_dir', :isolated_environment do
    context 'root_dir is applied in the config' do
      let(:config_body) { 'root_dir: some/fake/directory' }
      it 'should equal the config setting' do
        expect(config.working_dir).to eq 'some/fake/directory'
      end
    end
  end

  describe '.is_dev?', :isolated_environment do
    context 'setting root value is_dev to true' do
      let(:config_body) { 'is_dev: true' }
      it 'should be true' do
        expect(config.is_dev?).to be true
      end
    end

    context 'is blank/not supplied' do
      it 'should default to false' do
        expect(config.is_dev?).to be false
      end
    end
  end

  describe '.initialize', :isolated_environment do

    context 'setting a linter to be true' do
      let(:config_body) { 'scsslint: true' }
      it 'scsslint should exist' do
        expect(config.settings.has_key?(:scsslint)).to be true
      end
    end

    context 'not supplying a linter but relying on the default' do
      it 'should include a linter' do
        expect(config.settings.has_key?(:scsslint)).to be true
      end
    end

  end

  describe '.domain', :isolated_environment do

    context 'domain is provided' do

      context 'without a port' do
        let(:config_body) { 'domain: http://example.com' }
        it 'should provide the domain' do
          expect( config.domain ).to eq 'http://example.com'
        end
      end

      context 'with a port' do
        let(:config_body) { "domain: http://example.com\nport: 8080" }
        it 'should provide the domain with port attached' do
          expect( config.domain ).to eq 'http://example.com:8080'
        end
      end

    end

    context 'port is provided' do

      context 'without a domain' do
        let(:config_body) { 'port: 8080' }
        it 'should provide the default domain with the port attached' do
          expect( config.domain ).to eq 'http://localhost:8080'
        end
      end

      context 'with a domain' do
        let(:config_body) { "domain: http://example.com\nport: 8080" }
        it 'should provide the domain with the port attached' do
          expect( config.domain ).to eq 'http://example.com:8080'
        end
      end

    end

  end

  describe '.split_paths', :isolated_environment do

    context 'an array is provided' do
      let(:config_body) { "paths: \n  - '/'\n  - '/about'"}
      it 'should return the paths with labels' do
        expect( config.settings[:paths] ).to eq ({ 'home' => '/', 'about' => '/about'})
      end
    end

    context 'a hash is provided' do
      let(:config_body) { "paths: \n  home: '/'\n  about: '/about'"}
      it 'should return the paths with labels' do
        expect( config.settings[:paths] ).to eq ({ 'home' => '/', 'about' => '/about'})
      end
    end

    context 'nothing is provided' do
      it 'should return the default path with label' do
        expect( config.settings[:paths] ).to eq ({ 'home' => '/'})
      end
    end

  end

  describe '#load_config', :isolated_environment do

    context 'a file path is provided' do
      let(:config_body) { 'rubocop: spec/support/rubocop.yml' }
      it 'should load the file' do
        expect( YAML.load_file(config.settings[:rubocop])['Rubolinter'] ).to be true
      end
    end

    context 'settings are provided' do
      let(:config_body) { "rubocop:\n  Rubolinter: true" }
      it 'should store the settings appropriately' do
        expect( YAML.load_file(config.settings[:rubocop])['Rubolinter'] ).to be true
      end
    end

    context 'a file path is provided but is non-existent' do
      let(:config_body) { "rubocop: spec/support/not/a/real/file.yml" }
      it 'should puts an error message and an empty hash' do
        STDOUT.should_receive(:puts).with('spec/support/not/a/real/file.yml not found')
        expect( YAML.load_file(config.settings[:rubocop]) ).to eq ({})
      end
    end

  end

end
