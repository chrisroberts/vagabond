#encoding: utf-8

require 'vagabond'

module Vagabond
  class Command
    module Server
      # Upload items to chef server
      class Upload < Command

        # List of valid items to upload
        VALID_UPLOADS = [:cookbooks, :roles, :environments, :data_bags]

        # Upload things
        def run!
          to_upload = VALID_UPLOADS.find_all do |k|
            arguments.include?(k.to_s.gsub('_', '-')) || arguments.include?(k.to_s)
          end
          to_upload = VALID_UPLOADS if to_upload.empty?
          to_upload.each do |item|
            readable = item.to_s.split('_').join(' ')
            ui.info "Uploading #{readable}:"
            send("upload_#{item}")
            ui.info "Upload of #{readable} complete!"
          end
        end

        # Upload all cookbooks
        def upload_cookbooks
          if(options[:resolve])
            resolve_cookbooks
          end
          cmd = 'cookbook upload --all'.split(' ')
          Knife.new(options.merge(:ui => ui), cmd).execute!
        end

        # Resolve cookbooks using defined resolver
        def resolve_cookbooks
          case options[:resolver]
          when 'librarian'
            run_action 'Installing cookbooks with librarian' do
              host_command(
                'librarian-chef install',
                :cwd => vagabondfile.directory
              )
              nil
            end
          when 'berkshelf'
          else
            raise Error::UnknownResolver.new "Unknown resolver provided: #{opts[:resolver]}"
          end
        end

        # Upload all roles
        def upload_roles
          roles = Dir.glob(
            File.join(
              vagabondfile.directory,
              'roles', '**', '**', '*.{rb,json}'
            )
          )
          Knife.new(
            options.merge(
              :ui => ui,
              :knife_cwd => vagabondfile.directory
            ),
            Shellwords.split("role from file #{roles.join(' ')}")
          ).execute!
        end

        # Upload all environments
        def upload_environments
          environments = Dir.glob(
            File.join(
              vagabondfile.directory,
              'environments', '**', '**', '*.{rb,json}'
            )
          )
          Knife.new(
            options.merge(:ui => ui),
            Shellwords.split("environment from file #{environments.join(' ')}")
          ).execute!
        end

        # Create all data bags and upload all data bag items
        def upload_data_bags
          Knife.new(
            options.merge(:ui => ui),
            Shellwords.split('upload data_bags')
          ).execute!
        end

      end
    end
  end
end
