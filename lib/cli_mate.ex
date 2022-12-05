defmodule CliMate do
  defmacro __using__(_) do
    cli_mod = __CALLER__.module

    quote bind_quoted: [cli_mod: cli_mod], location: :keep, generated: true do
      # -----------------------------------------------------------------------
      # Shell
      # -----------------------------------------------------------------------

      # Here we just basically rewrite what mix does, because we do not want to
      # rely on Mix to be started if we build escripts.

      def put_shell(module) do
        :persistent_term.put({__MODULE__, :shell}, module)
      end

      def shell do
        :persistent_term.get({__MODULE__, :shell}, __MODULE__)
      end

      # -----------------------------------------------------------------------
      # Output
      # -----------------------------------------------------------------------

      @doc false
      def _print(output, _kind, iodata) do
        IO.puts(output, IO.ANSI.format(iodata))
      end

      def color(color, iodata) do
        [color, iodata]
      end

      def error(iodata) do
        shell()._print(:stderr, :error, [:bright, color(:red, iodata)])
      end

      def warn(iodata) do
        shell()._print(:stderr, :warn, color(:yellow, iodata))
      end

      def debug(iodata) do
        shell()._print(:stdio, :debug, color(:cyan, iodata))
      end

      def success(iodata) do
        shell()._print(:stdio, :info, color(:green, iodata))
      end

      def writeln(iodata) do
        shell()._print(:stdio, :info, iodata)
      end

      def halt(n \\ 0) when is_integer(n) do
        shell()._halt(n)
      end

      def halt_success(iodata) do
        success(iodata)
        halt(0)
      end

      def halt_error(n \\ 1, iodata) do
        error(iodata)
        halt(n)
      end

      @doc false
      def _halt(n) do
        System.halt(n)
      end

      defmodule ProcessShell do
        @moduledoc false

        @doc false
        def cli_mod, do: unquote(cli_mod)

        @doc false
        def _print(_output, kind, iodata) do
          send(message_target(), {cli_mod(), kind, format_message(iodata)})
        end

        defp format_message(iodata) do
          iodata
          |> IO.ANSI.format(false)
          |> :erlang.iolist_to_binary()
        end

        defp message_target() do
          case Process.get(:"$callers") do
            [parent | _] -> parent
            _ -> self()
          end
        end

        def _halt(n) do
          send(message_target(), {cli_mod(), :halt, n})
        end
      end

      # -----------------------------------------------------------------------
      # Defining commands
      # -----------------------------------------------------------------------

      defmodule Option do
        @moduledoc false
        @enforce_keys [:key, :doc, :type, :short, :default, :keep]
        defstruct @enforce_keys

        @type vtype :: :integer | :float | :string | :count | :boolean
        @type t :: %__MODULE__{
                key: atom,
                doc: binary,
                type: vtype,
                short: atom,
                default: term,
                keep: boolean
              }
      end

      defp build_option({key, conf}) when is_atom(key) and is_list(conf) do
        keep = Keyword.get(conf, :keep, false)
        type = Keyword.get(conf, :type, :string)
        doc = Keyword.get(conf, :doc, "")
        short = Keyword.get(conf, :short, nil)

        default =
          case Keyword.fetch(conf, :default) do
            {:ok, term} -> {:default, term}
            :error when type == :boolean -> {:default, false}
            :error -> :skip
          end

        opt = %Option{key: key, doc: doc, type: type, short: short, default: default, keep: keep}
        {key, opt}
      end

      defmodule Argument do
        @moduledoc false
        @enforce_keys [:key, :required, :cast, :doc]
        defstruct @enforce_keys

        @type t :: %__MODULE__{
                required: boolean,
                key: atom,
                doc: binary,
                cast: (term -> term) | {module, atom, [term]}
              }
      end

      defp build_argument({key, conf}) when is_atom(key) and is_list(conf) do
        required = Keyword.get(conf, :required, true)
        cast = Keyword.get(conf, :cast, &{:ok, &1})
        doc = Keyword.get(conf, :doc, "")
        %Argument{key: key, required: required, cast: cast, doc: doc}
      end

      defmodule Command do
        @moduledoc false
        @enforce_keys [:arguments, :options]
        defstruct [:arguments, :options, :module, :name]

        @type t :: %__MODULE__{
                arguments: [Argument.t()],
                options: [{atom, Option.t()}],
                module: module | nil,
                name: binary | nil
              }
      end

      defp build_command(conf) do
        options = conf |> Keyword.get(:options, []) |> Enum.map(&build_option/1)
        arguments = conf |> Keyword.get(:arguments, []) |> Enum.map(&build_argument/1)
        name = conf |> Keyword.get(:name, nil)
        module = conf |> Keyword.get(:module, nil)
        %Command{options: options, arguments: arguments, name: name, module: module}
      end

      # -----------------------------------------------------------------------
      # Parser
      # -----------------------------------------------------------------------

      def parse(argv, command) when is_list(command) do
        parse(argv, build_command(command))
      end

      def parse(argv, %Command{} = command) do
        options = command.options
        arguments = command.arguments

        strict = Enum.map(options, fn {key, opt} -> {key, opt_to_switch(opt)} end)
        aliases = Enum.flat_map(options, fn {_, opt} -> opt_alias(opt) end)

        with {parsed_options, parsed_arguments, []} <-
               OptionParser.parse(argv, strict: strict, aliases: aliases),
             {:ok, options_found} <- take_opts(options, parsed_options),
             {:ok, arguments_found} <- take_args(arguments, parsed_arguments) do
          {:ok, %{options: options_found, arguments: arguments_found}}
        else
          {_, _, invalid} -> {:error, {:invalid, invalid}}
          {:error, _} = err -> err
        end
      end

      defp opt_to_switch(%{keep: true, type: t}), do: [t, :keep]
      defp opt_to_switch(%{keep: false, type: t}), do: t
      defp opt_alias(%{short: nil}), do: []
      defp opt_alias(%{short: a, key: key}), do: [{a, key}]

      defp take_opts(schemes, opts) do
        all = Enum.reduce(schemes, %{}, fn scheme, acc -> collect_opt(scheme, opts, acc) end)
        {:ok, all}
      end

      defp collect_opt({key, scheme}, opts, acc) do
        case scheme.keep do
          true ->
            list = collect_list_option(opts, key)
            Map.put(acc, key, list)

          false ->
            case get_opt_value(opts, key, scheme.default) do
              {:ok, value} -> Map.put(acc, key, value)
              :skip -> acc
            end
        end
      end

      def get_opt_value(opts, key, default) do
        case Keyword.fetch(opts, key) do
          :error ->
            case default do
              {:default, v} -> {:ok, v}
              :skip -> :skip
            end

          {:ok, v} ->
            {:ok, v}
        end
      end

      defp collect_list_option(opts, key) do
        opts |> Enum.filter(fn {k, _} -> k == key end) |> Enum.map(&elem(&1, 1))
      end

      defp take_args(schemes = task, args) do
        take_args(schemes, args, %{})
      end

      defp take_args([%{required: true, key: key} | _], [], _acc) do
        {:error, {:missing_argument, key}}
      end

      defp take_args([%{key: key, cast: cast} | schemes], [value | argv], acc) do
        case cast.(value) do
          {:ok, casted} ->
            acc = Map.put(acc, key, casted)
            take_args(schemes, argv, acc)

          {:error, reason} ->
            {:error, {:argument_cast, key, reason}}

          other ->
            {:error, {:argument_cast, key, {:bad_return, other}}}
        end
      end

      defp take_args([], [extra | _], _) do
        {:error, {:extra_argument, extra}}
      end

      defp take_args([], [], acc) do
        {:ok, acc}
      end

      defp take_args([%{required: false} | _], [], acc) do
        {:ok, acc}
      end

      def parse_or_halt!(argv, command) do
        case parse(argv, command) do
          {:ok, parsed} ->
            parsed

          {:error, reason} ->
            writeln(format_usage(command))
            error(format_reason(reason))
            halt(1)
            {:error, :halted}
        end
      end

      defp format_reason({:argument_cast, key, reason}) do
        ["error when casting argument ", Atom.to_string(key), ": ", ensure_string(reason)]
      end

      defp format_reason({:argument_cast, key, {:bad_return, br}}) do
        ["could not cast argument ", Atom.to_string(key), " bad return: ", inspect(br)]
      end

      defp format_reason({:invalid, invalid}) do
        invalid |> Enum.map(fn {k, _v} -> "invalid option #{k}" end) |> Enum.intersperse("\n")
      end

      defp format_reason({:extra_argument, v}) do
        "unexpected extra argument #{v}"
      end

      defp format_reason({:missing_argument, key}) do
        ["missing argument ", Atom.to_string(key)]
      end

      defp format_reason(:other) do
        :lol
      end

      # -----------------------------------------------------------------------
      #  Usage Format
      # -----------------------------------------------------------------------

      def format_usage(command) when is_list(command) do
        format_usage(build_command(command))
      end

      def format_usage(%Command{} = command) do
        header = format_usage_header(command)
        options = format_usage_opts(command.options)
        [header, "\n\n", options]
      end

      defp format_usage_header(command) do
        name = format_usage_command_name(command)

        optarray =
          case command do
            %{options: []} -> ""
            _ -> " [options]"
          end

        argslist =
          case command do
            %{arguments: []} -> ""
            %{arguments: args} -> format_usage_args_list(args)
          end

        ["Usage\n\n  ", name, optarray, argslist]
      end

      defp format_usage_command_name(command) do
        case command do
          %Command{name: nil, module: nil} ->
            "unnamed command"

          %Command{name: name} when is_binary(name) ->
            name

          %Command{module: mod} when is_atom(mod) and mod != nil ->
            mod
            |> inspect()
            |> String.split(".")
            |> case do
              ["Mix", "Tasks" | rest] ->
                "mix #{Enum.map_join(rest, ".", &Macro.underscore/1)}"

              rest ->
                Enum.map_join(rest, ".", &Macro.underscore/1)
            end
        end
      end

      defp format_usage_args_list([%{required: req?, key: key} | rest]) do
        name = Atom.to_string(key)

        case req? do
          true -> [" <", name, ">" | format_usage_args_list(rest)]
          false -> [[" [<", name, ">" | format_usage_args_list(rest)], "]"]
        end
      end

      defp format_usage_args_list([]) do
        []
      end

      defp format_usage_opts([]) do
        []
      end

      defp format_usage_opts(options) do
        max_opt = max_key_len(options)
        columns = io_columns()
        columns |> IO.inspect(label: "columns")
        left_padding = 9 + max_opt
        wrapping = columns - left_padding
        pad_io = ["\n", String.duplicate(" ", left_padding)]

        opts = Enum.map(options, &format_usage_opt(&1, max_opt, wrapping, pad_io))

        ["Options\n\n" | opts]
      end

      defp format_usage_opt({k, option}, max_opt, wrapping, pad_io) do
        %Option{short: s, key: k, doc: doc, default: default} = option

        short =
          case s do
            nil -> "  "
            _ -> "-#{s}"
          end

        name = k |> Atom.to_string() |> String.replace("_", "-")
        long = ["--", String.pad_trailing(name, max_opt, " ")]

        doc =
          case default do
            :skip -> doc
            {:default, v} -> doc <> " Default: '#{ensure_string(v)}'."
          end

        wrapped_doc = doc |> wrap_doc(wrapping) |> Enum.intersperse(pad_io)

        ["  ", short, " ", long, "  ", wrapped_doc, "\n"]
      end

      defp wrap_doc(doc, width) do
        words = doc |> String.split(" ") |> Enum.map(&{&1, String.length(&1)})

        Enum.reduce(words, {0, [], []}, fn {word, len}, {line_len, this_line, lines} ->
          cond do
            line_len == 0 -> {len, [word | this_line], lines}
            line_len + 1 + len > width -> {len, [word], [:lists.reverse(this_line) | lines]}
            :_ -> {line_len + 1 + len, [word, " " | this_line], lines}
          end
        end)
        |> case do
          {_, [], lines} -> :lists.reverse(lines)
          {_, current, lines} -> :lists.reverse([:lists.reverse(current) | lines])
        end
      end

      defp max_key_len(kw) do
        kw
        |> Keyword.keys()
        |> Enum.map(&String.length(Atom.to_string(&1)))
        |> Enum.max(fn -> 0 end)
      end

      defp io_columns do
        case :io.columns() do
          {:ok, n} -> n
          _ -> 100
        end
      end

      defp ensure_string(str) when is_binary(str) do
        str
      end

      defp ensure_string(term) do
        to_string(term)
      rescue
        _ in Protocol.UndefinedError -> inspect(term)
      end
    end
  end
end
