module Buildr
  
  # Methods added to Project for creating JavaDoc documentation.
  module Javadoc

    # A convenient task for creating Javadocs from the project's compile task. Minimizes all
    # the hard work to calling #from and #using.
    #
    # For example:
    #   javadoc.from(projects('myapp:foo', 'myapp:bar')).using(:windowtitle=>'My App')
    # Or, short and sweet:
    #   desc 'My App'
    #   define 'myapp' do
    #     . . .
    #     javadoc projects('myapp:foo', 'myapp:bar')
    #   end
    class JavadocTask < Rake::Task

      def initialize(*args) #:nodoc:
        super
        @options = {}
        @classpath = []
        @sourcepath = []
        @files = FileList[]
        enhance do |task|
          rm_rf target.to_s
          generate source_files, File.expand_path(target.to_s), options.merge(:classpath=>classpath, :sourcepath=>sourcepath)
          touch target.to_s
        end
      end

      # The target directory for the generated Javadoc files.
      attr_reader :target

      # :call-seq:
      #   into(path) => self
      #
      # Sets the target directory and returns self. This will also set the Javadoc task
      # as a prerequisite to a file task on the target directory.
      #
      # For example:
      #   package :zip, :classifier=>'docs', :include=>javadoc.target
      def into(path)
        @target = file(path.to_s).enhance([self]) unless @target && @target.to_s == path.to_s
        self
      end

      # :call-seq:
      #   include(*files) => self
      #
      # Includes additional source files and directories when generating the documentation
      # and returns self. When specifying a directory, includes all .java files in that directory.
      def include(*files)
        @files.include *files.flatten.compact
        self
      end

      # :call-seq:
      #   exclude(*files) => self
      #
      # Excludes source files and directories from generating the documentation.
      def exclude(*files)
        @files.exclude *files
        self
      end

      # Classpath dependencies.
      attr_accessor :classpath

      # :call-seq:
      #   with(*artifacts) => self
      #
      # Adds files and artifacts as classpath dependencies, and returns self.
      def with(*specs)
        @classpath |= Buildr.artifacts(specs.flatten).uniq
        self
      end

      # Additional sourcepaths that are not part of the documented files.
      attr_accessor :sourcepath
        
      # Returns the Javadoc options.
      attr_reader :options

      # :call-seq:
      #   using(options) => self
      #
      # Sets the Javadoc options from a hash and returns self.
      #
      # For example:
      #   javadoc.using :windowtitle=>'My application'
      def using(*args)
        args.pop.each { |key, value| @options[key.to_sym] = value } if Hash === args.last
        args.each { |key| @options[key.to_sym] = true }
        self
      end

      # :call-seq:
      #   from(*sources) => self
      #
      # Includes files, directories and projects in the Javadoc documentation and returns self.
      #
      # You can call this method with Java source files and directories containing Java source files
      # to include these files in the Javadoc documentation, similar to #include. You can also call
      # this method with projects. When called with a project, it includes all the source files compiled
      # by that project and classpath dependencies used when compiling.
      #
      # For example:
      #   javadoc.from projects('myapp:foo', 'myapp:bar')
      def from(*sources)
        sources.flatten.each do |source|
          case source
          when Project
            self.enhance source.prerequisites
            self.include source.compile.sources
            self.with source.compile.dependencies 
          when Rake::Task, String
            self.include source
          else
            fail "Don't know how to generate Javadocs from #{source || 'nil'}"
          end
        end
        self
      end

      def prerequisites() #:nodoc:
        super + @files + classpath + sourcepath
      end

      def source_files() #:nodoc:
        @source_files ||= @files.map(&:to_s).
          map { |file| File.directory?(file) ? FileList[File.join(file, "**/*.java")] : file }.
          flatten.reject { |file| @files.exclude?(file) }
      end

      def needed?() #:nodoc:
        return false if source_files.empty?
        return true unless File.exist?(target.to_s)
        source_files.map { |src| File.stat(src.to_s).mtime }.max > File.stat(target.to_s).mtime
      end

    private

      def generate(sources, target, options = {})
        cmd_args = [ '-d', target, Buildr.application.options.trace ? '-verbose' : '-quiet' ]
        options.reject { |key, value| [:sourcepath, :classpath].include?(key) }.
          each { |key, value| value.invoke if value.respond_to?(:invoke) }.
          each do |key, value|
            case value
            when true, nil
              cmd_args << "-#{key}"
            when false
              cmd_args << "-no#{key}"
            when Hash
              value.each { |k,v| cmd_args << "-#{key}" << k.to_s << v.to_s }
            else
              cmd_args += Array(value).map { |item| ["-#{key}", item.to_s] }.flatten
            end
          end
        [:sourcepath, :classpath].each do |option|
          Array(options[option]).flatten.tap do |paths|
            cmd_args << "-#{option}" << paths.flatten.map(&:to_s).join(File::PATH_SEPARATOR) unless paths.empty?
          end
        end
        cmd_args += sources.flatten.uniq
        unless Buildr.application.options.dryrun
          info "Generating Javadoc for #{name}"
          trace (['javadoc'] + cmd_args).join(' ')
          Java.load
          Java.com.sun.tools.javadoc.Main.execute(cmd_args.to_java(Java.java.lang.String)) == 0 or
            fail 'Failed to generate Javadocs, see errors above'
        end
      end

    end


    include Extension

    first_time do
      desc 'Create the Javadocs for this project'
      Project.local_task('javadoc')
    end

    before_define do |project|
      JavadocTask.define_task('javadoc').tap do |javadoc|
        javadoc.into project.path_to(:target, :javadoc)
        javadoc.using :windowtitle=>project.comment || project.name
      end
    end

    after_define do |project|
      project.javadoc.from project
    end

    # :call-seq:
    #   javadoc(*sources) => JavadocTask
    #
    # This method returns the project's Javadoc task. It also accepts a list of source files,
    # directories and projects to include when generating the Javadocs.
    #
    # By default the Javadoc task uses all the source directories from compile.sources and generates
    # Javadocs in the target/javadoc directory. This method accepts sources and adds them by calling
    # JavadocsTask#from.
    #
    # For example, if you want to generate Javadocs for a given project that includes all source files
    # in two of its sub-projects:
    #   javadoc projects('myapp:foo', 'myapp:bar').using(:windowtitle=>'Docs for foo and bar')
    def javadoc(*sources, &block)
      task('javadoc').from(*sources).enhance &block
    end

  end
end
