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

class String
  def red; colorize(self, "\e[1m\e[31m"); end
  def green; colorize(self, "\e[1m\e[32m"); end
  def colorize(text, color_code)  "#{color_code}#{text}\e[0m" end
end

class Manifest
  attr_reader :client, :repo, :namespace

  def initialize
    puts 'Connecting to GitHub...'
    @client = Octokit::Client.new(access_token: $opts[:token])
    @repo = $opts[:cluster_repo]
    @namespace = $opts[:namespace]
    $templates = []
  end

  def self.cleanup
    instance = self.new
    instance.create_flux_manifest if $opts[:flux]

    return instance.dry_run if $opts[:dry_run]
    
    instance.delete_overlay_from_github
    puts 'Done!'
  end

  def create_flux_manifest
    generators = flux_generators
    generators.reject! { |g| g['command'].end_with?("/overlays/#{namespace}") }
    $templates << Templates::Flux.new(namespace: namespace, generators: generators)
  end

  def delete_overlay_from_github
    puts "Cleaning up namespace '#{namespace}' from GitHub repository #{repo}..."
    ref = 'heads/master'
    sha_latest_commit = client.ref(repo, ref).object.sha

    sha_base_tree = client.commit(repo, sha_latest_commit).commit.tree.sha
    base_tree = client.tree(repo, sha_base_tree, recursive: true)
    
    clean_tree = base_tree.tree.select { |o| o.type == 'blob' && !o.path.include?("overlays/#{namespace}") }
                               .map { |o| o.to_h.slice(:path, :mode, :type, :sha) }
    sha_new_tree = client.create_tree(repo, clean_tree).sha
    sha_new_tree = client.create_tree(repo, new_blobs, { base_tree: sha_new_tree }).sha

    commit_message = "Cleanup namespace '#{namespace}'"
    sha_new_commit = client.create_commit(repo, commit_message, sha_new_tree, sha_latest_commit).sha
    updated_ref = client.update_ref(repo, ref, sha_new_commit)
  end

  def dry_run
    puts $templates.any? ? 'Printing yaml files...' : 'No yaml files to print!'
    puts
    $templates.each do |t|
      puts "\n"
      puts t.path.green
      puts t.manifest.to_yaml
      puts "\n"
    end
  end

  private

  def new_blobs
    $templates.map do |t|
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
    hash = YAML.load Base64.decode64(flux.content)
    hash['commandUpdated']['generators']
  rescue
    []
  end
end
