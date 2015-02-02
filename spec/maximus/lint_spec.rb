require 'spec_helper'
require 'rainbow'
require 'rainbow/ext/string'

describe Maximus::Lint do
  let(:data) {
    {"/Users/Tim/dummy/app/assets/stylesheets/application.css"=>[{"line"=>1, "column"=>1, "length"=>1, "severity"=>"warning", "reason"=>"Use `//` comments everywhere", "linter"=>"Comment"}], "/Users/Tim/dummy/app/assets/stylesheets/main.css.scss"=>[{"line"=>2, "column"=>3, "length"=>16, "severity"=>"warning", "reason"=>"Properties should be ordered margin, max-width", "linter"=>"PropertySortOrder"}]}
  }

  subject(:lint) { described_class.new }

  describe '#refine', :isolated_environment do
    context 'data is blank' do
      let(:data) { }
      it 'should provide a blank response' do
        STDOUT.should_receive(:puts).with("#{''.color(:green)}: #{'[0]'.color(:yellow)}#{' [0]'.color(:red)}")
        blank_response = { lint_warnings: [], lint_errors: [], lint_conventions: [], lint_refactors: [], raw_data: "{}" }
        expect( lint.refine(data) ).to eq blank_response
      end
    end

    context 'data is an error' do
      let(:data) { 'No such linter available' }
      it 'should report the error' do
        STDOUT.should_receive(:puts).with("Error from : No such linter available")
        expect( lint.refine(data) ).to be_nil
      end
    end

    context 'data is provided' do
      it 'should be a Hash' do
        # As a string
        # Tests lint_summarize
        2.times { STDOUT.should_receive(:puts).with("#{''.color(:green)}: #{'[2]'.color(:yellow)}#{' [0]'.color(:red)}") }

        expect( lint.refine(data) ).to be_a(Hash)
        expect( lint.refine(data.to_json) ).to be_a(Hash)
      end
    end
  end

  describe '#evaluate_severities', :isolated_environment do
    it 'should be a Hash' do
      resp = lint.send(:evaluate_severities, data)

      expect( resp ).to be_a(Hash)
      expect( resp[:lint_warnings].length ).to eq 2
    end
  end

end
