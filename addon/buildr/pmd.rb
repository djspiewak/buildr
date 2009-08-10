require 'buildr/java'

module Buildr

  # Provides the <code>[project_name]:pmd:html</code> and <code>[project_name]:pmd:xml</code> tasks.
  # Require explicitly using <code>require "buildr/pmd"</code>.
  #
  # You can also specify which classes to include/exclude from report by
  # passing a class name regexp to the <code>pmd.include</code> or
  # <code>pmd.exclude</code> methods.
  #
  #   define 'someModule' do
  #      pmd.include 'some.package.*'
  #      pmd.include /some.(foo|bar).*/
  #      pmd.exclude 'some.foo.util.SimpleUtil'
  #      pmd.exclude /*.Const(ants)?/i
  #   end
  module PMD

    VERSION = '4.2.5'

    class << self

      def settings
        Buildr.settings.build['pmd'] || {}
      end

      def version
        settings['version'] || VERSION
      end

      def dependencies
        @dependencies ||= ["pmd:pmd:jar:#{version}",
          'ant:ant:jar:1.6',
          'asm:asm:jar:3.1',
          'jaxen:jaxen:jar:1.1.1',
          'junit:junit:jar:4.4'
        ]
        
      end

      def pmd
        unless @pmd
          @pmd = PMDConfig.new(self)
          @pmd.report_dir('reports/pmd')
          @pmd.data_file('reports/pmd.data')
          @pmd.compile_options :target => '1.6'
        end
        @pmd
      end

      # Create the pmd xml report
      def create_xml(config)
        mkdir_p config.report_to.to_s
        ant = config.ant

        info "Creating pmd report #{config.report_to('pmd-report.xml')}"
        params = {:shortFilenames => config.short_names, :failuresPropertyName => config.failure_property,
          :failOnRuleViolation => config.fail, :targetjdk => config.compile_options[:target],
          :rulesetfiles => config.rules.join(",")
        }
        params[:maxRuleViolations] = config.max_violations if config.max_violations

        ant.pmd params do
          ant.formatter :type => 'xml', :toFile => config.data_file
          includes, excludes = config.includes, config.excludes
          src_dirs = config.sources
          if includes.empty? && excludes.empty?
            src_dirs.each do |src_dir|
              if File.exist?(src_dir.to_s)
                config.ant.fileset :dir=>src_dir.to_s do
                  config.ant.include :name => "**/*.java"
                end
              end
            end
          else
            includes = [//] if includes.empty?
            src_dirs.each do |src_dir|
              Dir.glob(File.join(src_dir, "**/*.java")) do |src|
                src_name = src.gsub(/#{src_dir}\/?|\.java$/, '').gsub('/', '.')
                if includes.any? { |p| p === src_name } && !excludes.any? { |p| p === src_name }
                  config.ant.fileset :file => src
                end
              end
            end
          end
        end
      end

      # Create the pmd html report
      def create_html(config)
        config.ant.xslt :in => config.data_file, :out => config.html_out,
          :style => config.style
      end

      # Cleans pmd artifacts
      def clean(config)
        rm_rf [config.report_to, config.data_file]
      end
    end

    class PMDConfig # :nodoc:

      def initialize(project)
        @project = project
      end
      
      attr_writer :data_file

      attr_reader :project
      private :project

      def ant
        @ant ||= Buildr.ant('pmd') do |ant|
          cp = Buildr.artifacts(PMD.dependencies).each(&:invoke).map(&:to_s).join(File::PATH_SEPARATOR)
          ant.taskdef :classpath => cp, :name => 'pmd', :classname => 'net.sourceforge.pmd.ant.PMDTask'
        end
      end

      def failure_property
        'pmd.failure.property'
      end

      def report_to(file = nil)
        File.expand_path(File.join(*[report_dir, file.to_s].compact))
      end

      def html_out
        report_to('pmd-report.html')
      end

      # :call-seq:
      #   project.checkstyle.report_dir(*excludes)
      #
      def report_dir(*dir)
        if dir.empty?
          @report_dir ||= project.path_to(:reports, :pmd)
        else
          fail "Invalid report dir '#{dir.join(', ')}" unless dir.size == 1
          @report_dir = dir[0]
          self
        end
      end
      
      # :call-seq:
      #   project.pmd.data_file(file)
      #
      def data_file(*file)
        if file.empty?
          @data_file ||= project.path_to(:reports, 'pmd.data')
        else
          fail "Invalid data file '#{file.join(', ')}" unless file.size == 1
          @data_file = file[0]
          self
        end
      end

      # :call-seq:
      #   project.pmd.data_file(file)
      #
      def compile_options(*options)
        if options.empty?
          @compile_options ||= project.compile.options
        else
          @compile_options = {}
          options.pop.each { |key, value| @compile_options[key.to_sym] = value } if Hash === options.last
          options.each { |key| @compile_options[key.to_sym] = true }
          self
        end
      end

      # :call-seq:
      #   project.pmd.rules(*rulesets)
      #
      def rules(*rulesets)
        if rulesets.empty?
          @rulesets
        else
          @rulesets = [rulesets].flatten.uniq
          self
        end
      end

      # :call-seq:
      #   project.pmd.max_violations(max_violations)
      #
      def max_violations(*max_violations)
        if max_violations.empty?
          @max_violations ||= Checkstyle.settings['max.violations']
        else
          fail "Invalid violations value '#{max_violations.join(', ')}" unless max_violations.size == 1
          @max_violations = max_violations[0]
          self
        end
      end

      # :call-seq:
      #   project.pmd.style(style)
      #
      def style(*style)
        if style.empty?
          @html_style
        else
          fail "Invalid violations value '#{style.join(', ')}" unless style.size == 1
          @html_style = style[0]
          self
        end
      end

      # :call-seq:
      #   project.pmd.fail(fail_on_violation)
      #
      def fail(*fail_on_violation)
        if fail_on_violation.empty?
          @fail ||= (PMD.settings['fail.on.violation'] || false).to_s
        else
          fail "Invalid violations value '#{fail_on_violation.join(', ')}" unless fail_on_violation.size == 1
          @fail = fail_on_violation[0]
          self
        end
      end

      # :call-seq:
      #   project.pmd.short_names(short_filenames)
      #
      def short_names(*short_filenames)
        if short_filenames.empty?
          @short_names ||= (Checkstyle.settings['short.names'] || true).to_s
        else
          fail "Invalid violations value '#{short_filenames.join(', ')}" unless short_filenames.size == 1
          @short_names = short_filenames[0]
          self
        end
      end

      # :call-seq:
      #   project.checkstyle.sources(*sources)
      #
      def sources(*sources)
        if sources.empty?
          @sources ||= project.compile.sources
        else
          @sources = [sources].flatten.uniq
          self
        end
      end

      # :call-seq:
      #   project.pmd.include(*class_patterns)
      #
      def include(*class_patterns)
        includes.push(*class_patterns.map { |p| String === p ? Regexp.new(p) : p })
        self
      end

      def includes
        @include_classes ||= []
      end

      # :call-seq:
      #   project.pmd.exclude(*class_patterns)
      #
      def exclude(*class_patterns)
        excludes.push(*class_patterns.map { |p| String === p ? Regexp.new(p) : p })
        self
      end

      def excludes
        @exclude_classes ||= []
      end
    end

    module PMDExtension # :nodoc:
      include Buildr::Extension

      def pmd
        @pmd_config ||= PMDConfig.new(self)
      end

      before_define do
        namespace 'pmd' do
          desc "Creates an pmd html report"
          task :html

          desc "Fails the build if pmd detected any violations"
          task :fail_on_violation
        end
      end

      after_define do |project|
        pmd = project.pmd

        namespace 'pmd' do
          unless project.compile.target.nil?
            # all result dirs and files as base targets
            pmd_xml = file pmd.data_file do
              PMD.create_xml(pmd)
            end
            pmd_html = file pmd.html_out => pmd_xml do
              PMD.create_html(pmd)
            end
            file pmd.report_to => pmd_html

            task :xml => pmd_xml
            task :html => pmd_html

            task :pmd_lenient do
              info "Setting pmd to ignore violations"
              project.pmd.fail_on_violation(false)
            end

            task :fail_on_violation => [:pmd_lenient, :xml] do
              property = pmd.ant.project.properties.find { |current| current[0] == pmd.failure_property }
              property = property.nil? ? nil : property[1]
              fail "PMD rule violations encountered see reports in '#{pmd.report_to}'" if property
            end
          end

          project.clean do
            PMD.clean(pmd)
          end
        end
      end
    end

    class Buildr::Project
      include PMDExtension
    end

    namespace "pmd" do
      # all result dirs and files as base targets
      pmd_xml = file pmd.data_file do
        pmd.sources(Buildr.projects.map(&:pmd).map(&:sources).flatten)
        unless pmd.rules
          rules = Buildr.projects.map(&:pmd).map(&:rules).uniq.reject {|rule|
            rule.nil? || rule.empty?
          }
          fail "Could not set pmd rules from projects, existing configs: '#{rules.join(', ')}'" if rules.size != 1
          pmd.rules(rules[0])
        end
        create_xml(pmd)
      end
      pmd_html = file pmd.html_out => pmd_xml do
        unless pmd.style
          styles = Buildr.projects.map(&:pmd).map(&:style).uniq.reject{|style|
            style.nil? || style.strip.empty?
          }
          fail "Could not set html style from projects, existing styles: '#{styles.join(', ')}'" if styles.size != 1
          pmd.style(styles[0])
        end
        create_html(pmd)
      end
      file pmd.report_to => pmd_html
      
      desc "Create pmd xml report in #{pmd.report_to.to_s}"
      task :xml => pmd_xml
      desc "Create pmd html report in #{pmd.report_to.to_s}"
      task :html => pmd_html
    end

    task "clean" do
      clean(pmd)
    end
  end
end

