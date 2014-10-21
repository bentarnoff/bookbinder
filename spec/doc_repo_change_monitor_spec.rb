require 'spec_helper'

describe DocRepoChangeMonitor do
  include_context 'tmp_dirs'

  describe '#build_necessary?' do
    subject { monitor.build_necessary? }

    let(:cached_sha_dir) { tmpdir }
    let(:cached_sha_file) { File.join(cached_sha_dir, 'cached_shas.yml') }
    let(:logger) { NilLogger.new }
    let(:monitor) { DocRepoChangeMonitor.new logger, book, cached_sha_dir }
    let(:book) { Book.new(full_name: 'wow-org/such-book', sections: repos) }
    let(:git_client) { GitClient.new(logger, access_token: ENV['GITHUB_API_TOKEN']) }
    let(:repos) { [
        {"repository" => {"name" => "my-docs-org/my-docs-repo"}},
        {"repository" => {"name" => "some-other-org/some-other-repo"}},
    ] }

    before do
      allow(GitClient).to receive(:new).and_return(git_client)
      allow(git_client).to receive(:commits).with('my-docs-org/my-docs-repo')
        .and_return [OpenStruct.new(sha: 'shaA')]
      allow(git_client).to receive(:commits).with('some-other-org/some-other-repo')
        .and_return [OpenStruct.new(sha: 'shaB')]
      allow(git_client).to receive(:commits).with('wow-org/such-book')
        .and_return [OpenStruct.new(sha: 'old-book-sha')]
    end

    context 'when no cached sha file is available' do
      before do
        expect(File.exist?(cached_sha_file)).to eq(false)
      end

      it { is_expected.to eq(true) }

      it 'builds a new cached SHA file with the latest head SHAs' do
        subject
        expect(File.exist?(cached_sha_file)).to eq(true)
        expect(YAML.load(File.read(cached_sha_file))['my-docs-org/my-docs-repo']).to eq('shaA')
      end
    end

    context 'when the cached sha file is available but at least one repo is missing an entry' do
      before do
        write_cached_SHAs 'my-docs-org/my-docs-repo' => 'shaA'
      end

      it { is_expected.to eq(true) }
    end

    context 'when cached SHAS are available and all SHAs are up to date' do
      before do
        write_cached_SHAs 'my-docs-org/my-docs-repo' => 'shaA',
                          'some-other-org/some-other-repo' => 'shaB',
                          'wow-org/such-book' => 'old-book-sha'
      end

      it { is_expected.to eq(false) }
    end

    context 'when cached SHAs are available but the Book is out of date' do
      before do
        allow(git_client).to receive(:commits).with('wow-org/such-book')
          .and_return [OpenStruct.new(sha: 'new-book-sha')]
        write_cached_SHAs 'my-docs-org/my-docs-repo' => 'shaA',
                          'some-other-org/some-other-repo' => 'shaB',
                          'wow-org/such-book' => 'old-book-sha'
      end

      it { is_expected.to eq(true) }
    end

    context 'when cached SHAs are available but one is out of date' do
      before do
        write_cached_SHAs 'my-docs-org/my-docs-repo' => 'shaA', 'some-other-org/some-other-repo' => 'shaC'
      end

      it { is_expected.to eq(true) }
    end
  end

  def write_cached_SHAs(shas)
    yaml = YAML.dump(shas)
    File.open(cached_sha_file, 'w') { |f| f.write(yaml) }
  end
end
