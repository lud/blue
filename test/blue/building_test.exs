defmodule Blue.BuildingTest do
  use ExUnit.Case, async: true
  alias Blue.Building

  test "fetch building" do
    assert {:ok, %Building{name: "Airborne Critter Bait", id: "FlyingCreatureBait"}} =
             Building.by_id("FlyingCreatureBait")
  end

  test "unknown building" do
    assert {:error, {:unknown_building, "DoesNotExist"}} = Building.by_id("DoesNotExist")
  end
end
