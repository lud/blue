defmodule Blue.ElementTest do
  use ExUnit.Case, async: true
  alias Blue.Element

  test "fetch element" do
    assert {:ok, %Element{name: "Steel", id: "Steel", hash: -899_253_461}} =
             Element.find(-899_253_461)

    assert {:ok, %Element{name: "Steel", id: "Steel", hash: -899_253_461}} =
             Element.find("Steel")

    # Different name
    assert {:ok, %Element{name: "Copper Ore", id: "Cuprite", hash: -1_736_594_426}} =
             Element.find("Cuprite")

    assert {:ok, %Element{name: "Copper Ore", id: "Cuprite", hash: -1_736_594_426}} =
             Element.find(-1_736_594_426)
  end

  test "unknown element" do
    assert {:error, {:unknown_element, 123}} = Element.find(123)
    assert {:error, {:unknown_element, "Steel1"}} = Element.find("Steel1")
  end
end
