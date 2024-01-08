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

  test "unknown element is still valid" do
    assert {:ok, %Element{name: "Unknown 123", id: "Unknown123", hash: 123}} =
             Element.find(123)

    #  hash will always be -1 in that case. This is not a business case
    assert {:ok, %Element{name: "Unknown Some", id: "Some", hash: -1}} =
             Element.find("Some")
  end
end
