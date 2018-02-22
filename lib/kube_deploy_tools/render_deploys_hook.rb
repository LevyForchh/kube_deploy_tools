#!/usr/bin/env ruby
# Default rendering hook. Uses built in `templater` to render out all files
# underneath kubernetes/ directory, recursively.

require 'fileutils'
require 'json'
require 'yaml'
require 'kube_deploy_tools/templater'

module KubeDeployTools
  module RenderDeploysHook
    TEMPLATING_SUFFIX = '.erb'

    def self.render_deploys(config_file, input_dir, output_root)
      # Parse config into a struct.
      config = YAML.load(File.read(config_file))
      t = KubeDeployTools::Templater.new

      Dir["#{input_dir}/**/*.y*ml*"].each do |yml|
        # PREFIX/b/c/foo.yml.in -> foo.yml
        output_base = File.basename(yml, TEMPLATING_SUFFIX)

        # PREFIX/b/c/foo.yml.in -> b/c
        subdir = File.dirname(yml[input_dir.size..-1])

        # PREFIX/b/c/foo.yml.in -> output/b/c/foo.yml
        output_dir = File.join(output_root, subdir)
        output_file = File.join(output_dir, output_base)

        if yml.end_with? TEMPLATING_SUFFIX
          # File needs to be templated with templater.
          t.template_to_file(yml, config, output_file)
        else
          # File is not templatable, and is copied verbatim.
          FileUtils.mkdir_p output_dir
          FileUtils.copy(yml, output_file)
        end

        # Bonus: YAML validate the output.
        begin
          if File.file?(output_file)
            YAML.load(File.read(output_file))
          end
        rescue => e
          raise "Failed to YAML validate #{output_file} (generated from #{yml}): #{e}"
        end
      end
    end
  end
end