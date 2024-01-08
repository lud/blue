defmodule Blue.BuildingTest do
  use ExUnit.Case, async: true
  alias Blue.Building

  test "fetch building" do
    assert {:ok, %Building{name: "Airborne Critter Bait", id: "FlyingCreatureBait"}} =
             Building.by_id("FlyingCreatureBait")

    assert "Airborne Critter Bait" == Building.name_of!("FlyingCreatureBait")
  end

  test "fetch first building in CSV" do
    # in case the headers would be missed
    assert {:ok, %Building{name: "Aero Pot", id: "FlowerVaseHangingFancy"}} =
             Building.by_id("FlowerVaseHangingFancy")

    assert "Airborne Critter Bait" == Building.name_of!("FlyingCreatureBait")
  end

  test "unknown building is valid" do
    id = "SomeString"
    assert {:ok, %Building{name: ^id, id: ^id}} = Building.by_id(id)
  end
end
