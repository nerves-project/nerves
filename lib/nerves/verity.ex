# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Verity do
  @moduledoc """
  Create dm-verity metadata for root filesystem images

  This module creates a dm-verity superblock and hash tree for a file using
  the same on-disk format as `veritysetup format` from
  [cryptsetup](https://gitlab.com/cryptsetup/cryptsetup). It is run by `mix
  firmware` as a root filesystem post-processing step when dm-verity support
  is enabled:

      config :nerves, :firmware, verity: true

  This only creates the hashes. The Nerves system needs to install them and
  have an initramfs that sets up dm-verity.  See your Nerves system's
  documentation.

  The root filesystem is processed as follows:

  1. The filesystem is zero-padded in place to a multiple of the verity data
     block size (4096 bytes by default). This simplifies appending hashes to
     the end of the filesystem.
  2. The verity superblock and hash tree are written to `<path>.verity`.
  3. The root hash is written to `<path>.roothash`.
  4. If a signing key is configured, a detached PKCS#7 signature of the hex
     root hash is written to `<path>.roothash.p7s`.

  The `fwup.conf` should place the `.verity` file's contents wherever the
  initramfs expects it.

  The root hash should come from a trusted source such as a signed kernel
  command line or verified U-Boot environment.
  """

  import Bitwise

  @superblock_size 512
  @supported_algorithms [:sha256, :sha512]
  @max_salt_size 256
  @default_block_size 4096
  @roothash_extension ".roothash"
  @verity_extension ".verity"

  @typedoc """
  dm-verity options

  * `:algorithm` - hash algorithm, either `:sha256` (default) or `:sha512`
  * `:salt` - hex-encoded salt of up to #{@max_salt_size} bytes. Defaults to
    the SHA-256 hash of the padded data area
  * `:uuid` - UUID to store in the superblock (e.g.,
    `"3aaf3b00-7c5f-4f33-961c-5cb069f3e2a3"`). Defaults to a UUID derived
    from the root hash
  * `:data_block_size` - data block size in bytes (default 4096)
  * `:hash_block_size` - hash block size in bytes (default 4096)
  * `:signing_key` - path to a PEM-encoded private key. When set, OpenSSL
    signs the hex root hash producing a detached PKCS#7 signature at
    `<path>.roothash.p7s`. This is the format expected by the kernel's
    dm-verity signature verification
    (`CONFIG_DM_VERITY_VERIFY_ROOTHASH_SIG`), `veritysetup
    --root-hash-signature`, and systemd. Requires `:signing_cert`
  * `:signing_cert` - path to the PEM-encoded certificate for the signing
    key. The device checks the signature against this certificate, so it
    must be in the device's kernel keyring
  """
  @type option() ::
          {:algorithm, :sha256 | :sha512}
          | {:salt, String.t()}
          | {:uuid, String.t()}
          | {:data_block_size, pos_integer()}
          | {:hash_block_size, pos_integer()}
          | {:signing_key, Path.t()}
          | {:signing_cert, Path.t()}

  @typedoc """
  Information about the generated dm-verity metadata

  * `:root_hash` - hex-encoded root hash
  * `:root_hash_path` - path to the file containing the root hash
  * `:root_hash_sig_path` - path to the root hash signature or `nil` if
    signing wasn't configured
  * `:verity_path` - path to the file containing the superblock and hash tree
  * `:salt` - hex-encoded salt
  * `:uuid` - UUID stored in the superblock
  * `:algorithm` - hash algorithm
  * `:data_block_size` and `:hash_block_size` - block sizes in bytes
  * `:data_blocks` - number of data blocks covered by the hash tree
  * `:hash_offset` - byte offset of the superblock when the `.verity` file
    contents are placed directly after the padded data. Pass this to
    `veritysetup --hash-offset` when sharing one partition
  """
  @type info() :: %{
          root_hash: String.t(),
          root_hash_path: Path.t(),
          root_hash_sig_path: Path.t() | nil,
          verity_path: Path.t(),
          salt: String.t(),
          uuid: String.t(),
          algorithm: :sha256 | :sha512,
          data_block_size: pos_integer(),
          hash_block_size: pos_integer(),
          data_blocks: pos_integer(),
          hash_offset: pos_integer()
        }

  @doc """
  Create dm-verity metadata for a file

  The file is zero-padded in place to a multiple of the data block size.
  The dm-verity superblock and hash tree are saved to `<path>.verity` and
  the root hash to `<path>.roothash`. See `t:option/0` for the supported
  options and `t:info/0` for the returned information.
  """
  @spec format(Path.t(), [option()]) :: {:ok, info()} | {:error, String.t()}
  def format(path, opts \\ []) do
    with {:ok, config} <- parse_options(opts),
         {:ok, size} <- data_size(path) do
      write_verity_metadata(path, size, config)
    end
  end

  @doc """
  Validate dm-verity options

  This checks options without processing anything so that errors can be
  reported before starting a long firmware build.
  """
  @spec validate_options([option()]) :: :ok | {:error, String.t()}
  def validate_options(opts) do
    case parse_options(opts) do
      {:ok, _config} -> :ok
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Entry point for the `mix firmware` post-processing script

  This reads the file path from `$NERVES_VERITY_ROOTFS` and options from the
  other `$NERVES_VERITY_*` environment variables set by `mix firmware`. It's
  not intended to be called from anywhere else.
  """
  @spec main() :: :ok
  def main() do
    with {:ok, path} <- fetch_rootfs_env(),
         {:ok, info} <- format(path, options_from_env()) do
      IO.puts("dm-verity root hash: #{info.root_hash}")
    else
      {:error, reason} ->
        IO.puts(:stderr, "Error creating dm-verity metadata: #{reason}")
        System.halt(1)
    end
  end

  defp fetch_rootfs_env() do
    case System.get_env("NERVES_VERITY_ROOTFS") do
      nil -> {:error, "$NERVES_VERITY_ROOTFS is not set"}
      path -> {:ok, path}
    end
  end

  @env_options [
    {"NERVES_VERITY_ALGORITHM", :algorithm},
    {"NERVES_VERITY_SALT", :salt},
    {"NERVES_VERITY_UUID", :uuid},
    {"NERVES_VERITY_DATA_BLOCK_SIZE", :data_block_size},
    {"NERVES_VERITY_HASH_BLOCK_SIZE", :hash_block_size},
    {"NERVES_VERITY_SIGNING_KEY", :signing_key},
    {"NERVES_VERITY_SIGNING_CERT", :signing_cert}
  ]
  defp options_from_env() do
    for {name, key} <- @env_options, value = System.get_env(name) do
      {key, parse_env_value(key, value)}
    end
  end

  defp parse_env_value(key, value) when key in [:data_block_size, :hash_block_size] do
    case Integer.parse(value) do
      {size, ""} -> size
      _other -> value
    end
  end

  defp parse_env_value(_key, value), do: value

  defp parse_options(opts) do
    with :ok <- check_keys(opts),
         {:ok, algorithm} <- parse_algorithm(opts[:algorithm] || :sha256),
         {:ok, salt} <- parse_salt(opts[:salt]),
         {:ok, uuid} <- parse_uuid(opts[:uuid]),
         {:ok, data_block_size} <- parse_block_size(:data_block_size, opts),
         {:ok, hash_block_size} <- parse_block_size(:hash_block_size, opts),
         {:ok, signing} <- parse_signing(opts) do
      digest_size = byte_size(:crypto.hash(algorithm, <<>>))

      if hash_block_size >= 2 * digest_size do
        {:ok,
         %{
           algorithm: algorithm,
           salt: salt,
           uuid: uuid,
           data_block_size: data_block_size,
           hash_block_size: hash_block_size,
           digest_size: digest_size,
           signing: signing
         }}
      else
        {:error, ":hash_block_size is too small for #{algorithm} digests"}
      end
    end
  end

  defp check_keys(opts) do
    valid_keys = [
      :algorithm,
      :salt,
      :uuid,
      :data_block_size,
      :hash_block_size,
      :signing_key,
      :signing_cert
    ]

    invalid =
      Enum.find(opts, fn
        {key, _value} -> key not in valid_keys
        _other -> true
      end)

    case invalid do
      nil -> :ok
      option -> {:error, "unknown option #{inspect(option)}"}
    end
  end

  defp parse_algorithm(algorithm) when algorithm in @supported_algorithms, do: {:ok, algorithm}
  defp parse_algorithm("sha256"), do: {:ok, :sha256}
  defp parse_algorithm("sha512"), do: {:ok, :sha512}

  defp parse_algorithm(other) do
    {:error, ":algorithm must be :sha256 or :sha512, got: #{inspect(other)}"}
  end

  defp parse_salt(nil), do: {:ok, :derived}

  defp parse_salt(hex) when is_binary(hex) do
    case Base.decode16(hex, case: :mixed) do
      {:ok, salt} when byte_size(salt) <= @max_salt_size ->
        {:ok, salt}

      {:ok, _too_long} ->
        {:error, ":salt must be at most #{@max_salt_size} bytes"}

      :error ->
        {:error, ":salt must be a hex-encoded string, got: #{inspect(hex)}"}
    end
  end

  defp parse_salt(other),
    do: {:error, ":salt must be a hex-encoded string, got: #{inspect(other)}"}

  defp parse_uuid(nil), do: {:ok, :derived}

  defp parse_uuid(uuid) when is_binary(uuid) do
    case Base.decode16(String.replace(uuid, "-", ""), case: :mixed) do
      {:ok, raw} when byte_size(raw) == 16 -> {:ok, raw}
      _other -> {:error, ":uuid must be a UUID string, got: #{inspect(uuid)}"}
    end
  end

  defp parse_uuid(other), do: {:error, ":uuid must be a UUID string, got: #{inspect(other)}"}

  defp parse_signing(opts) do
    case {opts[:signing_key], opts[:signing_cert]} do
      {nil, nil} ->
        {:ok, nil}

      {key, cert} when is_binary(key) and is_binary(cert) ->
        cond do
          not File.exists?(key) ->
            {:error, ":signing_key not found: #{key}"}

          not File.exists?(cert) ->
            {:error, ":signing_cert not found: #{cert}"}

          System.find_executable("openssl") == nil ->
            {:error, "openssl is required to sign the root hash. Please install OpenSSL."}

          true ->
            {:ok, {key, cert}}
        end

      _other ->
        {:error, ":signing_key and :signing_cert must both be set to sign the root hash"}
    end
  end

  defp parse_block_size(key, opts) do
    case Keyword.get(opts, key, @default_block_size) do
      size
      when is_integer(size) and size >= 512 and size <= 524_288 and band(size, size - 1) == 0 ->
        {:ok, size}

      other ->
        {:error,
         "#{inspect(key)} must be a power of two between 512 and 524288, got: #{inspect(other)}"}
    end
  end

  defp data_size(path) do
    case File.stat(path) do
      {:ok, %File.Stat{size: 0}} -> {:error, "#{path} is empty"}
      {:ok, %File.Stat{size: size}} -> {:ok, size}
      {:error, reason} -> {:error, "could not read #{path}: #{inspect(reason)}"}
    end
  end

  defp write_verity_metadata(path, size, config) do
    %{data_block_size: data_block_size, hash_block_size: hash_block_size} = config

    data_blocks = ceil_div(size, data_block_size)
    padded_size = data_blocks * data_block_size
    salt = resolve_salt(config.salt, path, padded_size - size)

    digests = data_block_digests(path, salt, config)

    # The level list is ordered top (root) first, which is also the on-disk
    # order of the hash tree after the superblock.
    levels =
      if data_blocks == 1 do
        []
      else
        build_levels([pack_digests(digests, config)], salt, config)
      end

    root_hash =
      case levels do
        [] -> hd(digests)
        [top | _lower] -> block_digest(top, salt, config.algorithm)
      end

    uuid = resolve_uuid(config.uuid, root_hash)
    superblock = superblock(uuid, salt, data_blocks, config)

    metadata = [superblock, zeros(hash_block_size - @superblock_size) | levels]

    root_hash_hex = Base.encode16(root_hash, case: :lower)
    root_hash_path = path <> @roothash_extension
    verity_path = path <> @verity_extension

    with :ok <- append_file(path, zeros(padded_size - size)),
         :ok <- write_file(verity_path, metadata),
         :ok <- write_file(root_hash_path, root_hash_hex),
         {:ok, root_hash_sig_path} <- sign_root_hash(config.signing, root_hash_path) do
      {:ok,
       %{
         root_hash: root_hash_hex,
         root_hash_path: root_hash_path,
         root_hash_sig_path: root_hash_sig_path,
         verity_path: verity_path,
         salt: Base.encode16(salt, case: :lower),
         uuid: uuid_to_string(uuid),
         algorithm: config.algorithm,
         data_block_size: data_block_size,
         hash_block_size: hash_block_size,
         data_blocks: data_blocks,
         hash_offset: padded_size
       }}
    end
  end

  # Sign the hex root hash the way the kernel's dm-verity signature
  # verification, veritysetup, and systemd expect: a detached PKCS#7
  # signature of the hex string. This is the command documented in the
  # veritysetup man page for --root-hash-signature.
  defp sign_root_hash(nil, _root_hash_path), do: {:ok, nil}

  defp sign_root_hash({key, cert}, root_hash_path) do
    sig_path = root_hash_path <> ".p7s"

    args = [
      "smime",
      "-sign",
      "-nocerts",
      "-noattr",
      "-binary",
      "-in",
      root_hash_path,
      "-inkey",
      key,
      "-signer",
      cert,
      "-outform",
      "der",
      "-out",
      sig_path
    ]

    case System.cmd("openssl", args, stderr_to_stdout: true) do
      {_output, 0} -> {:ok, sig_path}
      {output, status} -> {:error, "signing the root hash failed (#{status}): #{output}"}
    end
  end

  # The default salt is the hash of the padded data area. This is
  # deterministic to support reproducible builds, unique per filesystem, and
  # just as public as a random salt would be since dm-verity stores the salt
  # in the superblock.
  defp resolve_salt(:derived, path, pad_bytes) do
    hash_file(path, :sha256, zeros(pad_bytes))
  end

  defp resolve_salt(salt, _path, _pad_bytes) when is_binary(salt), do: salt

  # The default UUID is derived from the root hash with the version and
  # variant bits set per RFC 4122 so that it's deterministic.
  defp resolve_uuid(:derived, root_hash) do
    <<a::binary-6, _::4, b::12, _::2, c::62, _rest::binary>> =
      :crypto.hash(:sha256, ["nerves-verity-uuid", root_hash])

    <<a::binary, 4::4, b::12, 2::2, c::62>>
  end

  defp resolve_uuid(uuid, _root_hash) when is_binary(uuid), do: uuid

  defp uuid_to_string(<<a::binary-4, b::binary-2, c::binary-2, d::binary-2, e::binary-6>>) do
    Enum.map_join([a, b, c, d, e], "-", &Base.encode16(&1, case: :lower))
  end

  defp hash_file(path, algorithm, trailer) do
    fd = File.open!(path, [:read, :binary, :raw, :read_ahead])

    try do
      hash_fd(fd, :crypto.hash_init(algorithm), trailer)
    after
      _ = File.close(fd)
    end
  end

  defp hash_fd(fd, context, trailer) do
    case :file.read(fd, 65_536) do
      {:ok, data} -> hash_fd(fd, :crypto.hash_update(context, data), trailer)
      :eof -> :crypto.hash_final(:crypto.hash_update(context, trailer))
    end
  end

  # Hash each data block, zero-padding the final partial block if the file
  # size isn't a multiple of the data block size
  defp data_block_digests(path, salt, config) do
    fd = File.open!(path, [:read, :binary, :raw, :read_ahead])

    try do
      read_digests(fd, salt, config, [])
    after
      _ = File.close(fd)
    end
  end

  defp read_digests(fd, salt, config, acc) do
    %{data_block_size: data_block_size, algorithm: algorithm} = config

    case :file.read(fd, data_block_size) do
      {:ok, block} when byte_size(block) == data_block_size ->
        read_digests(fd, salt, config, [block_digest(block, salt, algorithm) | acc])

      {:ok, partial} ->
        padded = [partial, zeros(data_block_size - byte_size(partial))]
        read_digests(fd, salt, config, [block_digest(padded, salt, algorithm) | acc])

      :eof ->
        Enum.reverse(acc)
    end
  end

  # dm-verity hash_type 1 digests are hash(salt || data)
  defp block_digest(block, salt, algorithm), do: :crypto.hash(algorithm, [salt, block])

  # Build hash tree levels up from level 0 (the data block digests) until a
  # level fits in a single hash block. The accumulator keeps the highest
  # level first.
  defp build_levels([current | _lower] = levels, salt, config) do
    %{hash_block_size: hash_block_size, algorithm: algorithm} = config

    if byte_size(current) == hash_block_size do
      levels
    else
      digests =
        for <<block::binary-size(^hash_block_size) <- current>> do
          block_digest(block, salt, algorithm)
        end

      build_levels([pack_digests(digests, config) | levels], salt, config)
    end
  end

  # Pack digests into hash blocks the way the kernel expects: each digest is
  # zero-padded to the next power of two and the unused end of each hash
  # block is zero-filled
  defp pack_digests(digests, config) do
    %{hash_block_size: hash_block_size, digest_size: digest_size} = config

    slot_size = next_power_of_two(digest_size)
    digests_per_block = div(hash_block_size, slot_size)
    slot_pad = zeros(slot_size - digest_size)

    digests
    |> Enum.chunk_every(digests_per_block)
    |> Enum.map(fn block_digests ->
      slots = Enum.map(block_digests, &[&1, slot_pad])
      [slots, zeros(hash_block_size - length(block_digests) * slot_size)]
    end)
    |> IO.iodata_to_binary()
  end

  defp superblock(uuid, salt, data_blocks, config) do
    algorithm_name = Atom.to_string(config.algorithm)

    <<"verity", 0, 0, 1::little-32, 1::little-32, uuid::binary,
      pad_zeros(algorithm_name, 32)::binary, config.data_block_size::little-32,
      config.hash_block_size::little-32, data_blocks::little-64, byte_size(salt)::little-16,
      0::6-unit(8), pad_zeros(salt, @max_salt_size)::binary, 0::168-unit(8)>>
  end

  defp append_file(path, iodata) do
    case File.open(path, [:append, :binary, :raw], &:file.write(&1, iodata)) do
      {:ok, :ok} -> :ok
      {:ok, {:error, reason}} -> {:error, "could not write #{path}: #{inspect(reason)}"}
      {:error, reason} -> {:error, "could not write #{path}: #{inspect(reason)}"}
    end
  end

  defp write_file(path, contents) do
    case File.write(path, contents) do
      :ok -> :ok
      {:error, reason} -> {:error, "could not write #{path}: #{inspect(reason)}"}
    end
  end

  defp ceil_div(n, d), do: div(n + d - 1, d)

  defp next_power_of_two(n), do: next_power_of_two(1, n)
  defp next_power_of_two(power, n) when power >= n, do: power
  defp next_power_of_two(power, n), do: next_power_of_two(power <<< 1, n)

  defp pad_zeros(data, size), do: data <> zeros(size - byte_size(data))

  defp zeros(0), do: <<>>
  defp zeros(count) when count > 0, do: :binary.copy(<<0>>, count)
end
