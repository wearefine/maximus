require 'spec_helper'

describe Maximus::Config do
  let(:config_path) { '.maximus.yml' }

  subject(:config) do
    File.write(config_path, config_body)
    config_contents = config_body.blank? ? {} : { config_file: config_path }
    described_class.new(config_contents)
  end

  describe '.is_dev?', :isolated_environment do
    context 'setting root value is_dev to true' do
      let(:config_body) { 'is_dev: true' }
      it 'should be true' do
        expect(config.is_dev?).to be true
      end
    end

    context 'is blank/not supplied' do
      let(:config_body) { '' }
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
      let(:config_body) { '' }
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
      let(:config_body) { '' }
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
