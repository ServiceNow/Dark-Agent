require "./elf/*"
require "./common/*"

# Setup logging
log_debug("Starting Dark Agent in direct mode (COFF loader only)...")

# Setup the default Beacon callbacks
Dark::ELF::Callbacks.register_defaults

# Check for COFF file argument
if ARGV.size < 1
  log_error("No COFF file specified. Usage: dark-agent-direct <coff_file> [args...]")
  exit(1)
end

coff_file = ARGV[0]

# Load and execute the specified COFF file
begin
  log_debug("Loading COFF file: #{coff_file}")
  
  # Read the file content
  coff_data = File.read(coff_file).to_slice
  
  # Get any arguments to pass to the BOF
  bof_args = ARGV.size > 1 ? ARGV[1..] : [] of String
  
  # Execute the BOF directly using the ELF module
  log_debug("Executing COFF with args: #{bof_args.join(" ")}")
  
  # Clear any previous output before execution
  Dark::ELF::Callbacks.get_and_clear_output
  
  # Load and execute the BOF
  Dark::ELF::ObjectFile.run(coff_data, bof_args)
  
  # Get the captured output
  output = Dark::ELF::Callbacks.get_and_clear_output
  
  # Print the output
  puts output unless output.empty?
  
rescue ex
  log_error("Error in direct mode: #{ex.message}")
  exit(1)
end