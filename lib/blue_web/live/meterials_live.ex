defmodule BlueWeb.MaterialsLive do
  alias Blue.Blueprint
  alias Blue.Building
  alias Blue.Element
  alias Blue.Original
  require Logger
  use BlueWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="flex gap-4">
      <%!-- Left --%>
      <div>
        <h1><%= @blueprint["friendlyname"] %></h1>
        <%= for mat <- @materials do %>
          <.material_picker build_mat={mat} replacements={@replacements} />
        <% end %>
      </div>

      <%!-- Right --%>
      <div>
        <h2>Replacements</h2>
        <form phx-change="change_name">
          <h3>New name</h3>
          <.input type="text" name="new_name" value={@new_name} phx-debounce={300} />
        </form>

        <div class="mt-2">
          <a
            href={~p(/blueprint-download/#{@download_id})}
            class="block box-border text-center text-white bg-blue-700 hover:bg-blue-800 focus:ring-4 focus:ring-blue-300 font-medium rounded-lg text-sm px-5 py-2.5 focus:outline-none"
            download={filename(@new_name)}
          >
            Download Blueprint<br /><code><%= filename(@new_name) %></code>
          </a>
        </div>
      </div>
    </div>
    """
  end

  defp filename(new_name) do
    name = new_name |> String.replace(" ", "_") |> String.downcase()
    "#{name}.blueprint"
  end

  @element_options Enum.map(Element.list_all(), fn %{hash: hash, name: name} -> {name, hash} end)

  defp element_options, do: @element_options

  defp material_picker(assigns) do
    ~H"""
    <div class="border border-blue-200 rounded my-2 p-2">
      <h2><%= @build_mat.building_name %></h2>

      <%= for hash <- @build_mat.selected_elements do %>
        <% chosen_hash =
          get_replacement(@replacements, @build_mat.buildingdef, @build_mat.selected_elements, hash) %>

        <div class={["flex gap-2 p-2 items-center", changed_mat_class(chosen_hash != hash)]}>
          <span>Replace</span>
          <strong><%= Element.find!(hash).name %></strong>
          <span>with</span>
          <form
            phx-change="select_replacement"
            phx-value-replaced_hash={hash}
            phx-value-original_elements={Jason.encode!(@build_mat.selected_elements)}
            phx-value-buildingdef={@build_mat.buildingdef}
          >
            <.input
              type="select"
              name="replacement_hash"
              options={element_options()}
              value={chosen_hash}
            />
          </form>
        </div>
      <% end %>
    </div>
    """
  end

  defp changed_mat_class(true), do: "bg-yellow-100"
  defp changed_mat_class(_), do: nil

  def mount(_params, _session, socket) do
    {:ok, blueprint} = Original.by_name("terrasieve")
    materials = prepare_mats(blueprint)

    replacements = %{}

    new_name = blueprint["friendlyname"]

    socket =
      assign(socket,
        blueprint: blueprint,
        materials: materials,
        replacements: replacements,
        new_name: new_name,
        download_id: socket.id
      )

    if connected?(socket) do
      register_mount(socket, blueprint)
    end

    {:ok, socket}
  end

  defp register_mount(socket, blueprint) do
    {:ok, _} = Registry.register(Blue.ReplacementsRegistry, {socket.id, :blueprint}, blueprint)

    {:ok, _} =
      Registry.register(Blue.ReplacementsRegistry, {socket.id, :changes}, registry_value(socket))
  end

  defp update_registry(socket) do
    {_new, _old} =
      Registry.update_value(Blue.ReplacementsRegistry, {socket.id, :changes}, fn _ ->
        registry_value(socket)
      end)
  end

  defp registry_value(socket) do
    %{friendlyname: socket.assigns.new_name, materials_replacements: socket.assigns.replacements}
  end

  def handle_event("select_replacement", params, socket) do
    socket |> IO.inspect(label: ~S/socket/)

    case select_replacement(socket.assigns.replacements, params) do
      {:ok, replacements} ->
        socket = assign(socket, replacements: replacements)
        update_registry(socket)
        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Invalid replacement")}
    end
  end

  def handle_event("change_name", %{"new_name" => new_name}, socket) do
    socket = assign(socket, new_name: new_name)
    update_registry(socket)
    {:noreply, socket}
  end

  defp select_replacement(replacements, params) do
    with %{
           "buildingdef" => buildingdef,
           "original_elements" => selected_elements_json,
           "replaced_hash" => replaced_hash_str,
           "replacement_hash" => replacement_hash_str
         } <- params,
         {:ok, selected_elements_hashs} <- Jason.decode(selected_elements_json),
         true <- Enum.all?(selected_elements_hashs, &is_integer/1),
         true <- Enum.all?(selected_elements_hashs, &match?({:ok, _}, Element.find(&1))),
         {:ok, _} <- Building.by_id(buildingdef),
         {replacement_hash, ""} <- Integer.parse(replacement_hash_str),
         {replaced_hash, ""} <- Integer.parse(replaced_hash_str),
         {:ok, _} <- Building.by_id(buildingdef) do
      binding() |> IO.inspect(label: ~S/binding()/)

      {:ok,
       put_replacement(
         replacements,
         buildingdef,
         selected_elements_hashs,
         replaced_hash,
         replacement_hash
       )}
    else
      other ->
        Logger.error("Invalid replacement params #{inspect(other)}, params: #{inspect(params)}")
        {:error, :invalid_params}
    end
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

  defp get_replacement(replacements, buildingdef, selected_elements, element_hash) do
    build_mat_key = {buildingdef, selected_elements}

    with {:ok, build_mat} <- Map.fetch(replacements, build_mat_key),
         {:ok, replacement} <- Map.fetch(build_mat, element_hash) do
      replacement
    else
      :error -> element_hash
    end
  end

  defp put_replacement(replacements, buildingdef, selected_elements, element_hash, replace_by) do
    build_mat_key = {buildingdef, selected_elements}

    Map.update(replacements, build_mat_key, %{element_hash => replace_by}, fn
      build_mat -> Map.put(build_mat, element_hash, replace_by)
    end)
  end
end
