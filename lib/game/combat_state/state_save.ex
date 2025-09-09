defmodule Game.CombatState.StateSave do
  @moduledoc """
  Module for saving and loading CombatState data.

  This module provides functions to encode a CombatState struct to a Base64-encoded JSON string
  and decode it back to a CombatState struct.
  """

  alias Game.CombatState
  alias Game.Character
  alias Game.Card
  alias Game.Grid

  # A constant key used for the encoding/decoding process
  @secret_key_base "game_combat_state_serialization_key"
  @iv_length 16

  # Define implementations for the Jason.Encoder protocol for our structs

  # Define a custom encoder for tuples (used in positions)
  defimpl Jason.Encoder, for: Tuple do
    def encode(tuple, opts) do
      tuple
      |> Tuple.to_list()
      |> Jason.Encoder.encode(opts)
    end
  end

  @doc """
  Encodes a CombatState struct to a Base64-encoded JSON string.

  ## Parameters
    * state - A CombatState struct to be encoded

  ## Returns
    * A Base64-encoded JSON string representing the CombatState
  """
  @spec encode(%CombatState{}) :: String.t()
  def encode(%CombatState{} = state) do
    # Convert struct to a serializable map
    serialized_map =
      Map.from_struct(state)
      |> Map.update!(:grid, fn grid ->
        grid_map = if is_struct(grid), do: Map.from_struct(grid), else: grid
        # Handle tiles map with tuple keys
        Map.update!(grid_map, :tiles, fn tiles ->
          Enum.map(tiles, fn {{q, r, s}, value} ->
            {Jason.encode!([q, r, s]), value}
          end)
          |> Enum.into(%{})
        end)
      end)
      |> Map.update!(:queue, fn queue ->
        Enum.map(queue, &character_to_map/1)
      end)
      |> Map.update!(:current_turn, fn turn ->
        turn = %{
          starting_position: turn[:starting_position],
          card: turn[:card],
          player: if(turn[:player], do: character_to_map(turn[:player]), else: nil)
        }

        turn
      end)

    serialized_map
    |> Jason.encode!()
    |> encrypt(@secret_key_base)
    |> Base.encode64()
  end

  # Encrypt data with a simple XOR cipher using the secret key
  defp encrypt(data, key) do
    # Generate a random IV (initialization vector)
    iv = :crypto.strong_rand_bytes(@iv_length)

    # Convert strings to binary lists for processing
    data_bytes = :erlang.binary_to_list(data)
    key_bytes = :erlang.binary_to_list(key)

    # XOR each byte with the corresponding key byte (cycling through key)
    key_length = length(key_bytes)
    encrypted = encrypt_bytes(data_bytes, key_bytes, key_length, 0, [])

    # Return IV + encrypted data for decryption later
    iv <> :erlang.list_to_binary(encrypted)
  end

  # Recursive function to XOR each byte
  defp encrypt_bytes([], _key, _key_length, _i, acc), do: Enum.reverse(acc)

  defp encrypt_bytes([byte | rest], key, key_length, i, acc) do
    key_byte = Enum.at(key, rem(i, key_length))
    encrypted_byte = :erlang.bxor(byte, key_byte)
    encrypt_bytes(rest, key, key_length, i + 1, [encrypted_byte | acc])
  end

  # Helper to convert Character struct to a serializable map
  defp character_to_map(%Character{} = character) do
    character =
      Map.from_struct(character)
      |> Map.update!(:cards, fn cards ->
        cards
        |> Map.update!(:hand, fn hand -> Enum.map(hand, &Map.from_struct/1) end)
        |> Map.update!(:draw, fn draw -> Enum.map(draw, &Map.from_struct/1) end)
        |> Map.update!(:discard, fn discard -> Enum.map(discard, &Map.from_struct/1) end)
      end)

    character
  end

  defp character_to_map(nil), do: nil

  @doc """
  Decodes a Base64-encoded JSON string back to a CombatState struct.

  ## Parameters
    * encoded_string - A Base64-encoded JSON string representing a CombatState

  ## Returns
    * {:ok, %CombatState{}} - Successfully decoded CombatState
    * {:error, reason} - Error with reason if decoding fails
  """
  @spec decode(String.t()) :: {:ok, CombatState.t()} | {:error, String.t()}
  def decode(encoded_string) when is_binary(encoded_string) do
    # Log the length of the encoded string for debugging
    IO.puts("Encoded string length: #{String.length(encoded_string)}")

    with {:ok, encrypted_data} <- decode_base64(encoded_string),
         {:ok, json_string} <- decrypt(encrypted_data, @secret_key_base),
         {:ok, decoded_map} <- decode_json(json_string),
         {:ok, combat_state} <- build_combat_state(decoded_map) do
      {:ok, combat_state}
    else
      {:error, reason} ->
        IO.inspect(reason, label: "Decode error")
        {:error, reason}
    end
  end

  # Private helper functions

  # Decrypt data that was encrypted with the encrypt function
  defp decrypt(data, key) when byte_size(data) > @iv_length do
    try do
      # Extract the IV and the encrypted data
      <<_iv::binary-size(@iv_length), encrypted_data::binary>> = data

      # Log the sizes for debugging
      IO.puts("Encrypted data size: #{byte_size(encrypted_data)} bytes")

      # Convert to binary lists for processing
      data_bytes = :erlang.binary_to_list(encrypted_data)
      key_bytes = :erlang.binary_to_list(key)

      # XOR decrypt (same operation as encrypt)
      key_length = length(key_bytes)
      decrypted = encrypt_bytes(data_bytes, key_bytes, key_length, 0, [])

      # Convert back to binary
      decrypted_binary = :erlang.list_to_binary(decrypted)
      IO.puts("Decrypted data size: #{byte_size(decrypted_binary)} bytes")

      {:ok, decrypted_binary}
    rescue
      e ->
        IO.puts("Exception during decryption: #{inspect(e)}")
        {:error, "Decryption error: #{inspect(e)}"}
    end
  end

  defp decrypt(_data, _key) do
    {:error, "Invalid encrypted data format"}
  end

  defp decode_base64(encoded_string) do
    try do
      # Check if string needs padding
      needs_padding = rem(byte_size(encoded_string), 4)

      if needs_padding > 0 do
        IO.puts("Base64 string needs padding (remainder: #{needs_padding})")
      end

      case Base.decode64(encoded_string) do
        {:ok, decoded} ->
          IO.puts("Base64 decoded successfully, size: #{byte_size(decoded)} bytes")
          {:ok, decoded}

        :error ->
          IO.puts("Adding padding to Base64 string")
          # Try with padding added if needed
          padded =
            case rem(byte_size(encoded_string), 4) do
              2 -> encoded_string <> "=="
              3 -> encoded_string <> "="
              _ -> encoded_string
            end

          case Base.decode64(padded) do
            {:ok, decoded} ->
              IO.puts("Base64 decoded with padding, size: #{byte_size(decoded)} bytes")
              {:ok, decoded}

            :error ->
              # Try to identify where the Base64 might be invalid
              # Show a snippet of the encoded string
              snippet =
                if byte_size(encoded_string) > 100 do
                  "#{String.slice(encoded_string, 0, 50)}...#{String.slice(encoded_string, -50..-1)}"
                else
                  encoded_string
                end

              IO.puts("Invalid Base64 snippet: #{snippet}")
              {:error, "Invalid Base64 encoding"}
          end
      end
    rescue
      e ->
        IO.puts("Exception during Base64 decoding: #{inspect(e)}")
        {:error, "Base64 decoding error: #{inspect(e)}"}
    end
  end

  defp decode_json(json_string) do
    # Log the length of the JSON string for debugging
    IO.puts("JSON string length: #{String.length(json_string)}")

    # Check if the string appears to be complete JSON
    if String.ends_with?(json_string, "}") do
      IO.puts("JSON string appears to end properly with '}'")
    else
      IO.puts("WARNING: JSON string does not end with '}', it might be truncated")
      # Print the last 100 characters to see where it cuts off
      IO.puts("Last 100 chars: #{String.slice(json_string, -100..-1)}")
    end

    case Jason.decode(json_string) do
      {:ok, decoded} ->
        {:ok, decoded}

      {:error, %Jason.DecodeError{position: pos} = error} ->
        IO.inspect(error, label: "JSON decode error")

        # Print context around the error position
        start_pos = max(0, pos - 50)
        end_pos = min(String.length(json_string), pos + 50)
        context = String.slice(json_string, start_pos, end_pos - start_pos)
        IO.puts("Error context (around position #{pos}):\n#{context}")

        # Show where exactly the error is
        pointer = String.duplicate(" ", pos - start_pos) <> "^"
        IO.puts(pointer)

        {:error, "Invalid JSON format: #{inspect(error)}"}
    end
  end

  defp build_combat_state(map) do
    try do
      # Convert string keys to atoms for struct creation and handle nested structures
      combat_state = atomize_keys(map)

      # Specially handle the grid tiles with tuple keys
      combat_state =
        if combat_state[:grid] && combat_state[:grid][:tiles] do
          grid_tiles = combat_state[:grid][:tiles]

          updated_tiles =
            Enum.map(grid_tiles, fn {key, value} ->
              if is_binary(key) do
                # Convert JSON array string back to tuple
                {:ok, [q, r, s]} = Jason.decode(key)
                {{q, r, s}, value}
              else
                {key, value}
              end
            end)
            |> Enum.into(%{})

          put_in(combat_state, [:grid, :tiles], updated_tiles)
        else
          combat_state
        end

      {:ok, struct(CombatState, combat_state)}
    rescue
      e -> {:error, "Failed to build CombatState struct: #{inspect(e)}"}
    end
  end

  # Convert string keys to atom keys recursively
  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {"__struct__", "Elixir.Game.CombatState"} ->
        {:__struct__, CombatState}

      {"__struct__", "Elixir.Game.Grid"} ->
        {:__struct__, Grid}

      {"__struct__", "Elixir.Game.Character"} ->
        {:__struct__, Character}

      {"__struct__", "Elixir.Game.Card"} ->
        {:__struct__, Card}

      {"state", state} when is_binary(state) ->
        {:state, String.to_existing_atom(state)}

      {"position", [q, r, s]} when is_integer(q) and is_integer(r) and is_integer(s) ->
        {:position, {q, r, s}}

      {"starting_position", [q, r, s]} when is_integer(q) and is_integer(r) and is_integer(s) ->
        {:starting_position, {q, r, s}}

      {"state", state} when is_atom(state) ->
        {:state, state}

      {key, value} when is_map(value) ->
        {String.to_atom(key), atomize_keys(value)}

      {key, value} when is_list(value) ->
        {String.to_atom(key), Enum.map(value, &atomize_list_item/1)}

      {key, value} ->
        {String.to_atom(key), value}
    end)
  end

  defp atomize_list_item(item) when is_map(item), do: atomize_keys(item)
  defp atomize_list_item(item), do: item
end
