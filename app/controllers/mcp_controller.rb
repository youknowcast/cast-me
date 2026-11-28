class McpController < Api::V1::ApplicationController
  def create
    rpc = parse_rpc(request.raw_post)
    return render json: Mcp::Server.error(nil, -32_700, 'Parse error') if rpc.nil?
    return render json: Mcp::Server.error(rpc['id'], -32_600, 'Invalid Request') unless valid_rpc?(rpc)

    if notification?(rpc)
      head :accepted
      return
    end

    render json: Mcp::Server.call(rpc, family: current_family, token_user: current_api_token.user)
  end

  private

  def parse_rpc(raw)
    JSON.parse(raw.to_s)
  rescue JSON::ParserError
    nil
  end

  def valid_rpc?(rpc) = rpc.is_a?(Hash) && rpc['jsonrpc'] == '2.0' && rpc['method'].is_a?(String)

  def notification?(rpc) = rpc['method'].to_s.start_with?('notifications/')
end
