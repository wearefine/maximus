require 'spec_helper'

describe Maximus::GitControl do
  let(:config) { {} }
  let(:sha1) { 'db4aa677aa1cf8cf477d5e66df1ea875b4fa20b6' }
  let(:sha2) { 'a2be59852c715382575b884e63c3e9bdee80e2db' }

  subject(:git) do
    conf_settings = config.merge({ root_dir: Dir.pwd })
    conf = Maximus::Config.new(conf_settings)
    described_class.new({ config: conf })
  end

  describe '#first_commit' do
    context 'a git repo exists' do
      it 'should return a hash equal to the first Maximus commit' do
        expect( git.first_commit ).to eq '40f2a7a7cf676a25580e04b38e3004249ed6f8ce'
      end
    end
  end

  describe '#previous_commit' do

    context 'a commit sha is provided' do
      let(:sha) { '051ba36b4ddfcaca5361312e4f6613f6ea6ee123' }

      context 'previous count is not provided' do
        it 'should return the commit directly before the provided sha' do
          expect( git.previous_commit(sha) ).to eq 'f0c02e5b9452fa4b8f1747aaa4fdf5c81099f575'
        end
      end

      context 'previous count is provided' do
        it 'should return the commit by n (previous count) commits before the provided sha' do
          expect( git.previous_commit(sha, 5) ).to eq '82933a240cff983cbc0eb668cf58671fda5cc5a5'
        end
      end

    end

  end

  describe '#commit_export' do

    context 'commit sha is provided' do
      it 'should return a formatted hash with information' do
        sha = '051ba36b4ddfcaca5361312e4f6613f6ea6ee123'
        export = git.commit_export(sha)

        expect( export[:commit_sha] ).to eq sha
        expect( export[:message] ).to eq 'misc'
        expect( export[:git_author] ).to eq 'Tim Shedor'
        expect( export[:git_author_email] ).to eq 'tim@finedesigngroup.com'
        expect( Time.parse export[:commit_date] ).to eq Time.parse('2014-11-11 00:19:25 -0800')
        expect( export[:diff] ).to be_a(Hash)
        expect( export[:remote_repo] ).to be_a(String)
        expect( export[:branch] ).to be_a(String)

      end
    end

    context 'initial sha is provided' do
      it 'should return a formatted hash with information' do
        sha = '40f2a7a7cf676a25580e04b38e3004249ed6f8ce'
        export = git.commit_export(sha)

        expect( export[:commit_sha] ).to eq sha
        expect( export[:message] ).to eq 'initial'
        expect( export[:git_author] ).to eq 'Tim Shedor'
        expect( export[:git_author_email] ).to eq 'tim@finedesigngroup.com'
        expect( Time.parse export[:commit_date] ).to eq Time.parse('2014-10-31 18:16:17 -0700')
        expect( export[:diff] ).to be_a(Hash)
        expect( export[:remote_repo] ).to be_a(String)
        expect( export[:branch] ).to be_a(String)
      end
    end

  end

  describe '#associations' do

    it 'should be a hash' do
      expect( git.associations ).to be_a(Hash)
    end

  end

  describe '#define_psuedo_commit' do

    context 'words are provided' do

      context 'master is supplied' do
        let(:config) { { commit: 'master' } }
        it 'should return the master sha' do
          expect( git.send(:define_psuedo_commit) ).to eq `git -C #{Dir.pwd} rev-parse --branches=master HEAD`.strip!
        end
      end

      context 'last is supplied' do
        let(:config) { { commit: 'last' } }
        it 'should return the previous_commit sha' do
          expect( git.send(:define_psuedo_commit) ).to eq `git -C #{Dir.pwd} rev-list --max-count=2 HEAD --reverse | head -n1`.strip!
        end
      end

      context 'working is supplied' do
        let(:config) { { commit: 'working' } }
        it 'should return the word "working"' do
          expect( git.send(:define_psuedo_commit) ).to eq 'working'
        end
      end

    end

    context 'a commit hash is provided' do
      let(:config) { { commit: '22126a6ba227d81f770d13c302e6225f7463f7be' } }
      it 'should return the provided hash' do
        expect( git.send(:define_psuedo_commit) ).to eq '22126a6ba227d81f770d13c302e6225f7463f7be'
      end
    end

  end

  describe '#associations' do

    it 'should be a hash' do
      expect( git.associations ).to be_a(Hash)
    end

  end

  describe '#commit_range', :isolated_environment do

    context 'shas are provided' do

      it 'should return an array of shas in between' do
        shas = ['a2be59852c715382575b884e63c3e9bdee80e2db', 'e20fe614d323782e5cab4215942e4f22ddb98464', 'db4aa677aa1cf8cf477d5e66df1ea875b4fa20b6']
        expect( git.send(:commit_range, sha1, sha2) ).to eq shas
      end

      context 'duplicate shas are provided' do
        let(:sha1) { 'a2be59852c715382575b884e63c3e9bdee80e2db' }

        it 'should only return that commit' do
          expect( git.send(:commit_range, sha1, sha2) ).to eq [sha1]
        end
      end

      context 'a psuedo_commit is passed in the config' do
        let(:config) { { commit: 'master' } }
        it 'should not return a sha' do
          expect( git.send(:commit_range, sha1, sha2) ).to eq ["git #{sha1}"]
        end
      end

    end

  end

  describe '#compare', :isolated_environment do

    context 'commit is not supplied in the config' do
      it 'should return a hash with commit shas, file associations, and changed line numbers' do
        result = git.compare(sha1, sha2)
        expect( result ).to be_a(Hash)
        expect( result.keys ).to eq ["db4aa677aa1cf8cf477d5e66df1ea875b4fa20b6", "e20fe614d323782e5cab4215942e4f22ddb98464", "a2be59852c715382575b884e63c3e9bdee80e2db"]
      end
    end

  end

end
