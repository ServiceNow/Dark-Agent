require "../common/libc"
require "../common/logger"

module Dark::ELF
  MAGIC = UInt8.slice(0x7f, 'E'.ord, 'L'.ord, 'F'.ord)
  PAGE_SIZE = 4096_u64
  PAGE_MASK = (PAGE_SIZE - 1)

  # Auxiliary vector types
  AT_NULL   = 0_u64  # End of vector
  AT_IGNORE = 1_u64  # Entry should be ignored
  AT_EXECFD = 2_u64  # File descriptor of program
  AT_PHDR   = 3_u64  # Program headers for program
  AT_PHENT  = 4_u64  # Size of program header entry
  AT_PHNUM  = 5_u64  # Number of program headers
  AT_PAGESZ = 6_u64  # System page size
  AT_BASE   = 7_u64  # Base address of interpreter
  AT_FLAGS  = 8_u64  # Flags
  AT_ENTRY  = 9_u64  # Entry point of program
  AT_NOTELF = 10_u64 # Program is not ELF
  AT_UID    = 11_u64 # Real uid
  AT_EUID   = 12_u64 # Effective uid
  AT_GID    = 13_u64 # Real gid
  AT_EGID   = 14_u64 # Effective gid
  AT_EXECFN = 31_u64 # Filename of program



  class Error < Exception; end

  # Base ELF definitions
  module Memory
    module Protection
      NONE  = 0x0
      READ  = 0x1
      WRITE = 0x2
      EXEC  = 0x4
    end

    module Map
      PRIVATE   = 0x2
      NORESERVE = 0x04
      FIXED     = 0x10
      # macOS uses MAP_ANON=0x1000; Linux uses MAP_ANONYMOUS=0x20
      {% if flag?(:darwin) %}
      ANONYMOUS = 0x1000
      # Apple Silicon requires MAP_JIT for W->X transitions in unsigned binaries
      JIT       = 0x0800
      {% else %}
      ANONYMOUS = 0x20
      JIT       = 0x0
      {% end %}
    end
  end

  enum Type : UInt16
    REL  = 1
    EXEC = 2
    DYN  = 3
    CORE = 4
  end

  enum Endianness
    Little = 1
    Big = 2
  end

  enum Machine : UInt16
    X86     = 0x03
    ARM     = 0x28
    X86_64  = 0x3E
    AARCH64 = 0xB7
  end

  enum Klass : UInt8
    ELF32 = 1
    ELF64 = 2
  end

  enum OSABI : UInt8
    SYSTEM_V = 0x00
    HP_UX    = 0x01
    NETBSD   = 0x02
    LINUX    = 0x03
    SOLARIS  = 0x06
    AIX      = 0x07
    IRIX     = 0x08
    FREEBSD  = 0x09
    OPENBSD  = 0x0C
    OPENVMS  = 0x0D
    NSK_OS   = 0x0E
    AROS     = 0x0F
    FENIS_OS = 0x10
    CLOUDABI = 0x11
    SORTIX   = 0x53
  end

  class SectionHeader
    enum Type : UInt32
      NULL          =  0
      PROGBITS      =  1
      SYMTAB        =  2
      STRTAB        =  3
      RELA          =  4
      HASH          =  5
      DYNAMIC       =  6
      NOTE          =  7
      NOBITS        =  8
      REL           =  9
      SHLIB         = 10
      DYNSYM        = 11
      INIT_ARRAY    = 14
      FINI_ARRAY    = 15
      PREINIT_ARRAY = 16
      GROUP         = 17
      SYMTAB_SHNDX  = 18
    end

    @[::Flags]
    enum Flags : UInt64
      WRITE            =        0x1
      ALLOC            =        0x2
      EXECINSTR        =        0x4
      MERGE            =       0x10
      STRINGS          =       0x20
      INFO_LINK        =       0x40
      LINK_ORDER       =       0x80
      OS_NONCONFORMING =      0x100
      GROUP            =      0x200
      TLS              =      0x400
      COMPRESSED       =      0x800
      MASKOS           = 0x0ff00000
      MASKPROC         = 0xf0000000
    end

    property! name_index : UInt32
    property name        : String?
    property! type       : Type
    property! flags      : Flags
    property! addr       : UInt32 | UInt64
    property! offset     : UInt32 | UInt64
    property! size       : UInt32 | UInt64
    property! link       : UInt32
    property! info       : UInt32
    property! addralign  : UInt32 | UInt64
    property! entsize    : UInt32 | UInt64
    property! mapping    : Pointer(Void)
  end

  struct Ident
    property klass : Klass
    property data : Endianness
    property version : UInt8
    property osabi : OSABI
    property abiversion : UInt8
    def initialize(@klass, @data, @version, @osabi, @abiversion)
    end
  end

  struct Symbol
    property! name_index : UInt32
    property! name : String
    property! info : UInt8
    property! other : UInt8
    property! shndx : UInt16
    property! value : UInt64
    property! size : UInt64
  end

  struct Relocation
    enum Type : UInt64
      R_X86_64_NONE            = 0x0
      R_X86_64_64              = 0x1
      R_X86_64_PC32            = 0x2
      R_X86_64_GOT32           = 0x3
      R_X86_64_PLT32           = 0x4
      R_X86_64_COPY            = 0x5
      R_X86_64_GLOB_DAT        = 0x6
      R_X86_64_JUMP_SLOT       = 0x7
      R_X86_64_RELATIVE        = 0x8
      R_X86_64_GOTPCREL        = 0x9
      R_X86_64_32              = 0x10
      R_X86_64_32S             = 0x11
      R_X86_64_16              = 0x12
      R_X86_64_PC16            = 0x13
      R_X86_64_8               = 0x14
      R_X86_64_PC8             = 0x15
      R_X86_64_DTPMOD64        = 0x16
      R_X86_64_DTPOFF64        = 0x17
      R_X86_64_TPOFF64         = 0x18
      R_X86_64_TLSGD           = 0x19
      R_X86_64_TLSLD           = 0x1a
      R_X86_64_DTPOFF32        = 0x1b
      R_X86_64_GOTTPOFF        = 0x1c
      R_X86_64_TPOFF32         = 0x1d
      R_X86_64_PC64            = 0x1e
      R_X86_64_GOTOFF64        = 0x1f
      R_X86_64_GOTPC32         = 0x20
      R_X86_64_GOT64           = 0x21
      R_X86_64_GOTPCREL64      = 0x22
      R_X86_64_GOTPC64         = 0x23
      R_X86_64_GOTPLT64        = 0x24
      R_X86_64_PLTOFF64        = 0x25
      R_X86_64_SIZE32          = 0x26
      R_X86_64_SIZE64          = 0x27
      R_X86_64_GOTPC32_TLSDESC = 0x28
      R_X86_64_TLSDESC_CALL    = 0x29
      R_X86_64_TLSDESC         = 0x2a
      R_X86_64_IRELATIVE       = 0x2b
      R_X86_64_RELATIVE64      = 0x2c
      R_X86_64_GOTPCRELX       = 0x2d
      R_X86_64_REX_GOTPCRELX   = 0x2e

      # AArch64 relocation types
      R_AARCH64_ABS64               = 257
      R_AARCH64_ABS32               = 258
      R_AARCH64_PREL64              = 260
      R_AARCH64_PREL32              = 261
      R_AARCH64_MOVW_UABS_G0_NC     = 264
      R_AARCH64_MOVW_UABS_G1_NC     = 266
      R_AARCH64_MOVW_UABS_G2_NC     = 268
      R_AARCH64_MOVW_UABS_G3        = 269
      R_AARCH64_ADR_PREL_PG_HI21    = 275
      R_AARCH64_ADD_ABS_LO12_NC     = 277
      R_AARCH64_LDST8_ABS_LO12_NC   = 278
      R_AARCH64_LDST16_ABS_LO12_NC  = 284
      R_AARCH64_LDST32_ABS_LO12_NC  = 285
      R_AARCH64_LDST64_ABS_LO12_NC  = 286
      R_AARCH64_JUMP26              = 282
      R_AARCH64_CALL26              = 283
      R_AARCH64_LDST128_ABS_LO12_NC = 299
      R_AARCH64_ADR_GOT_PAGE        = 311
      R_AARCH64_LD64_GOT_LO12_NC    = 312
      UNKNOWN                  = 0xFFFFFFFF_u64
    end

    property! offset : UInt64
    property! type : Type
    property! symidx : UInt64
    property! addend : Int32

    def set_type(value : UInt64)
      # Check for special cases where the relocation type might be misidentified
      if value == 0x2d # R_X86_64_GOTPCRELX
        @type = Type::R_X86_64_GOTPCRELX
      elsif value == 0x2e # R_X86_64_REX_GOTPCRELX
        @type = Type::R_X86_64_REX_GOTPCRELX
      else
        @type = Type.from_value?(value) || Type::UNKNOWN
      end
    end
  end

  # Base class for ELF parsing
  abstract class Base
    getter! ident : Ident
    property! type : Type
    property! machine : Machine
    property! version : UInt32
    property! entry : UInt32 | UInt64
    property! phoff : UInt32 | UInt64
    property! shoff : UInt32 | UInt64
    property! flags : UInt32
    property! ehsize : UInt16
    property! phentsize : UInt16
    property! phnum : UInt16
    property! shentsize : UInt16
    property! shnum : UInt16
    property! shstrndx : UInt16

    SECTION_SPACING = 0x5000_u64
    THUNK_SIZE = 16_u64

    @sections : Array(SectionHeader)?
    @relocations = Array(Relocation).new
    @symbols = Array(Symbol).new
    @base_addr : UInt64 = 0
    @section_mappings : Array(Pointer(Void)) = [] of Pointer(Void)
    @section_prots : Array(Int32) = [] of Int32
    @thunk_base : UInt64 = 0
    @thunk_table_entries = 255_u64  # This is intended to be overwritten based on requirements
    @thunk_offset = 0

    # GOT entries: symbol name → address of 8-byte mmap'd slot holding the symbol's VA
    @got_entries = {} of String => UInt64

    # for dyn linking
    @plt_rela : UInt64 = 0
    @rela : UInt64 = 0
    @rela_size : UInt64 = 0

    def initialize(@io : IO::Memory)
      read_elf_headers
      check_elf_compatibility
    end

    private def read_magic
      @io.read(magic = Bytes.new(4))
      raise Error.new("Invalid magic number") unless magic == MAGIC
    end

    private def read_ident
      ei_class = Klass.new(@io.read_byte.not_nil!)
      ei_data = Endianness.from_value(@io.read_byte.not_nil!)
      ei_version = @io.read_byte.not_nil!
      raise Error.new("Unsupported version number") unless ei_version == 1

      ei_osabi = OSABI.from_value(@io.read_byte.not_nil!)
      ei_abiversion = @io.read_byte.not_nil!
      @io.skip(7)
      @ident = Ident.new(ei_class, ei_data, ei_version, ei_osabi, ei_abiversion)
    end

    private def read_header
      @type      = Type.new(@io.read_bytes(UInt16, endianness))
      @machine   = Machine.new(@io.read_bytes(UInt16, endianness))
      @version   = @io.read_bytes(UInt32, endianness)
      @entry     = read_ulong
      @phoff     = read_ulong
      @shoff     = read_ulong
      @flags     = @io.read_bytes(UInt32, endianness)
      @ehsize    = @io.read_bytes(UInt16, endianness)
      @phentsize = @io.read_bytes(UInt16, endianness)
      @phnum     = @io.read_bytes(UInt16, endianness)
      @shentsize = @io.read_bytes(UInt16, endianness)
      @shnum     = @io.read_bytes(UInt16, endianness)
      @shstrndx  = @io.read_bytes(UInt16, endianness)
    end

    private def check_elf_compatibility
      case machine
      when Machine::X86_64
        raise Error.new("Incompatible ELF class") unless ident.klass == Klass::ELF64
      when Machine::X86
        raise Error.new("Incompatible ELF class") unless ident.klass == Klass::ELF32
      when Machine::AARCH64
        raise Error.new("Incompatible ELF class") unless ident.klass == Klass::ELF64
      else
        raise Error.new("Unsupported architecture")
      end
    end

    private def read_elf_headers
      read_magic
      read_ident
      read_header
      read_section_headers
    end

    # Utility methods
    protected def endianness
      ident.data == Endianness::Little ? IO::ByteFormat::LittleEndian : IO::ByteFormat::BigEndian
    end

    protected def read_word
      @io.read_bytes(UInt32, endianness)
    end

    protected def read_ulong
      case ident.klass
      when Klass::ELF32 then @io.read_bytes(UInt32, endianness)
      when Klass::ELF64 then @io.read_bytes(UInt64, endianness)
      else raise Error.new("Unsupported ELF class")
      end
    end

    protected def unsafe_put_u64(ptr : Pointer(Void), value : UInt64)
      ptr.as(UInt64*).value = value
    end

    protected def unsafe_put_u32(ptr : Pointer(Void), value : UInt32)
      ptr.as(UInt32*).value = value
    end

    def get_symbol_name(string_table : SectionHeader, index : UInt32) : String
      @io.seek(string_table.offset + index, IO::Seek::Set)
      String.build do |str|
        while (ch = @io.read_byte) != 0 && !ch.nil?
          str << ch.chr
        end
      end
    end

    # Section names are stored in shstrndx so we have to offset that and search for the sections name
    def get_section_name(header : SectionHeader) : String
      # The `header.name_index` is an index into the `.shstrtab` section
      shstrtab = section_headers[shstrndx] # The `.shstrtab` section should be at `shstrndx`

      # The name is stored as a C string in the `.shstrtab` at the index `header.name`
      @io.seek(shstrtab.offset + header.name_index, IO::Seek::Set)
      String.build do |str|
        while (ch = @io.read_byte) != 0 && !ch.nil?
          str << ch.chr
        end
      end
    end

    # Calculate protos for
    protected def calc_protections(flags : SectionHeader::Flags | UInt32) : Int32
      prot = Memory::Protection::NONE
      case flags
      when SectionHeader::Flags
        prot |= Memory::Protection::READ
        prot |= Memory::Protection::WRITE if flags.write?
        prot |= Memory::Protection::EXEC if flags.execinstr?
      when UInt32
        prot |= Memory::Protection::READ if flags & 0x4 != 0
        prot |= Memory::Protection::WRITE if flags & 0x2 != 0
        prot |= Memory::Protection::EXEC if flags & 0x1 != 0
      end
      prot
    end

    private def parse_symbols(section : SectionHeader)
      return unless section.type.in?({SectionHeader::Type::SYMTAB, SectionHeader::Type::DYNSYM})

      string_table = section_headers[section.link]
      log_debug "Parsing symbols from section at offset 0x#{section.offset.to_s(16)}, size 0x#{section.size.to_s(16)}"
      log_debug "String table linked at section #{section.link}"

      entry_size = ident.klass == Klass::ELF64 ? 24 : 16
      num_entries = section.size // entry_size

      num_entries.times do |i|
        current_offset = section.offset + (i*entry_size)
        @io.seek(current_offset, IO::Seek::Set)

        sym = Symbol.new
        sym.name_index = @io.read_bytes(UInt32, endianness)
        sym.info = @io.read_bytes(UInt8, endianness)
        sym.other = @io.read_bytes(UInt8, endianness)
        sym.shndx = @io.read_bytes(UInt16, endianness)
        sym.value = @io.read_bytes(UInt64, endianness)
        sym.size = @io.read_bytes(UInt64, endianness)

        # Handle symbol name based on symbol type and section index
        sym.name = case sym.shndx
        when 0x0000 # SHN_UNDEF
          sym.name_index == 0 ? "" : get_symbol_name(string_table, sym.name_index)
        when 0xfff1 # SHN_ABS
          # For STT_FILE symbols (info=4), empty name is normal
          if sym.info == 4 && sym.name_index == 0
            ""
          else
            get_symbol_name(string_table, sym.name_index)
          end
        when 0xfff2 # SHN_COMMON
          get_symbol_name(string_table, sym.name_index)
        when 0xff00..0xffff # Other special indices
          sym.name_index == 0 ? "" : get_symbol_name(string_table, sym.name_index)
        else
          if sym.name_index == 0
            if sym.shndx < section_headers.size
              get_section_name(section_headers[sym.shndx])
            else
              log_debug "Warning: Invalid section index #{sym.shndx} for symbol at offset 0x#{current_offset.to_s(16)}"
              ""
            end
          else
            get_symbol_name(string_table, sym.name_index)
          end
        end

        @symbols << sym
      end

    end

    private def parse_relocations(section : SectionHeader)
      return unless section.type.in?({SectionHeader::Type::REL, SectionHeader::Type::RELA})

      log_debug "Parsing relocations for #{section.name}"

      @io.seek(section.offset, IO::Seek::Set)
      entry_size = 24
      num_entries = section.size // entry_size

      # Check that we have symbols before trying to process relocations
      if @symbols.empty?
        log_debug "No symbols found for relocations in #{section.name}, skipping"
        return
      end

      num_entries.times do |i|
        rel = Relocation.new
        rel.offset = @io.read_bytes(UInt64, endianness)
        info = @io.read_bytes(UInt64, endianness)
        rel.type = rel.set_type(info & 0xffffffff_u64)
        rel.symidx = info >> 32
        rel.addend = @io.read_bytes(Int64, endianness).to_i32

        # Validate symbol index
        if rel.symidx >= @symbols.size
          log_debug "Skipping relocation at offset 0x#{@io.pos.to_s(16)}: Invalid symbol index #{rel.symidx} (max: #{@symbols.size - 1})"
          next
        end

        symbol = @symbols[rel.symidx]
        log_debug "Relocation[#{i}] Offset: 0x#{rel.offset.to_s(16)}, Type: #{rel.type}, Symbol index: #{rel.symidx}, Symbol: #{symbol.name}, Addend: #{rel.addend}"

        # For .rela.eh_frame, we only process specific relocations
        if section.name == ".rela.eh_frame"
          if rel.type != Relocation::Type::R_X86_64_PC32
            log_debug "Skipping non-PC32 relocation in .rela.eh_frame section"
            next
          end
        end

        # Skip relocations for weak symbols (binding type 2)
        binding = (symbol.info >> 4) & 0xf
        if binding == 2
          log_debug "Skipping relocation for weak symbol: #{symbol.name}"
          next
        end

        @relocations << rel
      end
    end



    # Returns all section headers in the ELF file
    def section_headers
      @sections ||= Array(SectionHeader).new(shnum.to_i) do |i|
        @io.seek(shoff + i * shentsize)

        sh = SectionHeader.new
        sh.name_index = read_word
        sh.type = SectionHeader::Type.new(read_word)
        sh.flags = SectionHeader::Flags.new(read_ulong.to_u64)
        sh.addr = read_ulong
        sh.offset = read_ulong
        sh.size = read_ulong
        sh.link = read_word
        sh.info = read_word
        sh.addralign = read_ulong
        sh.entsize = read_ulong

        sh
      end
    end


    private def read_section_headers
      return if shnum == 0 || shoff == 0

      # First pass - get all section names
      section_headers.each do |section|
        section.name = get_section_name(section)
        log_debug "Found Section: name=#{section.name}"
      end

      # Second pass - now that sections have names, process them in order:
      # 1. Symbol tables first so we have symbols for relocations
      # 2. Relocation tables next so we can resolve them

      # Process symbol tables first
      symtab_section = section_headers.find { |s| s.name == ".symtab" }
      if symtab_section
        log_debug "Found .symtab at index #{section_headers.index(symtab_section)}, processing symbols"
        parse_symbols(symtab_section)
      else
        section_headers.each do |section|
          if section.type.symtab? || section.type.dynsym?
            log_debug "Processing symbol table: #{section.name}"
            parse_symbols(section)
          end
        end
      end

      # Now process relocations
      rela_text = section_headers.find { |s| s.name == ".rela.text" }
      if rela_text
        log_debug "Found .rela.text at index #{section_headers.index(rela_text)}, processing relocations"
        parse_relocations(rela_text)
      else
        section_headers.each do |section|
          if section.type.rela? || section.type.rel?
            log_debug "Processing relocation section: #{section.name}"
            parse_relocations(section)
          end
        end
      end

      # Summarize
      log_debug "Found #{@symbols.size} symbols"
      log_debug "Found #{@relocations.size} relocations"

      # @symbols.each do |sym|
      #   log_debug "Found Symbol: name_idx=0x#{sym.name_index.to_s(16)} name=#{sym.name} info=0x#{sym.info.to_s(16)} other=0x#{sym.other.to_s(16)} shndx=0x#{sym.shndx.to_s(16)} value=0x#{sym.value.to_s(16)} size=0x#{sym.size.to_s(16)} named=#{sym.name}"
      # end
    end

    # Returns the address of a 1-page mmap slot holding target_addr.
    # Re-uses the same slot for the same symbol name (idempotent).
    protected def get_or_create_got_entry(symbol : Symbol, target_addr : UInt64) : UInt64
      if existing = @got_entries[symbol.name]?
        return existing
      end
      entry = LibC.mmap(nil, 8,
        Memory::Protection::READ | Memory::Protection::WRITE,
        Memory::Map::PRIVATE | Memory::Map::ANONYMOUS, -1, 0)
      raise Error.new("GOT alloc failed for #{symbol.name}") if entry.null?
      entry.as(UInt64*).value = target_addr
      log_debug "GOT entry for #{symbol.name}: addr=0x#{entry.address.to_s(16)} target=0x#{target_addr.to_s(16)}"
      @got_entries[symbol.name] = entry.address.to_u64
      entry.address.to_u64
    end

    private def create_trampoline(target_addr : UInt64) : UInt64
      return 0_u64 if @thunk_offset >= @thunk_table_entries
      tramp_addr = @thunk_base + (@thunk_offset * THUNK_SIZE)
      trampoline = Pointer(UInt8).new(tramp_addr)

      if machine == Machine::AARCH64
        # arm64: ldr x16, #8 (load address from 8 bytes ahead) + br x16 + 8-byte address
        trampoline.as(UInt32*).value = 0x58000050_u32  # ldr x16, +8
        (trampoline + 4).as(UInt32*).value = 0xD61F0200_u32  # br x16
        (trampoline + 8).as(UInt64*).value = target_addr
        readback = Pointer(UInt64).new(tramp_addr + 8).value
        log_debug "Trampoline write: addr=0x#{tramp_addr.to_s(16)} target=0x#{target_addr.to_s(16)} readback=0x#{readback.to_s(16)} match=#{readback == target_addr}"
      else
        # x86_64: movq rax, imm64 + jmpq *rax
        trampoline[0] = 0x48_u8  # REX.W prefix
        trampoline[1] = 0xb8_u8  # MOV rax, imm64
        (trampoline + 2).as(UInt64*).value = target_addr
        trampoline[10] = 0xff_u8 # JMP rax
        trampoline[11] = 0xe0_u8
      end

      @thunk_offset += 1
      tramp_addr
    end





    # Abstract methods that must be implemented by subclasses
    # Gets the memory-mapped address for a symbol or relocation
    abstract def get_mapping_addr(item : Symbol | Relocation) : UInt64
    # Cleans up allocated memory resources
    abstract def cleanup
  end
end