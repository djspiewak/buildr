require 'buildr/core/doc'

module Buildr
  module Doc

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
    class JavadocEngine < Base
      
      class << self
        def lang
          :java
        end
        
        def name
          :javadoc
        end
      end

      def source_files #:nodoc:
        @source_files ||= @files.map(&:to_s).
          map { |file| File.directory?(file) ? FileList[File.join(file, "**/*.java")] : file }.
          flatten.reject { |file| @files.exclude?(file) }
      end

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
  end
end

Buildr::Doc.engines << Buildr::Doc::JavadocEngine
