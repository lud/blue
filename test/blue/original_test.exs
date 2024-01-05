defmodule Blue.OriginalTest do
  use ExUnit.Case, async: true
  alias Blue.Original

  test "base dir is defined" do
    assert [_ | _] = File.ls!(Original.base_dir())
  end

  test "find by name" do
    assert {:ok, %{"friendlyname" => _, "buildings" => [_ | _]}} = Original.by_name("terrasieve")
  end
end
