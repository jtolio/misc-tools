#!/usr/bin/env ruby1.8

require 'rubygems'
require 'grit'
require 'set'

class InvalidReferenceError < StandardError; end
class GraphError < StandardError; end

module GitHelpers

  def merge_base_ref(ref1, ref2)
    raise InvalidReferenceError.new(ref1) unless @repo.commit(ref1)
    raise InvalidReferenceError.new(ref2) unless @repo.commit(ref2)
    `git --git-dir="#{@git_dir}" merge-base "#{ref1}" "#{ref2}"`.strip
  end

  def treesame_base_refs(*refs)
    # for n refs, we want to find an n-large set of tree-same commits that are
    # each in the ancestry of their respective ref. we'll proceed via
    # n-directional search; in other words, start a search from each of the n
    # refs in the graph and breadth-first search until the searches meet in the
    # middle.
    searches = refs.map{|ref| {
        "queue" => [@repo.commit(ref) || (raise InvalidReferenceError.new(ref))],
        "hashes" => {}
      }}
    loop do
      any_search_succeeded = false
      searches.each do |search|
        next if search["queue"].empty?
        any_search_succeeded = true
        commit = search["queue"].shift
        tree_id = commit.tree.id
        search["hashes"][tree_id] ||= commit
        set = searches.map do |s|
          break unless s["hashes"][tree_id]
          s["hashes"][tree_id]
        end
        return set unless set.nil?
        search["queue"] += commit.parents
      end
      raise GraphError unless any_search_succeeded
    end
  end

  def get_change_id(commit)
    commit.message.split("\n").find{|l| l =~ /^Change-Id:\s+(I[0-9a-z]+)\s*$/} && $1
  end

  def get_first_line(commit)
    commit.message.split("\n").first.strip
  end

  def commit_touches_subdir(commit, subdir)
    `git --git-dir="#{@git_dir}" diff --name-only "#{commit}"^ "#{commit}"`.strip.split("\n").each do |path|
      return true if path.start_with? subdir
    end
    false
  end

end

class Changelog

  attr_accessor :removed, :added

  def initialize(repo, git_dir, old_ref, new_ref, options={})
    @repo = repo
    @git_dir = git_dir
    @old_ref = old_ref
    @new_ref = new_ref
    @style = options[:style] || :treesame
    @removed = []
    @added = []
    calculate
  end

  def format(options={})
    lines = []
    added_and_removed_messages = options[:keep_dupes] ? [] :
        @added.map{|commit| get_first_line commit}.to_set &
        @removed.map{|commit| get_first_line commit}.to_set
    @removed.each do |commit|
      unless added_and_removed_messages.include? get_first_line(commit)
        lines << "  * [-#{commit.id[0..6]}] #{get_first_line commit}\n"
      end
    end
    @added.each do |commit|
      unless added_and_removed_messages.include? get_first_line(commit)
        lines << "  * [+#{commit.id[0..6]}] #{get_first_line commit}\n"
      end
    end
    lines.join
  end

  def filter(subdir)
    @removed.select! do |commit|
      commit_touches_subdir commit, subdir
    end
    @added.select! do |commit|
      commit_touches_subdir commit, subdir
    end
  end

  private

  include GitHelpers

  def calculate
    case @style
    when :changeid then calculate_from_changeid
    when :treesame then calculate_from_treesame
    end
  end

  def calculate_from_changeid
    base = merge_base_ref @old_ref, @new_ref
    old_commits = @repo.commits_between base, @old_ref
    new_commits = @repo.commits_between base, @new_ref
    old_changes = old_commits.map{|x| get_change_id(x)}.to_set
    new_changes = new_commits.map{|x| get_change_id(x)}.to_set
    old_changes_only = old_changes - new_changes
    new_changes_only = new_changes - old_changes
    @added = new_commits.find_all{|x| new_changes_only.include? get_change_id(x) }
    @removed = old_commits.find_all{|x| old_changes_only.include? get_change_id(x) }.reverse
  end

  def calculate_from_treesame
    old_base, new_base = treesame_base_refs @old_ref, @new_ref
    @added = @repo.commits_between(new_base, @new_ref)
    @removed = @repo.commits_between(old_base, @old_ref).reverse
  end

end

class ChangelogGenerator

  def initialize(repo_path)
    git_dir = `cd #{repo_path} && git rev-parse --git-dir`.strip
    raise Grit::InvalidGitRepositoryError.new(repo_path) if git_dir.empty?
    @git_dir = File.expand_path(git_dir)
    @repo = Grit::Repo.new @git_dir, :is_bare => true
  end

  def changelog(old_ref, new_ref, options={})
    Changelog.new(@repo, @git_dir, old_ref, new_ref, options)
  end

end

if __FILE__ == $0
  if ARGV[0] == "--help"
    puts "usage: changelog.rb <hash1> <hash2> [subdir]

generates a changelog history between two hashes in a git repo"
  else
    changelog = ChangelogGenerator.new(".").changelog(ARGV[0], ARGV[1])
    changelog.filter ARGV[2] if ARGV[2]
    puts changelog.format
  end
end
