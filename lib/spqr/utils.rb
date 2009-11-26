# Utility functions and modules for SPQR
#
# Copyright (c) 2009 Red Hat, Inc.
#
# Author:  William Benton (willb@redhat.com)
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0

module SPQR
  class Sink
    def method_missing(*args)
      yield if block_given?
      nil
    end
  end

  module PrettyPrinter
    def writemode
      $PP_WRITEMODE ||= File::WRONLY|File::CREAT|File::TRUNC
    end

    def stack
      @fstack ||= [STDOUT]
    end

    def inc_indent
      @indent = indent + 2
    end

    def dec_indent
      @indent = indent - 2
    end

    def indent
      @indent ||= 0
    end

    def outfile
      @fstack[-1] or STDOUT
    end

    def pp(s)
      outfile.puts "#{' ' * indent}#{s}\n"
    end

    def pp_decl(kind, name, etc=nil)
      pp "#{kind} #{name}#{etc}"
      inc_indent
      yield if block_given?
      dec_indent
      pp "end"
    end

    def pp_call(callable, args)
      arg_repr = args.map {|arg| (arg.inspect if arg.kind_of? Hash) or arg}.join(', ')
      pp "#{callable}(#{arg_repr})"
    end

    def pp_invoke(receiver, method, args)
      pp_call "#{receiver}.#{method}", args
    end

    def with_output_to(filename, &action)
      File::open(filename, writemode) do |of|
        stack << of
        action.call      
        stack.pop
      end
    end
  end

  module MiscUtil
    def symbolize_dict(k, kz=nil)
      k2 = {}
      kz ||= k.keys

      k.keys.each do |key|
        k2[key.to_sym] = k[key] if (kz.include?(key) or kz.include?(key.to_sym))
      end

      k2
    end
  end
end
