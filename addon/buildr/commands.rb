# Monkey-patches Object to define method_missing such
# that any unhandled methods are attempted as system
# commands before erroring.  This allows code like the
# following:
#
#    require 'commands'
#    
#    path = '/etc'
#    ls '-l', path    # prints files in /etc
#
# Commands executed in this way are handled by the
# system method.  The "which" command (on *nix) is
# run first to determine if the command is available.
# If not, then the method is passed on to the regular
# Object method_missing implementation.

class Object
  def method_missing(sym, *args)
    cmd = sym.to_s
    if cmd.downcase != 'cd' and command_available? cmd
      sys_args = if args.size > 0 then "'" + args.join("' '") + "'" else '' end

      system "#{cmd} #{sys_args}"
    else
      super
    end
  end
end

# TODO    make work on Windows
def command_available?(cmd)
  system "which #{cmd} &> /dev/null"
end
