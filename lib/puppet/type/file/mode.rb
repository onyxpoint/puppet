# Manage file modes.  This state should support different formats
# for specification (e.g., u+rwx, or -0011), but for now only supports
# specifying the full mode.
module Puppet
    Puppet::Type.type(:file).newproperty(:mode) do
        require 'etc'
        desc "Mode the file should be.  You may specify either the precise octal mode or the POSIX symbolic mode per GNU coreutils chmod.

            Note that when you set the mode of a directory, Puppet always
            sets the search/traverse (1) bit anywhere the read (4) bit is set. 
            This is almost always what you want: read allows you to list the
            entries in a directory, and search/traverse allows you to access 
            (read/write/execute) those entries.)  Because of this feature, you 
            can recursively make a directory and all of the files in it 
            world-readable by setting e.g.::

                file { '/some/dir':
                  mode => 644,
                  recurse => true,
                }

            In this case all of the files underneath ``/some/dir`` will have 
            mode 644, and all of the directories will have mode 755."
        @event = :file_changed

        # The bitwise position of the UGO fields.
        SYMBASE = {
                    "u" => 6,
                    "g" => 3,
                    "o" => 0
                  }

        # The general mask for activating the appropriate sections of 'how'.
        SYMLEFT = {
                    "u" => 05700, 
                    "g" => 03070, 
                    "o" => 01007, 
                    "a" => 07777
                  }
       # The regular expression for matching a valid symbolic mode.
       SYMREG = /^(([ugoa]+)([+-=])([rwxst]+|[ugo]),?)+$/

        # This is a helper that takes the current mode and the new mode and
        # returns the adjusted decimal representation octal file mode (0700,
        # etc...)
        #
        # The current mode (curmode) can be represented either as an integer
        # string or as a File::Stat object.
        def sym2oct(curmode,newmode)
            if !curmode.nil? and curmode.to_s =~ /^\d+$/ then
                value = curmode 
            else
                # Set this to 0600 so that we can actually read and write the
                # file as a normal user.
                if curmode.nil? then
                    value = 00600
                elsif curmode.is_a?(File::Stat) then
                    value = curmode.mode & 07777
                else
                    value = Integer(curmode)
                end

                # This needs to remain variable.
                right = {
                        "r" => 00444, 
                        "w" => 00222, 
                        "x" => 00111, 
                        "s" => 06000, 
                        "t" => 01000, 
                        "u" => 00700, 
                        "g" => 00070, 
                        "o" => 00007 
                        }

                newmode.split(",").each do |cmd|
                    match = cmd.match(SYMREG) or return curmode
                    # The following vars are directly dependent on the
                    # structure of SYMREG above
                    who = match[2]
                    what = match[3]
                    how = match[4].split(//).uniq.to_s
                    if how =~ /^[ugo]$/ then
                      who.split(//).uniq.each do |lhv|
                        right[how] = ( ((value << (SYMBASE[lhv] - SYMBASE[how])) & right[lhv]) | ( value & ~right[lhv] ) ) & 0777
                      end
                    end
                    who = who.split(//).inject(num=0) {|num,b| num |= SYMLEFT[b]; num }
                    how = how.split(//).inject(num=0) {|num,b| num |= right[b]; num }
                    mask = who & how
                    case what
                        when "+": value = value | mask
                        when "-": value = value & ~mask
                        when "=": value = ( mask & who ) | ( value & ~(who & 0777) )
                    end
                end
            end
            Integer("0%o" % value)
        end


        # Our modes are octal, so make sure they print correctly.  Other
        # valid values are symbols, basically
        def is_to_s(currentvalue)
            if currentvalue.is_a?(Integer) then
                return "%o" % currentvalue
            elsif ( currentvalue.is_a?(Symbol) or ( currentvalue.is_a?(String) and currentvalue.match(SYMREG))) then
                return currentvalue
            else
                raise Puppet::DevError, "Invalid current value for mode: %s" %
                    currentvalue.inspect
            end
        end

        def should_to_s(newvalue = @should)
            if newvalue.is_a?(Integer) then
                return "%o" % newvalue 
            elsif ( newvalue.is_a?(Symbol) or ( newvalue.is_a?(String) and newvalue.match(SYMREG))) then
                return newvalue
            else
                raise Puppet::DevError, "Invalid 'should' value for mode: %s" %
                    newvalue.inspect
            end
        end

        munge do |should|
            # This handles both numbers and symbolic modes matching SYMREG
            #
            # Note: This now returns a string and the accepting function must
            # know how to handle it!

            value = should
            if value.is_a?(String)
                if value =~ /^\d+$/ then
                    unless value =~ /^0/
                        value = "0#{value}"
                    end

                    old = value
                    begin
                        value = Integer(value)
                    rescue ArgumentError => detail
                        raise Puppet::DevError, "Could not convert %s to integer" %
                            old.inspect
                    end
                elsif value.match(SYMREG).nil? then
                    raise Puppet::DevError, "Symbolic mode %s does not match #{SYMREG}" %
                        value.inspect
                end
            end
            return value
       end

        # If we're a directory, we need to be executable for all cases
        # that are readable.  This should probably be selectable, but eh.
        def dirmask(value)
            if FileTest.directory?(@resource[:path])
                if value & 0400 != 0
                    value |= 0100
                end
                if value & 040 != 0
                    value |= 010
                end
                if value & 04 != 0
                    value |= 01
                end
            end

            return value
        end

        def insync?(currentvalue)
            if stat = @resource.stat and stat.ftype == "link" and @resource[:links] != :follow
                self.debug "Not managing symlink mode"
                return true
            else
                retval = super(currentvalue)
                if !retval then
                    if currentvalue == sym2oct(resource.stat,self.should) then
                        retval = true
                    end
                end

                return retval
            end
        end

        def retrieve
            # If we're not following links and we're a link, then we just turn
            # off mode management entirely.

            if stat = @resource.stat(false)
                unless defined? @fixed
                    if defined? @should and @should
                        @should = @should.collect { |s| self.dirmask(s) }
                    end
                end
                return stat.mode & 007777
            else
                return :absent
            end
        end

        def sync
            mode = sym2oct(resource.stat,self.should)
            begin
                File.chmod(mode, @resource[:path])
            rescue => detail
                error = Puppet::Error.new("failed to chmod %s: %s" %
                    [@resource[:path], detail.message])
                error.set_backtrace detail.backtrace
                raise error
            end
            return :file_changed
        end
    end
end

