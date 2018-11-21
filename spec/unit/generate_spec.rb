require 'kube_deploy_tools/generate'

INPUT_DIR='spec/resources/kubernetes/render-deploys-example/'
MANIFEST_FILE="spec/resources/deploy.yaml"
MANIFEST_FILE_NUM_CLUSTERS=9
JOB_NAME="FAKE_PROJECT"
BUILD_ID="12345"

describe KubeDeployTools::Generate do
  let(:shellrunner) { instance_double("shellrunner", :check_call => nil) }

  before(:example) do
    KubeDeployTools::Shellrunner.shellrunner = shellrunner

    # NOTE(jmodes): rspec mocks do not support child processes
    # https://github.com/rspec/rspec-mocks/issues/59
    # https://stackoverflow.com/a/6159391/1881379
    allow_any_instance_of(Object).to receive(:fork) do |&block|
      block.call
    end
end

  it 'renders correct image_registry in kubernetes yaml' do
    Dir.mktmpdir do |tmp_dir|
      app = KubeDeployTools::Generate.new(
        MANIFEST_FILE,
        INPUT_DIR,
        tmp_dir
      )
      app.generate
      expected = Dir["#{tmp_dir}/**/other.yaml"]
      expected.select{ |f| f =~ /local/ }.each do |rendered|
        expect(File.read(rendered)).to include("local-registry")
      end
    end
  end

  it "renders deploys for all clusters" do
    Dir.mktmpdir do |tmp_dir|
      # Stub out ENV
      ENV["JOB_NAME"] = JOB_NAME
      ENV["BUILD_ID"] = BUILD_ID

      app = KubeDeployTools::Generate.new(
        MANIFEST_FILE,
        INPUT_DIR,
        tmp_dir
      )

      app.generate

      expectation = <<-YAML

apiVersion: apps/v1beta1
kind: Deployment
metadata:
  namespace: default
  name: test-nginx
  labels:
    from_default_flag: bing
    tag: REMOVED
spec:
  replicas: 0
  template:
    spec:
      containers:
      - name: nginx
        image: nginx
        imagePullPolicy: IfNotPresent
        ports:
        - name: web
          containerPort: 80

YAML

      clusters = %w(local pippio-production platforms-prod ingestion-prod us-east-1-prod us-east-1-staging colo-service-prod colo-service-staging)
      expected = clusters.map do |cluster|
        File.join(tmp_dir, "#{cluster}_default", 'nginx', 'dep-nginx.yaml')
      end +
      clusters.map do |cluster|
        File.join(tmp_dir, "#{cluster}_default", 'other', 'other.yaml')
      end +
      [ File.join(tmp_dir, "filtered-artifact_default", 'nginx', 'dep-nginx.yaml') ]

      expect(Dir["#{tmp_dir}/**/*.yaml"]).to contain_exactly(*expected)
      expected.select{ |f| f =~ /nginx/ }.each do |rendered|
        rendered_no_tag = File.read(rendered).gsub(/tag: .*/, 'tag: REMOVED')
        expect(rendered_no_tag).to eq(expectation)
      end
      expect(shellrunner).to have_received(:check_call).with('tar', any_args).exactly(MANIFEST_FILE_NUM_CLUSTERS).times
    end
  end

  it "doesn't render deploys for any clusters on print only" do
    Dir.mktmpdir do |tmp_dir|
      # Stub out ENV
      ENV["JOB_NAME"] = JOB_NAME
      ENV["BUILD_ID"] = BUILD_ID

      app = KubeDeployTools::Generate.new(
        MANIFEST_FILE,
        INPUT_DIR,
        tmp_dir,
        print_flags_only: true
      )

      app.generate

      expect(Dir["#{tmp_dir}/*"].empty?).to be true
      expect(shellrunner).not_to have_received(:check_call)
    end
  end
end
