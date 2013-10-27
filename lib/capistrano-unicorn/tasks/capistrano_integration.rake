require 'capistrano'
require 'tempfile'
require_relative '../utility'
require_relative '../config'

module CapistranoUnicorn
  class Capistrano3
    include CapistranoUnicorn::Utility

    def _cset(key, &block)
      set key, block
    end

    def logger
      @logger ||= Class.new do
        def important(message)
          puts message
        end
      end.new
    end
  end
end

#
# Unicorn cap tasks
#
namespace :unicorn do
  task :environment do
    include CapistranoUnicorn::Utility
    CapistranoUnicorn::Config.load(CapistranoUnicorn::Capistrano3.new)
  end

  desc 'Debug Unicorn variables'
  task :show_vars => :environment do
    on roles :app do
      puts <<-EOF.gsub(/^ +/, '')
              # Environments
              rails_env          "#{fetch :rails_env}"
              unicorn_env        "#{fetch :unicorn_env}"
              unicorn_rack_env   "#{fetch :unicorn_rack_env}"

              # Execution
              unicorn_user       #{fetch :unicorn_user.inspect}
              unicorn_bundle     "#{fetch :unicorn_bundle}"
              unicorn_bin        "#{fetch :unicorn_bin}"
              unicorn_options    "#{fetch :unicorn_options}"
              unicorn_restart_sleep_time  #{fetch :unicorn_restart_sleep_time}

              # Relative paths
              app_subdir                         "#{fetch :app_subdir}"
              unicorn_config_rel_path            "#{fetch :unicorn_config_rel_path}"
              unicorn_config_filename            "#{fetch :unicorn_config_filename}"
              unicorn_config_rel_file_path       "#{fetch :unicorn_config_rel_file_path}"
              unicorn_config_stage_rel_file_path "#{fetch :unicorn_config_stage_rel_file_path}"

              # Absolute paths
              app_path                  "#{fetch :app_path}"
              unicorn_pid               "#{fetch :unicorn_pid}"
              bundle_gemfile            "#{fetch :bundle_gemfile}"
              unicorn_config_path       "#{fetch :unicorn_config_path}"
              unicorn_config_file_path  "#{fetch :unicorn_config_file_path}"
              unicorn_config_stage_file_path
              ->                        "#{fetch :unicorn_config_stage_file_path}"
            EOF
    end
  end

  unicorn_roles = fetch(:unicorn_roles, :app)

  # execute :sh, "-c", command
  # if command includes /\s/, SSHKit won't execute command within its dsl (within, with etc...)

  desc 'Start Unicorn master process'
  task :start => :environment do
    on roles unicorn_roles do
      execute :sh, "-c", "'#{start_unicorn.split.join(' ')}'"
    end
  end

  desc 'Stop Unicorn'
  task :stop => :environment do
    on roles unicorn_roles do
      execute :sh, "-c", "'#{kill_unicorn('QUIT').split.join(' ')}'"
    end
  end

  desc 'Immediately shutdown Unicorn'
  task :shutdown => :environment do
    on roles unicorn_roles do
      execute :sh, "-c", "'#{kill_unicorn('TERM').split.join(' ')}'"
    end
  end

  desc 'Restart Unicorn'
  task :restart => :environment do
    on roles unicorn_roles do
      execute :sh, "-c", <<-END
              '#{duplicate_unicorn}

              sleep #{fetch(:unicorn_restart_sleep_time)};

              if #{old_unicorn_is_running?}; then
                #{unicorn_send_signal('QUIT', get_old_unicorn_pid)};
              fi;'
            END
        .split.join(' ')
    end
  end

  desc 'Duplicate Unicorn'
  task :duplicate => :environment do
    on roles unicorn_roles do
      execute :sh, "-c", "'#{duplicate_unicorn.split.join(' ')}'"
    end
  end

  desc 'Reload Unicorn'
  task :reload => :environment do
    on roles unicorn_roles do
      execute :sh, "-c", <<-END
              'if #{unicorn_is_running?}; then
                echo "Reloading Unicorn...";
                #{unicorn_send_signal('HUP')};
              else
                #{start_unicorn}
              fi;'
            END
        .split.join(' ')
    end
  end

  desc 'Add a new worker'
  task :add_worker => :environment do
    on roles unicorn_roles do
      execute :sh, "-c", <<-END
              'if #{unicorn_is_running?}; then
                echo "Adding a new Unicorn worker...";
                #{unicorn_send_signal('TTIN')};
              else
                echo "Unicorn is not running.";
              fi;'
            END
        .split.join(' ')
    end
  end

  desc 'Remove amount of workers'
  task :remove_worker => :environment do
    on roles unicorn_roles do
      execute :sh, "-c", <<-END
              'if #{unicorn_is_running?}; then
                echo "Removing a Unicorn worker...";
                #{unicorn_send_signal('TTOU')};
              else
                echo "Unicorn is not running.";
              fi;'
            END
        .split.join(' ')
    end
  end
end
