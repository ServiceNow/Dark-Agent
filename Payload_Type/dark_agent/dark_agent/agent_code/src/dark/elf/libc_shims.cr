module Dark::ELF::Callbacks
  extend self

  @@xstat_ptr = Pointer(Void).null

  # On glibc < 2.33, stat/lstat/fstat are not exported as binary symbols.
  # The source-level names are macros that redirect to __xstat/__lxstat/__fxstat
  # at compile time. BOFs referencing "stat" need this registered so
  # resolve_symbol finds it before falling through to dlsym (which returns nil).
  {% unless flag?(:darwin) %}
  def register_libc_shims
    if xstat_ptr = LibC.dlsym(nil, "__xstat")
      @@xstat_ptr = xstat_ptr
      # Must not capture any local var: a capturing proc is a closure
      # {code_ptr, closure_data_ptr}, and .pointer.address below only
      # keeps code_ptr - the JIT'd BOF then calls raw code expecting a
      # closure_data it never receives, deref'ing garbage/null. Reading
      # @@xstat_ptr (module state) instead keeps this proc non-capturing.
      callback = ->(path : UInt8*, buf : Void*) {
        fn = Proc(Int32, UInt8*, Void*, Int32).new(@@xstat_ptr, Pointer(Void).null)
        fn.call(1, path, buf)
      }
      register("stat", callback.pointer.address)
    end
  end
  {% end %}
end
