defmodule Blue.Element do
  alias NimbleCSV.RFC4180, as: CSV

  defstruct [:id, :name, :hash]

  @hashs_path Path.join([:code.priv_dir(:blue), "data", "element_hashs.csv"])
  @external_resource @hashs_path

  @ids_path Path.join([:code.priv_dir(:blue), "data", "element_ids.csv"])
  @external_resource @ids_path

  @hash_data @hashs_path
             |> File.stream!()
             |> CSV.parse_stream(skip_headers: false)
             |> Enum.map(fn
               [id, hash] -> %{id: id, hash: String.to_integer(hash)}
             end)

  @id_data @ids_path
           |> File.stream!()
           |> CSV.parse_stream(skip_headers: false)
           #  Some IDs in the CSV have a C-style comment, we ignore them
           |> Enum.filter(fn
             ["//" <> _ | _] -> false
             _ -> true
           end)
           |> Enum.map(fn [name, id, _dlc] -> %{name: name, id: id} end)

  @raw_data Enum.concat([@hash_data, @id_data])
            |> Enum.group_by(fn %{id: id} -> id end)
            |> Enum.flat_map(fn
              {_, [a, b]} -> [Map.merge(a, b) |> Map.put(:__struct__, __MODULE__)]
              _ -> []
            end)
            |> Enum.sort_by(fn %{name: name} -> name end)

  Enum.each(@raw_data, fn element ->
    %{id: id, hash: hash} = element

    def find(unquote(id)), do: {:ok, unquote(Macro.escape(element))}
    def find(unquote(hash)), do: find(unquote(id))
  end)

  def find(hash) when is_integer(hash) do
    {:ok,
     %__MODULE__{
       name: "Unknown #{Integer.to_string(hash)}",
       id: "Unknown#{Integer.to_string(hash)}",
       hash: hash
     }}
  end

  def find(id) when is_binary(id) do
    {:ok,
     %__MODULE__{
       name: "Unknown #{id}",
       id: id,
       hash: -1
     }}
  end

  def find!(what) do
    {:ok, element} = find(what)
    element
  end

  def hash_of!(what), do: find!(what).hash

  def list_all, do: @raw_data
end
