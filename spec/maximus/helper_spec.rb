require 'spec_helper'

describe Maximus::Helper do

  subject(:dummy_class) do
    Class.new { extend Maximus::Helper }
  end

  describe '#is_rails?', :isolated_environment do

    context 'when Rails is not defined' do
      it 'should be nil' do
        expect(dummy_class.is_rails?).to be_nil
      end
    end

  end

  describe '#root_dir', :isolated_environment do

    context 'when project is not a Rails app' do
      it 'should be the current directory' do
        expect(dummy_class.root_dir).to eq(Dir.pwd)
      end
    end
  end

  describe '#node_module_exists', :isolated_environment do

    context 'when a command does not exist' do

      it 'should exit the script' do
        expect { dummy_class.node_module_exists('bash_func') }.to raise_error(SystemExit, "Missing command bash_func: Please run `npm install -g bash_func` And try again\n")
      end

      context 'and a custom install message is passed' do
        it 'should print the install message' do
          expect { dummy_class.node_module_exists('bash_func', 'premium_package_manager install') }.to raise_error(SystemExit, "Missing command bash_func: Please run `premium_package_manager install bash_func` And try again\n")
        end
      end

    end

  end

  describe '#truthy?', :isolated_environment do

    context 'when a true value is passed' do
      it 'should be true' do
        expect( dummy_class.truthy? 'true' ).to be true
        expect( dummy_class.truthy? '1' ).to be true
        expect( dummy_class.truthy? 'yes' ).to be true
        expect( dummy_class.truthy? 'y' ).to be true
      end
    end

    context 'when a false value is passed' do
      it 'should be false' do
        expect( dummy_class.truthy? 'false' ).to be false
        expect( dummy_class.truthy? '0' ).to be false
        expect( dummy_class.truthy? 'no' ).to be false
        expect( dummy_class.truthy? 'n' ).to be false
      end
    end

  end

  describe '#path_exists?', :isolated_environment do

    context 'when a nonexistent path(s) is passed' do
      it 'should be false' do
        STDOUT.should_receive(:puts).with('/fake/path/to/nowhere does not exist')
        expect( dummy_class.path_exists? '/fake/path/to/nowhere' ).to be false
      end
    end

    context 'when a real path is passed' do
      it 'should be true' do
        expect( dummy_class.path_exists? '.' ).to be true
      end
    end

  end

end
