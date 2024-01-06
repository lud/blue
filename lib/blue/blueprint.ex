defmodule Blue.Blueprint do
  def distinct_materials(blueprint) do
    blueprint
    |> Map.fetch!("buildings")
    |> Enum.reduce(MapSet.new(), fn building, acc ->
      MapSet.put(acc, building |> Map.take(~w(buildingdef selected_elements)))
    end)
    |> MapSet.to_list()
  end

  # replacements is a map of %{{buildingdef, selected_elements} => %{element_hash => replacement_hash}}
  def replace_materials(blueprint, replacements) do
    Map.update(blueprint, "buildings", [], fn buildings ->
      Enum.map(buildings, fn building -> replace_building_materials(building, replacements) end)
    end)
  end

  defp replace_building_materials(building, replacements) do
    %{"buildingdef" => buildingdef, "selected_elements" => selected_elements} = building

    case Map.fetch(replacements, {buildingdef, selected_elements}) do
      {:ok, replacements} ->
        new_elements = Enum.map(selected_elements, &Map.get(replacements, &1, &1))
        %{building | "selected_elements" => new_elements}

      :error ->
        building
    end
  end

  def change_name(blueprint, new_name) do
    Map.put(blueprint, "friendlyname", new_name)
  end
end
