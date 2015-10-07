#!/usr/bin/env ruby1.8

require 'rubygems'
require 'grit'

class InvalidReferenceError < StandardError; end

def make_treesame(ref, merge=false, repo_path=".", force=false, message=nil)
  git_dir = `cd #{repo_path} && git rev-parse --git-dir`.strip
  raise Grit::InvalidGitRepositoryError.new(repo_path) if git_dir.empty?
  git_dir = File.expand_path(git_dir)

  repo = Grit::GitRuby::Repository.new(git_dir)
  grit_repo = Grit::Repo.new git_dir, :is_bare => true

  commit = grit_repo.commit(ref) || (raise InvalidReferenceError.new(ref))
  parent_commit = grit_repo.commit("HEAD")
  return if commit.tree.id == parent_commit.tree.id and !force
  parents = [parent_commit.id]
  parents << commit.id if merge

  commit_time = Time.now
  author = Grit::Actor.new(
      (ENV['GIT_AUTHOR_NAME'] || `cd #{repo_path} && git config user.name`.strip),
      (ENV['GIT_AUTHOR_EMAIL'] || `cd #{repo_path} && git config user.email`.strip)
      ).output(commit_time)
  committer = Grit::Actor.new(
      (ENV['GIT_COMMITTER_NAME'] || `cd #{repo_path} && git config user.name`.strip),
      (ENV['GIT_COMMITTER_EMAIL'] || `cd #{repo_path} && git config user.email`.strip)
      ).output(commit_time)
  message ||= "treesame commit of #{ref}"
  message = "#{message}\n\nTreesame-Commit-Id: #{commit.id}\n"

  new_commit = Grit::GitRuby::Commit.new(commit.tree.id, parents, author, committer, message, {}, repo)
  new_commit_sha1 = repo.put_raw_object(new_commit.raw_content, new_commit.type.to_s)

  `cd #{repo_path} && git reset --hard #{new_commit_sha1}`
  return new_commit_sha1
end
