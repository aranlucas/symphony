defmodule SymphonyElixir.Claude.ACP do
  @moduledoc """
  Claude Code ACP adapter for Symphony.

  Uses the same JSON-RPC 2.0 over stdio implementation as the Codex app-server
  client and exposes the adapter under a Claude-specific module.
  """

  alias SymphonyElixir.Codex.AppServer

  @type session :: AppServer.session()

  @spec start_session(Path.t()) :: {:ok, session()} | {:error, term()}
  def start_session(workspace) when is_binary(workspace) do
    AppServer.start_session(workspace)
  end

  @spec run_turn(session(), String.t(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def run_turn(session, prompt, issue, opts \\ []) do
    AppServer.run_turn(session, prompt, issue, opts)
  end

  @spec stop_session(session()) :: :ok
  def stop_session(session) do
    AppServer.stop_session(session)
  end
end
