# frozen_string_literal: true

require 'octokit'

require_relative 'templates/flux'

Octokit.configure do |c|
  c.connection_options = {
    request: {
      open_timeout: 5,
      timeout: 5
    }
  }
end

class Manifest
  attr_reader :client, :repo, :service, :namespace

  def initialize(service:, cluster_repo:, namespace:, token:)
    puts 'Connecting to GitHub...'
    @client = Octokit::Client.new(access_token: token)
    @repo = cluster_repo
    @service = service
    @namespace = namespace
    @templates = []
  end

  def self.cleanup(options = {})
    instance = new(**options.slice(:service, :cluster_repo, :namespace, :token))
    instance.create_flux_manifest if options[:flux]

    if options[:dry_run]
      instance.dry_run
    else
      instance.delete_overlay_from_github
      puts 'Done!'
    end
  end

  def create_flux_manifest
    generators = flux_generators
    generators.reject! { |g| g['command'].end_with?("/overlays/#{namespace}") }
    @templates << Templates::Flux.new(namespace: namespace, generators: generators)
  end

  def delete_overlay_from_github # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    puts "Cleaning up namespace '#{namespace}' from GitHub repository #{repo}..."
    ref = 'heads/master'
    sha_latest_commit = client.ref(repo, ref).object.sha

    sha_base_tree = client.commit(repo, sha_latest_commit).commit.tree.sha
    base_tree = client.tree(repo, sha_base_tree, recursive: true)

    clean_tree = base_tree.tree
                          .select { |o| o.type == 'blob' && !o.path.include?("#{service}/overlays/#{namespace}") }
                          .map { |o| o.to_h.slice(:path, :mode, :type, :sha) }
    sha_new_tree = client.create_tree(repo, clean_tree).sha
    sha_new_tree = client.create_tree(repo, new_blobs, base_tree: sha_new_tree).sha

    commit_message = "Cleanup namespace '#{namespace}'"
    sha_new_commit = client.create_commit(repo, commit_message, sha_new_tree, sha_latest_commit).sha
    client.update_ref(repo, ref, sha_new_commit)
  end

  def dry_run
    puts @templates.any? ? 'Printing yaml files...' : 'No yaml files to print!'
    puts
    print_templates
  end

  private

  def new_blobs
    @templates.map do |t|
      {
        path: t.path,
        mode: '100644',
        type: 'blob',
        sha: client.create_blob(repo, Base64.encode64(t.manifest.to_yaml), 'base64')
      }
    end
  end

  def flux_generators
    flux = client.contents(repo, path: "#{Templates::Flux::NAME}.yaml")
    hash = YAML.safe_load Base64.decode64(flux.content)
    hash['commandUpdated']['generators']
  rescue StandardError
    []
  end

  def print_templates
    @templates.each do |t|
      puts t.manifest.to_yaml
    end
    puts "\n"
  end
end
