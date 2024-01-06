defmodule Blue.BlueprintTest do
  use ExUnit.Case, async: true
  alias Blue.Blueprint
  import Blue.Element

  test "distinct materials" do
    blueprint =
      %{
        "friendlyname" => "some name",
        "buildings" => [
          %{
            "buildingdef" => "Tile",
            "offset" => %{"x" => 7},
            "selected_elements" => [hash_of!("SandStone")]
          },
          # same building and SandStone as before
          %{
            "buildingdef" => "Tile",
            "offset" => %{"x" => 8},
            "selected_elements" => [hash_of!("SandStone")]
          },
          # same building but different element
          %{
            "buildingdef" => "Tile",
            "offset" => %{"x" => 9},
            "selected_elements" => [hash_of!("SedimentaryRock")]
          },
          # other building
          %{
            "buildingdef" => "LiquidConduit",
            "flags" => 2,
            "offset" => %{"x" => 7, "y" => 3},
            "selected_elements" => [hash_of!("SandStone")]
          }
        ]
      }

    expected_distinct_materials =
      Enum.sort([
        %{"buildingdef" => "Tile", "selected_elements" => [hash_of!("SandStone")]},
        %{"buildingdef" => "Tile", "selected_elements" => [hash_of!("SedimentaryRock")]},
        %{"buildingdef" => "LiquidConduit", "selected_elements" => [hash_of!("SandStone")]}
      ])

    assert expected_distinct_materials == Blueprint.distinct_materials(blueprint)
  end

  test "replace materials" do
    blueprint =
      %{
        "friendlyname" => "some name",
        "buildings" => [
          %{
            "buildingdef" => "Tile",
            "offset" => %{"x" => 7},
            "selected_elements" => [hash_of!("SandStone")]
          },
          # same building and SandStone as before
          %{
            "buildingdef" => "Tile",
            "offset" => %{"x" => 8},
            "selected_elements" => [hash_of!("SandStone")]
          },
          # same building but different element
          %{
            "buildingdef" => "Tile",
            "offset" => %{"x" => 9},
            "selected_elements" => [hash_of!("SedimentaryRock")]
          },
          # other building
          %{
            "buildingdef" => "LiquidConduit",
            "flags" => 2,
            "offset" => %{"x" => 7, "y" => 3},
            "selected_elements" => [hash_of!("SandStone")]
          }
        ]
      }

    replacements = %{
      {"Tile", [hash_of!("SandStone")]} => %{hash_of!("SandStone") => hash_of!("IgneousRock")}
    }

    # Nothing has changed expect the SandStone...
    expected =
      %{
        "friendlyname" => "some name",
        "buildings" => [
          %{
            "buildingdef" => "Tile",
            "offset" => %{"x" => 7},
            # ...here
            "selected_elements" => [hash_of!("IgneousRock")]
          },
          %{
            "buildingdef" => "Tile",
            "offset" => %{"x" => 8},
            # ...and here
            "selected_elements" => [hash_of!("IgneousRock")]
          },
          %{
            "buildingdef" => "Tile",
            "offset" => %{"x" => 9},
            "selected_elements" => [hash_of!("SedimentaryRock")]
          },
          %{
            "buildingdef" => "LiquidConduit",
            "flags" => 2,
            "offset" => %{"x" => 7, "y" => 3},
            "selected_elements" => [hash_of!("SandStone")]
          }
        ]
      }

    assert expected == Blueprint.replace_materials(blueprint, replacements)
  end

  test "change name" do
    blueprint = %{"friendlyname" => "some name", "untouched" => "value"}

    assert %{"friendlyname" => "new name", "untouched" => "value"} ==
             Blueprint.change_name(blueprint, "new name")
  end
end
