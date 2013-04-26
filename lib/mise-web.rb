#!/usr/bin/env ruby

require 'rubygems'
require 'sinatra'
require 'haml'
require 'json'
require 'yaml'
require "#{File.dirname(__FILE__)}/config"
require "#{File.dirname(__FILE__)}/models"

class MiseEnPlace < Sinatra::Base

  configure :production do
    set :config, '/etc/mise-en-place/config.yml'
  end

  configure :development do
    set :db, "sqlite3://#{Dir.pwd}/#{environment}.db"
    set :config, "#{Dir.pwd}/development.yml"
    require 'sinatra/reloader'
    register Sinatra::Reloader
  end

  configure do
    disable :protection
    set :views, "#{File.dirname(__FILE__)}/../views"
    MiseConfig.read_config(settings.config).each {|k, v| set k, v }
    req_log = File.new("#{settings.log_dir}/mise-en-place.requests.log", 'a')
    req_log.sync = true
    use Rack::CommonLogger, req_log
    DataMapper.setup(:default, settings.db)
    DataMapper.auto_upgrade!
  end

  helpers do
    def logger
      settings.logger
    end
    def fmt_time(t)
      t.strftime('%d %b %X')
    end
    def page
      params[:page] ? params[:page].to_i : 0
    end
    def page_size
      20
    end
    def paginate(q)
      q.merge(:offset => page.to_i * page_size,
              :limit => page_size,
              :order => :received_at.desc)
    end
    def filter_params(*allowed)
      params.reject {|k, v| !allowed.include?(k.to_sym) }
    end
    def fork_upload(ul)
      upload_pid = fork do
        exec("#{File.dirname(__FILE__)}/../bin/mise-do-upload",
             '--config', settings.config, '--upload', ul.id.to_s)
      end
      Process.detach(upload_pid)
    end
  end

  get '/' do
    @page = page
    @uploads = Upload.all(paginate(filter_params(:user, :branch)))
    haml :index
  end

  get '/upload/:id' do
    if @ul = Upload.get(params[:id])
      if File.exist?("#{settings.log_dir}/#{@ul.log_file}")
        @log = File.read("#{settings.log_dir}/#{@ul.log_file}") rescue "Error reading log"
      end
      @user = env['REMOTE_USER']
      haml :upload
    else
      halt 404
    end
  end

  get '/upload/:id/log' do
    if @ul = Upload.get(params[:id])
      content_type 'text/plain'
      begin
        File.read("#{settings.log_dir}/#{@ul.log_file}")
      rescue Errno::ENOENT
        "Upload #{@ul[:id]} is #{@ul[:status]}\n"
      end
    else
      halt 404
    end
  end

  post '/upload/:id' do
    if @ul = Upload.get(params[:id])
      if @ul.status == 'unapproved'
        case params[:action]
        when 'Approve'
          if env['REMOTE_USER'] != @ul.user
            @ul.approver = env['REMOTE_USER']
            @ul.status = 'ready'
            @ul.save
            fork_upload(@ul)
          end
          redirect "/upload/#{@ul.id}"
        when 'Delete'
          # This is rather hacky
          system 'git', "--git-dir=#{settings.repo_dir}", 'update-ref', "refs/heads/#{@ul.branch}", "#{@ul.prev}"
          @ul.destroy
          redirect "/"
        end
      else
        halt 400
      end
    else
      halt 404
    end
  end

  put '/branch/:name' do
    body = JSON.parse(request.body.read) rescue nil

    halt 400, 'Body must be JSON' unless body
    halt 400, 'Must specify ref' unless body['ref']

    status = settings.protected_branches.include?(params[:name]) ? 'unapproved' : 'ready'
    @ul = Upload.create(:branch => params[:name],
                        :ref => body['ref'],
                        :prev => body['prev'],
                        :user => env['REMOTE_USER'],
                        :status => status,
                        :received_at => Time.now,
                        :completed_at => nil)
    fork_upload(@ul) if @ul.status == 'ready'

    "*** Progress can be viewed here: #{settings.public_url}upload/#{@ul.id}\n"
  end

  delete '/branch/:name' do
    "*** Remember to delete the Opscode organization\n"
  end

  post '/push' do
    # FIXME: background this, do something more intelligent
    system 'git', "--git-dir=#{settings.repo_dir}", 'fetch'
    status 202
  end

end
