require 'data_mapper'
require "#{File.dirname(__FILE__)}/config"

class Upload

  include DataMapper::Resource

  property :id, Serial
  property :branch, String
  property :ref, String
  property :prev, String
  property :user, String
  property :approver, String
  property :status, String
  property :received_at, DateTime
  property :completed_at, DateTime

  def log_file
    "upload-#{@id}.log"
  end

  def github_url
    MiseConfig.read_config(file)[:github_url]
  end

  def github_link
    if prev
      "#{github_url}/compare/#{prev}...#{ref}"
    else
      "#{github_url}/commit/#{ref}"
    end
  end

  def short_hashes
    if prev
      "#{prev[0...7]}..#{ref[0...7]}"
    else
      ref[0...7]
    end
  end

end
