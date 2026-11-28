module Mcp
  class Server
    PROTOCOL_VERSION = '2025-11-25'.freeze
    SERVER_INFO = { name: 'cast-me', version: '1.0.0' }.freeze

    def self.call(rpc, family:, token_user:)
      id = rpc['id']

      case rpc['method']
      when 'initialize'
        result(id, { protocolVersion: PROTOCOL_VERSION, capabilities: { tools: {} }, serverInfo: SERVER_INFO })
      when 'ping'
        result(id, {})
      when 'tools/list'
        result(id, { tools: Mcp::Tools.list })
      when 'tools/call'
        tools_call(rpc, id, family: family, token_user: token_user)
      else
        error(id, -32_601, 'Method not found')
      end
    end

    def self.tools_call(rpc, id, family:, token_user:)
      params = rpc['params'].is_a?(Hash) ? rpc['params'] : {}
      name = params['name']
      raise Mcp::ToolError, 'tools/call requires a tool name' if name.nil?

      arguments = params['arguments'].is_a?(Hash) ? params['arguments'] : {}
      result(id, Mcp::Tools.call(name: name, args: arguments, family: family, token_user: token_user, request_id: id))
    rescue Mcp::ToolError => e
      result(id, { content: [{ type: 'text', text: JSON.generate(error: e.message) }], isError: true })
    end

    def self.result(id, result) = { jsonrpc: '2.0', id: id, result: result }

    def self.error(id, code, message) = { jsonrpc: '2.0', id: id, error: { code: code, message: message } }
  end
end
