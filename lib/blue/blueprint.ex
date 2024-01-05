defmodule Blue.Blueprint do
  def distinct_materials(blueprint) do
    blueprint
    |> Map.fetch!("buildings")
    |> Enum.reduce(MapSet.new(), fn building, acc ->
      MapSet.put(acc, building |> Map.take(~w(buildingdef selected_elements)))
    end)
    |> MapSet.to_list()
  end
end
