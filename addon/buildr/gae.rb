require 'buildr/java'

module Buildr
  module GAE
    include Extension
    
    HOME = ENV['GAE_HOME'] or fail 'Are we forgetting something? GAE_HOME not set.'
    LIBS = Dir["#{HOME}/lib/user/**/*.jar"]

    class GAEConfig
      attr_reader :host, :email
      attr_writer :host, :email
      
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
      appcfg = lambda do |action, *args|
        trace "#{HOME}/bin/appcfg.sh " + project.gae.options.join(' ') + action.to_s + args.join(' ')
        system "#{HOME}/bin/appcfg.sh", project.gae.options, action.to_s, *args
      end
      
      dev_appserver = lambda do |*args|
        trace "#{HOME}/bin/dev_appserver.sh " + args.join(' ')
        system "#{HOME}/bin/dev_appserver.sh", *args
      end
      
      war = project.package :war
      
      war_dir = file project.path_to(:target, :war) => war do
        mkdir project.path_to(:target, :war) unless File.exists? project.path_to(:target, :war)
        
        cwd = Dir.pwd
        Dir.chdir project.path_to(:target, :war)
        
        cmd = "jar xf '#{war.name}'"
        trace cmd
        system cmd
        
        Dir.chdir cwd
      end
      
      task :deploy => war_dir do
        appcfg.call :update, war_dir.name
      end
      
      task :rollback => war_dir do
        appcfg.call :rollback, war_dir.name
      end
      
      task :server => war_dir do
        dev_appserver.call war_dir.name
      end
    end
    
    def gae
      @gae || GAEConfig.new
    end
  end
  
  class Project
    include GAE
  end
end
