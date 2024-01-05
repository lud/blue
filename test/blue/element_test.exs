defmodule Blue.ElementTest do
  use ExUnit.Case, async: true
  alias Blue.Element

  test "fetch element" do
    assert {:ok, %Element{name: "Hydrogen", id: -1_046_145_888}} = Element.find(-1_046_145_888)
    assert {:ok, %Element{name: "Hydrogen", id: -1_046_145_888}} = Element.find("Hydrogen")
  end

  test "unknown element" do
    assert {:error, {:unknown_element, 123}} = Element.find(123)
    assert {:error, {:unknown_element, "Hydrogen1"}} = Element.find("Hydrogen1")
  end
end
