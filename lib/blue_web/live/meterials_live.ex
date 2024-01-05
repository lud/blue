defmodule BlueWeb.MaterialsLive do
  alias Blue.Blueprint
  alias Blue.Element
  alias Blue.Original
  alias Blue.Building
  # In Phoenix v1.6+ apps, the line is typically: use MyAppWeb, :live_view
  use BlueWeb, :live_view

  def render(assigns) do
    ~H"""
    <div><%= @counter %></div>
    <h1><%= @blueprint["friendlyname"] %></h1>
    <%= for mat <- @materials do %>
      <.material_picker build_mat={mat} replacements={@replacements} />
    <% end %>
    <pre>
      <%= Jason.encode!(@materials, pretty: true) %>
    </pre>
    """
  end

  defp material_picker(assigns) do
    ~H"""
    <div class="border border-blue-200 m-4 p-2">
      <h2><%= @build_mat.building_name %></h2>

      <%= for hash <- @build_mat.selected_elements do %>
        <div class="flex gap-3">
          <div>
            <p>Used element</p>
            <code><%= Element.find!(hash).name %></code>
          </div>
          <div>
            <p>Replace with</p>
            <select>
              <%= for element <- Element.list_all() do %>
                <option
                  value={element.id}
                  selected={replacement(@replacements, @build_mat, hash) == element.hash}
                >
                  <%= element.name %>
                </option>
              <% end %>
            </select>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, blueprint} = Original.by_name("terrasieve")
    materials = prepare_mats(blueprint)

    replacements = %{
      {"Door", [-1_736_594_426], -1_736_594_426} => 1_608_833_498
    }

    if connected?(socket), do: send_tick()

    {:ok,
     assign(socket,
       counter: 0,
       blueprint: blueprint,
       materials: materials,
       replacements: replacements
     )}
  end

  def handle_event("inc_temperature", _params, socket) do
    {:noreply, update(socket, :temperature, &(&1 + 1))}
  end

  def handle_info(:tick, socket) do
    send_tick()
    socket = update(socket, :counter, &(&1 + 1))
    {:noreply, socket}
  end

  defp send_tick do
    Process.send_after(self(), :tick, 5000)
  end

  defp prepare_mats(blueprint) do
    Blueprint.distinct_materials(blueprint)
    |> Enum.map(fn %{"buildingdef" => bid, "selected_elements" => hashs} ->
      %{
        building_name: Building.name_of!(bid),
        buildingdef: bid,
        selected_elements: hashs
      }
    end)
  end

  defp replacement(replacements, build_mat, element_hash) do
    key = {build_mat.buildingdef, build_mat.selected_elements, element_hash}

    if Map.has_key?(replacements, key) do
      key |> IO.inspect(label: ~S/key/)
      replacements[key] |> IO.inspect(label: ~S/replacements[key]/)
    end

    case Map.fetch(replacements, key) do
      {:ok, replacement} -> replacement
      :error -> element_hash
    end
  end
end
