#!/usr/bin/env ruby
# frozen_string_literal: true

require 'slop'

require_relative 'manifest'

$opts = Slop.parse do |o|
  o.banner = 'usage: cleanup_overlay [options]'
  o.separator 'example: cleanup_overlay --namespace my-namespace --cluster-repo my-company/my-cluster'
  o.separator ''
  o.separator 'options:'
  o.string '-r', '--cluster-repo',
    'GitHub repository that controls your cluster', default: ENV['CLUSTER_REPO']
  o.string '-n', '--namespace',
    'desired namespace, or inferred from GITHUB_HEAD_REF', default: ENV['GITHUB_HEAD_REF']&.split('/')&.join('-')
  o.string '-T', '--token',
    'GitHub access token with repos access, _NOT_ GITHUB_TOKEN', default: ENV['TOKEN']
  o.boolean '--flux',
    'Modifies manifests for automated Flux deployments', default: false
  o.boolean '--dry-run',
    'Print out yaml files to be created in GitHub - Do NOT commit', default: false
end

def exit_code(message, number)
  puts
  puts message
  puts
  puts $opts
  puts
  exit number
end

# ensure we have all the appropriate parameters to proceed

puts 'Checking required arguments...'
missing = $opts.to_hash.select { |k, v| v.nil? }
missing.delete(:token) if $opts[:dry_run]
exit_code("Missing required arguments: #{missing.keys.join(', ')}".red, 2) if missing.any?

Manifest.cleanup
