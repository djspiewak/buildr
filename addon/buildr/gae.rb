require 'buildr/java'

module Buildr
  module GAE
    include Extension
    
    HOME = ENV['GAE_HOME'] || fail 'Are we forgetting something? GAE_HOME not set.'
    
    class GAEConfig
      attr_accessor :host, :email
      attr_mutator :host, :email
      
      def options
        ['--email', email, '--host', host]
      end
    end
    
    first_time do
      Project.local_task :deploy
      Project.local_task :rollback
      Project.local_task :server
    end
    
    after_define do |project|
      war = project.package :war
      
      file _(:target, :war) => war do
        mkdir _(:target, :war)
        
        in_dir _(:target, :war) do
          cmd = "jar xf #{war.name} -C war"
          trace cmd
          system cmd
        end
      end
      
      task :deploy => _(:target, :war) do
        appcfg :update, _(:target, :war)
      end
      
      task :rollback => _(:target, :war) do
        appcfg :rollback, _(:target, :war)
      end
      
      task :server => _(:target, :war) do
        dev_appserver _(:target, :war)
      end
    end
    
    def gae
      @gae || GAEConfig.new
    end
    
  private
    
    def appcfg(action, *args)
      system "#{HOME}/appcfg.sh", gae.options, action.to_s, *args
    end
    
    def dev_appserver(*args)
      system "#{HOME}/dev_appserver.sh", *args
    end
    
    def in_dir(dir)
      cwd = Dir.pwd
      Dir.chdir dir
      yield
      Dir.chdir cwd
    end
  end
  
  class Project
    include GAE
  end
end
