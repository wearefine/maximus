require 'spec_helper'

describe Maximus::Config do
  let(:config_path) { '.maximus.yml' }

  subject(:config) do
    File.write(config_path, config_body)
    described_class.new(config_body.blank? ? {} : { config_file: config_path })
  end

  describe '#is_dev?', :isolated_environment do
    context 'setting root value is_dev to true' do
      let(:config_body) { 'is_dev: true' }
      it 'is_dev should be true' do
        expect(config.is_dev?).to be true
      end
    end

    context 'is_dev is blank/not supplied' do
      let(:config_body) { '' }
      it 'is_dev should default to false' do
        expect(config.is_dev?).to be false
      end
    end
  end

  describe '#initialize', :isolated_environment do

    context 'setting a linter to be true' do
      let(:config_body) { 'scsslint: true' }
      it 'scsslint should exist' do
        expect(config.settings.has_key?(:scsslint)).to be true
      end
    end

    context 'not supplying a linter but relying on the default include all' do
      let(:config_body) { '' }
      it 'should include a linter' do
        expect(config.settings.has_key?(:scsslint)).to be true
      end
    end

  end
end
