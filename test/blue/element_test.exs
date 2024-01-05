defmodule Blue.ElementTest do
  use ExUnit.Case, async: true
  alias Blue.Element

  test "fetch element" do
    assert {:ok, %Element{name: "Hydrogen", id: -1_046_145_888}} = Element.by_id(-1_046_145_888)
    assert {:ok, %Element{name: "Hydrogen", id: -1_046_145_888}} = Element.by_name("Hydrogen")
  end
end
