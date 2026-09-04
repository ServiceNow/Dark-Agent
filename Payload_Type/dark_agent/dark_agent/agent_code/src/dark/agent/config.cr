require "json"
require "./config/base"

# Conditionally include the appropriate config implementation
{% if flag?(:httpx_profile) %}
  require "./config/httpx"
{% else %}
  require "./config/http"
{% end %}

module Dark::Agent
  # Configuration module to handle settings from generated config
  module Config
    # Read config file at compile time
    {% begin %}
      {% if env("DARK_AGENT_CONFIG_PATH") %}
        private RAW_CONFIG = {{read_file(env("DARK_AGENT_CONFIG_PATH"))}}
      {% else %}
        {{ raise "No DARK_AGENT_CONFIG_PATH environment variable was passed to the compiler" }}
      {% end %}
    {% end %}

    private DARK_AGENT_CONFIG = JSON.parse(RAW_CONFIG)
    
    # Conditionally set the active config implementation based on compile flags
    {% if flag?(:httpx_profile) %}
      # For HTTPX profile
      Active = Dark::Agent::Config::HTTPX
    {% else %}
      # For HTTP profile
      Active = Dark::Agent::Config::HTTP
    {% end %}
    
    # Factory method to create a new instance of the active config implementation
    def self.create
      Active.new(DARK_AGENT_CONFIG)
    end
  end
end