defmodule Blue.ElementTest do
  use ExUnit.Case, async: true
  alias Blue.Element

  test "fetch element" do
    assert {:ok, %Element{name: "Hydrogen", id: "Hydrogen", hash: -1_046_145_888}} =
             Element.find(-1_046_145_888)

    assert {:ok, %Element{name: "Hydrogen", id: "Hydrogen", hash: -1_046_145_888}} =
             Element.find("Hydrogen")

    # Different name
    assert {:ok, %Element{name: "Copper Ore", id: "Cuprite", hash: -1_736_594_426}} =
             Element.find("Cuprite")

    assert {:ok, %Element{name: "Copper Ore", id: "Cuprite", hash: -1_736_594_426}} =
             Element.find(-1_736_594_426)
  end

  test "unknown element" do
    assert {:error, {:unknown_element, 123}} = Element.find(123)
    assert {:error, {:unknown_element, "Hydrogen1"}} = Element.find("Hydrogen1")
  end
end
