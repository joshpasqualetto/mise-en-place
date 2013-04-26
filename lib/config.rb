module MiseConfig

  DEFAULTS = {
    :public_url => 'http://localhost:4567/',
    :log_dir => "#{Dir.pwd}/log",
    :clones_dir => "#{Dir.pwd}/clones",
    :repo_dir => "#{Dir.pwd}/repo/chef.git",
    :protected_branches => [],
  }

  def self.read_config(config_file)
    DEFAULTS.dup.tap do |config|
      YAML::load(IO.read(config_file)).each do |k, v|
        config[k] = v
      end
    end
  end

end
