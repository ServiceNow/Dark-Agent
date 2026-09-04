require "./base"
require "./callbacks"

module Dark::ELF
  class ObjectFile < Base
    @thunk_table_entries = 255_u64
    @region_size : UInt64 = 0_u64

    def self.run(data : Bytes, args : Array(String))
      new(IO::Memory.new(data), args)
    end

    def initialize(@io : IO::Memory, @args : Array(String))
      super(@io)
      setup_memory_mappings
      perform_relocations
      finalize_memory_protections
      execute_entry
    ensure
      cleanup
    end


    private def get_mapping_addr(item : Symbol | Relocation) : UInt64
      case item
      when Symbol
        section = section_headers[item.shndx]
        mapping = @section_mappings[item.shndx]
        raise "Section not mapped" if mapping.nil?
        mapping.address.to_u64 + item.value
      when Relocation
        # For relocations, we need to find which section contains the offset
        # Use the relocation section's info field to get the target section
        rela_sections = section_headers.select { |s| s.type.in?({SectionHeader::Type::REL, SectionHeader::Type::RELA}) }
        target_section = nil
        target_index = nil

        rela_sections.each do |rela_section|
          # The 'info' field points to the section this relocation applies to
          section_idx = rela_section.info
          section = section_headers[section_idx]

          # Check if this relocation's offset is within the relocation entries of this section
          offset_start = rela_section.offset
          offset_end = offset_start + rela_section.size

          if (offset_start..offset_end).includes?(item.offset)
            # We've found the relocation section containing this relocation
            # Now we need the target section where the relocation will be applied
            target_section = section
            target_index = section_idx
            break
          end
        end

        if target_section.nil? || target_index.nil?
          log_debug "No target section for relocation offset 0x#{item.offset.to_s(16)}"
          return 0_u64
        end

        mapping = @section_mappings[target_index]
        if mapping.null?
          log_debug "Null mapping for relocation at offset 0x#{item.offset.to_s(16)}"
          return 0_u64
        end

        # Relocations have offsets relative to their target section
        final_addr = mapping.address + item.offset

        log_debug "Relocation address: offset=0x#{item.offset.to_s(16)}, section=#{target_section.name}, base=0x#{mapping.address.to_s(16)}, addr=0x#{final_addr.to_s(16)}"
        final_addr
      else
        raise "getaddr: Invalid item type"
      end
    end

    private def setup_memory_mappings
      # Calculate total memory for all sections + thunk table.
      # Allocating one contiguous region guarantees CALL26 range (±128MB).
      thunk_size = ((@thunk_table_entries * THUNK_SIZE) + 4095_u64) & ~4095_u64
      total_sections_size = section_headers.sum do |s|
        (s.size > 0 && s.type == SectionHeader::Type::PROGBITS) ? ((s.size.to_u64 + 4095_u64) & ~4095_u64) + SECTION_SPACING : 0_u64
      end
      total_size = thunk_size + total_sections_size + SECTION_SPACING

      # On Apple Silicon (arm64 macOS), MAP_JIT is required to later mprotect
      # a region from W to X without triggering W^X SIGBUS.
      region = LibC.mmap(nil, total_size,
        Memory::Protection::READ | Memory::Protection::WRITE | Memory::Protection::EXEC,
        Memory::Map::PRIVATE | Memory::Map::ANONYMOUS | Memory::Map::JIT, -1, 0)
      raise Error.new("Failed to allocate BOF memory region") if region.null?

      @thunk_base = region.address.to_u64
      @region_size = total_size
      offset = thunk_size + SECTION_SPACING

      @section_mappings = Array(Pointer(Void)).new(section_headers.size) { Pointer(Void).null }
      @section_prots = Array(Int32).new(section_headers.size, 0)

      # On Apple Silicon, new threads start with JIT write protection ENABLED (exec mode).
      # Must explicitly switch to write mode before any writes to the JIT region.
      {% if flag?(:darwin) %}
      LibC.pthread_jit_write_protect_np(0)
      {% end %}

      section_headers.reverse.each_with_index do |section, i|
        real_i = section_headers.size - 1 - i

        if section.size > 0 && section.type == SectionHeader::Type::PROGBITS
          mapping = Pointer(Void).new(region.address + offset)
          offset += ((section.size.to_u64 + 4095_u64) & ~4095_u64) + SECTION_SPACING

          @io.seek(section.offset)
          slice = Slice(UInt8).new(mapping.as(UInt8*), section.size)
          @io.read_fully(slice)

          @section_mappings[real_i] = mapping
          @section_prots[real_i] = calc_protections(section.flags)
          log_debug "Mapping section #{section.name} (size: 0x#{section.size.to_s(16)}) at 0x#{mapping.address.to_s(16)} page-aligned"
        end
      end
    end


    def execute_entry
      # Find the entry symbol (coffee function)
      entry_sym = @symbols.find { |sym| sym.name == "coffee" }
      raise Error.new("No entry symbol found. Expected coffee()") if entry_sym.nil?

      section = section_headers[entry_sym.shndx]
      mapping = @section_mappings[entry_sym.shndx]
      entry_addr = get_mapping_addr(entry_sym)

      log_debug "Executing entry point: symbol=#{entry_sym.name}, section=#{section.name}, base=0x#{mapping.address.to_s(16)}, addr=0x#{entry_addr.to_s(16)}"

    # Add memory validation in debug mode
    {% if flag?(:debug) %}
      if mapping
        # Dump first few bytes of the mapped memory
        bytes = Slice.new(mapping.as(UInt8*), [16_u64, section.size].min)
        entry_bytes = Slice.new(Pointer(UInt8).new(entry_addr), [16_u64, section.size].min)
        log_debug "Validating Entry Point: mapping=0x#{mapping.address.to_s(16)}, mapping_bytes=#{bytes.map { |b| b.to_s(16).rjust(2,'0') }.join(" ")}, entry_bytes=#{entry_bytes.map { |b| b.to_s(16).rjust(2,'0') }.join(" ")}"
      end
    {% end %}

      log_debug "\n--------------------------\nExecuting Object File\n--------------------------\n"

      # Process args
      args = @args.map(&.to_unsafe)
      args << Pointer(UInt8).null

      Proc(Int32, UInt8**, Void).new(
        Pointer(Void).new(entry_addr),
        Pointer(Void).null,
      ).call(args.size, args.to_unsafe)

      log_debug "Success!"
    end

    def cleanup
      if @thunk_base != 0 && @region_size > 0
        LibC.munmap(Pointer(Void).new(@thunk_base), @region_size)
      end
      @got_entries.each_value do |addr|
        LibC.munmap(Pointer(Void).new(addr), 8)
      end
    end


    private def perform_relocations
      # First find the relocation section - we need this for several relocation types
      rela_text = section_headers.find { |sect| sect.type == SectionHeader::Type::RELA && sect.name == ".rela.text" }

      if rela_text.nil?
        log_debug "Warning: No .rela.text section found"
      else
        # Get the target section for .rela.text
        text_section = section_headers[rela_text.info]
        text_mapping = @section_mappings[rela_text.info]

        if text_mapping.nil?
          log_debug "Warning: .text section not mapped"
        end
      end

      # Log basic section information without relying on .rodata
      section_headers.each do |section|
        if section.size > 0 && section.type == SectionHeader::Type::PROGBITS
          log_debug "Found section #{section.name} at offset 0x#{section.offset.to_s(16)}, size 0x#{section.size.to_s(16)}"
        end
      end

      # Now process each relocation
      @relocations.each do |rel|
        symbol = @symbols[rel.symidx]

        # For relocations, we need to know which section this relocation applies to
        # For typical relocations in .rela.text, they apply to the .text section
        target_section_idx = rela_text ? rela_text.info : nil
        target_section = target_section_idx ? section_headers[target_section_idx] : nil
        target_mapping = target_section_idx ? @section_mappings[target_section_idx] : nil

        if target_section.nil? || target_mapping.nil?
          log_debug "Warning: Can't determine target section/mapping for relocation"
          next
        end

        # Calculate the actual address in memory where the relocation should be applied
        target_addr = target_mapping.address + rel.offset

        # Resolve symbol address
        symbol_addr = if symbol.shndx == 0
          # External symbol - resolve via callbacks or system libraries
          resolve_symbol(symbol)
        else
          # Internal symbol - get its mapped address
          begin
            get_mapping_addr(symbol)
          rescue ex
            # If internal symbol resolution fails, try external resolution
            log_debug "Internal symbol resolution failed for #{symbol.name}: #{ex.message}, trying external resolution"
            resolve_symbol(symbol)
          end
        end

        log_debug "Perform Relocation: symbol=#{symbol.name}, target=0x#{target_addr.to_s(16)}, symbol_addr=0x#{symbol_addr.to_s(16)}, type=#{rel.type}"

        case rel.type
        when Relocation::Type::R_AARCH64_ABS64
          unsafe_put_u64(Pointer(Void).new(target_addr), symbol_addr + rel.addend.to_u64)

        when Relocation::Type::R_AARCH64_CALL26, Relocation::Type::R_AARCH64_JUMP26
          tramp_addr = create_trampoline(symbol_addr)
          offset_bytes = tramp_addr.to_i64 - target_addr.to_i64 + rel.addend.to_i64
          offset_instrs = (offset_bytes >> 2).to_i32
          existing = Pointer(UInt32).new(target_addr).value
          patched = (existing & 0xFC000000_u32) | (offset_instrs.to_u32! & 0x03FFFFFF_u32)
          Pointer(UInt32).new(target_addr).value = patched
          log_debug "AARCH64_CALL26: tramp=0x#{tramp_addr.to_s(16)}, offset=#{offset_instrs} instrs"

        when Relocation::Type::R_AARCH64_ADR_GOT_PAGE
          got_addr = get_or_create_got_entry(symbol, symbol_addr)
          page_offset = (got_addr.to_i64 & ~0xFFF_i64) - (target_addr.to_i64 & ~0xFFF_i64)
          imm21 = (page_offset >> 12).to_i32
          existing = Pointer(UInt32).new(target_addr).value
          lo2 = (imm21 & 0x3).to_u32!
          hi19 = ((imm21 >> 2) & 0x7FFFF).to_u32!
          patched = (existing & 0x9F00001F_u32) | (lo2 << 29) | (hi19 << 5)
          Pointer(UInt32).new(target_addr).value = patched
          log_debug "ADR_GOT_PAGE: got=0x#{got_addr.to_s(16)} page_off=#{page_offset}"

        when Relocation::Type::R_AARCH64_LD64_GOT_LO12_NC
          got_addr = get_or_create_got_entry(symbol, symbol_addr)
          lo12 = (got_addr & 0xFFF_u64).to_u32
          scaled = lo12 >> 3  # 64-bit load: scale by 8
          existing = Pointer(UInt32).new(target_addr).value
          patched = (existing & 0xFFC003FF_u32) | (scaled << 10)
          Pointer(UInt32).new(target_addr).value = patched
          log_debug "LD64_GOT_LO12_NC: got=0x#{got_addr.to_s(16)} lo12=0x#{lo12.to_s(16)}"

        when Relocation::Type::R_AARCH64_ADR_PREL_PG_HI21
          page_offset = ((symbol_addr.to_i64 + rel.addend.to_i64) & ~0xFFF_i64) - (target_addr.to_i64 & ~0xFFF_i64)
          imm21 = (page_offset >> 12).to_i32
          existing = Pointer(UInt32).new(target_addr).value
          lo2 = (imm21 & 0x3).to_u32!
          hi19 = ((imm21 >> 2) & 0x7FFFF).to_u32!
          patched = (existing & 0x9F00001F_u32) | (lo2 << 29) | (hi19 << 5)
          Pointer(UInt32).new(target_addr).value = patched
          log_debug "AARCH64_ADR_PREL_PG_HI21: page_offset=0x#{page_offset.to_s(16)}"

        when Relocation::Type::R_AARCH64_ADD_ABS_LO12_NC
          lo12 = ((symbol_addr.to_i64 + rel.addend.to_i64) & 0xFFF_i64).to_u32
          existing = Pointer(UInt32).new(target_addr).value
          patched = (existing & 0xFFC003FF_u32) | (lo12 << 10)
          Pointer(UInt32).new(target_addr).value = patched
          log_debug "AARCH64_ADD_ABS_LO12_NC: lo12=0x#{lo12.to_s(16)}"

        when Relocation::Type::R_AARCH64_LDST8_ABS_LO12_NC,
             Relocation::Type::R_AARCH64_LDST16_ABS_LO12_NC,
             Relocation::Type::R_AARCH64_LDST32_ABS_LO12_NC,
             Relocation::Type::R_AARCH64_LDST64_ABS_LO12_NC,
             Relocation::Type::R_AARCH64_LDST128_ABS_LO12_NC
          scale = case rel.type
            when Relocation::Type::R_AARCH64_LDST8_ABS_LO12_NC   then 0
            when Relocation::Type::R_AARCH64_LDST16_ABS_LO12_NC  then 1
            when Relocation::Type::R_AARCH64_LDST32_ABS_LO12_NC  then 2
            when Relocation::Type::R_AARCH64_LDST64_ABS_LO12_NC  then 3
            else 4
          end
          lo12 = ((symbol_addr.to_i64 + rel.addend.to_i64) & 0xFFF_i64).to_u32
          scaled = (lo12 >> scale)
          existing = Pointer(UInt32).new(target_addr).value
          patched = (existing & 0xFFC003FF_u32) | (scaled << 10)
          Pointer(UInt32).new(target_addr).value = patched
          log_debug "AARCH64_LDST_ABS_LO12_NC(scale=#{scale}): lo12=0x#{lo12.to_s(16)}"

        when Relocation::Type::R_X86_64_PLT32
          tramp_addr = create_trampoline(symbol_addr)
          base_diff = (tramp_addr.to_i64 - target_addr.to_i64)
          masked = (base_diff + rel.addend) & 0xFFFFFFFF_u64
          log_debug "PLT32 calculation: tramp=0x#{tramp_addr.to_s(16)}, section=#{target_section.name}, target=0x#{target_addr.to_s(16)}, offset=0x#{tramp_addr.to_s(16)}-0x#{target_addr.to_s(16)}+#{rel.addend}=0x#{masked.to_s(16)}"
          unsafe_put_u32(Pointer(Void).new(target_addr), masked.to_u32)

        when Relocation::Type::R_X86_64_PC32
          offset = (symbol_addr.to_i64 - target_addr.to_i64 + rel.addend.to_i64)
          relative = (offset & 0xFFFFFFFF_i64).to_i32!
          log_debug "PC32 calculation: section=#{target_section.name}, target=0x#{target_addr.to_s(16)}, symbol=0x#{symbol_addr.to_s(16)}, pc=0x#{(target_addr).to_s(16)}, addend=#{rel.addend}, calc=0x#{symbol_addr.to_s(16)}-0x#{(target_addr).to_s(16)}+#{rel.addend}, relative=0x#{relative.to_s(16)}"
          unsafe_put_u32(Pointer(Void).new(target_addr), relative.to_u32!)

        when Relocation::Type::R_X86_64_64
          unsafe_put_u64(Pointer(Void).new(target_addr), symbol_addr + rel.addend)

        when Relocation::Type::R_X86_64_REX_GOTPCRELX, Relocation::Type::R_X86_64_GOTPCRELX
          got_entry_addr = LibC.mmap(nil, 8, Memory::Protection::READ | Memory::Protection::WRITE,
                              Memory::Map::PRIVATE | Memory::Map::ANONYMOUS, -1, 0)
          if got_entry_addr.null?
            log_debug "Failed to allocate GOT entry for #{symbol.name}"
            next
          end
          unsafe_put_u64(got_entry_addr, symbol_addr)
          relative = (got_entry_addr.address.to_i64 - target_addr.to_i64 + rel.addend).to_i32
          unsafe_put_u32(Pointer(Void).new(target_addr), relative.to_u32!)
          log_debug "GOTPCRELX: symbol=#{symbol.name}, GOT entry at 0x#{got_entry_addr.address.to_s(16)}, points to 0x#{symbol_addr.to_s(16)}"

        when Relocation::Type::R_X86_64_TLSDESC
          descriptor_addr = LibC.mmap(nil, 16, Memory::Protection::READ | Memory::Protection::WRITE,
                                  Memory::Map::PRIVATE | Memory::Map::ANONYMOUS, -1, 0)
          if descriptor_addr.null?
            log_debug "Failed to allocate TLS descriptor for #{symbol.name}"
            next
          end
          unsafe_put_u64(descriptor_addr, symbol_addr)
          unsafe_put_u64(descriptor_addr + 8, 0_u64)
          relative = (descriptor_addr.address.to_i64 - target_addr.to_i64 + rel.addend).to_i32
          unsafe_put_u32(Pointer(Void).new(target_addr), relative.to_u32!)
          log_debug "TLSDESC: symbol=#{symbol.name}, descriptor at 0x#{descriptor_addr.address.to_s(16)}, points to 0x#{symbol_addr.to_s(16)}"

        else
          log_debug "  Unsupported relocation type: #{rel.type}"
        end
      end
    end

    private def resolve_symbol(symbol : Symbol) : UInt64
      # Check for beacon callback symbol
      if callback_addr = Callbacks.lookup(symbol.name)
        log_debug "External symbol \033[31m#{symbol.name}\033[0m found in \033[31mbeacon callbacks\033[0m at \033[31m0x#{callback_addr.to_s(16)}\033[0m"
        return callback_addr
      end

      # macOS SDK headers use __asm("_name") to embed a single leading underscore
      # into ELF symbol references (e.g. _stat, _popen). dlsym expects the name
      # WITHOUT that prefix. Only strip when it's a single leading '_' — symbols
      # like __stack_chk_guard start with double underscore and must be left intact.
      lookup_name = (symbol.name.starts_with?("_") && symbol.name.size > 1 && symbol.name[1] != '_') \
        ? symbol.name[1..] : symbol.name

      # Try current process first (Crystal runtime and statically linked libs)
      if addr = LibC.dlsym(nil, lookup_name)
        log_debug "External symbol \033[32m#{symbol.name}\033[0m found in \033[32mruntime\033[0m at \033[32m0x#{addr.address.to_s(16)}\033[0m"
        return addr.address.to_u64
      end

      # Fall back to all loaded libraries
      rtld_default = Pointer(Void).new(-2)  # RTLD_DEFAULT
      if addr = LibC.dlsym(rtld_default, lookup_name)
        log_debug "External symbol \033[33m#{symbol.name}\033[0m found in \033[33msystem libraries\033[0m at \033[33m0x#{addr.address.to_s(16)}\033[0m"
        return addr.address.to_u64
      end

      raise Error.new("Could not find symbol #{symbol.name} in any library")

      section = section_headers[symbol.shndx]
      section_addr = @base_addr + section.offset
      resolved_addr = section_addr + symbol.value
      resolved_addr
    end

    private def finalize_memory_protections
      {% if flag?(:darwin) %}
      # Apple Silicon MAP_JIT two-step cache flush:
      # 1. sys_dcache_flush (dc civac): writes data cache to PoC (main memory) for the
      #    write VMA so the read/exec VMA sees correct bytes on its next d-cache miss.
      # 2. sys_icache_invalidate (ic ivau): invalidates i-cache so code fetches
      #    go to main memory instead of seeing stale instruction cache lines.
      # 3. pthread_jit_write_protect_np(1): switch MAP_JIT region from write to exec mode.
      # mprotect is NOT called — it would invalidate the d-cache, causing stale reads
      # when the trampoline's ldr x16, #8 runs.
      log_debug "Flushing JIT region to PoC before exec (darwin)"
      LibC.sys_dcache_flush(Pointer(Void).new(@thunk_base), @region_size)
      LibC.sys_icache_invalidate(Pointer(Void).new(@thunk_base), @region_size)
      LibC.pthread_jit_write_protect_np(1)
      {% else %}
      thunk = LibC.mprotect(Pointer(Void).new(@thunk_base), ((@thunk_table_entries * THUNK_SIZE + 4095_u64) & ~4095_u64), Memory::Protection::READ | Memory::Protection::EXEC)
      log_debug "Thunk mprotect result: #{thunk}"

      section_headers.each_with_index do |section, i|
        next if @section_mappings[i].nil?
        next unless section.type == SectionHeader::Type::PROGBITS
        log_debug "Setting protection: section=#{section.name}, addr=0x#{@section_mappings[i].address.to_s(16)}, size=0x#{section.size.to_s(16)}, prot=#{@section_prots[i]}"
        LibC.mprotect(@section_mappings[i].as(Pointer(Void)), ((section.size.to_u64 + 4095_u64) & ~4095_u64), @section_prots[i])
      end
      {% end %}
    end
  end
end