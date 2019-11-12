#!/usr/bin/env ruby
# frozen_string_literal: true

require 'slop'

require_relative 'manifest'

$options = Slop.parse do |o|
  o.banner = 'usage: cleanup_overlay [options]'
  o.separator 'example: cleanup_overlay --namespace my-namespace --cluster-repo my-company/my-cluster'
  o.separator ''
  o.separator 'options:'
  o.string '-r', '--cluster-repo',
           'GitHub repository that controls your cluster',
           default: ENV['CLUSTER_REPO']
  o.string '-n', '--namespace',
           'desired namespace, or inferred from $GITHUB_HEAD_REF',
           default: ENV['GITHUB_HEAD_REF']&.gsub(/[^\w]/, '-')
  o.string '-T', '--token',
           'GitHub access token with repos access, _NOT_ $GITHUB_TOKEN',
           default: ENV['TOKEN']
  o.boolean '--flux',
            'Modifies manifests for automated Flux deployments',
            default: false
  o.boolean '--dry-run',
            'Print out yaml files to be created in GitHub - Do NOT commit',
            default: false
end

class String
  def red
    colorize(self, "\e[1m\e[31m")
  end

  private

  def colorize(text, color_code)
    "#{color_code}#{text}\e[0m"
  end
end

def exit_code(message, number, show_options: false)
  puts
  puts message.red
  if show_options
    puts
    puts $options
  end
  puts
  exit number
end

# ensure we have all the appropriate parameters to proceed
puts 'Checking required arguments...'
missing = $options.to_hash.select { |_, v| v.nil? }
missing.delete(:token) if $options[:dry_run]
exit_code("Missing required arguments: #{missing.keys}", 2, show_options: true) if missing.any?

Manifest.cleanup($options.to_hash)
