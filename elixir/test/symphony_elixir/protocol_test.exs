defmodule SymphonyElixir.Codex.ProtocolTest do
  use ExUnit.Case, async: true

  alias SymphonyElixir.Codex.Protocol

  test "normalizes top-level tool input method names" do
    assert Protocol.normalize_method("tool/requestUserInput") == "item/tool/requestUserInput"
  end

  test "passes through non-aliased binary method names" do
    assert Protocol.normalize_method("turn/completed") == "turn/completed"
  end

  test "returns nil for non-binary method values" do
    assert Protocol.normalize_method(nil) == nil
    assert Protocol.normalize_method(%{}) == nil
  end
end
