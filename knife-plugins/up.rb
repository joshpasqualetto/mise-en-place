require 'chef/shef/ext'

module Mise
  module Knife

    class Up < Chef::Knife

      banner "knife up ORGS"

      option :delete,
        :long => '--delete',
        :short => '-D',
        :description => "delete branch",
        :boolean => true


      def run
        #TODO: Get our security credentials from knife rb?
        #TODO: This needs full environment support
        ENV['MISE_USER'] = sec_creds['email']
        ENV['MISE_PASSWORD'] = sec_creds['token']
        name_args << Chef::Config[:knife][:org_name] if name_args.empty?
        name_args.unshift '-D' if config[:delete]
        exec 'mise-up', *name_args
      end

    end

  end
end
