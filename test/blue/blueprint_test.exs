defmodule Blue.BlueprintTest do
  use ExUnit.Case, async: true
  alias Blue.Blueprint
  import Blue.Element

  test "find by name" do
    blueprint =
      %{
        "friendlyname" => "some name",
        "buildings" => [
          %{
            "buildingdef" => "Tile",
            "offset" => %{"x" => 7},
            "selected_elements" => [id_of!("SandStone")]
          },
          # same building and SandStone as before
          %{
            "buildingdef" => "Tile",
            "offset" => %{"x" => 8},
            "selected_elements" => [id_of!("SandStone")]
          },
          # same building but different element
          %{
            "buildingdef" => "Tile",
            "offset" => %{"x" => 9},
            "selected_elements" => [id_of!("SedimentaryRock")]
          },
          # other building
          %{
            "buildingdef" => "LiquidConduit",
            "flags" => 2,
            "offset" => %{"x" => 7, "y" => 3},
            "selected_elements" => [id_of!("SandStone")]
          }
        ]
      }

    expected_distinct_materials =
      Enum.sort([
        %{"buildingdef" => "Tile", "selected_elements" => [id_of!("SandStone")]},
        %{"buildingdef" => "Tile", "selected_elements" => [id_of!("SedimentaryRock")]},
        %{"buildingdef" => "LiquidConduit", "selected_elements" => [id_of!("SandStone")]}
      ])

    assert expected_distinct_materials == Blueprint.distinct_materials(blueprint)
  end
end
