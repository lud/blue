defmodule Blue.OriginalsTest do
  use ExUnit.Case, async: true
  alias Blue.Originals

  test "base dir is defined" do
    assert [_ | _] = File.ls!(Originals.base_dir())
  end
end
