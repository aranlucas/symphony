defmodule SymphonyElixir.Codex.Protocol do
  @moduledoc false

  @spec normalize_method(String.t() | nil) :: String.t() | nil
  def normalize_method("tool/requestUserInput"), do: "item/tool/requestUserInput"
  def normalize_method(method) when is_binary(method), do: method
  def normalize_method(_method), do: nil
end
