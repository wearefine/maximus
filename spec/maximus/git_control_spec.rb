require 'spec_helper'

describe Maximus::GitControl do

  subject(:git) do
    conf = Maximus::Config.new({ root_dir: Dir.pwd })
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
        expect( export[:commit_date] ).to eq '2014-11-11 00:19:25 -0800'
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
        expect( export[:commit_date] ).to eq '2014-10-31 18:16:17 -0700'
        expect( export[:diff] ).to be_a(Hash)
        expect( export[:remote_repo] ).to be_a(String)
        expect( export[:branch] ).to be_a(String)

      end
    end

  end

end
