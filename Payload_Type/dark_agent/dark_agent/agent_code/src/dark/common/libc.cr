lib LibC
  fun memcpy(dest : Pointer(Void), src : Pointer(Void), size : Int64) : Pointer(UInt8)
  fun memset(s : Void*, c : Int32, n : SizeT) : Void*


  # fun memfd_create(name : Pointer(UInt8), flags : Int32) : Int32
  # fun execveat(dirfd : Int32, pathname : Pointer(UInt8), argv : Pointer(Pointer(UInt8)), envp : Pointer(Pointer(UInt8)), flags : Int32) : Int32
  fun strerror(errnum : Int32) : Pointer(UInt8)
  @[ThreadLocal]
  $errno : Int32

  AT_EMPTY_PATH = 0x1000

  # Add brk system call
  fun brk(addr : Void*) : Int32

  {% if flag?(:darwin) %}
  # Apple Silicon W^X: switch JIT region between write-mode (0) and exec-mode (1)
  fun pthread_jit_write_protect_np(enable : Int32) : Void
  # Flush instruction cache lines (to Point of Unification)
  fun sys_icache_invalidate(start : Pointer(Void), size : SizeT) : Void
  # Flush data cache lines to Point of Coherency (main memory) before mprotect
  fun sys_dcache_flush(start : Pointer(Void), size : SizeT) : Void
  {% end %}
end